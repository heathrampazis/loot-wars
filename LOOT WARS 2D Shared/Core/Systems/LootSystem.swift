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

    static func update(_ world: World, commands: [ActorID: [Command]]) {
        openBoxes(world, commands: commands)
        sweepUpItems(world)
    }

    // MARK: - Opening

    private static func openBoxes(_ world: World, commands: [ActorID: [Command]]) {
        for (id, list) in commands {
            guard let actor = world.actors[id] else { continue }

            for command in list {
                guard case .openLootbox = command else { continue }

                guard let box = world.nearestLootbox(to: actor.feet,
                                                     within: GameConfig.Loot.openRange) else {
                    break
                }

                world.removeLootbox(box.id)
                world.spawnGroundItem(.soda, at: box.position)
                break   // one box per tick, however many times it was asked
            }
        }
    }

    // MARK: - Picking up

    private static func sweepUpItems(_ world: World) {
        guard !world.groundItems.isEmpty else { return }

        var collected: [GroundItemID] = []

        for actorID in Array(world.actors.keys) {
            guard var actor = world.actors[actorID] else { continue }

            for item in world.groundItems.values {
                guard !collected.contains(item.id) else { continue }

                // Measured from the feet, so you sweep things up by walking over
                // them rather than by waving your head near them.
                let reach = (item.position - actor.feet).length
                guard reach <= GameConfig.Loot.pickupRange else { continue }

                // A full inventory leaves the item where it is. Picking something up
                // and having it disappear is worse than not picking it up.
                if actor.inventory.add(item.type) {
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
