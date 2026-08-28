//
//  GridPoint.swift
//  Loot Wars
//
//  One square on the map. Tile (col, row) covers the area
//  x in [col, col + 1) and y in [row, row + 1) in tile space.
//

import Foundation

struct GridPoint: Hashable {
    var col: Int
    var row: Int

    init(col: Int, row: Int) {
        self.col = col
        self.row = row
    }

    /// The grid square that contains a position in tile space.
    init(containing position: Vec2) {
        self.col = Int(floor(position.x))
        self.row = Int(floor(position.y))
    }

    /// The middle of this square, in tile space.
    var center: Vec2 {
        Vec2(x: Double(col) + 0.5, y: Double(row) + 0.5)
    }
}
