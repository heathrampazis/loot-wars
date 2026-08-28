//
//  TileMap.swift
//  Loot Wars
//
//  The map is one flat array, not an array of arrays - simpler to reason about
//  and much friendlier to the CPU cache.
//

import Foundation

struct TileMap {
    let width: Int
    let height: Int
    private var tiles: [TileType]

    init(width: Int, height: Int, filledWith fill: TileType = .floor) {
        self.width = width
        self.height = height
        self.tiles = Array(repeating: fill, count: width * height)
    }

    func contains(_ point: GridPoint) -> Bool {
        point.col >= 0 && point.col < width && point.row >= 0 && point.row < height
    }

    /// Reading off the edge of the map gives you stone, so the world is sealed by
    /// default and nothing can ever wander into empty space.
    subscript(_ point: GridPoint) -> TileType {
        get {
            guard contains(point) else { return .stone }
            return tiles[point.row * width + point.col]
        }
        set {
            guard contains(point) else { return }
            tiles[point.row * width + point.col] = newValue
        }
    }

    func isSolid(_ point: GridPoint) -> Bool {
        self[point].isSolid
    }
}
