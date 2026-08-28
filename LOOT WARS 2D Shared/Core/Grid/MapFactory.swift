//
//  MapFactory.swift
//  Loot Wars
//
//  A hand-built map so there is something to walk around and bump into.
//  Real seeded generation (terrain, 8 base claims, loot spawns) arrives in M3.
//

enum MapFactory {

    static func testMap() -> TileMap {
        var map = TileMap(width: GameConfig.Map.width, height: GameConfig.Map.height)

        // Solid border around the whole map.
        for col in 0..<map.width {
            map[GridPoint(col: col, row: 0)] = .stone
            map[GridPoint(col: col, row: map.height - 1)] = .stone
        }
        for row in 0..<map.height {
            map[GridPoint(col: 0, row: row)] = .stone
            map[GridPoint(col: map.width - 1, row: row)] = .stone
        }

        // A grid of 2x2 pillars so movement and collision are obvious.
        var col = 6
        while col < map.width - 6 {
            var row = 6
            while row < map.height - 6 {
                map[GridPoint(col: col,     row: row)]     = .stone
                map[GridPoint(col: col + 1, row: row)]     = .stone
                map[GridPoint(col: col,     row: row + 1)] = .stone
                map[GridPoint(col: col + 1, row: row + 1)] = .stone
                row += 9
            }
            col += 9
        }

        return map
    }
}
