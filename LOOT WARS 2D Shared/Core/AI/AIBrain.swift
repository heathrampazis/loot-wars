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
        state.drinkTimer = max(0, state.drinkTimer - dt)
        state.placeTimer = max(0, state.placeTimer - dt)
        state.reactionTimer = max(0, state.reactionTimer - dt)
        state.decisionTimer -= dt

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

        // Looking where you are going happens every tick, not on the decision timer.
        // Waiting up to three seconds to notice a tree is how a bot ends up grinding
        // into one in full view.
        steerAroundObstacles(&state, actor: actor, in: world)

        // The edge nudge is for roaming. Applying it in a fight fights the bot's
        // own attempt to hold its range near a border.
        if !state.goal.isFight {
            curveAwayFromEdges(&state, actor: actor, in: world)
        }

        // Turn towards the desired heading rather than snapping to it.
        state.heading = turn(state.heading,
                             towards: state.desiredHeading,
                             limit: GameConfig.AI.turnRate * dt)

        var commands: [Command] = [.move(state.heading)]

        if let wall = wallToLay(&state, actor: actor, in: world) {
            commands.append(.placeBlock(wall))
            actor.ai = state
        }

        if let slot = drinkToTake(&state, actor: actor) {
            commands.append(.useItem(slot: slot))
            actor.ai = state
        }

        // Worked out entirely separately from where the bot is walking, so it can
        // back off, circle or run for home without ever taking the blaster off its
        // target. That one separation is what stops fights collapsing into two bots
        // walking into each other.
        if let aim = shotToTake(state: state, actor: actor, in: world) {
            commands.append(.shoot(aim))
        }

        actor.ai = state

        // Open whatever is within reach, whatever the bot was busy doing. Walking
        // past an open-able crate and ignoring it is the sort of thing that gives
        // a bot away.
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
        case .loot, .collect:
            if state.goalAge > GameConfig.AI.lootPatience {
                state.lootCooldown = GameConfig.AI.lootCooldown
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
        case .wander, .fight, .retreat:
            break
        }

        var wanted = chooseGoal(for: actor, state: state, in: world)

        // Re-point at the current next wall rather than the one chosen minutes ago,
        // which may well have been laid by now.
        if case .build = wanted, case .build = state.goal,
           let current = world.nextBuildTile(for: actor.team) {
            wanted = .build(current)
        }

        if case .build = wanted, !state.goal.isBuild {
            state.blocksLeftToLay = Int.random(in: GameConfig.Build.blocksPerVisit, using: &world.rng)
        }

        if wanted != state.goal {
            // Only a NEW fight costs a reaction - a bot already shooting at someone
            // does not freeze up again every time it re-picks the same target.
            if case .fight = wanted, !state.goal.isFight {
                state.reactionTimer = Double.random(in: GameConfig.AI.reactionDelay,
                                                    using: &world.rng)
            }
            state.goal = wanted
            state.goalAge = 0
        }

        state.aimNoise = Double.random(in: -GameConfig.AI.aimError...GameConfig.AI.aimError,
                                       using: &world.rng)

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

        switch state.goal {
        case .fight, .retreat:
            return
        case .wander, .loot, .collect, .build:
            // Building is interruptible. A bot laying bricks while somebody shoots
            // at it is not a bot anyone believes in.
            break
        }

        guard let enemy = nearestVisibleEnemy(to: actor, in: world) else { return }

        let healthLeft = Double(actor.health) / Double(actor.maxHealth)

        state.goal = healthLeft < GameConfig.AI.retreatHealthFraction * state.caution
            ? .retreat(from: enemy.id)
            : .fight(enemy.id)
        state.goalAge = 0
        state.reactionTimer = Double.random(in: GameConfig.AI.reactionDelay, using: &world.rng)
    }

    /// Priority order: staying alive, then fighting, then loot, then roaming.
    private static func chooseGoal(for actor: Actor, state: AIState, in world: World) -> AIGoal {
        if let enemy = nearestVisibleEnemy(to: actor, in: world) {
            let healthLeft = Double(actor.health) / Double(actor.maxHealth)

            // Hurt and in danger: get out. Note this only holds while an enemy is
            // actually near - once it is safe, or once it has drunk its way back to
            // health, the bot turns round and fights rather than hiding at home for
            // the rest of the match.
            if healthLeft < GameConfig.AI.retreatHealthFraction * state.caution {
                return .retreat(from: enemy.id)
            }

            return .fight(enemy.id)
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

        // Almost out of drinks: go shopping, base or no base.
        if actor.inventory.totalHealing(of: actor.maxHealth) < GameConfig.AI.emergencyHealingStock,
           state.lootCooldown <= 0 {
            if let item = nearestItem(to: actor, in: world) { return .collect(item.id) }
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

            if let crate = nearestCrate(to: actor, in: world) {
                return .loot(crate.id)
            }
        }

        return .wander
    }

    private static func nearestItem(to actor: Actor, in world: World) -> GroundItem? {
        var closest: GroundItem?
        var shortest = Double.greatestFiniteMagnitude

        for item in world.groundItems.values {
            // Asks the actor the same question the pickup code will, so a bot can
            // never set off for something it would then decline to take.
            guard actor.wants(item.pickup) else { continue }

            // A drink is worth a few steps. A better helmet is worth a walk - it is
            // the difference between winning the next fight and losing it, so it
            // gets the same reach a crate does.
            let worthTravelling: Double
            switch item.pickup {
            case .item:   worthTravelling = GameConfig.AI.itemSearchRange
            case .helmet: worthTravelling = GameConfig.AI.lootSearchRange
            }

            let distance = (item.position - actor.position).length
            guard distance < worthTravelling, distance < shortest else { continue }
            shortest = distance
            closest = item
        }

        return closest
    }

    private static func nearestCrate(to actor: Actor, in world: World) -> Lootbox? {
        var closest: Lootbox?
        var shortest = GameConfig.AI.lootSearchRange

        for crate in world.lootboxes.values {
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
            steer(&state, actor: actor, to: world.lootboxes[id]?.position)

        case .collect(let id):
            steer(&state, actor: actor, to: world.groundItems[id]?.position)

        case .build(let tile):
            steer(&state, actor: actor,
                  to: standingSpot(for: tile, team: actor.team, in: world))

        case .retreat(let id):
            steer(&state, actor: actor,
                  to: breakOffPoint(for: actor, awayFrom: world.actors[id], in: world))

        case .fight(let id):
            steerForFight(&state, actor: actor, enemy: id, in: world)
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
              (enemy.position - actor.position).length <= GameConfig.AI.disengageRange else {
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
        if gap < GameConfig.AI.minimumRange || actor.ammo <= 0 {
            let escape = breakOffPoint(for: actor, awayFrom: enemy, in: world) - actor.position
            state.desiredHeading = escape.length > 0.01
                ? escape.normalized()
                : direct * -1
            return
        }

        // Too far to be shooting from: close the distance.
        if gap > GameConfig.AI.preferredRange {
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

        state.placeTimer = GameConfig.Build.placeInterval
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

    // MARK: - Drinking

    /// Which drink to reach for, if any.
    ///
    /// The whole point of this function is WHEN, not what. A bot that drinks the
    /// instant its health dips is a bot that swigs mid-burst, in the open, while
    /// somebody empties a magazine into it - and reads as a machine reacting to a
    /// number. So the habits are:
    ///
    ///   - about to die: drink now, under fire, whatever is to hand
    ///   - otherwise, finish the fight first
    ///   - then wait a beat after the shooting stops
    ///   - top up only if enough is missing to be worth it
    ///   - and never tip a big drink down a small wound
    ///
    /// Each bot's thresholds are scaled by its own nerve, so seven of them do not
    /// all reach for a drink on the same frame.
    private static func drinkToTake(_ state: inout AIState, actor: Actor) -> Int? {
        guard state.drinkTimer <= 0 else { return nil }
        guard actor.health < actor.maxHealth else { return nil }

        let maxHealth = Double(actor.maxHealth)
        let healthLeft = Double(actor.health) / maxHealth
        let missing = actor.maxHealth - actor.health

        let desperate = healthLeft < GameConfig.AI.criticalHealthFraction * state.caution

        if !desperate {
            // Still in it: keep shooting. A drink taken mid-fight is usually a
            // drink taken instead of the shot that would have won it.
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
            guard let stack = slot,
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

        // Check what that actually pours away. "Smallest that fills" is not enough
        // on its own: with only slushies in the bag, a forty point wound still
        // takes the whole hundred. Spending it on a graze is how a bot arrives at
        // its next fight with an empty bar and nothing left, so hold out for
        // something smaller unless properly hurt.
        let poured = actor.inventory.slots[chosen]?.type.healAmount(of: actor.maxHealth) ?? 0
        if !desperate,
           Double(poured) > Double(missing) * GameConfig.AI.maximumOverdrink,
           healthLeft > GameConfig.AI.overdrinkBelowFraction {
            return nil
        }

        state.drinkTimer = GameConfig.AI.drinkInterval
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
        let urgency = max(0, min(1, 1 - away.length / GameConfig.AI.engageRange))

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
                    && ($0.position - actor.position).length < GameConfig.AI.engageRange
            }
            // Nearest first; ties broken by id, so a seed always replays the same.
            .sorted {
                let a = ($0.position - actor.position).length
                let b = ($1.position - actor.position).length
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

        let targetID: ActorID?
        switch state.goal {
        case .fight(let id):   targetID = id
        case .retreat(let id): targetID = id
        case .wander, .loot, .collect, .build: targetID = nil
        }

        guard let id = targetID,
              let enemy = world.actors[id],
              enemy.isAlive,
              enemy.invulnerability <= 0 else { return nil }

        let towards = enemy.position - actor.position
        guard towards.length <= GameConfig.Blaster.range else { return nil }

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
        return Vec2.fromAngle((leadPoint - actor.position).angle + state.aimNoise)
    }

    /// Samples along the line. Uses the same rules a bullet does - including that
    /// walls stop shots even when they are your own - so a bot never takes a shot
    /// the simulation would swallow.
    private static func hasLineOfSight(from start: Vec2, to end: Vec2, in world: World) -> Bool {
        let delta = end - start
        let distance = delta.length
        guard distance > 0.01 else { return true }

        let direction = delta * (1 / distance)
        var travelled = GameConfig.Blaster.muzzleOffset

        while travelled < distance {
            if blocksShot(start + direction * travelled, in: world) { return false }
            travelled += 0.4
        }

        return true
    }

    private static func blocksShot(_ point: Vec2, in world: World) -> Bool {
        if world.map.isOccupied(GridPoint(containing: point)) { return true }
        if world.trees.contains(where: { $0.contains(point) }) { return true }
        if world.lootboxes.values.contains(where: { $0.hitbox.contains(point) }) { return true }
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

    private static func isClear(_ direction: Vec2, from actor: Actor, in world: World) -> Bool {
        for distance in GameConfig.AI.probeDistances {
            if !isOpen(actor.position + direction * distance, for: actor.team, in: world) {
                return false
            }
        }
        return true
    }

    private static func isOpen(_ point: Vec2, for team: TeamID, in world: World) -> Bool {
        let tile = GridPoint(containing: point)

        guard world.map.contains(tile) else { return false }
        guard !world.map.blocksMovement(at: tile, for: team) else { return false }
        guard !world.trees.contains(where: { $0.contains(point) }) else { return false }
        guard !world.lootboxes.values.contains(where: { $0.hitbox.contains(point) }) else { return false }

        return true
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
