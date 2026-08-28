//
//  GridGeometry.swift
//  Loot Wars
//
//  The bridge between tile space (what the simulation thinks in) and screen points
//  (what SpriteKit draws in). This is the ONLY place tileSize is allowed to appear.
//  Change it here and the whole game rescales; nothing in Core notices.
//

import CoreGraphics
import Foundation

enum GridGeometry {

    /// How many points one tile takes up on screen - in other words, the zoom
    /// level. This single number scales the entire game.
    static let tileSize: CGFloat = 40

    static func point(for position: Vec2) -> CGPoint {
        CGPoint(x: CGFloat(position.x) * tileSize,
                y: CGFloat(position.y) * tileSize)
    }

    static func pointAtCentre(of tile: GridPoint) -> CGPoint {
        point(for: tile.center)
    }

    static func length(ofTiles tiles: Double) -> CGFloat {
        CGFloat(tiles) * tileSize
    }

    /// The tile a point on screen falls in. The inverse of the functions above, and
    /// the only way a touch is allowed to become a coordinate.
    static func gridPoint(for point: CGPoint) -> GridPoint {
        GridPoint(col: Int(floor(point.x / tileSize)),
                  row: Int(floor(point.y / tileSize)))
    }
}
