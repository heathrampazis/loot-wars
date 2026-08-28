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
        state.reactionTimer = max(0, state.reactionTimer - dt)
        state.decisionTimer -= dt

        if state.decisionTimer <= 0 {
            changeOfMind(&state, actor: actor, in: world)
            state.decisionTimer = Double.random(in: GameConfig.AI.decisionInterval,
                                                using: &world.rng)
        }

        // Chasing goals re-aim every tick. Only committing to a direction twice a
        // second would let a bot sail straight past what it was walking to.
        aimAtTarget(&state, actor: actor, in: world)

        // Looking where you are going happens every tick, not on the decision timer.
        // Waiting up to three seconds to notice a tree is how a bot ends up grinding
        // into one in full view.
        steerAroundObstacles(&state, actor: actor, in: world)
        curveAwayFromEdges(&state, actor: actor, in: world)

        // Turn towards the desired heading rather than snapping to it.
        state.heading = turn(state.heading,
                             towards: state.desiredHeading,
                             limit: GameConfig.AI.turnRate * dt)

        actor.ai = state

        var commands: [Command] = [.move(movement(for: state, actor: actor, in: world))]

        if shouldShoot(state: state, actor: actor, in: world) {
            commands.append(.shoot)
        }

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
        case .wander, .fight, .retreat:
            break
        }

        let wanted = chooseGoal(for: actor, state: state, in: world)
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

        if case .wander = state.goal {
            // Swing off the CURRENT heading rather than picking a fresh direction
            // out of the air, so a change of mind is a course correction and not a
            // pirouette.
            let swing = Double.random(in: -GameConfig.AI.wanderTurn...GameConfig.AI.wanderTurn,
                                      using: &world.rng)
            state.desiredHeading = Vec2.fromAngle(state.heading.angle + swing)
        }
    }

    /// Priority order: staying alive, then fighting, then loot, then roaming.
    private static func chooseGoal(for actor: Actor, state: AIState, in world: World) -> AIGoal {
        if let enemy = nearestVisibleEnemy(to: actor, in: world) {
            let healthLeft = Double(actor.health) / Double(GameConfig.Player.maxHealth)

            // Hurt and in danger: get out. Note this only holds while an enemy is
            // actually near - once it is safe the bot goes back to work rather than
            // hiding at home for the rest of the match.
            if healthLeft < GameConfig.AI.retreatHealthFraction {
                return .retreat
            }

            return .fight(enemy.id)
        }

        guard state.lootCooldown <= 0 else { return .wander }

        // Something already on the ground beats walking to a crate: it is closer,
        // and it is usually the thing this bot just opened.
        if let item = nearestItem(to: actor, in: world) {
            return .collect(item.id)
        }

        if let crate = nearestCrate(to: actor, in: world) {
            return .loot(crate.id)
        }

        return .wander
    }

    private static func nearestItem(to actor: Actor, in world: World) -> GroundItem? {
        var closest: GroundItem?
        var shortest = GameConfig.AI.itemSearchRange

        for item in world.groundItems.values {
            // No point walking to something there is no room for.
            guard actor.inventory.canAccept(item.type) else { continue }

            let distance = (item.position - actor.position).length
            guard distance < shortest else { continue }
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

    private static func aimAtTarget(_ state: inout AIState, actor: Actor, in world: World) {
        let target: Vec2?

        switch state.goal {
        case .wander:
            return
        case .loot(let id):
            target = world.lootboxes[id]?.position
        case .collect(let id):
            target = world.groundItems[id]?.position
        case .fight(let id):
            target = world.actors[id].flatMap { $0.isAlive ? $0.position : nil }
        case .retreat:
            target = world.claim(for: actor.team)?.centreTile.center
        }

        // Somebody else got there first. Drop back to roaming rather than walking
        // towards something that no longer exists.
        guard let target else {
            state.goal = .wander
            state.goalAge = 0
            return
        }

        // Steering aims the actor's centre at the item, which puts the item well
        // inside the hitbox by the time it arrives - so walking to it is enough to
        // pick it up.
        let towards = target - actor.position
        guard towards.length > 0.01 else { return }

        // Aim wobble is applied to the heading, not to the bullet, because a bot
        // shoots where it walks. Missing therefore looks like slightly sloppy
        // movement, which is exactly how a person misses.
        if case .fight = state.goal {
            state.desiredHeading = Vec2.fromAngle(towards.angle + state.aimNoise)
        } else {
            state.desiredHeading = towards.normalized()
        }
    }

    // MARK: - Fighting

    private static func nearestVisibleEnemy(to actor: Actor, in world: World) -> Actor? {
        var closest: Actor?
        var shortest = GameConfig.AI.engageRange

        // Fixed order, so two equally distant enemies are always resolved the same
        // way and a seed replays identically.
        for id in world.actors.keys.sorted(by: { $0.raw < $1.raw }) {
            guard let candidate = world.actors[id],
                  candidate.team != actor.team,
                  candidate.isAlive,
                  candidate.invulnerability <= 0 else { continue }

            let distance = (candidate.position - actor.position).length
            guard distance < shortest else { continue }
            guard hasLineOfSight(from: actor.position, to: candidate.position, in: world) else { continue }

            shortest = distance
            closest = candidate
        }

        return closest
    }

    /// Whether to keep walking, or hold still and trade shots.
    ///
    /// Standing still keeps the last facing, which is what lets a bot hold its
    /// ground without losing its aim. It starts moving again the moment the target
    /// drifts off that aim - so it turns by taking a step, exactly as you do.
    private static func movement(for state: AIState, actor: Actor, in world: World) -> Vec2 {
        guard case .fight(let id) = state.goal,
              let enemy = world.actors[id], enemy.isAlive else { return state.heading }

        let towards = enemy.position - actor.position
        guard towards.length <= GameConfig.AI.standoffRange else { return state.heading }
        guard aimIsOn(actor: actor, towards: towards) else { return state.heading }

        return .zero
    }

    private static func shouldShoot(state: AIState, actor: Actor, in world: World) -> Bool {
        guard case .fight(let id) = state.goal else { return false }
        guard state.reactionTimer <= 0 else { return false }

        guard let enemy = world.actors[id],
              enemy.isAlive,
              enemy.invulnerability <= 0 else { return false }

        let towards = enemy.position - actor.position
        guard towards.length <= GameConfig.Blaster.range else { return false }
        guard aimIsOn(actor: actor, towards: towards) else { return false }

        // Do not fire into the back of a tree.
        return hasLineOfSight(from: actor.position, to: enemy.position, in: world)
    }

    /// Is the bot lined up well enough to be worth pulling the trigger?
    ///
    /// The tolerance is how wide the target LOOKS from here, not a fixed angle. A
    /// fixed 0.2 radians is about half a tile at two tiles away but two and a half
    /// tiles at twelve, so a bot using it would blaze away at long range and hit
    /// nothing. This way its aim error naturally pushes it to close the distance
    /// before shooting, which is what a person does.
    private static func aimIsOn(actor: Actor, towards: Vec2) -> Bool {
        let distance = max(towards.length, 0.5)
        let apparentWidth = atan(GameConfig.Player.halfWidth / distance)
        let tolerance = min(GameConfig.AI.aimTolerance, apparentWidth)

        return abs(shortestAngle(from: actor.facing.angle, to: towards.angle)) <= tolerance
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
