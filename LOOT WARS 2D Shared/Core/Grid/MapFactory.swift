//
//  MapFactory.swift
//  Loot Wars
//
//  Builds a map from a seed. Same seed in, same map out - always.
//
//  Still deliberately simple: an edge, one base claim, and scattered trees. Eight
//  claims on a ring, terrain features and loot spawns arrive at M3.
//

/// Everything the generator produces. Claims are part of the map's identity, not
/// something bolted on afterwards, so they come out of the same seeded pass.
struct GeneratedMap {
    let map: TileMap
    let claims: [TeamID: BaseClaim]
}

enum MapFactory {

    static func generate(seed: UInt64) -> GeneratedMap {
        var rng = SeededRandom(seed: seed)
        var map = TileMap(width: GameConfig.Map.width, height: GameConfig.Map.height)

        sealEdges(of: &map)
        let claims = makeClaims(in: map)
        scatterTrees(in: &map, avoiding: claims, using: &rng)

        return GeneratedMap(map: map, claims: claims)
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

    private static func scatterTrees(in map: inout TileMap,
                                     avoiding claims: [TeamID: BaseClaim],
                                     using rng: inout SeededRandom) {
        for row in 1..<(map.height - 1) {
            for col in 1..<(map.width - 1) {
                let point = GridPoint(col: col, row: row)

                // A claim is buildable ground - never grow anything on it.
                if claims.values.contains(where: { $0.contains(point) }) { continue }

                if Double.random(in: 0..<1, using: &rng) < GameConfig.Map.treeDensity {
                    map[point] = .tree
                }
            }
        }
    }
}
