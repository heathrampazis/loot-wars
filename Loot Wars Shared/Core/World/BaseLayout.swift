//
//  BaseLayout.swift
//  Loot Wars
//
//  The plan a team builds to, and the ORDER it builds in.
//
//  A base is described by the ground it ENCLOSES, not by the wall itself: pick a
//  rectangle, and the wall is whatever surrounds it. Doing it that way means the
//  wall is sealed by construction rather than by getting the geometry right, and
//  variety comes for free from the size and position of the rectangle.
//
//  The order is a list rather than a set. A base assembled from randomly chosen
//  tiles looks like rubble however good the final shape is; the same tiles laid in
//  sequence look like a wall going up. The order is a breadth-first walk from one
//  starting tile, which on a closed loop means two ends growing away from each
//  other - a wall extending in both directions, as somebody would build it.
//
//  There are no gateways. Owners walk through their own walls, so a base wants to
//  be shut, not doored.
//
//  Cross, ell, diamond and blob shapes lived here briefly and were cut for being
//  more strange than good. They are in the history at b8da1a8 if they are ever
//  wanted back - each was one function returning a set of tiles, and everything
//  below would take them unchanged.
//

struct BaseLayout {
    /// Every wall tile, in the order it should be laid. World coordinates.
    let tiles: [GridPoint]

    /// The ground the wall encloses. World coordinates.
    ///
    /// Kept rather than thrown away, because "inside the base" is not the same
    /// question as "inside the claim" and only this can answer it. The wall goes
    /// round a random rectangle WITHIN the claim, so most claims have ground that
    /// is theirs but stands outside their own walls - which is exactly where
    /// chests were being left, in full view, for anyone to walk up to.
    let region: Set<GridPoint>
}

enum BaseLayoutFactory {

    static func make(for claim: BaseClaim, using rng: inout SeededRandom) -> BaseLayout {
        let region = rectangle(in: claim.size, using: &rng)
        let wall = surroundingWall(of: region, in: claim.size)
        let ordered = buildOrder(of: wall, using: &rng)

        func world(_ local: GridPoint) -> GridPoint {
            GridPoint(col: claim.origin.col + local.col, row: claim.origin.row + local.row)
        }

        return BaseLayout(tiles: ordered.map(world),
                          region: Set(region.map(world)))
    }

    /// The enclosed ground. Stays within 1...(size - 2), so the wall around it
    /// always lands inside the claim and never spills onto ground the team cannot
    /// build on.
    private static func rectangle(in size: Int, using rng: inout SeededRandom) -> Set<GridPoint> {
        let span = size - 2

        // Never small. A three-by-three room inside a nine-by-nine claim puts the
        // whole wall two tiles from the middle, which is a hut standing in a field
        // rather than the edge of anybody's territory - and the claim tint around
        // it, which is the thing that actually says "this ground is yours", ends up
        // with a fence in the centre of it saying something different.
        //
        // At five and up the wall reads as the outline of the claim, the tint and
        // the wall agree, and the base a player is being taught to build is the one
        // the ground was already showing them. It costs about a third more wall
        // tiles per base, which the bots absorb in one extra trip home.
        let smallest = max(3, span - 2)

        // Favouring the bigger sizes (Nov 2026): the larger of
        // Base.layoutRolls rolls, so a full-size base is the most likely and
        // the smallest the rarest. Heath: "favour making bigger bases over
        // smaller ones". With 2 rolls on a span of 5...7: 7 about 56%, 6 about
        // 33%, 5 about 11% (it was a third each).
        func roll() -> Int {
            (0..<max(1, GameConfig.Base.layoutRolls))
                .map { _ in Int.random(in: smallest...span, using: &rng) }
                .max() ?? span
        }
        let width = roll()
        let height = roll()
        let col = Int.random(in: 1...(size - 1 - width), using: &rng)
        let row = Int.random(in: 1...(size - 1 - height), using: &rng)

        var region: Set<GridPoint> = []
        for c in col..<(col + width) {
            for r in row..<(row + height) { region.insert(GridPoint(col: c, row: r)) }
        }
        return region
    }

    /// Every tile touching the region on any of its eight sides.
    ///
    /// Eight rather than four on purpose: a four-sided wall leaves the diagonals
    /// open, and a base with corner gaps is not a base.
    private static func surroundingWall(of region: Set<GridPoint>, in size: Int) -> Set<GridPoint> {
        var wall: Set<GridPoint> = []

        for tile in region {
            for dCol in -1...1 {
                for dRow in -1...1 where !(dCol == 0 && dRow == 0) {
                    let neighbour = GridPoint(col: tile.col + dCol, row: tile.row + dRow)

                    guard !region.contains(neighbour) else { continue }
                    guard neighbour.col >= 0, neighbour.col < size,
                          neighbour.row >= 0, neighbour.row < size else { continue }

                    wall.insert(neighbour)
                }
            }
        }

        return wall
    }

    /// Round the wall from one tile, one way (Nov 2026), so whoever builds it
    /// walks the perimeter laying as they go. It was breadth-first, growing two
    /// arms at once, which had a bot pacing back and forth across an ever wider
    /// gap. Heath: enemies "should still have to walk around the perimeter of
    /// the base to build them".
    ///
    /// Each step takes a side neighbour if there is one (the wall is a ring of
    /// side-touching tiles round a rectangle), a corner neighbour if not, and
    /// jumps to the nearest tile left if neither - which a rectangle never needs
    /// but costs nothing to have.
    private static func buildOrder(of wall: Set<GridPoint>, using rng: inout SeededRandom) -> [GridPoint] {
        // Sorted before choosing, because Set iteration order is not stable and the
        // starting tile has to come from the seed like everything else.
        let sorted = wall.sorted { ($0.row, $0.col) < ($1.row, $1.col) }
        guard let start = sorted.randomElement(using: &rng) else { return [] }

        // Fixed neighbour order, so the same seed always lays the same sequence.
        let sides = [(1, 0), (0, 1), (-1, 0), (0, -1)]
        let corners = [(1, 1), (-1, 1), (-1, -1), (1, -1)]

        var ordered: [GridPoint] = [start]
        var seen: Set<GridPoint> = [start]
        var tile = start

        while ordered.count < wall.count {
            let unseen = { (step: (Int, Int)) -> GridPoint? in
                let next = GridPoint(col: tile.col + step.0, row: tile.row + step.1)
                return wall.contains(next) && !seen.contains(next) ? next : nil
            }
            let next = sides.lazy.compactMap(unseen).first
                ?? corners.lazy.compactMap(unseen).first
                ?? sorted.filter { !seen.contains($0) }.min { a, b in
                    let da = (a.col - tile.col) * (a.col - tile.col) + (a.row - tile.row) * (a.row - tile.row)
                    let db = (b.col - tile.col) * (b.col - tile.col) + (b.row - tile.row) * (b.row - tile.row)
                    return da < db
                }
            guard let step = next else { break }
            ordered.append(step)
            seen.insert(step)
            tile = step
        }

        return ordered
    }
}
