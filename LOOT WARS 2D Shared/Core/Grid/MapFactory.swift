//
//  MapFactory.swift
//  Loot Wars
//
//  Builds a map from a seed. Same seed in, same map out - always.
//
//  Still deliberately simple: an edge, and scattered trees. Real generation
//  (terrain features, 8 base claims, loot and arcade spawns) arrives at M3.
//

enum MapFactory {

    static func makeMap(seed: UInt64) -> TileMap {
        var rng = SeededRandom(seed: seed)
        var map = TileMap(width: GameConfig.Map.width, height: GameConfig.Map.height)

        sealEdges(of: &map)
        scatterTrees(in: &map, using: &rng)

        return map
    }

    /// Where the player starts. Kept here so the generator and the scene cannot
    /// disagree about it.
    static func spawnPoint(in map: TileMap) -> GridPoint {
        GridPoint(col: map.width / 2, row: map.height / 2)
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

    private static func scatterTrees(in map: inout TileMap, using rng: inout SeededRandom) {
        let spawn = spawnPoint(in: map)
        let clear = GameConfig.Map.spawnClearRadius

        for row in 1..<(map.height - 1) {
            for col in 1..<(map.width - 1) {
                // Never box the player in at spawn.
                let nearSpawn = abs(col - spawn.col) <= clear && abs(row - spawn.row) <= clear
                if nearSpawn { continue }

                if Double.random(in: 0..<1, using: &rng) < GameConfig.Map.treeDensity {
                    map[GridPoint(col: col, row: row)] = .tree
                }
            }
        }
    }
}
