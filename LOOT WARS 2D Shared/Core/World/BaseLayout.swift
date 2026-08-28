//
//  BaseLayout.swift
//  Loot Wars
//
//  The plan a team builds to, and the ORDER it builds in.
//
//  The order is the whole point. A base assembled from randomly chosen tiles looks
//  like scattered rubble no matter how good the final shape is; the same tiles laid
//  in sequence look like a wall going up. So a layout is a list, not a set, and it
//  is ordered to grow outwards from the gateway in both directions at once - the way
//  somebody would actually build a wall around themselves.
//

struct BaseLayout {
    /// Every wall tile, in the order it should be laid. World coordinates.
    let tiles: [GridPoint]
}

enum BaseLayoutFactory {

    /// The shapes a base can take. All of them are rings, which is what keeps every
    /// base coherent - the variety comes from how many, how far in, how wide the way
    /// in is, and which side it faces.
    private enum Style: CaseIterable {
        /// A single outer wall with a proper gateway.
        case ring
        /// A tighter wall set one tile in, leaving a walkway around the outside.
        case keep
        /// An outer wall and an inner redoubt, with the two gates on different
        /// sides, so anyone getting in has to go the long way round.
        case layered
        /// A wide-mouthed outer wall around a small central block.
        case courtyard
    }

    static func make(for claim: BaseClaim, using rng: inout SeededRandom) -> BaseLayout {
        let style = Style.allCases.randomElement(using: &rng) ?? .ring

        let rings: [(inset: Int, gate: Int)]
        switch style {
        case .ring:      rings = [(0, 2)]
        case .keep:      rings = [(1, 1)]
        case .layered:   rings = [(0, 2), (3, 1)]
        case .courtyard: rings = [(0, 4), (3, 1)]
        }

        var tiles: [GridPoint] = []
        for ring in rings {
            tiles += orderedRing(inset: ring.inset,
                                 gateWidth: ring.gate,
                                 size: claim.size,
                                 origin: claim.origin,
                                 using: &rng)
        }

        return BaseLayout(tiles: tiles)
    }

    // MARK: - Building one ring

    private static func orderedRing(inset: Int,
                                    gateWidth: Int,
                                    size: Int,
                                    origin: GridPoint,
                                    using rng: inout SeededRandom) -> [GridPoint] {
        let path = ringPath(inset: inset, size: size)
        guard path.count > gateWidth + 2 else { return [] }

        let gate = gateIndex(in: path, inset: inset, size: size, using: &rng)

        var isGateway = Array(repeating: false, count: path.count)
        for offset in 0..<gateWidth {
            isGateway[wrap(gate - gateWidth / 2 + offset, path.count)] = true
        }

        // Walk away from the gateway in both directions, taking one tile from each
        // side in turn. That is what makes a wall appear to extend outwards from the
        // entrance rather than sprouting at random points along its length.
        var clockwise: [GridPoint] = []
        var anticlockwise: [GridPoint] = []

        for offset in 1...(path.count / 2) {
            let ahead = wrap(gate + offset, path.count)
            let behind = wrap(gate - offset, path.count)

            if !isGateway[ahead] { clockwise.append(path[ahead]) }
            if behind != ahead, !isGateway[behind] { anticlockwise.append(path[behind]) }
        }

        var ordered: [GridPoint] = []
        for index in 0..<max(clockwise.count, anticlockwise.count) {
            if index < clockwise.count { ordered.append(clockwise[index]) }
            if index < anticlockwise.count { ordered.append(anticlockwise[index]) }
        }

        return ordered.map {
            GridPoint(col: origin.col + $0.col, row: origin.row + $0.row)
        }
    }

    /// One lap of the ring, in claim-local coordinates, in a continuous loop - so
    /// consecutive entries are always neighbours.
    private static func ringPath(inset: Int, size: Int) -> [GridPoint] {
        let low = inset
        let high = size - 1 - inset
        guard high > low else { return [] }

        var path: [GridPoint] = []

        for col in low...high { path.append(GridPoint(col: col, row: high)) }
        if high - 1 >= low {
            for row in stride(from: high - 1, through: low, by: -1) {
                path.append(GridPoint(col: high, row: row))
            }
        }
        if high - 1 >= low {
            for col in stride(from: high - 1, through: low, by: -1) {
                path.append(GridPoint(col: col, row: low))
            }
        }
        if low + 1 <= high - 1 {
            for row in (low + 1)...(high - 1) { path.append(GridPoint(col: low, row: row)) }
        }

        return path
    }

    /// Puts the gateway in the middle of one of the four sides rather than at a
    /// corner, where it would read as damage instead of a door.
    private static func gateIndex(in path: [GridPoint],
                                  inset: Int,
                                  size: Int,
                                  using rng: inout SeededRandom) -> Int {
        let low = inset
        let high = size - 1 - inset
        let middle = (low + high) / 2

        let midpoints = [
            GridPoint(col: middle, row: high),
            GridPoint(col: high, row: middle),
            GridPoint(col: middle, row: low),
            GridPoint(col: low, row: middle)
        ]

        let chosen = midpoints.randomElement(using: &rng) ?? midpoints[0]
        return path.firstIndex(of: chosen) ?? 0
    }

    private static func wrap(_ index: Int, _ count: Int) -> Int {
        ((index % count) + count) % count
    }
}
