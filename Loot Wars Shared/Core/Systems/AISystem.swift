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

            resupply(&actor, dt: dt, in: world)

            let produced = AIBrain.think(for: &actor, in: world, dt: dt)
            world.actors[id] = actor

            if !produced.isEmpty {
                commands[id] = produced
            }
        }
    }

    /// Hands a bot with nothing to raid with a single bomb, now and then.
    ///
    /// A deliberate cheat, and worth naming as one. Bots get bombs from crates like
    /// everyone else; this tops up ONLY an empty pocket, ONLY to one, and only every
    /// forty seconds. One crate in seven carries a bomb, which is fine on average
    /// and useless in particular - a bot that draws badly for two minutes simply
    /// cannot raid, and raiding is most of what makes a base worth building. So this
    /// is a floor under the supply rather than a supply.
    private static func resupply(_ actor: inout Actor, dt: Double, in world: World) {
        // Bots wait out the grace period like everybody else. A floor under the
        // bomb supply that ignored it would simply move the raiding it was meant to
        // hold back onto the bots.
        guard world.bombsAtFullSupply else { return }
        guard var state = actor.ai else { return }

        state.bombSupplyTimer -= dt

        if state.bombSupplyTimer <= 0 {
            state.bombSupplyTimer = GameConfig.AI.bombSupplyInterval
                * world.difficulty.bombSupplyScale

            if actor.inventory.count(of: .bomb) == 0 {
                _ = actor.inventory.add(.bomb)
            }
        }

        actor.ai = state
    }
}
