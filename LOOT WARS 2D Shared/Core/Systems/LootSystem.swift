//
//  LootSystem.swift
//  Loot Wars
//
//  Opening lootboxes and picking things up.
//
//  Both halves are deliberately here rather than split between input and rendering:
//  the rule about how close you have to stand exists once, and an AI walking over a
//  soda picks it up through exactly the same code a player does.
//

enum LootSystem {

    static func update(_ world: World, commands: [ActorID: [Command]], dt: Double) {
        openBoxes(world, commands: commands)
        sweepUpItems(world)

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
                world.spawnGroundItem(LootTable.roll(using: &world.rng), at: box.position)
                break   // one box per tick, however many times it was asked
            }
        }
    }

    // MARK: - Picking up

    /// Returns false when the actor has no use for it, and the pickup stays put.
    /// Walking over something and having it vanish is worse than leaving it.
    private static func take(_ pickup: Pickup, by actor: inout Actor) -> Bool {
        switch pickup {
        case .item(let type):
            return actor.inventory.add(type)

        case .helmet(let tier):
            guard tier > actor.helmet else { return false }

            // A better helmet is worn on the spot, and the extra capacity arrives
            // as actual health - so finding one mid-fight is a real reprieve
            // rather than just a longer bar to refill.
            let gained = tier.maxHealth - actor.maxHealth
            actor.helmet = tier
            actor.health = min(actor.maxHealth, actor.health + gained)
            return true

        case .blaster(let tier):
            guard tier > actor.blaster else { return false }
            actor.blaster = tier
            return true

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
