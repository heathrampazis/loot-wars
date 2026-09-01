//
//  LootSystem.swift
//  Loot Wars
//
//  Opening lootboxes and picking things up.
//
//  Both halves are deliberately here rather than split between input and rendering:
//  the rule about how close you have to stand exists once, and an AI walking over a
//  bandage picks it up through exactly the same code a player does.
//

enum LootSystem {

    static func update(_ world: World, commands: [ActorID: [Command]], dt: Double) {
        openBoxes(world, commands: commands)
        sweepUpItems(world)

        // After the sweep, so something thrown down this tick is not picked back up
        // by the same tick that threw it.
        dropItems(world, commands: commands)

        // After the sweep, so something you reached on its very last tick still
        // counts as picked up rather than as having vanished under your feet.
        world.ageGroundItems(by: dt)
        world.tickLootboxRespawns(dt: dt)
    }

    // MARK: - Opening

    private static func openBoxes(_ world: World, commands: [ActorID: [Command]]) {
        for (id, list) in commands {
            guard let actor = world.actors[id], actor.isAlive else { continue }

            for command in list {
                guard case .openLootbox = command else { continue }

                guard let box = world.reachableLootbox(for: actor) else { break }

                world.removeLootbox(box.id)
                world.spawnGroundItem(LootTable.roll(bombs: world.bombsAllowed,
                                                    using: &world.rng),
                                      at: box.position)
                break   // one box per tick, however many times it was asked
            }
        }
    }

    // MARK: - Putting something down

    private static func dropItems(_ world: World, commands: [ActorID: [Command]]) {
        for (id, list) in commands {
            for command in list {
                guard case .dropItem(let slot) = command else { continue }

                // Re-read per command: two drops can land in one tick, and the
                // second has to see what the first did to the bag.
                guard var actor = world.actors[id], actor.isAlive,
                      let stack = actor.inventory.stack(at: slot),
                      let spot = spotToThrow(from: actor, in: world) else { continue }

                guard actor.inventory.consume(at: slot) != nil else { continue }
                world.actors[id] = actor
                world.spawnGroundItem(.item(stack.type), at: spot)
            }
        }
    }

    /// Somewhere in front of the actor an item can actually be left.
    ///
    /// Thrown along the aim first, then swept round the compass if that direction
    /// is blocked. Two conditions, and both matter: the spot has to be reachable -
    /// not inside a wall, a tree or a crate - AND outside the thrower's own hitbox,
    /// or the pickup sweep would return it on the next tick and dropping would
    /// appear to do nothing.
    ///
    /// No randomness here, unlike a death drop. A deliberate throw should go where
    /// you were pointing, and a fixed search order keeps a seeded match reproducible
    /// without having to touch the world's generator at all.
    private static func spotToThrow(from actor: Actor, in world: World) -> Vec2? {
        let facing = actor.aim.length > 0.01 ? actor.aim.normalized() : Vec2(x: 1, y: 0)
        let box = actor.hitbox
        let turn = 2 * Double.pi / 8

        for step in 0..<8 {
            let heading = Vec2.fromAngle(facing.angle + Double(step) * turn)

            for distance in GameConfig.Drops.throwDistances {
                let spot = actor.position + heading * distance
                guard world.isClearForDrop(spot), !box.contains(spot) else { continue }
                return spot
            }
        }

        // Walled in on every side at every distance. Refuse rather than drop it
        // somewhere it cannot be picked up again - keeping the item is the kinder
        // failure by a long way.
        return nil
    }

    // MARK: - Picking up

    /// Returns false when the actor has no use for it, and the pickup stays put.
    /// Walking over something and having it vanish is worse than leaving it.
    private static func take(_ pickup: Pickup, by actor: inout Actor) -> Bool {
        switch pickup {
        case .item(.helmet(let tier)) where tier > actor.helmet:
            // A better helmet is worn on the spot, and the extra capacity arrives
            // as actual health - so finding one mid-fight is a real reprieve
            // rather than just a longer bar to refill.
            let gained = tier.maxHealth - actor.maxHealth
            actor.helmet = tier
            actor.health = min(actor.maxHealth, actor.health + gained)
            return true

        case .item(.blaster(let tier)) where tier > actor.blaster:
            actor.blaster = tier
            return true

        case .item(let type):
            // Anything that is not an upgrade goes in the bag if there is room.
            // That includes gear at or BELOW what is already worn, which is the
            // whole point of the change: a spare is worthless to you now and worth
            // a great deal the moment you respawn with a bare head.
            return actor.inventory.add(type)

        case .token(let value):
            actor.tokens += value
            return true
        }
    }

    private static func sweepUpItems(_ world: World) {
        guard !world.groundItems.isEmpty else { return }

        var collected: [GroundItemID] = []

        for actorID in Array(world.actors.keys) {
            guard var actor = world.actors[actorID], actor.isAlive else { continue }

            let reach = actor.hitbox

            for item in world.groundItems.values {
                guard !collected.contains(item.id) else { continue }

                // The actor's real hitbox, the same one walls and crates are tested
                // against. No separate pickup radius to drift out of step with it.
                guard reach.contains(item.position) else { continue }

                if take(item.pickup, by: &actor) {
                    collected.append(item.id)
                }
            }

            world.actors[actorID] = actor
        }

        for id in collected {
            world.removeGroundItem(id)
        }
    }
}
