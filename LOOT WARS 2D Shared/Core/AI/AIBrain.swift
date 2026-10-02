//
//  AIBrain.swift
//  Loot Wars
//
//  Turns a bot's situation into Commands - the same Commands the joystick produces.
//
//  The brain is a pure function with no memory of its own: everything it remembers
//  lives in the actor's AIState. All randomness comes from world.rng, never from
//  Int.random, so the same seed always produces the same match.
//
//  It works in headings rather than waypoints, and that is the important bit.
//  Walking to a point means arriving, stopping, and standing there until the next
//  decision - which is exactly the stop-start shuffle that gives a bot away. Here a
//  bot always has a heading and is always moving along it; deciding only ever
//  changes where it WANTS to go, and the steering below eases it round.
//
//  Every goal answers in the same currency - a direction - so when fighting and
//  looting arrive, they steer through this same layer and inherit the same feel.
//

import Foundation

enum AIBrain {

    static func think(for actor: inout Actor, in world: World, dt: Double) -> [Command] {
        guard var state = actor.ai else { return [] }

        state.goalAge += dt
        state.lootCooldown = max(0, state.lootCooldown - dt)
        state.buildUrgeTimer = max(0, state.buildUrgeTimer - dt)
        // Faster while somebody else is running away with the match - see
        // GameConfig.AI.leaderRush. Both the urges that point at the leader.
        let rush = 1 + (world.runaway(against: actor.team)?.lead ?? 0) * GameConfig.AI.leaderRush
        state.raidUrgeTimer = max(0, state.raidUrgeTimer - dt * rush)
        state.huntUrgeTimer = max(0, state.huntUrgeTimer - dt * rush)
        state.stashCooldown = max(0, state.stashCooldown - dt)
        state.healTimer = max(0, state.healTimer - dt)
        state.placeTimer = max(0, state.placeTimer - dt)

        // Noticing the base is finished, so a gap in it later can be told apart
        // from never having built it. Checked here rather than on the decision
        // timer: the moment of completion is brief and easy to walk past.
        if !world.baseIsBreached(actor.team) { state.baseWasComplete = true }
        state.reactionTimer = max(0, state.reactionTimer - dt)
        state.fightCooldown = max(0, state.fightCooldown - dt)
        state.decisionTimer -= dt

        let carryingPerk = actor.inventory.slots.contains { $0?.type.perk != nil }
        state.perkHeldFor = carryingPerk ? state.perkHeldFor + dt : 0

        // Being shot at cancels giving up. Walking away from somebody you cannot
        // reach is sensible; ignoring somebody who is hitting you is not.
        if actor.secondsSinceHit < GameConfig.AI.combatRecency {
            state.fightCooldown = 0
        }

        // A raid keeps its place in the queue while its owner is being fought off.
        //
        // The clock is PAUSED rather than merely generous, and the difference is
        // the whole point: a defender who turns up is the most likely reason a raid
        // takes a long time, so a hold that ran down during the fight would expire
        // precisely in the case it exists to cover. Dealing with somebody is part
        // of the raid, not an interruption to be charged for.
        if !state.goal.isCombat, actor.secondsSinceHit >= GameConfig.AI.combatRecency {
            state.raidHold = max(0, state.raidHold - dt)
        }

        if state.raidHold <= 0 { state.raidingBase = nil }


        if state.decisionTimer <= 0 {
            changeOfMind(&state, actor: actor, in: world)
            state.decisionTimer = Double.random(in: GameConfig.AI.decisionInterval,
                                                using: &world.rng)
        }

        // Danger runs on its own, much faster clock. Waiting up to three seconds for
        // the ordinary decision timer to notice somebody shooting at you is most of
        // the reason fights never started.
        state.threatScanTimer -= dt
        if state.threatScanTimer <= 0 {
            reactToThreats(&state, actor: actor, in: world)
            state.threatScanTimer = GameConfig.AI.threatScanInterval
        }

        // Steering runs every tick. Only committing to a direction twice a second
        // would let a bot sail straight past what it was walking to.
        steerTowardsGoal(&state, actor: actor, in: world)

        // Before the obstacle pass, so a weave never steers into a wall.
        dodgeWhileRaiding(&state, actor: actor, in: world)

        // Looking where you are going happens every tick, not on the decision timer.
        // Waiting up to three seconds to notice a tree is how a bot ends up grinding
        // into one in full view.
        //
        // No exemption here any more. It used to skip obstacle avoidance while a
        // bot was pressed against a chest breaking it open, because the chest WAS
        // the obstacle and steering round it cancelled the raid. A chest is shot
        // from a distance now, so a bot raiding one has no reason to be standing in
        // it and every reason to keep steering round the furniture.
        steerAroundObstacles(&state, actor: actor, in: world)

        // Gas is walked around, and LATE - see avoidGas. Still above the goal list,
        // because no errand is worth standing in a cloud for, but no longer above
        // running for your life, and no longer instant.
        avoidGas(&state, actor: actor, dt: dt, in: world)

        // The edge nudge is for roaming. Applying it in a fight fights the bot's
        // own attempt to hold its range near a border.
        if !state.goal.isFight {
            curveAwayFromEdges(&state, actor: actor, in: world)
        }

        // Last, and over the top of everything above: a bot that is not moving is a
        // bot that has to stop doing whatever it is doing.
        shoveOffIfStuck(&state, actor: actor, dt: dt, in: world)

        // Turn towards the desired heading rather than snapping to it.
        state.heading = turn(state.heading,
                             towards: state.desiredHeading,
                             limit: GameConfig.AI.turnRate * dt)

        var commands: [Command] = [.move(state.heading)]

        if let wall = wallToLay(&state, actor: actor, in: world) {
            commands.append(.placeBlock(wall))
            actor.ai = state
        }

        if let stand = arcadeToPlace(actor: actor, in: world) {
            commands.append(.placeArcade(stand.origin, stand.kind))
        }

        if let origin = turretToPlace(actor: actor, in: world) {
            commands.append(.placeTurret(origin))
        }

        if let tile = chestToPlace(actor: actor, in: world) {
            commands.append(.placeChest(tile))
        }

        if let slot = bombToThrow(state: state, actor: actor, in: world) {
            commands.append(.useItem(slot: slot))
        }

        if let slot = stinkToThrow(state: state, actor: actor, in: world) {
            commands.append(.useItem(slot: slot))
        }

        if let purchase = purchaseToMake(actor: actor, in: world) {
            commands.append(.buyItem(purchase))
        }

        // Anything in the bag that beats what it is wearing goes on at once. This
        // is how a bot re-arms itself after respawning bare-headed, from a spare it
        // picked up earlier - the same move a player makes from the hotbar.
        if let slot = (0..<Inventory.slotCount).first(where: {
            EquipSystem.canEquip(slot: $0, actor: actor)
        }) {
            commands.append(.useItem(slot: slot))
        }

        // Before reaching for a bandage, because that is the order a player uses
        // them in: the perk is what you spend when the fight is still on, the
        // bandage is what you spend when it is over.
        if let slot = perkToUse(state: state, actor: actor, in: world) {
            commands.append(.useItem(slot: slot))
        }

        if let slot = healToUse(&state, actor: actor) {
            commands.append(.useItem(slot: slot))
            actor.ai = state
        }

        // Worked out entirely separately from where the bot is walking, so it can
        // back off, circle or run for home without ever taking the blaster off its
        // target. That one separation is what stops fights collapsing into two bots
        // walking into each other.
        // Worked out once and used twice: line of sight is a raycast against every
        // tree and crate on the map, and this is the most expensive thing a brain
        // does. Asking again for the staleness check below would double it.
        let shot = shotToTake(state: state, actor: actor, in: world)

        if let aim = shot {
            commands.append(.shoot(aim))
        }

        // A fight with no shot in it is going nowhere. This is the bot hanging
        // outside a base trying to reach somebody stood behind their own wall,
        // which it can neither shoot through nor walk through - so it counts the
        // time it has spent achieving nothing and eventually goes back to the
        // match. Any shot at all resets it, so a real firefight never trips it.
        if state.goal.isFight, shot == nil {
            state.fightStale += dt

            if state.fightStale > GameConfig.AI.fightPatience {
                state.fightStale = 0
                state.fightCooldown = GameConfig.AI.fightCooldown
                state.goal = .wander
                state.goalAge = 0
                state.decisionTimer = 0
            }
        } else {
            state.fightStale = 0
        }

        actor.ai = state

        // Open whatever is within reach, whatever the bot was busy doing. Walking
        // past an open-able crate and ignoring it is the sort of thing that gives
        // a bot away.
        // Nothing here about breaking a chest open any more: a chest is SHOT open,
        // so a bot raiding one does it through shotToTake, the same way it takes a
        // machine apart. See GameConfig.Chest.health.

        // Standing at its OWN chest under-equipped: take the gear back out.
        //
        // Bots only ever emptied chests belonging to somebody else, which was fine
        // while dying cost a rung or two. It takes everything now, so a bot with a
        // stocked chest ten tiles away and nothing on its head has to be able to do
        // the obvious thing - and it is the same obvious thing the player has to
        // learn to do, demonstrated seven times a match.
        if let chest = world.reachableChest(for: actor), chest.owner == actor.team,
           let slot = gearWorthTaking(from: chest, actor: actor) {
            commands.append(.takeItem(chest: chest.id, slot: slot))
        }

        if world.reachableLootbox(for: actor) != nil {
            commands.append(.openLootbox)

            // Whatever falls out is right there. Re-decide on the next tick so the
            // bot turns for it immediately, instead of wandering off and only
            // noticing seconds later when the timer happens to come round.
            state.decisionTimer = 0
            actor.ai = state
        }

        return commands
    }

    // MARK: - Deciding

    private static func changeOfMind(_ state: inout AIState, actor: Actor, in world: World) {
        // Been walking at the same crate for a while and still not there? Something
        // is in the way that steering cannot solve. Give up and look elsewhere.
        switch state.goal {
        case .loot(let id) where world.lootboxes[id]?.supply == true:
            // No patience at a supply drop. Standing at a locked crate for twenty
            // seconds is not a bot that is stuck, it is a bot that is waiting -
            // which is the whole idea of one.
            break
        case .loot, .collect:
            if state.goalAge > GameConfig.AI.lootPatience {
                state.lootCooldown = GameConfig.AI.lootCooldown
            }
        case .robChest:
            // Same clock as a crate. A bot that cannot get to a chest has usually
            // found a base that is not as open as its wall plan suggested.
            if state.goalAge > GameConfig.AI.lootPatience {
                state.lootCooldown = GameConfig.AI.lootCooldown
            }
        case .farm(let id):
            // Arrived, or given up trying to. Either way take the cooldown, so a
            // bot sweeps a machine and moves on rather than orbiting an empty one -
            // which is the camping the payout cap exists to prevent, and it would
            // be a poor look to have the bots do it.
            //
            // The tokens themselves are picked up by .collect on the way in, so by
            // the time it is standing here there is nothing left to wait for.
            let arrived = world.arcade(id).map {
                $0.hitbox.expanded(by: GameConfig.AI.arcadeReach).contains(actor.position)
            } ?? true

            if arrived || state.goalAge > GameConfig.AI.lootPatience {
                state.lootCooldown = GameConfig.AI.lootCooldown
            }
        case .defend:
            // No patience at all, deliberately. Every other errand here can be
            // given up on; this one ends when the intruder leaves or dies, and
            // steerTowardsGoal drops it the moment either happens. A defender that
            // times out is a defender somebody can outwait.
            break
        case .wreck, .silence:
            // The same clock a crate gets. A machine that cannot be got at is
            // usually one behind a wall the bot has no way through.
            if state.goalAge > GameConfig.AI.lootPatience {
                state.lootCooldown = GameConfig.AI.lootCooldown
            }
        case .rearm:
            // The same clock a crate gets. A bot that cannot reach its own chest
            // has usually had its base taken apart around it, and standing in the
            // rubble is not the answer.
            if state.goalAge > GameConfig.AI.lootPatience {
                state.lootCooldown = GameConfig.AI.lootCooldown
            }
        case .stash:
            // Backs off exactly as a build trip does when something is in the way.
            if state.goalAge > GameConfig.Build.patience {
                state.stashCooldown = GameConfig.Build.patience
            }
        case .build:
            if state.goalAge > GameConfig.Build.patience {
                // Clearing the allowance is what releases the commitment above -
                // otherwise a bot that cannot reach its wall would hold onto the
                // trip forever.
                state.blocksLeftToLay = 0
                state.buildUrgeTimer = Double.random(in: GameConfig.Build.urgeInterval,
                                                     using: &world.rng)
            }
        case .hunt:
            // A hunt gives up. It is the only errand here that can be walked all
            // the way to the end of and still have found nothing, because the thing
            // it is looking for moves - and a bot thirty seconds into an empty
            // search is a bot that has left its own match to go for a walk.
            //
            // Giving up costs it a fresh urge, so it does not simply re-pick the
            // same quarry on the next tick and walk the same empty line again.
            if state.goalAge > GameConfig.AI.huntPatience {
                state.huntUrgeTimer = Double.random(in: GameConfig.AI.huntUrgeInterval,
                                                    using: &world.rng)
                state.huntMark = nil
            }
        case .wander, .fight, .retreat, .raid:
            // Raiding needs no patience of its own: it ends the moment the wall
            // falls or the last bomb is spent, and raidTarget stops offering it.
            break
        }

        // A base with nothing left standing in it is a base this bot has finished
        // with, and it stops being remembered the moment it is picked clean rather
        // than when the hold runs out.
        //
        // Gated on being THERE, which is the whole care needed here: out of range,
        // remaining() would be answering about a base the bot cannot see, and a
        // raid abandoned under fire would be forgotten at exactly the moment the
        // memory exists to survive. And gated on nothing else - see remaining(),
        // which deliberately has no opinion about the bot's own condition.
        if let victim = state.raidingBase,
           nearEnoughToReturn(to: victim, from: actor, in: world),
           remaining(at: victim, for: actor, in: world) == nil {
            state.raidingBase = nil
            state.raidHold = 0
        }

        var wanted = chooseGoal(for: actor, state: state, in: world)

        // Re-point at the current next wall rather than the one chosen minutes ago,
        // which may well have been laid by now.
        if case .build = wanted, case .build = state.goal,
           let current = world.nextBuildTile(for: actor.team) {
            wanted = .build(current)
        }

        if case .build = wanted, !state.goal.isBuild {
            // Three sizes of armful, in order of urgency. A hole in a finished
            // base is the urgent one: it has to be enough to actually close the
            // breach, or the bot walks off with its base still open and gets
            // robbed again by the next person past. Behind on the wall is the
            // slow-burn one - see GameConfig.Build.blocksWhenBehind for why the
            // armful, and not the priority bump, is what closes that gap.
            let armful: ClosedRange<Int>

            if !state.baseWasComplete {
                armful = GameConfig.Build.blocksWhenUnsealed
            } else if world.baseIsBreached(actor.team) {
                armful = GameConfig.Build.blocksWhenBreached
            } else if world.isFallingBehind(actor.team) {
                armful = GameConfig.Build.blocksWhenBehind
            } else {
                armful = GameConfig.Build.blocksPerVisit
            }

            state.blocksLeftToLay = Int.random(in: armful, using: &world.rng)
        }

        // A raid has been taken on: the urge is spent, whether or not it ends in
        // a chest being emptied. Resetting on the ATTEMPT rather than on success is
        // what stops a bot that cannot reach anybody from trying every single tick
        // for the rest of the match.
        if wanted.isRaiding, !state.goal.isRaiding {
            state.raidUrgeTimer = Double.random(in: GameConfig.AI.raidUrgeInterval,
                                                using: &world.rng)
        }

        // And it remembers WHOSE, which is the thing none of the raiding goals
        // could say on their own - see AIState.raidingBase.
        //
        // Refreshed on every raiding goal rather than only on the first, so a bot
        // that opens a wall, takes the chest and starts on the machine is holding a
        // hold that reaches to the end of the job rather than one that started
        // running down at the wall.
        if wanted.isRaiding, let victim = base(of: wanted, in: world) {
            state.raidingBase = victim
            state.raidHold = GameConfig.AI.raidHold
        }

        // Same bargain for a hunt, and for the same reason: spent on setting off
        // rather than on catching anybody, so a bot that never finds its quarry
        // does not re-ask for the rest of the match. A fresh hunt also starts with
        // no mark, so it walks at the quarry's base until it sees them - see
        // AIState.huntMark.
        if case .hunt = wanted, !isHunt(state.goal) {
            state.huntUrgeTimer = Double.random(in: GameConfig.AI.huntUrgeInterval,
                                                using: &world.rng)
            state.huntMark = nil
        }

        if wanted != state.goal {
            // Only a NEW fight costs a reaction - a bot already shooting at someone
            // does not freeze up again every time it re-picks the same target.
            if wanted.isCombat, !state.goal.isCombat {
                state.reactionTimer = reactionDelay(for: actor, in: world)
            }
            state.goal = wanted
            state.goalAge = 0
        }

        // Rolled as a unit value and turned into an angle at the moment of firing,
        // where the range is known. See GameConfig.AI.aimSpread.
        state.aimNoise = Double.random(in: -1...1, using: &world.rng)

        if Double.random(in: 0..<1, using: &world.rng) < GameConfig.AI.strafeFlipChance {
            state.strafeDirection *= -1
        }

        if case .wander = state.goal {
            // Swing off the CURRENT heading rather than picking a fresh direction
            // out of the air, so a change of mind is a course correction and not a
            // pirouette.
            let swing = Double.random(in: -GameConfig.AI.wanderTurn...GameConfig.AI.wanderTurn,
                                      using: &world.rng)
            state.desiredHeading = Vec2.fromAngle(state.heading.angle + swing)
        }
    }

    /// Spotting an enemy interrupts whatever the bot was doing.
    ///
    /// Only picking a NEW fight - a bot already fighting or already running is left
    /// alone, so this cannot re-trigger the reaction delay every tenth of a second.
    private static func reactToThreats(_ state: inout AIState, actor: Actor, in world: World) {
        // Already running - nothing to reconsider.
        if state.goal.isRetreat { return }

        // Mid-fight and hurt: break off NOW. Waiting for the ordinary decision
        // timer means up to three more seconds of standing there being shot, which
        // is most of why a bot on its last legs looks like it is loitering.
        if case .fight(let id) = state.goal {
            let healthLeft = Double(actor.health) / Double(actor.maxHealth)
            if healthLeft < GameConfig.AI.retreatHealthFraction * state.caution {
                state.goal = .retreat(from: id)
                state.goalAge = 0
            }
            return
        }

        guard state.fightCooldown <= 0 else { return }

        // An open supply drop within reach is grabbed, not fought over: nothing
        // seen - not even being shot - turns a bot away from the best item in the
        // game when it is a few steps from it. See grabbableSupply.
        //
        // Unless somebody else is going to get there first. Then the drop is lost
        // to the run, and the only way to win it is to shoot them - which the case
        // below lets happen, because this bot is at the drop.
        if case .loot(let id) = state.goal,
           let drop = world.lootboxes[id], drop.supply, !drop.isLocked,
           (drop.position - actor.position).length <= GameConfig.SupplyDrop.botGrabRange,
           firstInLine(for: drop, actor: actor, in: world) {
            return
        }

        switch state.goal {
        case .fight, .retreat:
            return

        case .loot(let id) where world.lootboxes[id]?.supply == true:
            // On the way to a drop, the same rule as a raid: seeing somebody is
            // not a reason to stop, being hit is.
            //
            // AT the drop it is the opposite. Everybody there is waiting for the
            // same crate, and standing politely in a crowd until it opens is not a
            // plan - the crate goes to whoever is still alive. So near it, any
            // enemy in sight is reason enough. See contestedDrop.
            guard contestedDrop(near: actor, in: world) != nil
                    || actor.secondsSinceHit < GameConfig.AI.combatRecency else { return }

        case .raid, .robChest, .wreck, .silence:
            // Mid-raid, and this is the one thing worth NOT reacting to.
            //
            // A raider has spent a bomb, crossed the map and is standing in
            // somebody's base with their chest in front of it. Turning to fight the
            // owner there is how a raid ends with nothing taken: the bomb is gone,
            // the hole is made, and the bot spends the next twenty seconds circling
            // a person instead of the two it needed for the chest. Seeing somebody
            // is not a reason to stop. Being HIT by them is, and that is the test.
            //
            // And it is what makes a defender's shots matter: a raider that refuses
            // to be distracted is one who has to actually be shot off the chest
            // rather than merely walked up to.
            guard actor.secondsSinceHit < GameConfig.AI.combatRecency else { return }

        case .wander, .loot, .collect, .build, .farm, .stash, .rearm, .defend, .hunt:
            // All interruptible, and the hunt MOST of all: getting close enough to
            // be interrupted is the entire job it was given. This is the line
            // where a hunt turns into a fight.
            //
            // All interruptible. A bot laying bricks - or lining up a throw, or
            // waiting on a payout - while somebody shoots at it is not a bot
            // anyone believes in.
            break
        }

        guard let enemy = nearestVisibleEnemy(to: actor, in: world) else { return }

        let healthLeft = Double(actor.health) / Double(actor.maxHealth)

        if healthLeft < GameConfig.AI.retreatHealthFraction * state.caution {
            state.goal = .retreat(from: enemy.id)
        } else {
            // Spotting somebody is no longer a reason to drop everything. It has to
            // be a fight worth interrupting a trip home for - or a rival for a drop
            // this bot is standing at.
            guard shouldEngage(enemy, actor: actor, in: world)
                    || isRivalForDrop(enemy, actor: actor, in: world) else { return }
            state.goal = .fight(enemy.id)
        }

        state.goalAge = 0
        state.reactionTimer = reactionDelay(for: actor, in: world)
    }

    /// Priority order: staying alive, then fighting, then loot, then roaming.
    private static func chooseGoal(for actor: Actor, state: AIState, in world: World) -> AIGoal {
        // An OPEN supply drop close by beats everything, fighting included. It is
        // the hottest thing on the map, it goes to whoever touches it first, and a
        // bot trading shots beside an open one is handing it to the player.
        //
        // Unless somebody is going to beat it there. Then the run is lost and the
        // only way to the crate is through them, so it shoots whoever is nearest
        // the crate instead.
        if let drop = grabbableSupply(for: actor, in: world) {
            if firstInLine(for: drop, actor: actor, in: world) {
                return .loot(drop.id)
            }
            if let rival = nearestRival(to: drop, for: actor, in: world) {
                return .fight(rival.id)
            }
        }

        if state.fightCooldown <= 0, let enemy = nearestVisibleEnemy(to: actor, in: world) {
            let healthLeft = Double(actor.health) / Double(actor.maxHealth)

            // Hurt and in danger: get out. Note this only holds while an enemy is
            // actually near - once it is safe, or once it has drunk its way back to
            // health, the bot turns round and fights rather than hiding at home for
            // the rest of the match.
            //
            // Running is judged on seeing ANYBODY, unlike fighting. You flee from
            // whoever is there; you do not pick who to flee from.
            if healthLeft < GameConfig.AI.retreatHealthFraction * state.caution {
                return .retreat(from: enemy.id)
            }

            // A fight it does not want simply falls through to the rest of the list,
            // and the bot gets on with looting, building or raiding instead.
            //
            // And it does not want one at all while it is mid-raid unless somebody
            // is actually hitting it - the same rule reactToThreats applies, applied
            // here too, or the decision timer would undo on its own clock what the
            // threat scan had just declined to do.
            // A supply run counts as a raid here: it is an errand worth not being
            // distracted from.
            //
            // Only on the WAY to one, though. Once it is there, the people around
            // the drop are the competition and are fought - see contestedDrop.
            let atDrop = contestedDrop(near: actor, in: world) != nil
            let raiding = state.goal.isRaiding
                || (isSupplyRun(state.goal, in: world) && !atDrop)
            let underFire = actor.secondsSinceHit < GameConfig.AI.combatRecency
            let rival = isRivalForDrop(enemy, actor: actor, in: world)

            if !(raiding && !underFire),
               rival || shouldEngage(enemy, actor: actor, in: world) {
                return .fight(enemy.id)
            }
        }

        // Somebody is standing in your base.
        //
        // Above the repair, above the raid, above the loot - above everything
        // except not dying, which is the branch immediately overhead. This is the
        // system that was simply missing: there was no concept of defending a base
        // anywhere in this file, so a raid was a five-second errand run against an
        // absent owner. The only reaction to being broken into was to walk home and
        // REPAIR, and canBuild refuses for the twelve seconds of raid grace, so the
        // owner arrived and stood in the doorway doing nothing at all while their
        // chest was emptied in front of them.
        //
        // It answers on the claim rather than the wall, so it fires while the
        // raider is still climbing through the hole. It is not gated on seeing
        // them: your base being entered is not something you have to spot, and a
        // defender who needed line of sight would be told about it after the raid.
        if let intruder = world.intruder(in: actor.team) {
            return .defend(intruder)
        }

        // A supply drop within reach. This high on purpose: it is the one thing
        // on the map built to start a fight, and bots that let it go would simply
        // hand the best gear in the game to whoever turned up - see
        // SupplyDropSystem. Below defending, because your own base comes first.
        if let drop = supplyWorthContesting(for: actor, in: world) {
            return .loot(drop.id)
        }

        // Somebody has put a hole in a finished base. Everything else waits.
        //
        // Above the build commitment rather than folded into it, because this is
        // not the slow business of building - it is a door standing open, and the
        // chest behind it is being emptied while the bot thinks about it.
        if state.baseWasComplete, world.baseIsBreached(actor.team),
           let wall = world.nextBuildTile(for: actor.team) {
            return .build(wall)
        }

        // The FIRST wall, before anything but a fight.
        //
        // Walls cost nothing. There is no material to fetch, nothing spent, no
        // reason on earth for a bot to have an unfinished base four minutes in -
        // and every version of "make them build faster" so far has been a rate,
        // when the thing actually holding them up was the queue. Below this line
        // sit gear detours, raiding, errands and shopping, and each of them fires
        // readily enough that the build urge underneath rarely got its turn.
        //
        // Only until the base has closed ONCE. After that building goes back to
        // its usual place on the urge timer, and a hole in a finished base is
        // handled above this anyway. So it is not a rule that turns bots into
        // bricklayers - it is a rule that says the opening two minutes are for
        // getting the thing up, which is what the opening two minutes are for.
        //
        // Still on the urge timer, so a bot lays an armful, goes and does
        // something else for three or four seconds, and comes back. It builds fast
        // without going deaf to the rest of the match.
        if !state.baseWasComplete, state.buildUrgeTimer <= 0,
           let wall = world.nextBuildTile(for: actor.team) {
            return .build(wall)
        }

        // Somebody is running away with the match, and this bot has decided to go
        // and do something about it in person.
        //
        // Placed here on purpose: under defending your own base and under getting
        // the first wall up, because those are yours and this is somebody else's
        // problem - but over every errand below, because an errand is exactly what
        // a hunt has always lost to. Everything down there fires readily, and a
        // thing that is always eighth in line never happens.
        //
        // It is the only goal in this list that goes looking for a PERSON. Fights
        // were acquired at twelve tiles by line of sight and dropped again at
        // sixteen, so nothing ever followed anybody: a player who kept moving chose
        // every fight they were in, and choosing your fights is most of what
        // dominating a match consists of.
        if state.huntUrgeTimer <= 0,
           let quarry = worthHunting(for: actor, in: world) {
            return .hunt(quarry.id)
        }

        // Gear on the grass that beats what it is holding.
        //
        // High in the list, and it belongs here for the reason the raid urge does:
        // the problem was never that a bot did not WANT the better blaster, it was
        // that collecting sits at the bottom of this list behind building, raiding
        // and errands, so by the time the question came round it had committed to
        // something else and the drop had expired. Gear decides fights, a fight
        // decides a chunk of the scoreboard, and a rung lying eight tiles away is
        // the cheapest one anybody will ever get.
        //
        // Only a genuine upgrade - Actor.wantsFromGround is the same test that
        // decides whether walking over it would pick it up, so a bot can never set
        // off for something it would then decline - and only within arm's reach of
        // its own route. Below fighting, because a blaster is no use to a corpse.
        if state.lootCooldown <= 0,
           let upgrade = upgradeWorthTheDetour(for: actor, in: world) {
            return .collect(upgrade.id)
        }

        // The raid urge, and this is the highest anything voluntary sits.
        //
        // Above the build commitment on purpose - see AIState.raidUrgeTimer. Every
        // previous attempt at "more raiding" made the targets richer or the bots
        // keener and changed almost nothing, because the problem was never that a
        // bot did not want to rob somebody. It was that by the time the question
        // was asked it had already committed to an armful of walls, and finishing
        // that set another timer, and the cycle closed over the top of raiding.
        //
        // Only when it has what a raid needs, which chestWorthRobbing already
        // knows: supplies to travel on, a way in, and something at the far end
        // worth taking. When it does, it goes now rather than after the wall.
        //
        // FINISH THE JOB FIRST. Standing in a base that is already open, with
        // anything left in it, beats setting out for a different one - and it beats
        // the urge timer, because the timer is there to stop a bot re-deciding to
        // BREAK IN every tick, and this bot is already in. Without it a raider
        // cracked one chest and wandered off past the second one and the machine,
        // which is how a base that had been broken into stayed worth breaking into.
        //
        // Behind the loot cooldown, which is the escape hatch. changeOfMind sets it
        // when a rob or a wreck has run past its patience, and without it a bot
        // that could see the last chest but not get to it would re-pick the same
        // unreachable target every tick for the rest of the match, standing in
        // somebody's base doing nothing at all.
        if state.lootCooldown <= 0,
           let next = unfinishedBusiness(for: actor, in: world) {
            return next
        }

        // The urge picks a BASE, not a chest: an empty chest is no reason to leave a player alone.
        if state.raidUrgeTimer <= 0,
           let raid = raidGoal(for: actor, in: world) {
            return raid
        }

        // A machine standing in a base somebody has already opened.
        //
        // Below the chests, because loot you can carry beats loot you can only
        // deny - but above everything else here, because an open base is a clock:
        // the owner is on their way home to shut it, and after that the machine is
        // behind a wall again.
        if state.raidUrgeTimer <= 0,
           let machine = machineWorthWrecking(for: actor, in: world) {
            return .wreck(machine.id)
        }

        // A trip home is a commitment.
        //
        // Without this a bot re-weighs building against every crate it walks past,
        // and since there is nearly always a crate worth a detour it oscillates
        // between the two - drifting a little way towards each and arriving at
        // neither. Fighting still interrupts, because that is checked above.
        if case .build = state.goal,
           state.blocksLeftToLay > 0,
           let wall = world.nextBuildTile(for: actor.team) {
            return .build(wall)
        }

        // Nothing on its head and a chest at home that has something. Above every
        // other errand and all of the aggression, because a bot that has just
        // respawned bare is not going to win the fight it is walking into, and the
        // whole reason this game asks anybody to keep a base is that it is the
        // thing you come back to.
        //
        // It ends the moment the gear is out of the chest - reArmWanted stops
        // answering once the bot is carrying better than the chest holds - so it
        // cannot become a bot that lives at home.
        //
        // The cooldown gate is not decoration. changeOfMind has always set a loot
        // cooldown when a re-arm runs past its patience, and for two commits nothing
        // read it on this path: a bot that could SEE gear in its own chest and not
        // reach it - wedged between the chest and the wall of a small base, which is
        // where chests get put - re-picked the same errand every tick and spent the
        // rest of the match walking into its own furniture. Exactly the failure the
        // comment above unfinishedBusiness describes, in the one goal that had no
        // gate. Patience that nothing checks is not patience.
        if state.lootCooldown <= 0,
           let chest = reArmWanted(for: actor, in: world) {
            return .rearm(chest.id)
        }

        // A chest in the bag and a base to put it in. Above the aggression list
        // because it is a short errand with a large payoff - a base with no chest in
        // it is a base nobody has any reason to break into, including the bot's own
        // reason to have built it. It ends the moment the chest is out of the bag,
        // so it cannot hold anyone up.
        //
        // No longer waits for a build urge. The urge timer is there to stop bots
        // commuting home constantly, and this is not a commute - the base is already
        // shut, the thing is already in the bag, and the errand ends when it is out
        // of it. All the gate ever did was leave a finished base standing empty for
        // up to eight seconds at a time while its owner carried the reason to raid
        // it around the map.
        if state.stashCooldown <= 0,
           let spot = chestSpotWanted(for: actor, in: world) {
            return .stash(spot)
        }

        // Behind on the wall. Building comes before any of the aggression below,
        // because a bot that never closes its base is a bot that never has a chest
        // worth anyone raiding - including its own reason to exist on this map.
        if world.isFallingBehind(actor.team),
           let wall = world.nextBuildTile(for: actor.team) {
            return .build(wall)
        }

        // FINISH THE RAID YOU STARTED, whatever happened in the middle of it.
        //
        // This replaces a narrower version that only held onto one chest, and only
        // while the goal was already .robChest. Everything it missed is what the
        // bots were doing wrong: a wall bombed open and then walked away from, a
        // machine left standing beside an emptied chest, and above all a raid that
        // a fight had been declared on top of - because a fight REPLACES the goal,
        // so the errand underneath it was simply gone by the time the shooting
        // stopped.
        //
        // It asks a different question from the search below, deliberately. That
        // one prices a base against every other base on the map and against the
        // walk, which is the right question when choosing where to go and the wrong
        // one when you are already standing in the wreckage of somebody's wall: the
        // walk is nothing, the bomb is spent, and raidWorth has just been knocked
        // down by the raid itself. So this asks only whether anything is LEFT.
        if let unfinished = unfinishedRaid(for: actor, state: state, in: world) {
            return unfinished
        }

        // Somebody's chest, and a way to it. This is the top of the aggression
        // list on purpose: raiding is the point of bases existing, and it used to
        // sit below the supply check where it almost never came up.
        if let chest = chestWorthRobbing(for: actor, in: world) {
            return .robChest(chest.id)
        }

        // Standing next to somebody's wall with a bomb in the bag, and no chest
        // worth the trip. Opportunistic vandalism - it opens a base up for later,
        // and for everybody else.
        if let wall = raidTarget(for: actor, in: world) {
            return .raid(wall)
        }

        // Almost out of supplies: go shopping, base or no base. Healing only - a
        // token is no use to a bot that is about to die.
        //
        // Below robbing now, which is safe rather than lucky: chestWorthRobbing
        // refuses to set out on an empty bag, so whenever this branch is true that
        // one was false. The two cannot both want the bot at once.
        if actor.inventory.totalHealing(of: actor.maxHealth) < GameConfig.AI.emergencyHealingStock,
           state.lootCooldown <= 0 {
            if let item = nearestItem(to: actor, in: world, include: isHealing) {
                return .collect(item.id)
            }
            if let crate = nearestCrate(to: actor, in: world) { return .loot(crate.id) }
        }

        // Otherwise the base gets its turn whenever the urge is up. The urge timer
        // is what balances building against looting, not a running comparison
        // against whatever happens to be lying nearby.
        if state.buildUrgeTimer <= 0, let wall = world.nextBuildTile(for: actor.team) {
            return .build(wall)
        }

        if state.lootCooldown <= 0 {
            // Something already on the ground beats walking to a crate: it is
            // closer, and it is usually the thing this bot just opened.
            if let item = nearestItem(to: actor, in: world) {
                return .collect(item.id)
            }

            // Crate or machine, whichever is actually nearer.
            //
            // Compared by distance rather than ranked, and that is not fussiness.
            // Rank machines above crates and a bot stops opening crates; rank them
            // below and it never visits a machine at all, because with forty-two
            // crates on the map there is always one in range - the fall-through
            // would be unreachable code that reads like a feature. That exact
            // mistake is what stopped bots building their bases a few weeks ago.
            let crate = nearestCrate(to: actor, in: world)
            let machine = nearestArcade(to: actor, in: world)

            switch (crate, machine) {
            case let (crate?, machine?):
                let toCrate = (crate.position - actor.position).length
                let toMachine = (machine.centre - actor.position).length
                return toMachine < toCrate ? .farm(machine.id) : .loot(crate.id)
            case let (crate?, nil):
                return .loot(crate.id)
            case let (nil, machine?):
                return .farm(machine.id)
            case (nil, nil):
                break
            }
        }

        return .wander
    }

    /// A rung of gear, or a power-up, lying close enough to be worth the detour.
    ///
    /// Deliberately narrower than nearestItem: healing and tokens are not worth
    /// interrupting a build or a raid for, and they already have their own places
    /// in the list - the emergency supply check above and the general collect below.
    /// This is only for the things that change what happens the next time somebody
    /// shoots at this bot.
    private static func upgradeWorthTheDetour(for actor: Actor,
                                              in world: World) -> GroundItem? {
        // A genuine upgrade, which this did not check.
        //
        // The filter was "is it a helmet, a blaster or a perk" - any tier, any
        // rung - while the comment above claimed it only ever answered with an
        // upgrade. A bot in a Cosmic would set off across fourteen tiles for a
        // Common, and this branch sits above the build urge, so it fired on nearly
        // every decision and building never got its turn.
        //
        // Harmless once, and then two things made it the reason bases stopped
        // going up. Death started stripping ALL gear, so every kill scatters a
        // helmet and a blaster at up to four-in-five odds and the map is now
        // carpeted in the stuff; and spares became worth picking up, so the bot
        // that walked over the Common took it as well. Between them there was
        // always some gear within range, and a bot with a base to build spent the
        // opening two minutes shopping.
        let candidate = nearestItem(to: actor, in: world, include: { pickup in
            guard case .item(let type) = pickup else { return false }

            switch type {
            case .helmet(let tier):  return tier > actor.helmet
            case .blaster(let tier): return tier > actor.blaster
            // Always worth the walk: one perk is one perk whatever you are wearing.
            case .perk:              return true
            case .bandage, .medkit, .bomb, .stink, .chest, .arcade, .turret: return false
            }
        })

        guard let candidate,
              (candidate.position - actor.position).length
                  <= GameConfig.AI.upgradeSearchRange else { return nil }

        return candidate
    }

    /// The nearest thing on the ground this bot would actually pick up.
    ///
    /// - Parameter include: narrows it to a kind of pickup. This is not decoration:
    ///   a bot down to its last bandage asks for healing specifically, and without
    ///   the filter the nearest wanted item might be a token - sending it to collect
    ///   currency in the exact moment it was about to die for want of a medkit.
    private static func nearestItem(to actor: Actor,
                                    in world: World,
                                    include: (Pickup) -> Bool = { _ in true }) -> GroundItem? {
        var closest: GroundItem?
        var shortest = Double.greatestFiniteMagnitude

        for item in world.groundItems.values {
            guard include(item.pickup) else { continue }

            // Asks the actor the same question the pickup code will, so a bot can
            // never set off for something it would then decline to take.
            guard actor.wants(item.pickup) else { continue }

            // A bandage is worth a few steps. A better helmet is worth a walk - it is
            // the difference between winning the next fight and losing it, so it
            // gets the same reach a crate does.
            let worthTravelling: Double
            switch item.pickup {
            // A perk travels as far as gear does. It is worth about half a health
            // bar in the fight it is spent in, which beats anything else that ends
            // up lying on the grass.
            case .item(.helmet), .item(.blaster), .item(.perk):
                worthTravelling = GameConfig.AI.lootSearchRange
            case .item:
                worthTravelling = GameConfig.AI.itemSearchRange
            case .token:
                worthTravelling = GameConfig.AI.tokenSearchRange
            }

            let distance = (item.position - actor.position).length
            guard distance < worthTravelling, distance < shortest else { continue }
            shortest = distance
            closest = item
        }

        return closest
    }

    /// The wall of the base most worth opening, at the point most worth opening it.
    ///
    /// Two questions, and they are answered in that order. WHICH base is worth what
    /// is inside it less the walk - see World.lootValue, which prices a base once so
    /// this and chestWorthRobbing cannot disagree about which one is rich. WHERE is
    /// then the tile nearest the loot itself, so the hole comes out somewhere
    /// useful: blowing the far side open and walking round is the sort of thing
    /// that makes a bot look like it is following a rule rather than robbing
    /// somebody.
    ///
    /// A machine counts as loot here, which is what puts a base with nothing but an
    /// arcade in it back on the map. The blast that opens a wall beside one usually
    /// takes the machine with it, so the twenty-five tokens come out of the same
    /// bomb as the hole.
    private static func wallGuarding(theLootOf actor: Actor, in world: World) -> GridPoint? {
        var bestTile: GridPoint?
        var bestScore = Double(GameConfig.AI.raidWorthOpening)

        for (team, claim) in world.claims.sorted(by: { $0.key.raw < $1.key.raw })
        where team != actor.team {
            // The whole price, standing and neglect included - see World.raidWorth.
            // This used to ask lootValue, which is only what is in the chests, and
            // then refuse outright on a base worth nothing. That is the line that
            // made the player unraidable: their chest is theirs to fill, so an
            // unbanked or already-cracked base priced at zero and was skipped
            // before any of the reasons to go there were even considered.
            let toBase = (claim.centreTile.center - actor.position).length
            let score = world.raidWorth(of: team) - toBase * GameConfig.AI.raidDistanceCost
            guard score > bestScore else { continue }

            guard let tile = breachTile(into: team, for: actor, in: world) else { continue }
            bestScore = score
            bestTile = tile
        }

        return bestTile
    }

    /// Who is worth crossing the map for.
    ///
    /// The leader, if there is one worth the name - World.lead measures that the
    /// same way for all eight teams, so this points at a runaway bot exactly as
    /// readily as at a runaway player, and the bots do not need to know which they
    /// are looking at.
    ///
    /// Gated on carrying some healing, like the raiding pickers are and for the
    /// same reason: arriving at the best player in the match with an empty pocket
    /// is a donation. That gate is also why a hunt cannot dogpile even when every
    /// bot's urge happens to come round together - the ones that have been losing
    /// fights are out of bandages and stay home.
    ///
    /// Sorted by id, because two teams on the same lead would otherwise resolve out
    /// of dictionary order and two runs of one seed would diverge.
    private static func worthHunting(for actor: Actor, in world: World) -> Actor? {
        guard actor.inventory.totalHealing(of: actor.maxHealth)
                >= GameConfig.AI.emergencyHealingStock else { return nil }

        var best: Actor?
        var bestLead = GameConfig.AI.huntsLeaderAt

        for id in world.actors.keys.sorted(by: { $0.raw < $1.raw }) {
            guard let candidate = world.actors[id],
                  candidate.isAlive,
                  candidate.team != actor.team else { continue }

            let ahead = world.lead(of: candidate.team)
            guard ahead > bestLead else { continue }

            bestLead = ahead
            best = candidate
        }

        return best
    }

    /// An enemy chest worth going for.
    ///
    /// Two ways in, and adding the second is most of why raids were so rare. A
    /// base already breached can simply be walked into. A base still sealed can be
    /// OPENED - and a bot carrying a bomb is carrying the way in. Requiring
    /// somebody else to have made the hole first meant that once bases were built
    /// fast and repaired properly, almost nothing was ever open, so almost nothing
    /// was ever robbed.
    ///
    /// The supply check is what lets this sit above the emergency branch. A bot
    /// will not set out on a raid with an empty bag, so whenever this returns
    /// something, that branch was not going to fire anyway - they can never both
    /// want the bot at the same moment.
    /// Anything left to take or break in a base this bot is already inside.
    ///
    /// The difference between a raid and a shoplifting trip. A break-in costs a
    /// bomb, a walk and the owner's attention, and all of that is paid before the
    /// first chest is opened - so leaving with one armful while a second chest and
    /// a machine stand untouched is the worst possible use of the price already
    /// paid. This is what makes a raid an EVENT for the victim: they come home to a
    /// base that has been gone through, not to one drawer left open.
    ///
    /// Only while standing in it. The test is the claim, not the wall, so it holds
    /// while a bot is in the doorway and stops the moment it leaves - which is what
    /// keeps this from being a rule that drags bots back to bases they had given up
    /// on. Whoever left is finished; whoever is still there is not.
    ///
    /// Chests before the machine: loot you can carry beats loot you can only deny.
    private static func unfinishedBusiness(for actor: Actor, in world: World) -> AIGoal? {
        let standing = GridPoint(containing: actor.feet)

        guard let team = world.claims.first(where: { team, claim in
            team != actor.team && claim.contains(standing)
        })?.key else { return nil }

        // And only somewhere that is actually open. A bot that walks into a claim
        // whose wall is shut has not broken in, it is trespassing on the lawn.
        guard world.baseIsBreached(team) else { return nil }

        // Its turret first - see remaining(at:).
        if let turret = turretStanding(at: team, nearest: actor.position, in: world) {
            return .silence(turret.id)
        }

        if let chest = chestToBreak(at: team, for: actor, in: world) {
            return .robChest(chest.id)
        }

        // Sorted, because this picks a target and targets decide outcomes - even
        // though one machine to a base makes the answer unique today.
        if let machine = world.arcades.keys.sorted(by: { $0.raw < $1.raw })
            .compactMap({ world.arcades[$0] })
            .first(where: { $0.owner == team }) {
            return .wreck(machine.id)
        }

        return nil
    }

    /// Somebody's machine, standing in a base that is already open.
    ///
    /// No bomb needed and none checked, which is the point of it: a base with a
    /// hole in it is an invitation, and a bot that walks past one because it is not
    /// carrying a key is a bot that cannot see. The wall being down is the only
    /// permission required.
    ///
    /// Sorted, because this picks a target and targets decide outcomes.
    /// Whose base a raiding goal is against.
    ///
    /// The wall case is the one that matters: a bombed wall is usually the FIRST
    /// thing a bot does to a base, so it is where the memory has to start. Without
    /// it the raid would only be remembered from the chest onwards, which is the
    /// half that was already working.
    private static func base(of goal: AIGoal, in world: World) -> TeamID? {
        switch goal {
        case .robChest(let id):
            return world.chests[id]?.owner
        case .wreck(let id):
            return world.arcade(id)?.owner
        case .silence(let id):
            return world.turrets[id]?.owner
        case .raid(let tile):
            return world.map[tile].blockOwner
        case .wander, .loot, .collect, .fight, .retreat, .build, .farm, .stash,
             .rearm, .defend, .hunt:
            return nil
        }
    }

    /// What is left to do at the base this bot is already raiding, or nil.
    ///
    /// The chest first and the machine second, and it is worth saying why rather
    /// than leaving it to look arbitrary. Both are worth taking; the chest is the
    /// one that can be defended, restocked and emptied by somebody else while you
    /// are busy, so it is the one that stops being available. A machine standing in
    /// a breached base will still be standing in thirty seconds.
    ///
    /// No scoring, no distance cost, no comparison against other bases - see the
    /// call site. This is the question "is there anything still here", and the only
    /// gates on it are the ones about whether the bot can act at all.
    private static func unfinishedRaid(for actor: Actor,
                                       state: AIState,
                                       in world: World) -> AIGoal? {
        guard let victim = state.raidingBase, victim != actor.team,
              nearEnoughToReturn(to: victim, from: actor, in: world) else { return nil }

        // The same supply floor the ordinary search uses. A bot on its last legs
        // should be patching up rather than going back in, and this branch sits
        // ABOVE the emergency supply run exactly as that one does.
        guard actor.inventory.totalHealing(of: actor.maxHealth)
                >= GameConfig.AI.emergencyHealingStock else { return nil }

        return remaining(at: victim, for: actor, in: world)
    }

    /// Whether the bot is close enough to a base for the raid on it to still be a
    /// raid rather than a walk.
    private static func nearEnoughToReturn(to victim: TeamID,
                                           from actor: Actor,
                                           in world: World) -> Bool {
        guard let claim = world.claim(for: victim) else { return false }
        return (claim.centreTile.center - actor.position).length
            <= GameConfig.AI.raidReturnRange
    }

    /// What is still standing at a base, with no opinion about whether this bot is
    /// in any condition to take it.
    ///
    /// Split from the gates above it so that "there is nothing left here" and "I
    /// cannot do anything about it right now" are two different answers. They were
    /// one for a moment, and the bug that shape produces is precise: a bot driven
    /// off with no bandages would have read its own empty pockets as the base being
    /// stripped, forgotten the raid, and left.
    private static func remaining(at victim: TeamID,
                                  for actor: Actor,
                                  in world: World) -> AIGoal? {
        // The turret before anything else. Every second spent at a chest or a
        // machine with one still standing is a second spent being shot, and a
        // raid that ignores it ends with the raider carried out.
        if let turret = turretStanding(at: victim, nearest: actor.position, in: world) {
            return .silence(turret.id)
        }

        // Their chests, every one of them - see chestToBreak.
        if let chest = chestToBreak(at: victim, for: actor, in: world) {
            return .robChest(chest.id)
        }

        // Then anything they were making money with.
        var machine: Arcade?
        var shortest = Double.greatestFiniteMagnitude

        for id in world.arcades.keys.sorted(by: { $0.raw < $1.raw }) {
            guard let candidate = world.arcades[id], candidate.owner == victim else { continue }
            let distance = (candidate.centre - actor.position).length
            guard distance < shortest else { continue }
            shortest = distance
            machine = candidate
        }

        if let machine { return .wreck(machine.id) }

        return nil
    }

    /// The chest a raider should break next at this base, if any are left.
    ///
    /// The nearest one with something in it first, and then the nearest one
    /// whatever it holds. Empty ones used to be skipped altogether, and that let
    /// the player off every raid: a player's chests are theirs to fill, so they are
    /// often empty, and a raider who broke the wall, found nothing in the chests
    /// and walked out had cost the base a few blocks and nothing else. Breaking
    /// the chest is the raid - the owner loses it, and has to reseal to get it
    /// back.
    ///
    /// Sorted by id before the distance test, so two chests the same distance
    /// away are never split by dictionary order.
    private static func chestToBreak(at victim: TeamID,
                                     for actor: Actor,
                                     in world: World) -> Chest? {
        let theirs = world.chests(notOwnedBy: actor.team)
            .filter { $0.owner == victim }
            .sorted { $0.id.raw < $1.id.raw }

        func nearest(_ chests: [Chest]) -> Chest? {
            var best: Chest?
            var shortest = Double.greatestFiniteMagnitude
            for chest in chests {
                let distance = (chest.position - actor.position).length
                guard distance < shortest else { continue }
                shortest = distance
                best = chest
            }
            return best
        }

        let stocked = theirs.filter { $0.contents.slots.contains { $0 != nil } }
        return nearest(stocked) ?? nearest(theirs)
    }

    /// The nearest turret a base still has standing. Sorted, because this picks a
    /// target and two at the same distance must not be split by dictionary order.
    private static func turretStanding(at team: TeamID,
                                       nearest point: Vec2,
                                       in world: World) -> Turret? {
        var best: Turret?
        var shortest = Double.greatestFiniteMagnitude

        for id in world.turrets.keys.sorted(by: { $0.raw < $1.raw }) {
            guard let turret = world.turrets[id], turret.owner == team else { continue }
            let distance = (turret.centre - point).length
            guard distance < shortest else { continue }
            shortest = distance
            best = turret
        }

        return best
    }

    // The best enemy base to raid right now, priced by World.raidWorth (machines, an intact wall,
    // neglect, the lead, and whether a person owns it), and the first job there.
    private static func raidGoal(for actor: Actor, in world: World) -> AIGoal? {
        guard actor.inventory.totalHealing(of: actor.maxHealth)
                >= GameConfig.AI.emergencyHealingStock else { return nil }

        let hasBomb = actor.inventory.count(of: .bomb) > 0
        let runaway = world.runaway(against: actor.team)?.team

        var best: AIGoal?
        var bestScore = Double(GameConfig.AI.raidWorthOpening)

        for (team, claim) in world.claims.sorted(by: { $0.key.raw < $1.key.raw })
        where team != actor.team {
            let distance = (claim.centreTile.center - actor.position).length
            guard distance < GameConfig.AI.robRange || team == runaway else { continue }

            let score = world.raidWorth(of: team) - distance * GameConfig.AI.raidDistanceCost
            guard score > bestScore else { continue }

            // Already open: straight to its turret, chests or machines. Shut: bomb the wall.
            let goal: AIGoal?
            if world.baseIsBreached(team) {
                goal = remaining(at: team, for: actor, in: world)
            } else if hasBomb, let wall = breachTile(into: team, for: actor, in: world) {
                goal = .raid(wall)
            } else {
                goal = nil
            }

            guard let goal else { continue }
            bestScore = score
            best = goal
        }

        return best
    }

    private static func machineWorthWrecking(for actor: Actor, in world: World) -> Arcade? {
        guard actor.inventory.totalHealing(of: actor.maxHealth)
                >= GameConfig.AI.emergencyHealingStock else { return nil }

        // A runaway's machines at any distance - see chestWorthRobbing.
        let runaway = world.runaway(against: actor.team)?.team

        var best: Arcade?
        var shortest = Double.greatestFiniteMagnitude

        for id in world.arcades.keys.sorted(by: { $0.raw < $1.raw }) {
            guard let machine = world.arcades[id],
                  let owner = machine.owner,
                  owner != actor.team,
                  world.baseIsBreached(owner) else { continue }

            let distance = (machine.centre - actor.position).length
            guard distance < GameConfig.AI.robRange || owner == runaway,
                  distance < shortest else { continue }
            shortest = distance
            best = machine
        }

        return best
    }

    private static func chestWorthRobbing(for actor: Actor, in world: World) -> Chest? {
        // The healing gate stays exactly where it is, and it is not a raiding dial.
        // It is what lets this branch sit ABOVE the emergency supply run: a bot
        // that would fail this test wanted supplies anyway, so the two can never
        // both be trying to move it at once. Lower it and a bot on its last legs
        // sets out to rob somebody instead of patching up, and never arrives.
        guard actor.inventory.totalHealing(of: actor.maxHealth)
                >= GameConfig.AI.emergencyHealingStock else { return nil }

        let carryingAWayIn = actor.inventory.count(of: .bomb) > 0

        // A runaway's base is worth any walk. robRange keeps an ordinary raid
        // local; somebody doubling the field's score is not an ordinary target, and
        // a leader whose base happened to be on the far side of the map from every
        // bot was a leader nobody ever visited.
        let runaway = world.runaway(against: actor.team)?.team

        var best: Chest?
        var bestScore = 0.0

        for chest in world.chests(notOwnedBy: actor.team) {
            guard carryingAWayIn || world.baseIsBreached(chest.owner) else { continue }

            let distance = (chest.position - actor.position).length
            guard distance < GameConfig.AI.robRange || chest.owner == runaway else { continue }

            // What the BASE is worth, not what this chest holds.
            //
            // The contents used to be a hard gate - an empty chest disqualified the
            // whole base - and that quietly made the player unraidable. Their chests
            // are not stocked for them, because a player's chest is theirs to fill,
            // so a player who banks nothing owns a base that scored zero and was
            // never visited. Bots stock and restock their own, so bots spent every
            // match raiding each other.
            //
            // Three things make a base worth the trip, and any of them will do it:
            // what is in the chests, whether there is a machine to wreck, and how
            // long its owner has been left alone. The third is the one that finds a
            // turtle - see GameConfig.AI.raidPressurePerSecond.
            // Less the walk, which is what keeps a raider robbing the rich base
            // rather than merely the near one. The base is priced in one place -
            // World.raidWorth - so this and the wall-opening search above cannot
            // come to different conclusions about who is worth robbing.
            let score = world.raidWorth(of: chest.owner)
                - distance * GameConfig.AI.raidDistanceCost

            guard score > bestScore else { continue }
            bestScore = score
            best = chest
        }

        return best
    }

    /// The wall standing between this bot and the chest it came for.
    ///
    /// Nearest to the bot rather than nearest to the chest: by the time this is
    /// asked the bot has walked up to the base and is facing whatever is in front
    /// of it, and that is the tile whose removal lets it in.
    private static func wallInTheWay(of chestID: ChestID,
                                     for actor: Actor,
                                     in world: World) -> GridPoint? {
        guard let chest = world.chests[chestID] else { return nil }

        // The wall as BUILT, not the plan. A base is whatever encloses ground now,
        // so a player who walled their own shape has a plan full of empty tiles and
        // a real wall the raider has to get through - and the plan was what this
        // aimed at.
        let ring = world.enclosure(of: chest.owner).wall
        let candidates = ring.isEmpty
            ? Set(world.baseLayouts[chest.owner]?.tiles ?? [])
            : ring

        func isWall(_ point: GridPoint) -> Bool {
            world.map[point].blockOwner == chest.owner
        }

        var straight: GridPoint?
        var straightAway = GameConfig.Bomb.throwRange
        var anyTile: GridPoint?
        var anyAway = GameConfig.Bomb.throwRange

        // Sorted, because this picks where a bomb goes.
        for tile in candidates.sorted(by: { ($0.row, $0.col) < ($1.row, $1.col) }) {
            guard isWall(tile) else { continue }

            let distance = (tile.center - actor.position).length
            guard distance < GameConfig.Bomb.throwRange else { continue }

            if distance < anyAway {
                anyAway = distance
                anyTile = tile
            }

            // A tile in the MIDDLE of a straight run, which is the only kind of
            // hole worth making.
            //
            // Bots were bombing corners, because a corner is what is nearest when
            // you walk up to a base diagonally and nearest was the whole test. A
            // corner is the one place on a wall where a blast does not make a
            // doorway: it takes out the turn and leaves an opening facing two ways
            // at once, with the standing wall of both arms pinching the diagonal
            // the raider then has to walk. They would spend the bomb, fail to get
            // in, and stand outside the hole they had paid for.
            //
            // Neighbours on exactly one axis is the whole test. Both axes is a
            // junction, one of each is a corner, neither is a stub - and none of
            // the three is a run.
            let horizontal = isWall(GridPoint(col: tile.col - 1, row: tile.row))
                && isWall(GridPoint(col: tile.col + 1, row: tile.row))
            let vertical = isWall(GridPoint(col: tile.col, row: tile.row - 1))
                && isWall(GridPoint(col: tile.col, row: tile.row + 1))

            guard horizontal != vertical else { continue }

            if distance < straightAway {
                straightAway = distance
                straight = tile
            }
        }

        // A straight run if there is one in range, and the nearest wall otherwise -
        // because refusing to raid at all is worse than an awkward hole, and a base
        // small enough to be all corners is a base worth getting into anyway.
        return straight ?? anyTile
    }

    /// Whether this fight is worth having.
    ///
    /// Seeing somebody was the whole test before, which is why every bot on the map
    /// converged on you the moment you came into view - eight actors who could see
    /// each other were eight actors fighting, every time, regardless of whether it
    /// made any sense.
    ///
    /// Now a bot fights when it MUST, or when the fight is worth crossing ground
    /// for. Must covers the three cases where declining would look stupid: somebody
    /// shooting at it, somebody at arm's length, and somebody standing in its base.
    /// Past that it weighs the target, and the weighing is already done for it -
    /// a kill is priced by what the victim was carrying, so a well-equipped bot
    /// hunting a fresh spawn is spending a minute on 50 points when a chest is
    /// worth more. The AI is just agreeing with the scoreboard.
    static func shouldEngage(_ enemy: Actor, actor: Actor, in world: World) -> Bool {
        // Shot at. Nothing else matters.
        if actor.secondsSinceHit < GameConfig.AI.combatRecency { return true }

        let distance = (enemy.position - actor.position).length
        if distance <= fightRanges(for: actor, in: world).pressing { return true }

        // In its base. Whatever they came for, they are not getting it.
        if world.claim(for: actor.team)?
            .contains(GridPoint(containing: enemy.feet)) == true { return true }

        // Whoever is winning is worth stopping, wherever they are and whatever they
        // happen to be wearing. A slope rather than the cliff this used to be:
        // "level with the best score" made the leader worth chasing and the team
        // one point behind them worth ignoring, which on a scoreboard that moves in
        // fifties is a coin toss rather than a judgement.
        if world.lead(of: enemy.team) >= GameConfig.AI.leaderChaseAt { return true }

        // Otherwise the target has to be worth the ground between them, and the
        // further away they are the more they have to be worth. Somebody a step
        // outside arm's length is worth going for; the same person at the edge of
        // vision is somebody else's problem.
        let ranges = fightRanges(for: actor, in: world)
        let band = max(0.001, ranges.engage - ranges.pressing)
        let reach = min(1, (distance - ranges.pressing) / band)

        let wanted = Double(GameConfig.AI.worthChasingGear)
            + reach * Double(GameConfig.AI.worthChasingAtRange)

        guard Double(enemy.gearWorth) >= wanted else { return false }

        // And one reason to decline anyway: far weaker, so there is little to win.
        // Punching down pays 50 points and 8 tokens where the same minute spent on
        // a chest pays more, so a bot in a Cosmic has better uses for its time.
        return enemy.gearWorth + GameConfig.AI.punchDownSlack >= actor.gearWorth
    }

    /// How far away a target FEELS, given how well they are doing.
    ///
    /// The leader reads as closer than they are. Scaling the distance rather than
    /// replacing it is what keeps this sane: a bot never ignores somebody standing
    /// next to it in order to cross the map, it just breaks ties towards the player
    /// worth stopping.
    private static func weightedDistance(from actor: Actor,
                                         to target: Actor,
                                         in world: World) -> Double {
        let distance = (target.position - actor.position).length
        return distance * (1 - GameConfig.AI.leaderPull * world.lead(of: target.team))
    }

    private static func nearestArcade(to actor: Actor, in world: World) -> Arcade? {
        var closest: Arcade?
        var shortest = GameConfig.AI.arcadeSearchRange

        for machine in world.arcades.values {
            let distance = (machine.centre - actor.position).length
            guard distance < shortest else { continue }
            shortest = distance
            closest = machine
        }

        return closest
    }

    /// Where to stand to work a machine: the nearest tile of the ring it pays out
    /// onto. Walking at the machine itself only presses a bot into three tiles of
    /// solid cabinet.
    private static func approachSpot(for arcade: Arcade, from actor: Actor, in world: World) -> Vec2 {
        var best = arcade.centre
        var shortest = Double.greatestFiniteMagnitude

        for tile in arcade.surroundingTiles where world.isClearForDrop(tile.center) {
            let distance = (tile.center - actor.position).length
            guard distance < shortest else { continue }
            shortest = distance
            best = tile.center
        }

        return best
    }

    private static func isHealing(_ pickup: Pickup) -> Bool {
        guard case .item(let type) = pickup else { return false }
        return type.isHealing
    }

    /// The supply drop worth going for, or nil.
    ///
    /// A hot commodity: an OPEN one pulls every bot on the map whatever it is
    /// carrying, because it will not be there for long. A locked one pulls any bot
    /// within GameConfig.SupplyDrop.botInterest, and those need something to heal
    /// with - they are walking into the fight the countdown was built to start.
    private static func supplyWorthContesting(for actor: Actor, in world: World) -> Lootbox? {
        let supplied = actor.inventory.totalHealing(of: actor.maxHealth)
            >= GameConfig.AI.emergencyHealingStock

        var best: Lootbox?
        var shortest = Double.greatestFiniteMagnitude

        for drop in world.supplyDrops {
            let distance = (drop.position - actor.position).length
            if drop.isLocked {
                guard supplied, distance < GameConfig.SupplyDrop.botInterest else { continue }
            }
            guard distance < shortest else { continue }
            shortest = distance
            best = drop
        }

        return best
    }

    /// An open supply drop close enough to simply run in and take.
    private static func grabbableSupply(for actor: Actor, in world: World) -> Lootbox? {
        world.supplyDrops.first {
            !$0.isLocked
                && ($0.position - actor.position).length <= GameConfig.SupplyDrop.botGrabRange
        }
    }

    /// Whether no enemy will reach this drop clearly before this bot does.
    ///
    /// Any living enemy, seen or not: this is a race to a point both of them know
    /// about, not a question of who has spotted whom. "Clearly" is
    /// SupplyDrop.botBeatenBy, so two bots a step apart both still run for it.
    private static func firstInLine(for drop: Lootbox, actor: Actor, in world: World) -> Bool {
        let mine = (drop.position - actor.position).length
        return !world.actors.values.contains {
            $0.team != actor.team && $0.isAlive
                && ($0.position - drop.position).length
                    + GameConfig.SupplyDrop.botBeatenBy < mine
        }
    }

    /// The enemy nearest a drop - the one about to take it. Sorted by id first, so
    /// two the same distance away are never split by dictionary order.
    private static func nearestRival(to drop: Lootbox, for actor: Actor, in world: World) -> Actor? {
        var best: Actor?
        var shortest = Double.greatestFiniteMagnitude

        for id in world.actors.keys.sorted(by: { $0.raw < $1.raw }) {
            guard let other = world.actors[id], other.team != actor.team, other.isAlive,
                  other.invulnerability <= 0 else { continue }
            let distance = (other.position - drop.position).length
            guard distance < shortest else { continue }
            shortest = distance
            best = other
        }

        return best
    }

    /// The supply drop this bot is standing at, if it is standing at one.
    private static func contestedDrop(near actor: Actor, in world: World) -> Lootbox? {
        world.supplyDrops.first {
            ($0.position - actor.position).length <= GameConfig.SupplyDrop.botContestRadius
        }
    }

    /// Whether this enemy is competing with this bot for the drop it is at.
    private static func isRivalForDrop(_ enemy: Actor, actor: Actor, in world: World) -> Bool {
        guard let drop = contestedDrop(near: actor, in: world) else { return false }
        return (enemy.position - drop.position).length <= GameConfig.SupplyDrop.botContestRadius
    }

    private static func isSupplyRun(_ goal: AIGoal, in world: World) -> Bool {
        guard case .loot(let id) = goal else { return false }
        return world.lootboxes[id]?.supply == true
    }

    private static func nearestCrate(to actor: Actor, in world: World) -> Lootbox? {
        var closest: Lootbox?
        var shortest = GameConfig.AI.lootSearchRange

        // Ordinary crates only. A supply drop is chosen on purpose, above, and a
        // locked one found by accident would be walked at and waited on by a bot
        // that only wanted a bandage.
        for crate in world.lootboxes.values where !crate.supply {
            let distance = (crate.position - actor.position).length
            guard distance < shortest else { continue }
            shortest = distance
            closest = crate
        }

        return closest
    }

    // MARK: - Aiming at a target

    private static func steerTowardsGoal(_ state: inout AIState, actor: Actor, in world: World) {
        switch state.goal {
        case .wander:
            return

        case .loot(let id):
            if let drop = world.lootboxes[id], drop.supply,
               drop.lockTimer > GameConfig.SupplyDrop.botMoveInAt {
                holdNear(drop, state: &state, actor: actor)
                return
            }
            steer(&state, actor: actor, to: world.lootboxes[id]?.position)

        case .collect(let id):
            steer(&state, actor: actor, to: world.groundItems[id]?.position)

        case .farm(let id):
            steer(&state, actor: actor,
                  to: world.arcade(id).map { approachSpot(for: $0, from: actor, in: world) })

        case .robChest(let id):
            // Emptied, or gone. Re-decide on the very next tick rather than waiting
            // out the timer: the bot is standing INSIDE a base it paid a bomb to
            // open, and there may well be another chest a few tiles away. Wandering
            // off for three seconds first is how a raid ended up half done.
            // Cracked, or gone. Re-decide on the very next tick rather than
            // waiting out the timer: the bot is standing INSIDE a base it paid a
            // bomb to open, with the contents lying on the grass around it, and
            // wandering off for three seconds first is how a raid ended up half
            // done.
            guard let chest = world.chests[id] else {
                state.goal = .wander
                state.goalAge = 0
                state.decisionTimer = 0
                return
            }
            steer(&state, actor: actor, to: chest.position)

        case .stash(let tile):
            // Walks at the spot, and the spot is guaranteed not to be under its own
            // feet - see World.nextChestTile, which is where this was fixed. There
            // is no stopping here because there is no stopping anywhere: a bot's
            // command is always .move(heading) at full speed, so "stand still" is
            // not a thing this brain can express.
            steer(&state, actor: actor, to: tile.center)

        case .defend(let id):
            // Gone, dead, or driven off - and the claim is the test, not the
            // distance, so chasing somebody out of your base ends at the fence
            // rather than halfway across the map.
            guard let enemy = world.actors[id], enemy.isAlive,
                  world.intruder(in: actor.team) != nil else {
                state.goal = .wander
                state.goalAge = 0
                state.decisionTimer = 0
                return
            }
            steer(&state, actor: actor, to: enemy.position)

        case .wreck(let id):
            // Gone already, or somebody else got it. Re-decide immediately: the
            // bot is standing in a base it broke into and there is usually still
            // something in there worth its time.
            guard let machine = world.arcade(id) else {
                state.goal = .wander
                state.goalAge = 0
                state.decisionTimer = 0
                return
            }

            // Walk at it until there is a shot. shotToTake does the firing, the
            // same way it does for a person - so a bot wrecking a machine still
            // breaks off to deal with anybody who turns up, because the fight
            // check sits above this.
            steer(&state, actor: actor, to: machine.centre)

        case .silence(let id):
            // Knocked out already, by this bot or anybody. Re-decide at once:
            // whatever it was guarding is now open for business.
            guard let turret = world.turrets[id] else {
                state.goal = .wander
                state.goalAge = 0
                state.decisionTimer = 0
                return
            }

            // Straight at it. Standing off at range is what the turret wants -
            // it out-damages a bot in a long exchange - and closing the distance
            // makes its slow barrel the thing that loses.
            steer(&state, actor: actor, to: turret.centre)

        case .rearm(let id):
            // Emptied, or taken while the bot was walking. Re-decide immediately
            // rather than standing at a bare chest waiting out a timer.
            guard let chest = world.chests[id],
                  gearWorthTaking(from: chest, actor: actor) != nil else {
                state.goal = .wander
                state.goalAge = 0
                state.decisionTimer = 0
                return
            }
            steer(&state, actor: actor, to: chest.position)

        case .build(let tile):
            steer(&state, actor: actor,
                  to: standingSpot(for: tile, team: actor.team, in: world))

        case .raid(let tile):
            // Walk at the wall until close enough to throw, then stop closing -
            // standing on top of a bomb you threw is a poor raid.
            guard world.map[tile].blockOwner != nil else {
                state.goal = .wander
                state.goalAge = 0
                return
            }
            steer(&state, actor: actor, to: tile.center)

        case .retreat(let id):
            steer(&state, actor: actor,
                  to: breakOffPoint(for: actor, awayFrom: world.actors[id], in: world))

        case .fight(let id):
            steerForFight(&state, actor: actor, enemy: id, in: world)

        case .hunt(let id):
            guard let quarry = world.actors[id], quarry.isAlive else {
                // Dead, or gone. Somebody else got there first and the reason for
                // the walk went with them.
                state.goal = .wander
                state.goalAge = 0
                state.decisionTimer = 0
                state.huntMark = nil
                return
            }

            // The mark refreshes only on a clear VIEW, and only from inside
            // huntSight. This is the whole honesty of the mechanic: without the
            // sight test a hunt would track a live position through walls and
            // across the map, which is not a bot hunting you, it is a bot that
            // knows where you are. With it, breaking line of sight works - the bot
            // keeps coming to where you were, arrives, and has to find you again.
            let away = quarry.position - actor.position
            if away.length <= GameConfig.AI.huntSight,
               hasLineOfSight(from: actor.position, to: quarry.position, in: world) {
                state.huntMark = quarry.position
            }

            // No mark yet means it has never laid eyes on them, so it walks at
            // their base instead. That is the one place somebody turns up sooner or
            // later, and it puts the bot somewhere useful even if they never do.
            let mark = state.huntMark ?? world.claims[quarry.team]?.centreTile.center

            // Stood on the spot with nobody here: the trail is cold. Dropping the
            // mark sends it to their base on the next tick rather than leaving it
            // milling about on an empty patch of grass.
            if let mark, (mark - actor.position).length < GameConfig.AI.huntArrival {
                state.huntMark = nil
            }

            steer(&state, actor: actor, to: mark)
        }
    }

    /// Whether this goal is a hunt. AIGoal has no isHunt of its own because
    /// nothing else needs to ask, and one more near-identical one-line predicate on
    /// that enum earns less than it costs - isRob is already sitting there unread.
    private static func isHunt(_ goal: AIGoal) -> Bool {
        if case .hunt = goal { return true }
        return false
    }

    /// Weave, rather than walk a straight line, while raiding under fire.
    ///
    /// See GameConfig.AI.dodgeSwing. Only the FEET: where the blaster points is
    /// shotToTake's business, so a raider can zig-zag at a chest and keep shooting
    /// it. Each bot weaves on its own beat, offset by its id, so two raiders side
    /// by side do not swing in step - and it is built off the match clock rather
    /// than the generator, so it costs no random draws and cannot knock a seed out
    /// of step.
    private static func dodgeWhileRaiding(_ state: inout AIState, actor: Actor, in world: World) {
        guard state.goal.isRaiding, underThreat(actor, in: world) else { return }

        let beat = world.elapsed * 2 * Double.pi / GameConfig.AI.dodgePeriod
        let swing = GameConfig.AI.dodgeSwing * sin(beat + Double(actor.id.raw) * 1.7)
        state.desiredHeading = Vec2.fromAngle(state.desiredHeading.angle + swing)
    }

    /// Whether anything is shooting at this bot, or about to.
    private static func underThreat(_ actor: Actor, in world: World) -> Bool {
        if actor.secondsSinceHit < GameConfig.AI.dodgeMemory { return true }

        if world.turrets.values.contains(where: { $0.target == actor.id }) { return true }

        return world.actors.values.contains { other in
            other.isAlive && other.team != actor.team
                && (other.position - actor.position).length <= GameConfig.AI.dodgeRange
        }
    }

    /// Waits out a locked supply drop at a distance instead of on top of it.
    ///
    /// Walks in to SupplyDrop.botHoldRadius and then circles there, the way a bot
    /// circles in a fight - moving, so it is hard to hit, and spread round the
    /// crate so the bots waiting can see and shoot each other. Moves in for the
    /// crate itself only in the last seconds of the lock.
    private static func holdNear(_ drop: Lootbox, state: inout AIState, actor: Actor) {
        let fromDrop = actor.position - drop.position
        let gap = fromDrop.length
        let hold = GameConfig.SupplyDrop.botHoldRadius

        guard gap > 0.01 else {
            state.desiredHeading = Vec2(x: state.strafeDirection, y: 0)
            return
        }

        let outward = fromDrop.normalized()

        if gap > hold + 1 {
            state.desiredHeading = outward * -1
        } else if gap < hold - 1 {
            state.desiredHeading = outward
        } else {
            state.desiredHeading = Vec2(x: -outward.y, y: outward.x) * state.strafeDirection
        }
    }

    private static func steer(_ state: inout AIState, actor: Actor, to target: Vec2?) {
        // Whatever it was walking to is gone - somebody else got there first, or it
        // died. Drop back to roaming rather than walking to a place with nothing in it.
        guard let target else {
            state.goal = .wander
            state.goalAge = 0
            return
        }

        let towards = target - actor.position
        if towards.length > 0.01 {
            state.desiredHeading = towards.normalized()
        }
    }

    /// Where to put your FEET in a fight. Where to point the blaster is a separate
    /// question, answered in shotToTake, and keeping the two apart is what lets a
    /// bot fight like somebody who has done this before.
    private static func steerForFight(_ state: inout AIState,
                                      actor: Actor,
                                      enemy id: ActorID,
                                      in world: World) {
        // Deliberately no line-of-sight test. Acquiring a target needs a clear view;
        // STAYING on one does not, or a tree passing between two bots would end the
        // fight and they would both wander off.
        guard let enemy = world.actors[id], enemy.isAlive,
              (enemy.position - actor.position).length
                <= fightRanges(for: actor, in: world).disengage else {
            state.goal = .wander
            state.goalAge = 0
            return
        }

        let towards = enemy.position - actor.position
        let gap = towards.length
        guard gap > 0.01 else { return }

        let direct = towards.normalized()

        // Too close, or nothing loaded: give ground. Backing off no longer costs a
        // bot its shot, so this is a reposition rather than a surrender.
        let ranges = fightRanges(for: actor, in: world)

        if gap < ranges.minimum || actor.ammo <= 0 {
            let escape = breakOffPoint(for: actor, awayFrom: enemy, in: world) - actor.position
            state.desiredHeading = escape.length > 0.01
                ? escape.normalized()
                : direct * -1
            return
        }

        // Too far to be shooting from: close the distance.
        if gap > ranges.preferred {
            state.desiredHeading = direct
            return
        }

        // At a range worth fighting at: circle, rather than stand still or walk in.
        // A bot that holds its ground is a stationary target, and one that keeps
        // closing ends up in the enemy's face - which is every circling, nose-to-
        // nose fight we have been chasing. Strafing keeps the blaster on target
        // while making the bot hard to hit, which is simply what good players do.
        state.desiredHeading = Vec2(x: -direct.y, y: direct.x) * state.strafeDirection
    }

    // MARK: - Building

    /// Where to stand to lay a given wall tile.
    ///
    /// Pulled a little towards the middle of the claim rather than aiming at the
    /// tile itself: a bot standing exactly on a bottom-edge wall line has its FEET
    /// outside the claim, and BuildSystem quite rightly refuses the placement.
    private static func standingSpot(for tile: GridPoint, team: TeamID, in world: World) -> Vec2 {
        guard let claim = world.claim(for: team) else { return tile.center }

        let inward = claim.centreTile.center - tile.center
        guard inward.length > 0.01 else { return tile.center }

        return tile.center + inward.normalized() * GameConfig.Build.standIn
    }

    /// The wall to lay this tick, if any.
    ///
    /// Spaced out by a timer so walls go up one after another, and capped per trip
    /// so a bot lays a couple and gets back to the match rather than camping its
    /// claim until the base is finished.
    // MARK: - How far a fight reaches

    /// The distances a fight is actually fought at on THIS screen.
    ///
    /// Derived rather than configured, and that is the whole point. These were
    /// three fixed tile counts chosen with no reference to the camera, and on a
    /// phone held in landscape the camera shows under five tiles above and below
    /// the player while bots were opening fire at twelve. You were being shot by
    /// things two and a half screens away - correctly, by rules that had simply
    /// never been asked whether you could see them.
    ///
    /// The vertical half-extent is what binds, because landscape is much wider than
    /// it is tall and a bot approaching from above or below is the one that
    /// disappears. Capped by engageRange as well, so a huge screen does not turn
    /// bots into snipers.
    struct FightRanges {
        let engage: Double
        let preferred: Double
        let minimum: Double
        let disengage: Double
        /// Close enough that a fight is not a decision.
        let pressing: Double
    }

    /// Takes no target any more. It used to, so that the local player could be
    /// given a shorter engage range than a bot - see canOpenFire, which is where
    /// that protection went and why it is better off there.
    ///
    /// It still takes the actor and the world, and at the moment uses neither: the
    /// engage range is one number for everybody. They are kept because the NEXT
    /// question anybody asks of this is "should somebody holding a Blaster 6 pick
    /// fights from further away", and that wants an actor. Deleting two parameters
    /// to add them back is a worse trade than a pair that are briefly unread.
    static func fightRanges(for actor: Actor, in world: World) -> FightRanges {
        let engage = GameConfig.AI.engageRange

        return FightRanges(engage: engage,
                           preferred: engage * GameConfig.AI.preferredFraction,
                           minimum: engage * GameConfig.AI.minimumFraction,
                           disengage: engage * GameConfig.AI.disengageFraction,
                           pressing: engage * GameConfig.AI.pressingFraction)
    }

    /// Whether a shot at this target is one the target could see coming.
    ///
    /// THE CAP MOVED. It used to sit on the engage RANGE, capping how far off a bot
    /// could take an interest in the local player at all - and that conflated two
    /// different things. Not shooting somebody from off screen is fair. Not being
    /// allowed to WALK TOWARDS them from off screen is not a fairness rule, it is a
    /// blind spot, and on a landscape phone it was an enormous one.
    ///
    /// The arithmetic: tiles are 36 points, so a landscape screen is about eleven
    /// tiles wide either side of the player and under six tall. Bots engaged each
    /// other at a flat twelve and engaged the player at whatever the screen edge
    /// allowed along the line between them - eleven sideways, five and a bit
    /// vertically. By area that is a shade over forty per cent of the region a bot
    /// gets. Move vertically and almost nothing noticed you. That is a large part
    /// of "the player can roam all game without much threat", and it was invisible
    /// because it reads as a courtesy.
    ///
    /// So noticing is symmetric now - twelve tiles, everybody - and this is what
    /// is left of the courtesy: a bot may come for you from anywhere, and may not
    /// shoot until you could see it. Asked as a rectangle, because the screen is
    /// one and the camera is centred on the player, so it is simply whether the
    /// bot is inside the box.
    ///
    /// Only the local player is protected. Nobody is watching one bot shoot
    /// another.
    private static func canOpenFire(on target: Actor,
                                    from actor: Actor,
                                    in world: World) -> Bool {
        guard target.id == world.localPlayerID else { return true }

        let away = actor.position - target.position
        let half = world.visibleHalfExtent

        return abs(away.x) <= half.x * GameConfig.AI.visibleMargin
            && abs(away.y) <= half.y * GameConfig.AI.visibleMargin
    }

    // MARK: - Spending

    /// What this bot should buy, if anything.
    ///
    /// Bots shop from the same counter the player does, at the same prices, with
    /// tokens earned the same three ways - so the top of the ladder stops being a
    /// thing only you can reach. Without this the crates cap every bot at Rare and
    /// Blaster 3 for the whole match while you climb past them, which is exactly the
    /// too-easy feeling: you are not outplaying seven opponents, you are outspending
    /// them in a shop they cannot use.
    ///
    /// The CHEAPER of the two offers wins, so both ladders climb together rather
    /// than one bot hoarding for a Cosmic while carrying a starter blaster. Modelled
    /// against a bot's income, that lands it around Legendary and Blaster 5 by the
    /// whistle, with the buying happening in the second half - late enough to be a
    /// difficulty curve rather than a head start.
    private static func purchaseToMake(actor: Actor, in world: World) -> ItemType? {
        // Healing before gear, and only when the cupboard is bare.
        //
        // It goes first because it is the cheaper decision by an order of magnitude
        // - a bandage is six tokens against forty for the next helmet - and because
        // being out of bandages is what stops a bot raiding at all.
        // emergencyHealingStock gates chestWorthRobbing and machineWorthWrecking
        // both, so a bot with nothing to patch up with does not go and take
        // anybody's chest; it wanders off to find a crate. Six tokens buys that
        // walk back.
        if let healing = healingToBuy(actor: actor, in: world) { return healing }

        // What used to stand here was a guard on GameConfig.AI.investsUntil whose
        // two branches were the same line, left behind when the shop stopped
        // selling furniture. Bots once bought a chest the moment their wall shut
        // and a machine when they could afford one; neither is on the shelf any
        // more - see GameConfig.Shop.tabs, which is gear and healing - so the only
        // thing tokens have gone on for some time is the ladder. The constant and
        // its several paragraphs of reasoning have gone with the branch.
        return upgradeToBuy(actor: actor, in: world)
    }

    /// The cheapest thing on the healing shelf a bot can afford, when it has run
    /// out of healing.
    ///
    /// Reads everythingOffered rather than a tab index, because which tab the
    /// bandages sit on is a lookup detail and nothing out here should have to know
    /// it. worthBuying does the "has it actually run out" half, so both kinds of
    /// purchase are decided in the same place.
    private static func healingToBuy(actor: Actor, in world: World) -> ItemType? {
        ShopSystem.everythingOffered(to: actor, unlocks: world.unlocks)
            .filter { offer in
                switch offer.type {
                case .bandage, .medkit: return true
                default:                return false
                }
            }
            .filter { worthBuying($0.type, for: actor, in: world)
                      && ShopSystem.canBuy($0.type, actor: actor, in: world) }
            .min { $0.price < $1.price }?
            .type
    }

    private static func upgradeToBuy(actor: Actor, in world: World) -> ItemType? {
        ShopSystem.upgradeOffers(for: actor, unlocks: world.unlocks)
            .filter { worthBuying($0.type, for: actor, in: world)
                      && ShopSystem.canBuy($0.type, actor: actor, in: world) }
            .min { $0.price < $1.price }?
            .type
    }

    /// Whether this is worth tokens rather than worth waiting for.
    ///
    /// THREE ways to clear the bar for gear, and only the first of them used to
    /// exist. Either the rung is one crates never hand out, so the shop is the only
    /// way up; or the match has run past buysAnythingAfter and waiting has stopped
    /// being a plan; or the bot is being left behind badly enough that a gun now
    /// beats a better gun later.
    ///
    /// The first alone could never be cleared from below, because the shop offers
    /// the rung ABOVE what you are wearing and that rung is always one short of the
    /// line until a crate has already carried you past it. See
    /// GameConfig.AI.buysHelmetsAbove for the whole of that - it is the reason
    /// seven bots finished every match with a full purse and a starting blaster.
    ///
    /// Healing is a different question and gets a different test: not whether this
    /// is good value, but whether the bot has any.
    private static func worthBuying(_ type: ItemType, for actor: Actor, in world: World) -> Bool {
        let impatient = world.behind(actor.team) >= GameConfig.AI.pressureBuysAt
        let waited = world.matchProgress >= GameConfig.AI.buysAnythingAfter

        switch type {
        case .helmet(let tier):
            return tier.rawValue > GameConfig.AI.buysHelmetsAbove.rawValue
                || waited || impatient
        case .blaster(let tier):
            return tier.rawValue > GameConfig.AI.buysBlastersAbove.rawValue
                || waited || impatient
        case .bandage, .medkit:
            return actor.inventory.totalHealing(of: actor.maxHealth)
                 < GameConfig.AI.buysHealingBelow
        case .bomb, .stink, .chest, .arcade, .turret, .perk:
            return false
        }
    }

    // MARK: - Keeping house

    /// Where a carried chest wants to go, ignoring how far away the bot is.
    ///
    /// This exists because the reach-checked version below was unreachable in
    /// practice. Placing needs a FINISHED base; every goal that took a bot home
    /// needed an UNFINISHED one, because they all hang off nextBuildTile. The two
    /// conditions are mutually exclusive, so a bot could only ever put a chest down
    /// in the single moment it laid its last wall while already carrying one -
    /// which is why bases kept ending up with nothing in them to raid.
    private static func chestSpotWanted(for actor: Actor, in world: World) -> GridPoint? {
        guard !world.baseIsBreached(actor.team) else { return nil }

        // A machine before a chest when carrying both, because it starts earning the
        // moment it is down and a chest only holds what you put in it. Either size
        // will do - a mini earns less but earns immediately, and a bot holding one
        // of each stands the first one it finds up and comes back for the other.
        //
        // Each only while the base has room for another - see
        // GameConfig.Base.maxChests - or a bot carries it home forever.
        if let kind = carriedArcade(of: actor),
           !PlacementSystem.baseIsFull(for: .arcade(kind), team: actor.team, in: world),
           let origin = world.nextArcadeOrigin(for: actor.team,
                                               kind: kind,
                                               near: actor.position) {
            return origin
        }

        // Then a turret, ahead of the chest it will be guarding: a chest stood up
        // in a base with nothing watching it is the cheapest thing on the map.
        if actor.inventory.firstSlot(holding: .turret) != nil,
           !PlacementSystem.baseIsFull(for: .turret, team: actor.team, in: world),
           let origin = world.nextTurretOrigin(for: actor.team, near: actor.position) {
            return origin
        }

        guard actor.inventory.firstSlot(holding: .chest) != nil,
              !PlacementSystem.baseIsFull(for: .chest, team: actor.team, in: world) else { return nil }
        return world.nextChestTile(for: actor.team, near: actor.position)
    }

    /// A tile to stand a carried chest on, right now, from where the bot stands.
    private static func chestToPlace(actor: Actor, in world: World) -> GridPoint? {
        // Not until the wall is shut, and this is now the ONLY place that rule
        // lives. ChestSystem will happily stand a chest up in an open base - it is
        // the player's base and their decision - but a bot doing it would be
        // leaving free loot for whoever wandered past, and a map where you can walk
        // into a half-built base and help yourself is a map with no reason to own
        // a bomb.
        //
        // A preference rather than a law is the right shape for it: the rule that
        // protects the raiding loop is about what the seven bots DO, not about what
        // the rules permit.
        guard !world.baseIsBreached(actor.team) else { return nil }
        guard let tile = world.nextChestTile(for: actor.team,
                                             near: actor.position) else { return nil }
        guard (tile.center - actor.position).length <= GameConfig.Build.reach else { return nil }
        guard ChestSystem.canPlace(at: tile, by: actor, in: world) else { return nil }
        return tile
    }

    /// Which size of machine this bot is carrying, if any.
    ///
    /// Sorted, so a bot holding one of each always reaches for the same one and two
    /// runs of a seed cannot diverge over which. The cabinet goes down first: it is
    /// worth more standing and worth more to whoever kills this bot on the way home.
    private static func carriedArcade(of actor: Actor) -> ArcadeKind? {
        for kind in [ArcadeKind.full, .mini]
        where actor.inventory.firstSlot(holding: .arcade(kind)) != nil {
            return kind
        }
        return nil
    }

    /// A spot to stand a carried machine up, from where the bot is now, and which
    /// machine goes there.
    private static func arcadeToPlace(actor: Actor,
                                      in world: World) -> (origin: GridPoint, kind: ArcadeKind)? {
        guard !world.baseIsBreached(actor.team) else { return nil }
        guard let kind = carriedArcade(of: actor) else { return nil }
        guard let origin = world.nextArcadeOrigin(for: actor.team,
                                                  kind: kind,
                                                  near: actor.position) else { return nil }

        let machine = Arcade(id: ArcadeID(-1), kind: kind, origin: origin,
                             owner: actor.team, emitTimer: 0)
        guard (machine.centre - actor.position).length <= GameConfig.Build.reach + 1.5 else {
            return nil
        }
        guard ArcadeSystem.canPlace(at: origin, kind: kind, by: actor, in: world) else {
            return nil
        }
        return (origin, kind)
    }

    /// A spot to stand a carried turret on, from where the bot is now.
    ///
    /// The same rules a machine follows, for the same reason: not in an open
    /// base, and only from arm's reach, so a bot stands it up on its way through
    /// rather than making a special trip.
    private static func turretToPlace(actor: Actor, in world: World) -> GridPoint? {
        guard !world.baseIsBreached(actor.team) else { return nil }
        guard actor.inventory.firstSlot(holding: .turret) != nil else { return nil }
        guard let origin = world.nextTurretOrigin(for: actor.team,
                                                  near: actor.position) else { return nil }

        let turret = Turret(id: TurretID(-1), origin: origin, owner: actor.team)
        guard (turret.centre - actor.position).length <= GameConfig.Build.reach + 1.5 else {
            return nil
        }
        guard TurretSystem.canPlace(at: origin, by: actor, in: world) else { return nil }
        return origin
    }

    /// The best thing in somebody else's chest that this bot could carry off.
    ///
    /// Takes the biggest heal it can hold first, then anything else - a raider
    /// with one trip's worth of pockets should leave with the good stuff.
    /// The slot in a chest holding gear this actor would rather be wearing.
    ///
    /// Gear only, and strictly an upgrade. A bot emptying its own chest of bandages
    /// would be a bot undoing the thing it built the chest for, and a bot swapping
    /// its Legendary for the Epic it stored last minute would be worse than useless.
    private static func gearWorthTaking(from chest: Chest, actor: Actor) -> Int? {
        var best: Int?
        var bestGain = 0

        for (index, slot) in chest.contents.slots.enumerated() {
            guard let stack = slot, actor.canAcquire(stack.type) else { continue }

            var gain = 0

            switch stack.type {
            case .helmet(let tier) where tier > actor.helmet:
                gain = tier.rawValue - actor.helmet.rawValue
            case .blaster(let tier) where tier > actor.blaster:
                gain = tier.rawValue - actor.blaster.rawValue
            default:
                continue
            }

            // The biggest jump first, so a bot standing at a chest holding both a
            // helmet and a gun reaches for whichever it is further behind on.
            guard gain > bestGain else { continue }
            bestGain = gain
            best = index
        }

        return best
    }

    /// Its own chest, if going home would put it back in the fight.
    ///
    /// Nearest first rather than best-stocked: a bot deciding between two of its own
    /// chests should walk to the near one, and by the time it gets there the far one
    /// is a second trip it can decide on separately.
    private static func reArmWanted(for actor: Actor, in world: World) -> Chest? {
        var best: Chest?
        var shortest = Double.greatestFiniteMagnitude

        for id in world.chests.keys.sorted(by: { $0.raw < $1.raw }) {
            guard let chest = world.chests[id], chest.owner == actor.team else { continue }
            guard gearWorthTaking(from: chest, actor: actor) != nil else { continue }

            let distance = (chest.position - actor.position).length
            guard distance < shortest else { continue }
            shortest = distance
            best = chest
        }

        return best
    }


    private static func wallToLay(_ state: inout AIState, actor: Actor, in world: World) -> GridPoint? {
        guard case .build = state.goal else { return nil }
        guard state.placeTimer <= 0, state.blocksLeftToLay > 0 else { return nil }

        // Take whatever is next NOW - the tile picked when the trip started may
        // already have been laid, by this bot or by a teammate later on.
        guard let tile = world.nextBuildTile(for: actor.team) else {
            state.goal = .wander
            state.goalAge = 0
            return nil
        }

        guard (tile.center - actor.position).length <= GameConfig.Build.reach else { return nil }
        guard BuildSystem.canPlace(at: tile, by: actor, in: world) else { return nil }

        // Quicker while there is a hole in it. Patching is not building.
        state.placeTimer = world.baseIsBreached(actor.team)
            ? GameConfig.Build.repairInterval
            : GameConfig.Build.placeInterval
        state.blocksLeftToLay -= 1

        if state.blocksLeftToLay <= 0 {
            // Done for now. Back to the match.
            state.buildUrgeTimer = Double.random(in: GameConfig.Build.urgeInterval,
                                                 using: &world.rng)
            state.goal = .wander
            state.goalAge = 0
        }

        return tile
    }

    // MARK: - Raiding

    // The wall tile whose removal opens the way to this base's loot, as the wall is actually built.
    private static func breachTile(into team: TeamID, for actor: Actor, in world: World) -> GridPoint? {
        let spots = world.lootSpots(of: team)
        guard !spots.isEmpty else { return nil }

        var tile: GridPoint?
        var closest = Double.greatestFiniteMagnitude

        // The wall AS BUILT, not as planned.
        //
        // This read baseLayouts - the schematic the tutorial draws - and that
        // is a plan, not a fact. Bots follow it, so for seven bases the two
        // agreed and the bug was invisible. A player can build any shape they
        // like inside their claim, and when they do, every tile in this loop
        // comes back with no block on it, no candidate survives, and the base
        // is skipped entirely. Build off-plan and you were unbombable.
        //
        // wallInTheWay two functions down already asks the enclosure for
        // exactly this reason and says so in its own comment. This is the same
        // question and now gets the same authority.
        //
        // Sorted, because a Set has no order and the minimum below would
        // otherwise resolve differently between two runs of the same seed.
        for candidate in world.enclosure(of: team).wall
            .sorted(by: { ($0.col, $0.row) < ($1.col, $1.row) }) {
            guard world.map[candidate].blockOwner != nil else { continue }

            let toLoot = spots
                .map { (candidate.center - $0).length }
                .min() ?? Double.greatestFiniteMagnitude
            let toBot = (candidate.center - actor.position).length

            // Near the loot, and near the bot: the tile whose removal actually
            // opens a way through to it.
            let placement = toLoot + toBot * 0.5
            guard placement < closest else { continue }
            closest = placement
            tile = candidate
        }

        return tile
    }

    // A wall worth bombing when carrying a bomb: the best-priced base first, else the nearest wall.
    private static func raidTarget(for actor: Actor, in world: World) -> GridPoint? {
        guard actor.inventory.count(of: .bomb) > 0 else { return nil }

        if let worthwhile = wallGuarding(theLootOf: actor, in: world) { return worthwhile }

        var closest: GridPoint?
        var shortest = GameConfig.AI.raidRange

        for (team, claim) in world.claims where team != actor.team {
            // Cheap test first: the claim's middle is a good enough stand-in for
            // whether it is worth looking at every tile in it.
            guard (claim.centreTile.center - actor.position).length
                    <= GameConfig.AI.raidRange + Double(claim.size) else { continue }

            for col in claim.origin.col..<(claim.origin.col + claim.size) {
                for row in claim.origin.row..<(claim.origin.row + claim.size) {
                    let tile = GridPoint(col: col, row: row)
                    guard world.map[tile].blockOwner != nil else { continue }

                    let distance = (tile.center - actor.position).length
                    guard distance < shortest else { continue }
                    shortest = distance
                    closest = tile
                }
            }
        }

        return closest
    }

    /// Which hotbar slot to lob, or nil for "not yet".
    ///
    /// Steers clear of any cloud the bot is standing in or about to walk into -
    /// eventually, imperfectly, and not while it is being shot at.
    ///
    /// A push directly away from the middle of it, blended into the heading rather
    /// than replacing it, so a bot skirts a cloud on its way somewhere instead of
    /// turning round and abandoning the trip.
    ///
    /// Three things here are deliberately WORSE than they were, and they are the
    /// reason a stink bomb is now worth throwing. See GameConfig.AI.gasReaction for
    /// the full account; briefly: this used to run with a look-ahead longer than a
    /// cloud's own radius, no reaction time at all, and a weight of 1.0 that threw
    /// the heading away for the exactly optimal vector out. Nobody was ever in the
    /// gas, so no amount of damage on the cloud could make the item matter.
    private static func avoidGas(_ state: inout AIState, actor: Actor, dt: Double,
                                 in world: World) {
        let ahead = actor.feet + state.desiredHeading * GameConfig.AI.gasLookAhead

        for id in world.gasClouds.keys.sorted(by: { $0.raw < $1.raw }) {
            guard let cloud = world.gasClouds[id],
                  cloud.density >= GameConfig.Stink.bitingDensity else { continue }

            let inIt = cloud.contains(actor.feet)
            guard inIt || cloud.contains(ahead) else { continue }

            // Noticing it comes first, and takes a moment. Divided by caution
            // rather than multiplied, so a nervy bot (caution above one) reacts
            // SOONER - and seven bots do not all flinch on the same tick.
            state.gasNoticed += dt
            let needed = GameConfig.AI.gasReaction / max(0.01, state.caution)
            guard state.gasNoticed >= needed else { return }

            let away = actor.feet - cloud.centre
            let escape = away.length > 0.01 ? away.normalized() : Vec2(x: 1, y: 0)

            // Standing in one outranks whatever errand it was on; seeing one ahead
            // is a nudge.
            var weight = inIt ? GameConfig.AI.gasFlee : GameConfig.AI.gasSwerve

            // Except when it is running for its life, where a cloud is the lesser
            // problem. This is what makes gas across somebody's escape route work:
            // it used to be rerouted around for free.
            if state.goal.isRetreat { weight *= GameConfig.AI.gasPanic }

            let steer = state.desiredHeading * (1 - weight) + escape * weight

            // A blend can cancel itself out - walking straight at the middle of a
            // cloud puts escape opposite the heading - and normalized() answers
            // .zero for that, which would leave the bot with no heading at all.
            // Falling back on the escape is right either way: it is the direction
            // this function exists to produce.
            state.desiredHeading = steer.length > 0.01 ? steer.normalized() : escape
            return
        }

        // Clear of all of them, so the next cloud gets to surprise it again.
        state.gasNoticed = 0
    }

    /// A bomb flies along the aim, which for a raiding bot is wherever it is
    /// walking - so it has to be close enough AND actually pointed at the wall
    /// before throwing. Without the second test it would fling bombs sideways while
    /// rounding the corner of somebody's base.
    private static func bombToThrow(state: AIState, actor: Actor, in world: World) -> Int? {
        // Thrown on either raiding goal. Vandalism has a target handed to it;
        // robbing works out what is in the way, which is what turns "walk at the
        // chest and hope" into "open the wall and walk in".
        let target: GridPoint?

        switch state.goal {
        case .raid(let tile):
            target = tile
        case .robChest(let id):
            target = wallInTheWay(of: id, for: actor, in: world)
        case .wander, .loot, .collect, .fight, .retreat, .build, .farm, .stash,
             .rearm, .wreck, .silence, .defend, .hunt:
            target = nil
        }

        guard let tile = target else { return nil }
        guard world.map[tile].blockOwner != nil else { return nil }

        guard let slot = BombSystem.loadedSlot(of: actor),
              BombSystem.canThrow(actor, from: slot) else { return nil }

        let towards = tile.center - actor.position
        guard towards.length <= GameConfig.Bomb.throwRange else { return nil }
        guard abs(shortestAngle(from: actor.aim.angle, to: towards.angle))
                <= GameConfig.AI.throwTolerance else { return nil }

        return slot
    }

    /// A stink bomb worth throwing, or nil.
    ///
    /// At a PERSON rather than at a wall, which is the whole difference between the
    /// two things a bot can throw: a blast opens a base and is aimed at masonry, a
    /// cloud takes the ground somebody is standing on and is aimed at them. Using
    /// one on a wall would waste it, and the bomb picker above only ever finds
    /// blast bombs, so the two can never be confused.
    ///
    /// It will not throw one into gas that is already there. Two clouds on the same
    /// spot are one cloud that cost twice as much, and a bot that cannot see that
    /// looks like a bot.
    private static func stinkToThrow(state: AIState, actor: Actor, in world: World) -> Int? {
        guard case .fight(let id) = state.goal,
              let enemy = world.actors[id], enemy.isAlive else { return nil }

        guard let slot = actor.inventory.firstSlot(holding: .stink),
              BombSystem.canThrow(actor, from: slot) else { return nil }

        guard !world.gasAt(enemy.feet) else { return nil }

        let towards = enemy.position - actor.position
        guard towards.length <= GameConfig.Bomb.throwRange else { return nil }

        // Aimed, like a bomb: a bot lobbing one sideways while rounding a corner
        // gasses the ground it is about to walk over.
        guard abs(shortestAngle(from: actor.aim.angle, to: towards.angle))
                <= GameConfig.AI.throwTolerance else { return nil }

        return slot
    }

    // MARK: - Patching up

    /// Which supply to reach for, if any.
    ///
    /// The whole point of this function is WHEN, not what. A bot that patches up
    /// the instant its health dips is a bot that stops to wind a bandage mid-burst,
    /// in the open, while somebody empties a magazine into it - and reads as a
    /// machine reacting to a number. So the habits are:
    ///
    ///   - about to die: patch up now, under fire, whatever is to hand
    ///   - otherwise, finish the fight first
    ///   - then wait a beat after the shooting stops
    ///   - top up only if enough is missing to be worth it
    ///   - and never spend a medkit on a scratch
    ///
    /// Each bot's thresholds are scaled by its own nerve, so seven of them do not
    /// all reach for a bandage on the same frame.
    /// The power-up worth switching on, if there is one and now is the moment.
    ///
    /// Bots get these on exactly the same terms as the player - found in a crate,
    /// one at a time, refused by Actor.canUse while one is running - so all this
    /// has to decide is WHEN, and being in a fight is now the whole answer.
    ///
    /// It used to hold regeneration back until the bot was actually hurt, which was
    /// right when regeneration was a bottle of healing and nothing else: fifteen
    /// seconds of it at full health is fifteen seconds of nothing. The perk carries
    /// three other powers now, and every one of them is worth as much in the first
    /// second of a fight as in the last, so waiting to be hurt before drinking it
    /// is waiting to be behind.
    ///
    /// No cooldown timer of its own. Holding two perks at once is already rare, and
    /// Actor.canUse refuses the second while the first runs.
    ///
    /// Fighting was the whole answer, and it was too narrow: a bot only drank once
    /// it was already being shot, so most perks were either drunk too late to
    /// matter or carried until the bot died. Each perk now has its own moments, the
    /// ones a player would pick:
    ///
    ///   - any of them, in a fight or with an enemy close enough to start one
    ///   - Strength, Resistance and the disco ball on the way into a raid, once
    ///     the target base is close
    ///   - Resistance when defending its own base or contesting a supply drop
    ///   - Speed on a supply run, in retreat, or heading off on a raid
    ///   - Regeneration whenever it is hurt enough to want healing
    ///   - and anything carried longer than AI.perkPatience, whatever is going on
    private static func perkToUse(state: AIState, actor: Actor, in world: World) -> Int? {
        let held = actor.inventory.slots.enumerated().compactMap { index, slot -> (Int, Perk)? in
            guard let perk = slot?.type.perk, actor.canUse(slot: index) else { return nil }
            return (index, perk)
        }
        guard !held.isEmpty else { return nil }

        let fighting = state.goal.isFight
            || actor.secondsSinceHit < GameConfig.AI.combatRecency
        let enemyClose = nearestVisibleEnemy(to: actor, in: world).map {
            ($0.position - actor.position).length <= GameConfig.AI.perkEnemyRange
        } ?? false
        let hurt = Double(actor.health)
            < Double(actor.maxHealth) * GameConfig.AI.perkRegenBelow

        // Close to the base it is raiding: inside its claim, or nearly.
        let atRaid: Bool = {
            guard state.goal.isRaiding, let victim = base(of: state.goal, in: world),
                  let claim = world.claim(for: victim) else { return false }
            return (claim.centreTile.center - actor.position).length
                <= Double(claim.size) * 0.9
        }()
        let raidingFar = state.goal.isRaiding && !atRaid

        let supplyRun = isSupplyRun(state.goal, in: world)
        let retreating = state.goal.isRetreat
        let defending: Bool = {
            if case .defend = state.goal { return true }
            return false
        }()

        func wanted(_ perk: Perk) -> Bool {
            switch perk {
            case .overdrive:
                return fighting || enemyClose || atRaid || supplyRun
            case .strength:
                return fighting || enemyClose || atRaid
            case .resistance:
                return fighting || enemyClose || atRaid || defending || supplyRun
            case .speed:
                return fighting || supplyRun || retreating || raidingFar
            case .regeneration:
                return hurt || (fighting && actor.health < actor.maxHealth)
            }
        }

        if let pick = held.first(where: { wanted($0.1) }) { return pick.0 }

        // Carried too long without a moment for it: use it now.
        if state.perkHeldFor >= GameConfig.AI.perkPatience { return held[0].0 }

        return nil
    }

    private static func healToUse(_ state: inout AIState, actor: Actor) -> Int? {
        guard state.healTimer <= 0 else { return nil }
        guard actor.health < actor.maxHealth else { return nil }

        let maxHealth = Double(actor.maxHealth)
        let healthLeft = Double(actor.health) / maxHealth
        let missing = actor.maxHealth - actor.health

        let desperate = healthLeft < GameConfig.AI.criticalHealthFraction * state.caution

        if !desperate {
            // Still in it: keep shooting. A moment spent bandaging mid-fight is
            // usually a moment spent instead of the shot that would have won it.
            let stillFighting = state.goal.isFight
                || actor.secondsSinceHit < GameConfig.AI.combatRecency
            if stillFighting { return nil }

            // And a moment to breathe once it is over.
            guard actor.secondsSinceHit >= GameConfig.AI.settleDelay else { return nil }

            // Barely scratched - not worth an item.
            guard healthLeft <= GameConfig.AI.topUpHealthFraction * state.caution else {
                return nil
            }
        }

        var smallestThatFills: Int?
        var smallestAmount = Int.max
        var biggest: Int?
        var biggestAmount = 0

        for (index, slot) in actor.inventory.slots.enumerated() {
            guard let stack = slot, stack.type.isHealing,
                  ConsumableSystem.canUse(slot: index, actor: actor) else { continue }

            let amount = stack.type.healAmount(of: actor.maxHealth)

            if amount >= missing, amount < smallestAmount {
                smallestAmount = amount
                smallestThatFills = index
            }
            if amount > biggestAmount {
                biggestAmount = amount
                biggest = index
            }
        }

        guard let chosen = smallestThatFills ?? biggest else { return nil }

        // Check what that actually spends. "Smallest that fills" is not enough on
        // its own: with only medkits in the bag, a forty point wound still costs
        // the whole hundred. Spending it on a graze is how a bot arrives at its
        // next fight with an empty bar and nothing left, so hold out for something
        // smaller unless properly hurt.
        let spent = actor.inventory.slots[chosen]?.type.healAmount(of: actor.maxHealth) ?? 0
        if !desperate,
           Double(spent) > Double(missing) * GameConfig.AI.maximumOverheal,
           healthLeft > GameConfig.AI.overhealBelowFraction {
            return nil
        }

        state.healTimer = GameConfig.AI.healInterval
        return chosen
    }

    /// Where to go when breaking off - whether that is backing out of somebody's
    /// face mid-fight or running for your life.
    ///
    /// Blended: right on top of them, getting away is all that matters; with
    /// daylight between you, home is what matters, because that is where your own
    /// walls let you through and theirs do not.
    private static func breakOffPoint(for actor: Actor,
                                      awayFrom threat: Actor?,
                                      in world: World) -> Vec2 {
        let home = world.claim(for: actor.team)?.centreTile.center ?? actor.position

        guard let threat else { return home }

        let away = actor.position - threat.position
        guard away.length > 0.01 else { return home }

        let escape = actor.position + away.normalized() * GameConfig.AI.breakOffDistance
        let urgency = max(0, min(1, 1 - away.length / fightRanges(for: actor, in: world).engage))

        return escape * urgency + home * (1 - urgency)
    }

    // MARK: - Fighting

    private static func nearestVisibleEnemy(to actor: Actor, in world: World) -> Actor? {
        // Cheap tests first. Line of sight is a raycast against every tree and
        // crate on the map, and this runs ten times a second per bot - so it is
        // only ever paid for candidates that already passed everything else, in
        // order, until one is visible.
        let candidates = world.actors.values
            .filter {
                $0.team != actor.team
                    && $0.isAlive
                    && $0.invulnerability <= 0
                    && ($0.position - actor.position).length
                        < fightRanges(for: actor, in: world).engage
            }
            // Nearest first - but weighted by standing, so a bot will walk past
            // somebody nearer to go after whoever is winning. Ties broken by id, so
            // a seed always replays the same.
            .sorted {
                let a = weightedDistance(from: actor, to: $0, in: world)
                let b = weightedDistance(from: actor, to: $1, in: world)
                return a == b ? $0.id.raw < $1.id.raw : a < b
            }

        return candidates.first {
            hasLineOfSight(from: actor.position, to: $0.position, in: world)
        }
    }

    /// Whether to keep walking, or plant your feet and shoot.
    ///
    /// This is the single most important decision in a fight. Moving is how a bot
    /// aims, so a bot that keeps walking once it already HAS the shot never stops
    /// chasing - and two of them doing that to each other is exactly the pair of
    /// circling enemies you end up watching. Two actors at identical speed can
    /// never catch one another, so a fight has to be settled by shooting, not by
    /// closing the distance.
    /// Where to point the blaster, or nil for "hold your fire".
    ///
    /// Note this fires while RETREATING as well as while fighting. Running away
    /// with the blaster holstered is exactly what made bots look terrified; now a
    /// withdrawal is a fighting withdrawal.
    private static func shotToTake(state: AIState, actor: Actor, in world: World) -> Vec2? {
        guard state.reactionTimer <= 0, actor.ammo > 0 else { return nil }

        // A machine is shot at exactly the way a person is, and this is the only
        // branch that leaves before the lead calculation below - because furniture
        // does not move, so aiming ahead of it would miss on purpose.
        if case .wreck(let id) = state.goal, let machine = world.arcade(id) {
            return aimAtTarget(machine.centre, halfSpan: AIBrain.machineFaceInset,
                               from: actor, in: world)
        }

        // A turret is furniture that shoots back, and aimed at the same way: at
        // the box, with no lead, because it does not move.
        if case .silence(let id) = state.goal, let turret = world.turrets[id] {
            return aimAtTarget(turret.centre, halfSpan: AIBrain.turretFaceInset,
                               from: actor, in: world)
        }

        // A chest is shot open, so robbing one is the same act as wrecking a
        // machine and goes through the same door. Its half-span is small - a chest
        // is under a tile across - so the aim is at very nearly its centre.
        if case .robChest(let id) = state.goal, let chest = world.chests[id],
           chest.owner != actor.team {
            return aimAtTarget(chest.position, halfSpan: AIBrain.chestFaceInset,
                               from: actor, in: world)
        }

        let targetID: ActorID?
        switch state.goal {
        case .fight(let id):   targetID = id
        case .retreat(let id): targetID = id
        case .defend(let id):  targetID = id
        // A hunt is deliberately not here. It walks; it does not shoot. The
        // moment there is anything worth shooting at, reactToThreats has already
        // turned it into a .fight - see AIGoal.hunt.
        // .defend used to appear here as well as three lines up, where it binds.
        // The second one was unreachable and the compiler said so on every build.
        case .wander, .loot, .collect, .build, .raid, .farm, .robChest, .stash,
             .rearm, .wreck, .silence, .hunt:
            targetID = nil
        }

        guard let id = targetID,
              let enemy = world.actors[id],
              enemy.isAlive,
              enemy.invulnerability <= 0 else { return nil }

        let towards = enemy.position - actor.position
        guard towards.length <= GameConfig.Blaster.range else { return nil }

        // And they have to be able to SEE it coming. The blaster reaches twelve
        // tiles and a landscape screen shows under six of them vertically, so
        // without this a bot would open fire from above or below the camera - which
        // is the one thing the old engage cap was genuinely there to prevent.
        guard canOpenFire(on: enemy, from: actor, in: world) else { return nil }

        // Do not fire into the back of a tree. Same rules a bullet obeys, so a bot
        // never takes a shot the simulation would swallow.
        guard hasLineOfSight(from: actor.position, to: enemy.position, in: world) else {
            return nil
        }

        // Aim where they will BE, not where they are. A shot takes over half a
        // second to cross eight tiles and an actor covers two and a half in that
        // time, so against anything that is moving, aiming at its current position
        // misses almost every shot.
        //
        // This was tried once before and made fights markedly worse - but that was
        // when aiming and walking were the same thing, and the lead point wandering
        // about stopped a bot ever settling long enough to plant and shoot. Nothing
        // plants any more, so the objection died with the button. Simulated over 48
        // duels the difference is 28% of shots landing versus 51%, and a fight
        // resolving in five seconds rather than sixty.
        let flightTime = towards.length / GameConfig.Blaster.projectileSpeed
        let drift = enemy.moveInput.clampedToUnit()
            * (GameConfig.Player.moveSpeed * flightTime)
        let leadPoint = enemy.position + drift

        // The wobble is the only reason a bot misses now that aiming is its own
        // input rather than a side effect of which way it happens to be walking.
        //
        // Converted from a sideways distance into an angle HERE, because only here
        // is the range known. A fixed angle would make a bot deadlier the closer it
        // got, which is not how missing works and would have made bringing fights
        // into view a straight buff to the people shooting at you.
        // Tighter the further behind this bot is - see GameConfig.AI.pressureAim.
        // Deliberately a small share of the spread rather than a march towards
        // perfect: a bot that cannot miss is the least enjoyable opponent there is,
        // and the point of this is to be competitive rather than to be a wall.
        let spread = GameConfig.AI.aimSpread
            * (1 - world.behind(actor.team) * GameConfig.AI.pressureAim)

        let wobble = atan(spread / max(towards.length, 0.5))
        return Vec2.fromAngle((leadPoint - actor.position).angle + state.aimNoise * wobble)
    }

    /// Samples along the line. Uses the same rules a bullet does - including that
    /// walls stop shots even when they are your own - so a bot never takes a shot
    /// the simulation would swallow.
    /// The direction to fire at a machine, or nil if there is no shot yet.
    ///
    /// Line of sight is checked to a point short of the machine rather than to the
    /// machine itself, and that is not a fudge - it is the only way to ask the
    /// question correctly. blocksShot counts structures, and a machine IS a
    /// structure, so a ray drawn to its middle is stopped by the thing it is aimed
    /// at and every shot would be judged blocked. Backing off by more than its
    /// largest half-extent puts the test point at or outside the face the bullet
    /// will hit, which is exactly what needs to be clear.
    /// Where to point at a solid thing the bot wants to break: a machine, or a
    /// chest.
    ///
    /// Line of sight is checked to the FACE rather than the centre, because the
    /// thing's own body sits between the two and would report itself as cover.
    /// halfSpan is how far back that face can be from the centre at any angle.
    private static func aimAtTarget(_ centre: Vec2,
                                    halfSpan: Double,
                                    from actor: Actor,
                                    in world: World) -> Vec2? {
        let towards = centre - actor.position
        let distance = towards.length

        guard distance > 0.01, distance <= GameConfig.Blaster.range else { return nil }

        let direction = towards * (1 / distance)
        let face = centre - direction * halfSpan

        guard hasLineOfSight(from: actor.position, to: face, in: world) else { return nil }
        return direction
    }

    /// How far back from a machine's centre its nearest face can be, in tiles.
    ///
    /// Its footprint is three by two, so the largest half-extent is 1.5 and this
    /// clears it from any angle.
    private static let machineFaceInset: Double = 1.6

    /// The same for a chest, which is under a tile across - so this is barely off
    /// its centre, and a bot shooting one is aiming at the box itself.
    private static let chestFaceInset: Double = 0.55

    /// The same for a turret, whose footprint is two by two - a half-extent of
    /// one tile, cleared from any angle.
    private static let turretFaceInset: Double = 1.1

    private static func hasLineOfSight(from start: Vec2, to end: Vec2, in world: World) -> Bool {
        let delta = end - start
        let distance = delta.length
        guard distance > 0.01 else { return true }

        let direction = delta * (1 / distance)
        var travelled = GameConfig.Blaster.holdDistance

        while travelled < distance {
            if blocksShot(start + direction * travelled, in: world) { return false }
            travelled += 0.4
        }

        return true
    }

    private static func blocksShot(_ point: Vec2, in world: World) -> Bool {
        if world.map.isOccupied(GridPoint(containing: point)) { return true }
        if world.trees.contains(where: { $0.contains(point) }) { return true }
        if world.structureBlocks(point) { return true }
        return false
    }

    // MARK: - Steering

    /// If the way ahead is blocked, aim at the gentlest open direction instead.
    ///
    /// Because this only nudges the DESIRED heading, the bot still eases round at
    /// its normal turn rate. It reads as somebody seeing a tree and going around it,
    /// not as a bump followed by a rethink.
    private static func steerAroundObstacles(_ state: inout AIState,
                                             actor: Actor,
                                             in world: World) {
        guard !isClear(state.desiredHeading, from: actor, in: world) else { return }

        let base = state.desiredHeading.angle

        for offset in GameConfig.AI.avoidanceAngles {
            // Preferred side first, so a cornered bot commits rather than dithering.
            for side in [state.turnPreference, -state.turnPreference] {
                let candidate = Vec2.fromAngle(base + offset * side)
                if isClear(candidate, from: actor, in: world) {
                    state.desiredHeading = candidate
                    return
                }
            }
        }

        // Boxed in on every side: turn around and try again next tick.
        state.desiredHeading = Vec2.fromAngle(base + .pi)
    }

    /// Backs out of somewhere the bot has got itself wedged.
    ///
    /// The safety net under isClear, and it is worth having both. A wider probe
    /// stops a bot choosing a gap it cannot fit through; nothing stops the gap
    /// closing after it is already in there - a teammate lays a wall behind it, a
    /// chest is stood down beside it, a machine appears where it was standing. And
    /// MovementSystem.push deliberately leaves a genuinely wedged actor where it is
    /// rather than pinning it between two solids, on the reasoning that they can
    /// walk out. A person can. A bot walks back into it, sixty times a second,
    /// because full speed at its goal is the only thing it knows how to do.
    ///
    /// So: measure. Distance covered over a window rather than speed on one tick,
    /// because a bot squeezing along a wall genuinely does crawl and should not be
    /// mistaken for a stuck one. Then turn most of the way round and hold it long
    /// enough to actually get out - the turn rate means a reversal takes half a
    /// second before the bot has even started moving the other way.
    ///
    /// It drops the goal too. Backing out of a corner and then aiming straight back
    /// into it is the same bot stuck twice.
    private static func shoveOffIfStuck(_ state: inout AIState,
                                        actor: Actor,
                                        dt: Double,
                                        in world: World) {
        if state.shoveFor > 0 {
            state.shoveFor -= dt
            state.desiredHeading = state.shoveHeading
            return
        }

        let moved = state.lastPosition.map { (actor.position - $0).length } ?? 0
        state.lastPosition = actor.position

        state.stuckFor += dt
        state.stuckDistance += moved

        guard state.stuckFor >= GameConfig.AI.stuckWindow else { return }

        let wentNowhere = state.stuckDistance < GameConfig.AI.stuckDistance
        state.stuckFor = 0
        state.stuckDistance = 0

        guard wentNowhere else { return }

        state.shoveFor = GameConfig.AI.shoveDuration
        state.shoveHeading = Vec2.fromAngle(state.heading.angle
                                            + .pi * 0.8 * state.turnPreference)

        state.goal = .wander
        state.goalAge = 0
        state.decisionTimer = GameConfig.AI.shoveDuration
    }

    /// A soft nudge back towards the middle when a bot gets close to the map edge.
    ///
    /// Plain obstacle avoidance turns a bot to run PARALLEL to a wall, which is why
    /// they end up patrolling the border. This blends the heading towards the centre
    /// the closer they get, so they peel away instead of tracking along it.
    private static func curveAwayFromEdges(_ state: inout AIState, actor: Actor, in world: World) {
        let margin = GameConfig.AI.edgeMargin
        let width = Double(world.map.width)
        let height = Double(world.map.height)

        // 0 while comfortably inside, rising to 1 at the very edge.
        let closeness = max(
            max(margin - actor.position.x, actor.position.x - (width - margin)),
            max(margin - actor.position.y, actor.position.y - (height - margin))
        ) / margin

        guard closeness > 0 else { return }

        let inward = Vec2(x: width / 2, y: height / 2) - actor.position
        guard inward.length > 0.01 else { return }

        let strength = min(1, closeness) * GameConfig.AI.edgeBias
        let blended = state.desiredHeading * (1 - strength) + inward.normalized() * strength

        if blended.length > 0.01 {
            state.desiredHeading = blended.normalized()
        }
    }

    /// Whether the bot could actually walk this way - at its own WIDTH, not down a
    /// line drawn through the middle of it.
    ///
    /// A single line of probe points calls a gap clear when the gap is narrower
    /// than the bot. The figure is nine tenths of a tile across and one and three
    /// quarters deep, which is most of a tile and nearly two, so there are a great
    /// many holes its centre fits through and it does not: between a chest and the
    /// wall behind it, past the corner of a machine, through a doorway a teammate
    /// half filled.
    ///
    /// It walks in and wedges, and MovementSystem.push then declines to shove it
    /// anywhere at all - by design, see the reasoning there - so a person walks out
    /// under their own steam and a bot, whose heading is still pointed at whatever
    /// it was going to, does not. That is the bot standing motionless by its own
    /// chest until somebody bumps into it, and it was never really about chests.
    ///
    /// Three points across rather than one, offset along the direction's own
    /// perpendicular by how far the figure reaches that way.
    private static func isClear(_ direction: Vec2, from actor: Actor, in world: World) -> Bool {
        let side = Vec2(x: -direction.y, y: direction.x)

        // How far the box reaches along that perpendicular - its support in that
        // direction. Sideways travel is checked against the figure's width and
        // up-and-down travel against its depth, which is the axis that actually
        // catches: it is nearly twice the other one.
        let reach = (abs(side.x) * GameConfig.Player.halfWidth
                     + abs(side.y) * GameConfig.Player.halfDepth)
            * GameConfig.AI.probeWidthShare

        for distance in GameConfig.AI.probeDistances {
            let ahead = actor.position + direction * distance

            if !isOpen(ahead, for: actor.team, in: world) { return false }

            // Only close in. The far probes are about which way to head, and asking
            // for a body's worth of clearance three tiles out has a bot refusing
            // directions it would have been fine in by the time it got there - so
            // it stands turning on the spot in its own base, which is the failure
            // this is meant to end rather than a second flavour of it. Wedging
            // happens where the bot already is, so that is where the width matters.
            guard distance <= GameConfig.AI.probeWidthRange else { continue }

            for offset in [reach, -reach] {
                if !isOpen(ahead + side * offset, for: actor.team, in: world) {
                    return false
                }
            }
        }

        return true
    }

    private static func isOpen(_ point: Vec2, for team: TeamID, in world: World) -> Bool {
        let tile = GridPoint(containing: point)

        guard world.map.contains(tile) else { return false }
        guard !world.map.blocksMovement(at: tile, for: team) else { return false }
        guard !world.trees.contains(where: { $0.contains(point) }) else { return false }
        guard !world.structureBlocks(point) else { return false }

        return true
    }

    /// How long this bot takes to notice somebody, given how the match is going.
    ///
    /// Nobody reacts instantly and a bot that does feels like a machine, so the
    /// floor stays: even a bot being thrashed takes a fraction of a second. What
    /// changes is how much of the top of the range it draws from - a bot that is
    /// losing is paying attention.
    private static func reactionDelay(for actor: Actor, in world: World) -> Double {
        let range = GameConfig.AI.reactionDelay
        let keen = world.behind(actor.team) * GameConfig.AI.pressureReaction
        let upper = range.upperBound - (range.upperBound - range.lowerBound) * keen

        return Double.random(in: range.lowerBound...max(range.lowerBound, upper),
                             using: &world.rng)
    }

    /// Rotates one heading towards another by at most `limit` radians.
    private static func turn(_ heading: Vec2, towards desired: Vec2, limit: Double) -> Vec2 {
        let delta = shortestAngle(from: heading.angle, to: desired.angle)
        let step = max(-limit, min(limit, delta))
        return Vec2.fromAngle(heading.angle + step)
    }

    /// The short way round, so 170° to -170° is a 20° nudge rather than a 340° spin.
    private static func shortestAngle(from: Double, to: Double) -> Double {
        var delta = to - from
        while delta > .pi { delta -= 2 * .pi }
        while delta < -.pi { delta += 2 * .pi }
        return delta
    }
}
