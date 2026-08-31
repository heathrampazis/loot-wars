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
        let width = Int.random(in: 3...span, using: &rng)
        let height = Int.random(in: 3...span, using: &rng)
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

    /// Breadth-first from one tile, so the wall grows outwards from a single point
    /// in every available direction at once.
    private static func buildOrder(of wall: Set<GridPoint>, using rng: inout SeededRandom) -> [GridPoint] {
        // Sorted before choosing, because Set iteration order is not stable and the
        // starting tile has to come from the seed like everything else.
        let sorted = wall.sorted { ($0.row, $0.col) < ($1.row, $1.col) }
        guard let start = sorted.randomElement(using: &rng) else { return [] }

        var ordered: [GridPoint] = []
        var seen: Set<GridPoint> = [start]
        var frontier = [start]

        while !frontier.isEmpty {
            let tile = frontier.removeFirst()
            ordered.append(tile)

            // Fixed neighbour order, so the same seed always lays the same sequence.
            for dCol in -1...1 {
                for dRow in -1...1 where !(dCol == 0 && dRow == 0) {
                    let neighbour = GridPoint(col: tile.col + dCol, row: tile.row + dRow)
                    guard wall.contains(neighbour), !seen.contains(neighbour) else { continue }
                    seen.insert(neighbour)
                    frontier.append(neighbour)
                }
            }
        }

        return ordered
    }
}
