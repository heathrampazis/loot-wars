//
//  AssistSystem.swift
//  Loot Wars
//
//  Easy controls: the fiddly parts done for you, so a new player can spend their
//  attention on moving and shooting.
//
//  - A crate opens the moment you are in reach of it.
//  - A heal is used when your health drops low - bought first if you have none.
//  - Your base follows you: walls go up on its outline as you walk along it,
//    the outline moves out to meet you if you linger just outside it, and walls
//    left inside the new outline come down as you pass them.
//  - A shot fired roughly at somebody is bent onto them (aim help).
//  - A power-up you are carrying switches on when a fight starts.
//
//  It works through the same commands a player sends - an open, a use, a shot -
//  so every rule about whether that is allowed is still checked in the one place
//  it lives. Apart from bending a shot it only ever adds; anything the player
//  does themselves still works.
//
//  Per actor rather than per match (see Actor.assisted), so in a match with real
//  people one player can have it on without it touching anyone else.
//

import Foundation

enum AssistSystem {

    static func contribute(to commands: inout [ActorID: [Command]], in world: World, dt: Double) {
        for id in world.actors.keys.sorted(by: { $0.raw < $1.raw }) {
            guard var actor = world.actors[id], actor.assisted, actor.ai == nil else { continue }

            actor.assistHealWait = max(0, actor.assistHealWait - dt)
            actor.assistBuildWait = max(0, actor.assistBuildWait - dt)
            actor.assistBuyWait = max(0, actor.assistBuyWait - dt)
            defer { world.actors[id] = actor }
            guard actor.isAlive else { continue }

            var added: [Command] = []

            // Aim help: each shot this tick is turned onto the best target near
            // where it was pointed. Noted, so a power-up can tell a fight has
            // started from the player's side too, not only from being hit.
            var lockedOn = false
            if let list = commands[id] {
                commands[id] = list.map { command in
                    guard case .shoot(let direction) = command,
                          let aimed = assistedAim(direction, for: actor, in: world) else {
                        return command
                    }
                    lockedOn = true
                    return .shoot(aimed)
                }
            }

            // Crates: in reach is enough. LootSystem picks the box and opens one
            // per tick, exactly as if the button had been pressed.
            if world.reachableLootbox(for: actor) != nil {
                added.append(.openLootbox)
            }

            // Heals: below the line, the best one in the bag - the smallest that
            // fills you up, or the biggest if none does. A short wait after each,
            // so two can not go in the same instant and the heal reads as a beat.
            let healthLeft = Double(actor.health) / Double(max(1, actor.maxHealth))
            if actor.assistHealWait <= 0, healthLeft < GameConfig.Assist.healBelow {
                if let slot = ConsumableSystem.bestHeal(for: actor) {
                    added.append(.useItem(slot: slot))
                    actor.assistHealWait = GameConfig.Assist.healGap
                } else if actor.assistBuyWait <= 0, let heal = bestHealToBuy(for: actor, in: world) {
                    // Nothing in the bag: buy one. It is used on a later tick by
                    // the line above, once it is in the bag.
                    added.append(.buyItem(heal))
                    actor.assistBuyWait = GameConfig.Assist.buyGap
                }
            }

            // Walls: the next piece of your base where you are walking, or an old
            // wall the base has moved out past. The plan is worked out every tick
            // so the time spent outside it is counted even between walls.
            let plan = basePlan(for: &actor, in: world, dt: dt)
            if actor.assistBuildWait <= 0, let plan,
               let change = nextWallChange(for: actor, plan: plan, in: world) {
                added.append(change)
                // Quicker while you are walking the route, so the wall keeps up.
                let walkingRoute = actor.moveInput.length > 0.2
                    && plan.isAlongOutline(GridPoint(containing: actor.feet))
                actor.assistBuildWait = walkingRoute ? GameConfig.Assist.buildGapAlongPath
                                                     : GameConfig.Assist.buildGap
            }

            // Power-ups: switched on when a fight starts - you were just hit, or
            // you are shooting at somebody - and only when none is running.
            let inFight = lockedOn || actor.secondsSinceHit < GameConfig.Assist.perkHitWithin
            if inFight, actor.perk == nil, let slot = bestPerk(for: actor) {
                added.append(.useItem(slot: slot))
            }

            if !added.isEmpty {
                commands[id, default: []].append(contentsOf: added)
            }
        }
    }

    // MARK: - Aim help

    /// The shot turned onto the enemy nearest to where it was aimed, if one is
    /// inside the aim help's cone, in range and in plain sight - or nil to leave
    /// the shot alone. Aimed where they will be, the way the bots aim.
    private static func assistedAim(_ direction: Vec2, for actor: Actor, in world: World) -> Vec2? {
        guard direction.length > 0.01 else { return nil }
        let aim = direction.normalized()
        let cone = GameConfig.Assist.aimCone

        var best: (point: Vec2, score: Double)?

        for id in world.actors.keys.sorted(by: { $0.raw < $1.raw }) {
            guard let enemy = world.actors[id], enemy.team != actor.team,
                  enemy.isAlive, enemy.invulnerability <= 0 else { continue }

            let towards = enemy.position - actor.position
            let distance = towards.length
            guard distance > 0.01, distance <= GameConfig.Blaster.range else { continue }

            let dot = max(-1, min(1, (aim.x * towards.x + aim.y * towards.y) / distance))
            let angle = acos(dot)
            guard angle <= cone else { continue }
            guard AIBrain.hasLineOfSight(from: actor.position, to: enemy.position, in: world) else {
                continue
            }

            // Mostly the angle, a little the distance: the one you are pointing
            // at, and of two in line, the nearer.
            let score = angle / cone + distance / GameConfig.Blaster.range * 0.35
            guard score < (best?.score ?? .greatestFiniteMagnitude) else { continue }

            let flightTime = distance / GameConfig.Blaster.projectileSpeed
            let drift = enemy.moveInput.clampedToUnit()
                * (GameConfig.Player.moveSpeed * enemy.speedMultiplier * flightTime)
            best = (enemy.position + drift, score)
        }

        guard let target = best?.point else { return nil }
        let turned = target - actor.position
        return turned.length > 0.01 ? turned.normalized() : nil
    }

    // MARK: - Power-ups

    /// The power-up worth switching on, or nil. Low on health, the ones that
    /// keep you alive come first; otherwise the ones that win the fight. Health
    /// back is never used near full health, where it would be wasted.
    private static func bestPerk(for actor: Actor) -> Int? {
        let healthLeft = Double(actor.health) / Double(max(1, actor.maxHealth))
        let order: [Perk] = healthLeft < GameConfig.Assist.healBelow
            ? [.overdrive, .regeneration, .resistance, .strength, .speed]
            : [.strength, .resistance, .overdrive, .speed, .regeneration]

        for perk in order {
            if perk == .regeneration, healthLeft >= GameConfig.Assist.regenBelow { continue }
            for (index, slot) in actor.inventory.slots.enumerated() {
                guard slot?.type.perk == perk,
                      ConsumableSystem.canUse(slot: index, actor: actor) else { continue }
                return index
            }
        }
        return nil
    }

    // MARK: - Building

    /// Your base as easy controls sees it, or nil when there is nothing to build:
    /// out of your claim, just bombed, or already closed.
    ///
    /// Before your first wall the square sits round wherever you are. After that
    /// it stays put until you have stood just over its outline for followDelay
    /// seconds, and only then moves out to meet you - so walking past it, or out
    /// of your base, leaves it alone. Noted on the actor so the markers draw the
    /// same plan.
    private static func basePlan(for actor: inout Actor, in world: World,
                                 dt: Double) -> World.BasePlan? {
        let feet = GridPoint(containing: actor.feet)
        let base = world.enclosure(of: actor.team)

        guard world.canBuild(actor.team),
              world.claim(for: actor.team)?.contains(feet) == true,
              !base.isSealed else {
            actor.assistOutsideTime = 0
            actor.assistFollowing = nil
            return nil
        }

        if base.ownWalls.isEmpty {
            actor.assistOutsideTime = 0
            actor.assistFollowing = feet
        } else {
            let still = world.basePlan(for: actor.team, walls: base.ownWalls, towardsMiddle: true)
            if still?.isJustOutside(feet) == true {
                actor.assistOutsideTime += dt
            } else {
                actor.assistOutsideTime = 0
            }
            actor.assistFollowing = actor.assistOutsideTime >= GameConfig.Assist.followDelay
                ? feet : nil
        }

        return world.basePlan(for: actor.team, walls: base.ownWalls,
                              towardsMiddle: true, following: actor.assistFollowing)
    }

    /// The next wall to put up or take down near your feet, or nil.
    ///
    /// Up first: the nearest gap in the plan's outline within a step or so,
    /// never the tile you are standing on. Failing that, down: one of your own
    /// walls within reach that the plan has moved out past, so the base reshapes
    /// round you rather than leaving its old outline standing inside the new one.
    private static func nextWallChange(for actor: Actor, plan: World.BasePlan,
                                       in world: World) -> Command? {
        let base = world.enclosure(of: actor.team)

        if let tile = nearest(plan.gaps, to: actor, where: {
            !actor.overlaps($0) && BuildSystem.canPlace(at: $0, by: actor, in: world)
        }) {
            return .placeBlock(tile)
        }

        if let tile = nearest(Array(base.ownWalls), to: actor, where: {
            plan.isInterior($0) && BuildSystem.canRemove(at: $0, by: actor, in: world)
        }) {
            return .removeBlock(tile)
        }
        return nil
    }

    /// The tile within build reach nearest your feet that passes the test, or nil.
    /// A tie goes to the lower tile so the same spot always gives the same answer.
    private static func nearest(_ tiles: [GridPoint], to actor: Actor,
                                where allowed: (GridPoint) -> Bool) -> GridPoint? {
        var best: (tile: GridPoint, away: Double)?
        for tile in tiles {
            let centre = Vec2(x: Double(tile.col) + 0.5, y: Double(tile.row) + 0.5)
            let away = (centre - actor.feet).length
            guard away <= GameConfig.Assist.buildReach else { continue }
            if let current = best {
                if away > current.away { continue }
                if away == current.away,
                   (tile.row, tile.col) > (current.tile.row, current.tile.col) { continue }
            }
            guard allowed(tile) else { continue }
            best = (tile, away)
        }
        return best?.tile
    }

    // MARK: - Buying heals

    /// The biggest heal on the shelf you can afford, as the quick buy offers it.
    private static func bestHealToBuy(for actor: Actor, in world: World) -> ItemType? {
        GameConfig.Shop.tabs
            .flatMap { tab -> [GameConfig.Shop.Item] in
                if case .shelf(let items) = tab.stock { return items }
                return []
            }
            .filter { $0.type.isHealing && ShopSystem.canBuy($0.type, actor: actor, in: world) }
            .max { $0.price < $1.price }?
            .type
    }
}
