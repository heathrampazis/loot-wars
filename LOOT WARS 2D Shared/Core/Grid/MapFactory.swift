//
//  MapFactory.swift
//  Loot Wars
//
//  Builds a map from a seed. Same seed in, same map out - always. That includes
//  which way each tree spins, so two runs of the same seed are identical.
//
//  Still deliberately simple: an edge, one base claim, and scattered tree clumps.
//  Eight claims on a ring, terrain features and loot spawns arrive at M3.
//

/// Everything the generator produces. Claims and trees are part of the map's
/// identity, not something bolted on afterwards, so they come out of the same
/// seeded pass.
struct GeneratedMap {
    let map: TileMap
    let claims: [TeamID: BaseClaim]
    let trees: [TreePatch]
}

enum MapFactory {

    static func generate(seed: UInt64) -> GeneratedMap {
        var rng = SeededRandom(seed: seed)
        var map = TileMap(width: GameConfig.Map.width, height: GameConfig.Map.height)

        sealEdges(of: &map)
        let claims = makeClaims(in: map)
        let trees = plantTrees(in: map, avoiding: claims, using: &rng)

        return GeneratedMap(map: map, claims: claims, trees: trees)
    }

    /// One claim in the middle for now. M3 spreads eight of them around a ring.
    private static func makeClaims(in map: TileMap) -> [TeamID: BaseClaim] {
        let claim = BaseClaim(team: TeamID(0),
                              centredOn: GridPoint(col: map.width / 2, row: map.height / 2),
                              size: GameConfig.Map.claimSize)
        return [claim.team: claim]
    }

    private static func sealEdges(of map: inout TileMap) {
        for col in 0..<map.width {
            map[GridPoint(col: col, row: 0)] = .stone
            map[GridPoint(col: col, row: map.height - 1)] = .stone
        }
        for row in 0..<map.height {
            map[GridPoint(col: 0, row: row)] = .stone
            map[GridPoint(col: map.width - 1, row: row)] = .stone
        }
    }

    // MARK: - Trees

    private static func plantTrees(in map: TileMap,
                                   avoiding claims: [TeamID: BaseClaim],
                                   using rng: inout SeededRandom) -> [TreePatch] {
        var planted: [TreePatch] = []

        // Placement can fail, so try more often than we need and stop once we have
        // enough. A fixed attempt budget means generation always terminates.
        let attempts = GameConfig.Map.treePatchCount * 25

        for _ in 0..<attempts {
            guard planted.count < GameConfig.Map.treePatchCount else { break }

            let size = GameConfig.Map.treePatchSizes.randomElement(using: &rng) ?? 2
            let factor = GameConfig.Trees.collisionRadiusFactor[size] ?? 0.85

            // Draw every random value up front and in a fixed order, so the same
            // seed always produces the same forest.
            let col = Int.random(in: 1...(map.width - size - 1), using: &rng)
            let row = Int.random(in: 1...(map.height - size - 1), using: &rng)
            let speed = Double.random(in: GameConfig.Trees.minSpin...GameConfig.Trees.maxSpin,
                                      using: &rng)
            let clockwise = Bool.random(using: &rng)
            let startAngle = Double.random(in: 0..<(2 * .pi), using: &rng)

            let candidate = TreePatch(
                origin: GridPoint(col: col, row: row),
                size: size,
                radius: Double(size) / 2 * factor,
                spin: clockwise ? speed : -speed,
                initialRotation: startAngle
            )

            guard isClear(candidate, of: planted, and: claims) else { continue }
            planted.append(candidate)
        }

        return planted
    }

    /// A clump needs clear space around it: away from other clumps so they read as
    /// separate, and away from every claim so nobody is ever penned into their base.
    private static func isClear(_ candidate: TreePatch,
                                of planted: [TreePatch],
                                and claims: [TeamID: BaseClaim]) -> Bool {
        for other in planted {
            let delta = candidate.centre - other.centre
            let minimum = candidate.radius + other.radius + GameConfig.Trees.spacing
            if delta.length < minimum { return false }
        }

        for claim in claims.values {
            // The claim, grown by a tile of breathing room.
            let closest = candidate.closestPoint(
                inBox: Vec2(x: Double(claim.origin.col) - 1, y: Double(claim.origin.row) - 1),
                to: Vec2(x: Double(claim.origin.col + claim.size) + 1,
                         y: Double(claim.origin.row + claim.size) + 1)
            )
            if (closest - candidate.centre).length < candidate.radius { return false }
        }

        return true
    }
}
