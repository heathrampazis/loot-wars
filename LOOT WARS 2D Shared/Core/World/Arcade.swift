//
//  Arcade.swift
//  Loot Wars
//
//  A machine standing on the map that pays out tokens.
//
//  Unlike a crate, an arcade is bigger than one tile - two wide and three high -
//  so it is the first thing in the game whose footprint has to be reasoned about
//  rather than assumed. Everything that needs its shape asks `hitbox`, and
//  everything that needs the ground around it asks `surroundingTiles`.
//

struct ArcadeID: Hashable {
    let raw: Int

    init(_ raw: Int) {
        self.raw = raw
    }
}

struct Arcade {
    let id: ArcadeID

    /// Which size of machine this is, and with it everything that differs between
    /// them - see ArcadeKind, which owns all of it.
    let kind: ArcadeKind

    /// Bottom-left tile of the footprint. The machine extends right and up.
    let origin: GridPoint

    /// Whose it is, or nil for the ones the map came with.
    ///
    /// The distinction decides two things: only an owned machine can be blown up,
    /// because the map's are scenery rather than property, and only an owned one is
    /// placed inside somebody's walls where they can work it in safety. That safety
    /// is the whole reason to buy one.
    var owner: TeamID?

    /// How much punishment is left in it.
    ///
    /// Only an OWNED machine has any: the map's own are scenery, and a board whose
    /// economy could be shot off it in the first minute is a board with no economy.
    ///
    /// Bullets rather than only bombs, because a bomb was the wrong and only key.
    /// A bomb is the thing you spend to get INTO somebody's base, and spending the
    /// same one thing on the wall and on what is behind it meant a raider had to
    /// choose between opening the door and breaking the furniture - so the furniture
    /// never got broken. A machine you can shoot is a machine an opportunist can
    /// wreck on their way past, which makes owning one a thing you have to defend
    /// rather than a thing you have to hide.
    var health: Int

    /// Counts down to the next token. Starts staggered, so several machines on
    /// one map do not pay out in lockstep.
    var emitTimer: Double

    /// Seconds left of a jackpot, or zero.
    ///
    /// Only the map's own machines ever have one. A jackpot is a reason to LEAVE
    /// your base and cross open ground at speed, which is precisely what a machine
    /// standing safely behind your own walls should never be handing out - the one
    /// in your base already pays you for staying home.
    var jackpotRemaining: Double = 0

    /// Counts down to the next roll for one.
    var jackpotCheck: Double = GameConfig.Arcade.jackpotInterval

    var isJackpot: Bool { jackpotRemaining > 0 }

    /// Written out rather than left to the memberwise one, because health depends
    /// on the kind and a stored property's default cannot read another property.
    /// Every machine therefore starts at its own full health and nobody has to
    /// remember to pass it.
    init(id: ArcadeID,
         kind: ArcadeKind = .full,
         origin: GridPoint,
         owner: TeamID?,
         emitTimer: Double) {
        self.id = id
        self.kind = kind
        self.origin = origin
        self.owner = owner
        self.health = kind.health
        self.emitTimer = emitTimer
    }

    /// Instance properties now, not static ones. They were static because there was
    /// one size of machine; asking the world how big A machine is, rather than how
    /// big THIS machine is, is exactly the assumption a second size breaks.
    var width: Int { kind.width }
    var height: Int { kind.height }

    /// Every tile the machine stands on.
    var tiles: [GridPoint] {
        (0..<width).flatMap { dx in
            (0..<height).map { dy in
                GridPoint(col: origin.col + dx, row: origin.row + dy)
            }
        }
    }

    var centre: Vec2 {
        Vec2(x: Double(origin.col) + Double(width) / 2,
             y: Double(origin.row) + Double(height) / 2)
    }

    /// Solid, and exactly the size the renderer draws - the machine you see is the
    /// machine you bump into.
    var hitbox: Box {
        Box(centre: centre,
            size: Vec2(x: Double(width), y: Double(height)))
    }

    /// The footprint plus a margin of ground around it.
    ///
    /// Used at map generation to demand ROOM. One ring is where a token can land;
    /// two is what makes a landed token reachable, because a token on the ring with
    /// a tree or the map edge behind it is a token you can see and cannot walk to.
    /// Measured over 3,000 generated maps, asking for two costs nothing - every map
    /// still fits all five machines - and asking for three starts failing.
    func tiles(within margin: Int) -> [GridPoint] {
        var area: [GridPoint] = []

        for dx in -margin..<(width + margin) {
            for dy in -margin..<(height + margin) {
                area.append(GridPoint(col: origin.col + dx, row: origin.row + dy))
            }
        }

        return area
    }

    /// The ring of tiles immediately around the footprint - where a token can land.
    ///
    /// This is the whole "needs a free space to pay out" rule: a machine hemmed in
    /// by walls, trees or crates has nowhere to put a token, so it does not make
    /// one. Nothing is stockpiled and nothing is lost; it simply waits.
    var surroundingTiles: [GridPoint] {
        var ring: [GridPoint] = []

        for dx in -1...width {
            for dy in -1...height {
                let inside = (0..<width).contains(dx) && (0..<height).contains(dy)
                guard !inside else { continue }
                ring.append(GridPoint(col: origin.col + dx, row: origin.row + dy))
            }
        }

        return ring
    }
}
