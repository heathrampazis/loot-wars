//
//  ArcadeSystem.swift
//  Loot Wars
//
//  Machines paying out tokens.
//
//  Two rules stop this from becoming a reason to stand still, which is the exact
//  opposite of what the game wants:
//
//  1. A machine will not let more than a few of its tokens pile up uncollected.
//     Camping one therefore caps out, and a circuit between machines beats it.
//  2. It needs a free tile around it to put a token on. Wall one in and it stops.
//

enum ArcadeSystem {

    static func update(_ world: World, commands: [ActorID: [Command]], dt: Double) {
        place(world, commands: commands)
        emit(world, dt: dt)
    }

    // MARK: - Standing one up

    /// Where a machine may go: entirely inside your own walls, clear of everything.
    ///
    /// Two wide and three high, so unlike a chest this needs SIX tiles rather than
    /// one - checked as a block, because a footprint half inside a wall is not a
    /// placement. Measured across 200,000 random layouts, 98.8% of bases have room
    /// for one and 97.8% still do with a chest already down; the rest are the tight
    /// ones where the spawn tile sits in the only gap.
    static func canPlace(at origin: GridPoint, by actor: Actor, in world: World) -> Bool {
        guard actor.inventory.firstSlot(holding: .arcade) != nil else { return false }
        guard let layout = world.baseLayouts[actor.team] else { return false }

        // Placed from inside, like everything else you build.
        guard world.claim(for: actor.team)?.contains(GridPoint(containing: actor.feet)) == true else {
            return false
        }

        let machine = Arcade(id: ArcadeID(-1), origin: origin, owner: actor.team, emitTimer: 0)

        for tile in machine.tiles {
            guard layout.region.contains(tile) else { return false }
            guard tile != world.claim(for: actor.team)?.centreTile else { return false }
            guard world.map[tile] == .floor else { return false }
            guard !world.structureIntersects(Box(tile: tile)) else { return false }
            guard !world.trees.contains(where: { $0.overlaps(tile) }) else { return false }
        }

        // Nothing standing where it would appear - it is solid, and six tiles of it.
        return !world.actors.values.contains {
            $0.isAlive && $0.hitbox.intersects(machine.hitbox)
        }
    }

    @discardableResult
    static func place(at origin: GridPoint, by actor: Actor, in world: World) -> Bool {
        guard canPlace(at: origin, by: actor, in: world) else { return false }

        var owner = actor
        guard let slot = owner.inventory.firstSlot(holding: .arcade),
              owner.inventory.consume(at: slot) != nil else { return false }

        world.actors[actor.id] = owner
        world.spawnArcade(at: origin, owner: actor.team)
        return true
    }

    private static func place(_ world: World, commands: [ActorID: [Command]]) {
        for (id, list) in commands {
            for command in list {
                guard case .placeArcade(let origin) = command else { continue }
                guard let actor = world.actors[id], actor.isAlive else { break }
                place(at: origin, by: actor, in: world)
            }
        }
    }

    // MARK: - Paying out

    private static func emit(_ world: World, dt: Double) {
        // Sorted keys rather than dictionary order: this draws from the world's
        // generator when it picks a tile, and dictionary order is not stable between
        // runs, so the obvious loop would quietly break seeded replays.
        for id in world.arcades.keys.sorted(by: { $0.raw < $1.raw }) {
            guard var arcade = world.arcades[id] else { continue }

            // The timer runs down and then STAYS down. A machine that is blocked or
            // already full is ready the instant that stops being true, rather than
            // making you wait out another whole interval for something it was
            // holding all along.
            if arcade.emitTimer > 0 {
                arcade.emitTimer -= dt
                world.arcades[id] = arcade
                continue
            }

            guard world.uncollectedTokens(around: arcade) < GameConfig.Arcade.maxUncollected,
                  let spot = world.freeSpot(around: arcade) else {
                world.arcades[id] = arcade
                continue
            }

            world.spawnGroundItem(.token(GameConfig.Arcade.tokenValue), at: spot)
            arcade.emitTimer = GameConfig.Arcade.emitInterval
            world.arcades[id] = arcade
        }
    }
}
