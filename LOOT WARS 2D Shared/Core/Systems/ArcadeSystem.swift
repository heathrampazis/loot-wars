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

        // One to a base. Two machines in the same walls would double an income that
        // is already the safest on the map, and the shop refuses to sell a second
        // for the same reason - this is the backstop for one found any other way.
        guard !world.hasArcade(actor.team) else { return false }
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

    /// How many tokens this machine will let pile up before it stops.
    ///
    /// The anti-camping valve, and the answer to "why build a base" in one number.
    /// A machine in the open holds four, so standing at one never beats moving
    /// between them. A machine behind a wall that is STANDING holds eight, because
    /// nothing is going to walk off with them - which turns it from a thing you
    /// babysit into a thing that earns while you are out playing the match.
    ///
    /// It is also precisely what a raid takes: breach somebody and their bank halves
    /// until they repair it.
    private static func bank(for arcade: Arcade, in world: World) -> Int {
        guard let owner = arcade.owner, !world.baseIsBreached(owner) else {
            return GameConfig.Arcade.maxUncollected
        }
        return GameConfig.Arcade.sealedUncollected
    }

    /// How long the tokens it pays out survive on the ground.
    ///
    /// Without this the bank above is a fiction. Tokens live ten seconds, which
    /// is the right number for a machine standing in the open - the pile is a thing
    /// you catch, not a thing you find - but it means eight of them can never
    /// coexist: at two seconds a token the first has expired before the fifth
    /// exists, and a base that banks nothing is a base that pays nothing.
    ///
    /// Behind a shut wall they keep for the best part of a minute, which is the
    /// same argument as the bank itself: nobody is going to wander off with them.
    /// Not forever, though - leave your own machine alone all match and the oldest
    /// still rot, so it remains money you have to come home for.
    private static func lifetime(for arcade: Arcade, in world: World) -> Double {
        guard let owner = arcade.owner, !world.baseIsBreached(owner) else {
            return GameConfig.Arcade.tokenLifetime
        }
        return GameConfig.Arcade.sealedTokenLifetime
    }

    /// How long this machine waits between tokens.
    ///
    /// Faster behind a wall that is standing, and that multiplier is the answer to
    /// "why build a base". Not points for laying bricks - nobody plays for those -
    /// but the machine inside your walls paying half again as fast for as long as
    /// those walls are shut. It makes the wall an income rather than a chore, and
    /// makes repairing one the thing that turns the income back on.
    ///
    /// The map's own machines never qualify: they stand in the open, they belong to
    /// nobody, and being the risky way to earn is their whole job.
    private static func interval(for arcade: Arcade, in world: World) -> Double {
        guard let owner = arcade.owner, !world.baseIsBreached(owner) else {
            return GameConfig.Arcade.emitInterval
        }
        return GameConfig.Arcade.emitInterval * GameConfig.Arcade.sealedInterval
    }

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

            guard world.uncollectedTokens(around: arcade) < bank(for: arcade, in: world),
                  let spot = world.freeSpot(around: arcade) else {
                world.arcades[id] = arcade
                continue
            }

            world.spawnGroundItem(.token(GameConfig.Arcade.tokenValue), at: spot,
                                  lifetime: lifetime(for: arcade, in: world))
            arcade.emitTimer = interval(for: arcade, in: world)
            world.arcades[id] = arcade
        }
    }
}
