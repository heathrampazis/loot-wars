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
//  Two phases, on purpose:
//
//    chooseGoal - runs on a timer, decides WHAT to do
//    execute    - runs every tick, decides HOW, given the current goal
//
//  Splitting them is what stops bots dithering. Re-deciding the goal sixty times a
//  second makes them vibrate between options; deciding twice a second and then
//  committing makes them look like they meant it.
//

import Foundation

enum AIBrain {

    static func think(for actor: inout Actor, in world: World, dt: Double) -> [Command] {
        guard var state = actor.ai else { return [] }

        state.decisionTimer -= dt
        if state.decisionTimer <= 0 {
            reconsider(&state, actor: actor, in: world)
            state.decisionTimer = GameConfig.AI.decisionInterval
            state.positionAtLastDecision = actor.position
        }

        actor.ai = state
        return execute(state.goal, state: state, actor: actor, in: world)
    }

    // MARK: - Deciding

    private static func reconsider(_ state: inout AIState, actor: Actor, in world: World) {
        state.goal = chooseGoal(for: actor, in: world)

        let arrived = (state.destination - actor.position).length <= GameConfig.AI.arriveDistance

        // Barely moved since the last decision? Something is in the way, and no
        // amount of walking at it will help. Pick somewhere else.
        let stuck = (actor.position - state.positionAtLastDecision).length < GameConfig.AI.stuckDistance

        if arrived || stuck {
            state.destination = wanderDestination(from: actor, in: world)
        }
    }

    /// Always .wander for now. Fighting, looting and retreating are added here, in
    /// priority order, as each one lands.
    private static func chooseGoal(for actor: Actor, in world: World) -> AIGoal {
        .wander
    }

    // MARK: - Doing

    private static func execute(_ goal: AIGoal,
                                state: AIState,
                                actor: Actor,
                                in world: World) -> [Command] {
        switch goal {
        case .wander:
            return walk(towards: state.destination, from: actor)
        }
    }

    private static func walk(towards destination: Vec2, from actor: Actor) -> [Command] {
        let heading = destination - actor.position

        // Arriving has to be said out loud. Producing no command would leave the
        // previous move input in place, and the bot would drift off forever.
        guard heading.length > GameConfig.AI.arriveDistance else { return [.move(.zero)] }

        return [.move(heading.normalized())]
    }

    // MARK: - Picking somewhere to go

    private static func wanderDestination(from actor: Actor, in world: World) -> Vec2 {
        // Try a handful of spots and take the first open one. A fixed number of
        // attempts means this always terminates, however cluttered the map gets.
        for _ in 0..<GameConfig.AI.destinationAttempts {
            let angle = Double.random(in: 0..<(2 * .pi), using: &world.rng)
            let distance = Double.random(in: GameConfig.AI.wanderRange, using: &world.rng)

            let candidate = actor.position + Vec2(x: cos(angle), y: sin(angle)) * distance
            if isOpen(candidate, for: actor.team, in: world) { return candidate }
        }

        // Nowhere obvious to go: stand still rather than walk into a wall forever.
        return actor.position
    }

    private static func isOpen(_ point: Vec2, for team: TeamID, in world: World) -> Bool {
        let tile = GridPoint(containing: point)

        guard world.map.contains(tile) else { return false }
        guard !world.map.blocksMovement(at: tile, for: team) else { return false }
        guard !world.trees.contains(where: { $0.contains(point) }) else { return false }
        guard !world.lootboxes.values.contains(where: { $0.hitbox.contains(point) }) else { return false }

        return true
    }
}
