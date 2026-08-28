//
//  AISystem.swift
//  Loot Wars
//
//  Runs every brain and folds what they produce into the tick's commands.
//
//  It runs INSIDE World.step rather than in the scene, which matters: a networked
//  host would then run exactly these bots the same way, from the same seed, without
//  the client having to send anything about them.
//
//  External commands always win. If something is already driving an actor - a
//  joystick today, a remote player later - its brain stays quiet.
//

enum AISystem {

    static func contribute(to commands: inout [ActorID: [Command]], in world: World, dt: Double) {
        guard GameConfig.AI.enabled else { return }

        // Fixed order. Brains draw from world.rng, so the order they run in decides
        // which numbers each one gets - dictionary order would make the same seed
        // play out differently every run.
        for id in world.actors.keys.sorted(by: { $0.raw < $1.raw }) {
            guard commands[id] == nil else { continue }

            guard var actor = world.actors[id],
                  actor.ai != nil,
                  actor.isAlive else { continue }

            let produced = AIBrain.think(for: &actor, in: world, dt: dt)
            world.actors[id] = actor

            if !produced.isEmpty {
                commands[id] = produced
            }
        }
    }
}
