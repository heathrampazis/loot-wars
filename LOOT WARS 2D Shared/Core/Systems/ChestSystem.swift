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

    static func update(_ world: World, commands: [ActorID: [Command]], dt: Double) {
        restock(world, dt: dt)

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
        let chest = world.spawnChest(at: point, owner: actor.team)

        // A bot's chest arrives with something in it. See GameConfig.Chest.stockCount
        // for why this is a credit rather than a simulation - and note it is bots
        // only, because a player's chest is theirs to fill.
        if actor.ai != nil { stock(chest, in: world) }

        return true
    }

    /// Puts an item back into raided bot chests, a little at a time.
    ///
    /// Iterated in id order rather than dictionary order: this draws from the
    /// world's generator, and a dictionary's iteration order is not stable between
    /// runs, so doing it the obvious way would quietly break seeded replays.
    private static func restock(_ world: World, dt: Double) {
        for id in world.chests.keys.sorted(by: { $0.raw < $1.raw }) {
            guard var chest = world.chests[id], chest.selfStocking else { continue }

            // Nothing comes back while there is a hole in the wall.
            //
            // The owner has to shut the base before it starts paying again, which
            // is what stops a raider standing in a broken base collecting an item
            // every half minute forever. Repair is now the thing that turns the
            // supply back on, rather than a chore with no reward attached.
            guard !world.baseIsBreached(chest.owner) else {
                chest.restockTimer = GameConfig.Chest.restockInterval
                world.chests[id] = chest
                continue
            }

            let held = chest.contents.slots.compactMap { $0 }.reduce(0) { $0 + $1.count }
            guard held < GameConfig.Chest.restockCeiling else {
                // Full enough. A FULL wait is parked ahead of it rather than zero -
                // parking zero here is what made the first item come straight back
                // the instant a chest was emptied, which read as no cooldown at all.
                chest.restockTimer = GameConfig.Chest.restockInterval
                world.chests[id] = chest
                continue
            }

            chest.restockTimer -= dt
            if chest.restockTimer <= 0 {
                chest.restockTimer = GameConfig.Chest.restockInterval
                add(oneItemTo: &chest, in: world)
            }

            world.chests[id] = chest
        }
    }

    /// Fills a freshly placed bot chest, so there is something to raid it for.
    ///
    /// Draws from world.rng in a fixed order, so a seed still replays exactly.
    private static func stock(_ id: ChestID, in world: World) {
        guard var chest = world.chests[id] else { return }

        chest.selfStocking = true

        let count = Int.random(in: GameConfig.Chest.stockCount, using: &world.rng)
        for _ in 0..<count { add(oneItemTo: &chest, in: world) }

        world.chests[id] = chest
    }

    private static func add(oneItemTo chest: inout Chest, in world: World) {
        // Same grace period the crates observe. A chest full of bombs in the first
        // two minutes would be a way round the one thing the grace period is for.
        let rows = world.bombsAllowed
            ? GameConfig.Chest.stockTable
            : GameConfig.Chest.stockTable.filter { $0.item != .bomb }

        let total = rows.reduce(0) { $0 + $1.weight }
        var pick = Int.random(in: 0..<total, using: &world.rng)

        for entry in rows {
            if pick < entry.weight {
                _ = chest.contents.add(entry.item)
                return
            }
            pick -= entry.weight
        }
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

    /// Putting something IN is still yours alone - stocking somebody else's base
    /// is not a thing anyone wants to do.
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

    /// Taking something OUT needs only that you are standing at it.
    ///
    /// Not owner-only, and that asymmetry is the whole of chest raiding. A chest
    /// that only its owner could open would be a safe, and a safe behind a wall is
    /// worth nothing to anyone who breaks the wall - which would leave bombs with
    /// nothing to be for.
    private static func take(from slot: Int, of chestID: ChestID,
                             by id: ActorID, in world: World) {
        guard var actor = world.actors[id],
              var chest = world.chests[chestID],
              canReach(chest, from: actor),
              let stack = chest.contents.stack(at: slot) else { return }

        // Same question the ground asks, so a helmet that would be worn where it
        // fell is worn when it comes out of a chest too - and a bag with no room
        // is no obstacle to an upgrade, because an upgrade does not need a slot.
        guard actor.canAcquire(stack.type),
              chest.contents.consume(at: slot) != nil else { return }
        _ = actor.acquire(stack.type)

        world.actors[id] = actor

        // Stripped by somebody who does not own it: the chest goes with the
        // contents.
        //
        // This is what makes a raid cost the victim something that lasts. Refilling
        // alone meant a raid was a dent that healed itself - annoying, then gone.
        // Losing the chest means finding another one and standing it up again, and
        // since a chest cannot be placed until the wall is shut, it means fixing
        // the hole first. One raid therefore costs a repair AND a replacement.
        //
        // Emptied rather than touched: a chest that vanished on the first item
        // taken would hand a raider one bandage for a bomb, a breach and the walk.
        // And taking your OWN things out is not a raid, so this never fires on the
        // owner - otherwise nobody could ever use a chest for what it is for.
        let emptied = chest.contents.slots.allSatisfy { $0 == nil }

        if emptied, chest.owner != actor.team {
            world.removeChest(chestID)
            return
        }

        // Survived, with less in it. Start the clock again from the top, so a
        // partial raid always costs the full wait rather than however much of it
        // had already elapsed.
        chest.restockTimer = GameConfig.Chest.restockInterval
        world.chests[chestID] = chest
    }
}
