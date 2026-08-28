//
//  GridGeometry.swift
//  Loot Wars
//
//  The bridge between tile space (what the simulation thinks in) and screen points
//  (what SpriteKit draws in). This is the ONLY place tileSize is allowed to appear.
//  Change it here and the whole game rescales; nothing in Core notices.
//

import CoreGraphics

enum GridGeometry {

    static let tileSize: CGFloat = 32

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
}
