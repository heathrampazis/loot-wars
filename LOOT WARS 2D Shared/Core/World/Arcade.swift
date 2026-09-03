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

    /// Bottom-left tile of the footprint. The machine extends right and up.
    let origin: GridPoint

    /// Whose it is, or nil for the ones the map came with.
    ///
    /// The distinction decides two things: only an owned machine can be blown up,
    /// because the map's are scenery rather than property, and only an owned one is
    /// placed inside somebody's walls where they can work it in safety. That safety
    /// is the whole reason to buy one.
    var owner: TeamID?

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

    static var width: Int { GameConfig.Arcade.footprintWidth }
    static var height: Int { GameConfig.Arcade.footprintHeight }

    /// Every tile the machine stands on.
    var tiles: [GridPoint] {
        (0..<Arcade.width).flatMap { dx in
            (0..<Arcade.height).map { dy in
                GridPoint(col: origin.col + dx, row: origin.row + dy)
            }
        }
    }

    var centre: Vec2 {
        Vec2(x: Double(origin.col) + Double(Arcade.width) / 2,
             y: Double(origin.row) + Double(Arcade.height) / 2)
    }

    /// Solid, and exactly the size the renderer draws - the machine you see is the
    /// machine you bump into.
    var hitbox: Box {
        Box(centre: centre,
            size: Vec2(x: Double(Arcade.width), y: Double(Arcade.height)))
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

        for dx in -margin..<(Arcade.width + margin) {
            for dy in -margin..<(Arcade.height + margin) {
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

        for dx in -1...Arcade.width {
            for dy in -1...Arcade.height {
                let inside = (0..<Arcade.width).contains(dx) && (0..<Arcade.height).contains(dy)
                guard !inside else { continue }
                ring.append(GridPoint(col: origin.col + dx, row: origin.row + dy))
            }
        }

        return ring
    }
}
