//
//  BaseEnclosure.swift
//  Loot Wars
//
//  What counts as a finished base, worked out from the walls rather than read off a
//  plan.
//
//  A base used to be sealed when every tile of a generated rectangle had a wall on
//  it. That was easy to compute and quietly wrong, because the build rules never
//  agreed with it: you may build on ANY free tile inside your own claim, so a player
//  who walled in their own shape got walls that counted for nothing - no chests, no
//  vault income, no sealed rate on their machine - while the markers went on
//  pointing at a rectangle they had decided not to build. The game let you do a
//  thing and then declined to notice you had done it.
//
//  So the question is asked of the map instead: is there any ground inside this
//  claim that cannot be walked to from outside it? Wall off a corner, an L, a room
//  with a tree for one side - if a person cannot get in without breaking something,
//  it is a base.
//
//  A FLOOD FILL FROM THE EDGE, four-way. Start from every open tile on the claim's
//  border, spread through open tiles, and whatever is left unvisited is enclosed.
//  Four-way rather than eight because the question is whether a person can walk in,
//  and a diagonal pinch between two walls still leaves both of the tiles beside it
//  wide open - that is a gap, and a fill that squeezed through diagonally would be
//  the one telling the truth about it.
//
//  Trees count as wall. They are permanent, they block, and building against one is
//  the sort of thing a player should be rewarded for noticing.
//
//  FURNITURE HOLDS THE WALL IN WITHOUT BEING PART OF IT, and the split is the fix
//  for a base that could never be finished.
//
//  A crate, a chest or a machine stops a person walking onto its tile, and it also
//  stops anyone BUILDING there - BuildSystem.isBuildableTile refuses a tile with a
//  structure on it. So a crate sitting in the line somebody is walling along used to
//  be a tile that could not be built on and did not count as wall: a permanent,
//  unfixable hole. The player walls up to it on both sides, cannot walk through the
//  result, sees a finished base, and the game quietly goes on saying the base is
//  open - no chests, no income, no seal. There is no marker on that tile either,
//  because the markers only show what can be built, so nothing on screen says which
//  tile is the problem. Two rules disagreed about what a solid thing is, and the
//  player was left in the gap between them.
//
//  So the fill is stopped by anything a PERSON cannot walk through, while the room
//  is measured against the masonry alone. A crate in a gap seals a base; the tile it
//  stands on is still floor inside that base.
//
//  Kept out of the room count deliberately, and this is the trap in the other
//  direction. Counting furniture as solid for BOTH questions would take every chest
//  and all six tiles of a machine out of the room - so a base near the size floor
//  would UNSEAL itself the moment it was furnished, and since furnishing is what
//  sealing does, a base could seal and unseal in the same frame. That is the loop
//  worth not opening, and it is why these are two closures rather than one.
//
//  There is a floor on the size, and it is the only thing standing between this and
//  a nine-wall phone box. See GameConfig.Base.minimumRoom.
//

struct BaseEnclosure {

    /// Open ground inside the claim that cannot be reached from outside it.
    let room: Set<GridPoint>

    /// The solid tiles holding that ground in - the wall, as actually built, in no
    /// particular order. Whoever wants to draw it decides what order means.
    let wall: Set<GridPoint>

    /// Every wall this team has actually put down inside its own claim.
    ///
    /// Kept because the build markers need to know what shape somebody is aiming
    /// at, and the only evidence of that is what they have already laid.
    let ownWalls: Set<GridPoint>

    var isSealed: Bool { room.count >= GameConfig.Base.minimumRoom }

    /// - Parameters:
    ///   - solid: whether a tile is WALL - masonry, terrain or a tree. What holds
    ///     the room in, and what is not counted as part of it.
    ///   - blocks: whether a tile stops somebody walking onto it, which is the same
    ///     thing plus the furniture standing on the ground. Only the fill asks this,
    ///     so a crate can plug a gap without eating the floor it stands on.
    ///   - ownWall: whether a tile is a wall belonging to the team being asked
    ///     about, which is what separates "extend your base" from "there is a rock
    ///     here".
    static func compute(claim: BaseClaim,
                        solid: (GridPoint) -> Bool,
                        blocks: (GridPoint) -> Bool,
                        ownWall: (GridPoint) -> Bool) -> BaseEnclosure {
        let low = claim.origin
        let high = GridPoint(col: low.col + claim.size - 1,
                             row: low.row + claim.size - 1)

        func inside(_ p: GridPoint) -> Bool {
            p.col >= low.col && p.col <= high.col && p.row >= low.row && p.row <= high.row
        }

        // Seeded from the border ring: an open tile on the edge of the claim is a
        // tile somebody can step onto from the map outside, so it is "outside" for
        // this purpose and everything it connects to is too.
        var open: Set<GridPoint> = []
        var queue: [GridPoint] = []

        // Reached, but not walked THROUGH. A tile with a crate on it can be stood
        // next to from outside, so it is not enclosed and must not be counted as
        // room - otherwise every crate lying loose on a claim would add a tile to
        // the tally and enough of them would seal a base that has no walls at all.
        // But nobody gets past it either, so the fill stops there.
        func reach(_ p: GridPoint) {
            guard !solid(p), open.insert(p).inserted else { return }
            guard !blocks(p) else { return }
            queue.append(p)
        }

        for col in low.col...high.col {
            for row in [low.row, high.row] { reach(GridPoint(col: col, row: row)) }
        }
        for row in low.row...high.row {
            for col in [low.col, high.col] { reach(GridPoint(col: col, row: row)) }
        }

        var head = 0
        while head < queue.count {
            let p = queue[head]
            head += 1

            for next in [GridPoint(col: p.col + 1, row: p.row),
                         GridPoint(col: p.col - 1, row: p.row),
                         GridPoint(col: p.col, row: p.row + 1),
                         GridPoint(col: p.col, row: p.row - 1)] {
                guard inside(next) else { continue }
                reach(next)
            }
        }

        var room: Set<GridPoint> = []
        var ownWalls: Set<GridPoint> = []

        for col in low.col...high.col {
            for row in low.row...high.row {
                let p = GridPoint(col: col, row: row)

                guard !solid(p) else {
                    if ownWall(p) { ownWalls.insert(p) }
                    continue
                }

                if !open.contains(p) { room.insert(p) }
            }
        }

        // The wall is whatever is holding the room in - read off the room rather
        // than assumed, so a tree doing the job of three blocks is counted as the
        // wall it is.
        var wall: Set<GridPoint> = []
        for p in room {
            for next in [GridPoint(col: p.col + 1, row: p.row),
                         GridPoint(col: p.col - 1, row: p.row),
                         GridPoint(col: p.col, row: p.row + 1),
                         GridPoint(col: p.col, row: p.row - 1)] {
                if solid(next) { wall.insert(next) }
            }
        }

        return BaseEnclosure(room: room, wall: wall, ownWalls: ownWalls)
    }
}
