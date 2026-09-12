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
    /// Two wide and either two or three high, so unlike a chest this needs four or
    /// six tiles rather than one - checked as a block, because a footprint half
    /// inside a wall is not a placement. Measured across 200,000 random layouts,
    /// 98.8% of bases have room for a cabinet and 97.8% still do with a chest
    /// already down; the rest are the tight ones where the spawn tile sits in the
    /// only gap. A mini needs a third less and fits in most of those too, which is
    /// half of why it exists.
    static func canPlace(at origin: GridPoint,
                         kind: ArcadeKind,
                         by actor: Actor,
                         in world: World) -> Bool {

        // No requirement that the wall be shut, and that is a deliberate reversal.
        //
        // It was a hard rule here for one commit, to stop anybody strolling into a
        // half-built base and helping themselves. But the thing that actually stops
        // that is the BOTS not putting furniture out early - which is where the rule
        // now lives, in AIBrain, as a preference rather than a law. Down here it was
        // also telling the player what to do with their own base, and refusing to
        // let somebody set a chest down in a base they have chosen not to finish is
        // a rule protecting them from a decision that is theirs to make. Leave it
        // out in the open and somebody will take it; that is the deal, and it is a
        // legible one.
        guard actor.inventory.firstSlot(holding: .arcade(kind)) != nil else { return false }

        // NO CAP. There used to be one machine to a base, and that single line was
        // holding up the whole economy on its own - which is exactly why it had to
        // be replaced rather than simply deleted. Uncapped and undamped, a room you
        // can fit six machines into pays about 860 tokens a match, against a full
        // gear ladder at 150 and a raiding player's entire income at around 136.
        // That is not a strong base, it is the end of the shop.
        //
        // So the limit is a cost instead of a wall: machines crowd, and each one in
        // a base slows the others - see GameConfig.Arcade.crowding. Six machines
        // earn about twice what one does rather than nine times, the floor space
        // they eat is real, and every one of them is another thing a raider is
        // coming for. Nothing here has to say no.

        // The room you actually walled in, not the rectangle the generator drew for
        // this claim. See World.baseGround: asking the plan here let the game
        // suggest a spot inside your own base and then refuse to let you use it.
        let ground = world.baseGround(of: actor.team)

        // Placed from inside, like everything else you build.
        guard world.claim(for: actor.team)?.contains(GridPoint(containing: actor.feet)) == true else {
            return false
        }

        let machine = Arcade(id: ArcadeID(-1), kind: kind, origin: origin,
                             owner: actor.team, emitTimer: 0)

        for tile in machine.tiles {
            guard ground.contains(tile) else { return false }
            guard tile != world.claim(for: actor.team)?.centreTile else { return false }
            guard world.map[tile] == .floor else { return false }
            guard !world.structureOccupies(tile) else { return false }
            guard !world.treeTiles.contains(tile) else { return false }
        }

        // Nothing standing where it would appear - it is solid, and four or six
        // tiles of it.
        return !world.actors.values.contains {
            $0.isAlive && $0.hitbox.intersects(machine.hitbox)
        }
    }

    @discardableResult
    static func place(at origin: GridPoint,
                      kind: ArcadeKind,
                      by actor: Actor,
                      in world: World) -> Bool {
        guard canPlace(at: origin, kind: kind, by: actor, in: world) else { return false }

        var owner = actor
        guard let slot = owner.inventory.firstSlot(holding: .arcade(kind)),
              owner.inventory.consume(at: slot) != nil else { return false }

        world.actors[actor.id] = owner
        world.spawnArcade(at: origin, kind: kind, owner: actor.team)
        return true
    }

    private static func place(_ world: World, commands: [ActorID: [Command]]) {
        for (id, list) in commands {
            for command in list {
                guard case .placeArcade(let origin, let kind) = command else { continue }
                guard let actor = world.actors[id], actor.isAlive else { break }
                place(at: origin, kind: kind, by: actor, in: world)
            }
        }
    }

    // MARK: - Paying out

    /// How many tokens this machine will let pile up before it stops.
    ///
    /// The anti-camping valve, and the answer to "why build a base" in one number.
    /// A machine in the open holds three, so standing at one never beats moving
    /// between them. A machine behind a wall that is STANDING holds five, because
    /// nothing is going to walk off with them - which turns it from a thing you
    /// babysit into a thing that earns while you are out playing the match.
    ///
    /// It is also precisely what a raid takes: breach somebody and their bank halves
    /// until they repair it.
    private static func bank(for arcade: Arcade, in world: World) -> Int {
        if arcade.isJackpot { return GameConfig.Arcade.jackpotBank }

        guard let owner = arcade.owner, !world.baseIsBreached(owner) else {
            return arcade.kind.openBank
        }
        return basePile(of: owner, in: world)
    }

    /// How many loose tokens a whole BASE will let pile up before every machine in
    /// it stops.
    ///
    /// ONE allowance for the room, not one each. Per machine was right while a base
    /// could only hold one; with four of them it meant four separate piles measured
    /// in four small overlapping radii, and the better part of twenty tokens on the
    /// floor. That is not a bank, it is litter - and worse, it silently deleted the
    /// rule: a cap that is never reached cannot say "come home and clear this",
    /// which is the one thing it is for.
    ///
    /// The machines' own banks still add up, so a base with a cabinet in it holds
    /// more than one with a single mini and coming home is worth proportionally
    /// more - but the total stops at a ceiling. Beyond that a bigger base earns by
    /// PAYING FASTER while you stand in it, which is what crowding already governs,
    /// rather than by leaving more on the ground while you are somewhere else.
    private static func basePile(of team: TeamID, in world: World) -> Int {
        var total = 0
        for machine in world.arcades.values where machine.owner == team {
            total += machine.kind.sealedBank
        }
        return min(GameConfig.Arcade.basePileCeiling, total)
    }

    /// How much is already lying about, as far as THIS machine is concerned.
    ///
    /// The mirror of bank above, and they have to agree about what they are
    /// counting or the comparison is nonsense. A machine standing in the open or in
    /// a breached base answers for itself, in its own radius, because the map's four
    /// stand a long way apart and a breached base is not a room any more. A machine
    /// behind a standing wall answers for the whole base.
    ///
    /// It counts every loose token on that ground, including anything somebody
    /// spilled dying in there. That is deliberate: the cap is about how much is on
    /// the floor, and the floor does not care where it came from.
    private static func pile(for arcade: Arcade, in world: World) -> Int {
        guard let owner = arcade.owner, !world.baseIsBreached(owner) else {
            return world.uncollectedTokens(around: arcade)
        }
        return world.looseTokens(inside: owner)
    }

    /// How long the tokens it pays out survive on the ground.
    ///
    /// Without this the bank above is a fiction. Tokens live ten seconds, which
    /// is the right number for a machine standing in the open - the pile is a thing
    /// you catch, not a thing you find - but it means a full bank can never
    /// coexist: at 2.4 seconds a token the first has expired before the fifth
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
        if arcade.isJackpot {
            return GameConfig.Arcade.emitInterval * GameConfig.Arcade.jackpotRate
        }

        // A mini is slower wherever it stands - see ArcadeKind.rate.
        let base = GameConfig.Arcade.emitInterval * arcade.kind.rate

        guard let owner = arcade.owner, !world.baseIsBreached(owner) else {
            return base
        }

        // CROWDING. Every other machine in the same base slows this one down, as
        // though the room only has so many people in it to play them. It is what
        // replaced the one-machine cap: a limit you weigh rather than one you hit,
        // so a second machine is clearly worth standing up and a sixth is mostly
        // floor space. See GameConfig.Arcade.crowding for the arithmetic.
        //
        // Owned and sealed only. The map's four stand a long way apart and belong
        // to nobody, so there is nothing for them to crowd against; and a base
        // standing open has already lost the multiplier this modifies.
        let others = max(0, world.arcadeCount(ownedBy: owner) - 1)
        let crowded = 1 + GameConfig.Arcade.crowding * Double(others)

        return base * GameConfig.Arcade.sealedInterval * crowded
    }

    /// Starts and ends jackpots on the map's own machines.
    ///
    /// Rolled from the world's generator in the same fixed order as everything else
    /// here, so a seed still replays exactly - a jackpot is worth a dozen tokens to
    /// whoever is nearest, which is more than enough to send two runs of the same
    /// match in different directions.
    private static func rollJackpot(_ arcade: inout Arcade, in world: World, dt: Double) {
        guard arcade.owner == nil else { return }

        if arcade.jackpotRemaining > 0 {
            arcade.jackpotRemaining = max(0, arcade.jackpotRemaining - dt)
            return
        }

        arcade.jackpotCheck -= dt
        guard arcade.jackpotCheck <= 0 else { return }

        arcade.jackpotCheck = GameConfig.Arcade.jackpotInterval

        guard Double.random(in: 0..<1, using: &world.rng)
                < GameConfig.Arcade.jackpotChance else { return }

        arcade.jackpotRemaining = GameConfig.Arcade.jackpotDuration

        // Paid out at once rather than waiting for the next interval, so there is
        // something on the ground saying so from the moment it starts.
        arcade.emitTimer = 0
        world.record(.jackpot(at: arcade.centre))
    }

    private static func emit(_ world: World, dt: Double) {
        // Sorted keys rather than dictionary order: this draws from the world's
        // generator when it picks a tile, and dictionary order is not stable between
        // runs, so the obvious loop would quietly break seeded replays.
        for id in world.arcades.keys.sorted(by: { $0.raw < $1.raw }) {
            guard var arcade = world.arcades[id] else { continue }

            rollJackpot(&arcade, in: world, dt: dt)

            // The timer runs down and then STAYS down. A machine that is blocked or
            // already full is ready the instant that stops being true, rather than
            // making you wait out another whole interval for something it was
            // holding all along.
            if arcade.emitTimer > 0 {
                arcade.emitTimer -= dt
                world.arcades[id] = arcade
                continue
            }

            guard pile(for: arcade, in: world) < bank(for: arcade, in: world),
                  let spot = world.freeSpot(around: arcade) else {
                world.arcades[id] = arcade
                continue
            }

            // One payout in fifteen is golden. Rolled per token rather than per
            // machine, so a jackpot - a dozen payouts in eight seconds - is also
            // where most golden ones turn up, without either rule having to know
            // the other exists.
            let golden = Double.random(in: 0..<1, using: &world.rng)
                < GameConfig.Arcade.goldenChance

            let value = golden
                ? GameConfig.Arcade.goldenValue
                : GameConfig.Arcade.tokenValue

            world.spawnGroundItem(.token(value), at: spot,
                                  lifetime: lifetime(for: arcade, in: world))
            arcade.emitTimer = interval(for: arcade, in: world)
            world.arcades[id] = arcade
        }
    }
}
