//
//  BaseLayout.swift
//  Loot Wars
//
//  The plan a team builds to, and the ORDER it builds in.
//
//  Two ideas hold this together.
//
//  First, a base is described by the ground it ENCLOSES, not by the wall itself.
//  Pick a shape - a rectangle, a cross, a diamond, a blob - and the wall is
//  whatever surrounds it. That is what lets bases be odd shapes and still be
//  coherent: any enclosed region has exactly one sensible wall, and it is always
//  sealed. Walls are the tiles touching the region on any of the eight sides, so
//  there are no diagonal gaps to squeeze through.
//
//  Second, the order is a list rather than a set. A base assembled from randomly
//  chosen tiles looks like rubble however good the final shape is; the same tiles
//  laid in sequence look like a wall going up. The order is a breadth-first walk
//  from one starting tile, which on a closed loop means two ends growing away from
//  each other - a wall extending in both directions, as somebody would build it.
//
//  There are no gateways. Owners walk through their own walls, so a base wants to
//  be shut, not doored.
//

struct BaseLayout {
    /// Every wall tile, in the order it should be laid. World coordinates.
    let tiles: [GridPoint]
}

enum BaseLayoutFactory {

    /// The ground a base encloses. The wall follows from it.
    private enum Shape: CaseIterable {
        case rectangle
        case cross
        case ell
        case diamond
        case blob
    }

    static func make(for claim: BaseClaim, using rng: inout SeededRandom) -> BaseLayout {
        let size = claim.size
        let shape = Shape.allCases.randomElement(using: &rng) ?? .rectangle

        var region: Set<GridPoint>
        switch shape {
        case .rectangle: region = rectangle(in: size, using: &rng)
        case .cross:     region = cross(in: size, using: &rng)
        case .ell:       region = ell(in: size, using: &rng)
        case .diamond:   region = diamond(in: size, using: &rng)
        case .blob:      region = blob(in: size, using: &rng)
        }

        // A shape that came out too thin would make a wall with no inside worth
        // defending. Fall back to something sensible rather than shipping a scribble.
        if region.count < 6 {
            region = rectangle(in: size, using: &rng)
        }

        let wall = surroundingWall(of: region, in: size)
        let ordered = buildOrder(of: wall, using: &rng)

        return BaseLayout(tiles: ordered.map {
            GridPoint(col: claim.origin.col + $0.col, row: claim.origin.row + $0.row)
        })
    }

    // MARK: - The wall around a region

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

        // Anything the walk could not reach - a wall in two disconnected pieces -
        // still gets built, just afterwards.
        return ordered + sorted.filter { !seen.contains($0) }
    }

    // MARK: - Shapes
    //
    // Every region stays within 1...(size - 2), so its surrounding wall always
    // lands inside the claim and never spills onto ground the team cannot build on.

    private static func rectangle(in size: Int, using rng: inout SeededRandom) -> Set<GridPoint> {
        let span = size - 2
        let width = Int.random(in: 3...span, using: &rng)
        let height = Int.random(in: 3...span, using: &rng)
        let col = Int.random(in: 1...(size - 1 - width), using: &rng)
        let row = Int.random(in: 1...(size - 1 - height), using: &rng)

        return tiles(col..<(col + width), row..<(row + height))
    }

    private static func cross(in size: Int, using rng: inout SeededRandom) -> Set<GridPoint> {
        let arm = Int.random(in: 2...3, using: &rng)
        let middle = size / 2
        let low = middle - arm / 2

        return tiles(1..<(size - 1), low..<(low + arm))
            .union(tiles(low..<(low + arm), 1..<(size - 1)))
    }

    private static func ell(in size: Int, using rng: inout SeededRandom) -> Set<GridPoint> {
        let thickness = Int.random(in: 2...3, using: &rng)
        let long = size - 2

        var shape = tiles(1..<(1 + thickness), 1..<(1 + long))
            .union(tiles(1..<(1 + long), 1..<(1 + thickness)))

        // Spin it, so the corner is not always in the same place.
        for _ in 0..<Int.random(in: 0...3, using: &rng) {
            shape = Set(shape.map { GridPoint(col: size - 1 - $0.row, row: $0.col) })
        }

        return shape.filter {
            $0.col >= 1 && $0.col <= size - 2 && $0.row >= 1 && $0.row <= size - 2
        }
    }

    private static func diamond(in size: Int, using rng: inout SeededRandom) -> Set<GridPoint> {
        let middle = size / 2
        let radius = Int.random(in: 2...3, using: &rng)

        var shape: Set<GridPoint> = []
        for col in 1...(size - 2) {
            for row in 1...(size - 2) where abs(col - middle) + abs(row - middle) <= radius {
                shape.insert(GridPoint(col: col, row: row))
            }
        }

        return shape
    }

    /// Grown one tile at a time from the middle. Organic, lopsided, and no two the
    /// same - this is the one that makes bases look hand-made.
    private static func blob(in size: Int, using rng: inout SeededRandom) -> Set<GridPoint> {
        let middle = size / 2
        var shape: Set<GridPoint> = [GridPoint(col: middle, row: middle)]
        let target = Int.random(in: 10...22, using: &rng)

        var attempts = 0
        while shape.count < target && attempts < target * 20 {
            attempts += 1

            let sorted = shape.sorted { ($0.row, $0.col) < ($1.row, $1.col) }
            guard let from = sorted.randomElement(using: &rng) else { break }

            let steps = [(1, 0), (-1, 0), (0, 1), (0, -1)]
            guard let step = steps.randomElement(using: &rng) else { break }

            let candidate = GridPoint(col: from.col + step.0, row: from.row + step.1)
            guard candidate.col >= 1, candidate.col <= size - 2,
                  candidate.row >= 1, candidate.row <= size - 2 else { continue }

            shape.insert(candidate)
        }

        return shape
    }

    private static func tiles(_ cols: Range<Int>, _ rows: Range<Int>) -> Set<GridPoint> {
        var out: Set<GridPoint> = []
        for col in cols {
            for row in rows { out.insert(GridPoint(col: col, row: row)) }
        }
        return out
    }
}
