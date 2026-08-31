//
//  ChestSystem.swift
//  Loot Wars
//
//  Putting chests down, and moving things in and out of them.
//
//  Every transfer below checks there is somewhere for the item to GO before taking
//  it from where it is. That ordering is the whole safety property: get it the wrong
//  way round and a tap on a full chest quietly deletes what you were holding, which
//  is the worst bug an inventory can have and the hardest to notice.
//

enum ChestSystem {

    static func update(_ world: World, commands: [ActorID: [Command]]) {
        for (id, list) in commands {
            for command in list {
                // Re-read the actor per command rather than once per list: two taps
                // can land in the same tick, and the second must see what the first
                // did to the inventory.
                guard let actor = world.actors[id], actor.isAlive else { break }

                switch command {
                case .placeChest(let point):
                    place(at: point, by: actor, in: world)
                case .storeItem(let chest, let slot):
                    store(from: slot, by: id, into: chest, in: world)
                case .takeItem(let chest, let slot):
                    take(from: slot, of: chest, by: id, in: world)
                case .move, .placeBlock, .removeBlock, .shoot,
                     .openLootbox, .useItem, .dropItem:
                    break
                }
            }
        }
    }

    // MARK: - Putting one down

    static func canPlace(at point: GridPoint, by actor: Actor, in world: World) -> Bool {
        guard actor.inventory.firstSlot(holding: .chest) != nil else { return false }

        // The same ground rules a wall answers to: your own claim, nothing already
        // there. A chest is furniture in your base, not something you leave lying
        // in the open for anyone to walk up to.
        guard BuildSystem.isBuildableTile(point, for: actor.team, in: world) else { return false }

        // And placed from inside, like a wall - measured from the feet, so it is
        // standing on your own ground rather than leaning over the fence.
        guard world.claim(for: actor.team)?.contains(GridPoint(containing: actor.feet)) == true else {
            return false
        }

        // A chest is solid, so one appearing under somebody would shove them out of
        // the way - yourself included.
        let box = Box(tile: point)
        return !world.actors.values.contains { $0.isAlive && $0.hitbox.intersects(box) }
    }

    @discardableResult
    static func place(at point: GridPoint, by actor: Actor, in world: World) -> Bool {
        guard canPlace(at: point, by: actor, in: world) else { return false }

        var owner = actor
        guard let slot = owner.inventory.firstSlot(holding: .chest),
              owner.inventory.consume(at: slot) != nil else { return false }

        world.actors[actor.id] = owner
        world.spawnChest(at: point, owner: actor.team)
        return true
    }

    // MARK: - Moving things in and out

    /// Whether this actor is close enough to be rummaging in this chest.
    ///
    /// Checked on every transfer, not only when the panel opens. The world keeps
    /// running while a chest is open - you can be shot, and an explosion can shove
    /// you out of reach - so an open panel is a picture of a chest, never a claim
    /// on it.
    static func canReach(_ chest: Chest, from actor: Actor) -> Bool {
        actor.hitbox.expanded(by: GameConfig.Chest.openReach).intersects(chest.hitbox)
    }

    private static func store(from slot: Int, by id: ActorID,
                              into chestID: ChestID, in world: World) {
        guard var actor = world.actors[id],
              var chest = world.chests[chestID],
              chest.owner == actor.team,
              canReach(chest, from: actor),
              let stack = actor.inventory.stack(at: slot) else { return }

        // Room first, then move. Never the other way round.
        guard chest.contents.canAccept(stack.type),
              actor.inventory.consume(at: slot) != nil else { return }
        _ = chest.contents.add(stack.type)

        world.actors[id] = actor
        world.chests[chestID] = chest
    }

    private static func take(from slot: Int, of chestID: ChestID,
                             by id: ActorID, in world: World) {
        guard var actor = world.actors[id],
              var chest = world.chests[chestID],
              chest.owner == actor.team,
              canReach(chest, from: actor),
              let stack = chest.contents.stack(at: slot) else { return }

        guard actor.inventory.canAccept(stack.type),
              chest.contents.consume(at: slot) != nil else { return }
        _ = actor.inventory.add(stack.type)

        world.actors[id] = actor
        world.chests[chestID] = chest
    }
}
