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
    /// Points per tile, and the game's zoom.
    ///
    /// Went out to 32 to buy fighting distance back, then in again to 36 once the
    /// bots stopped measuring what they can see as a circle. The circle had to fit
    /// the SHORT axis of a landscape screen, so it threw away most of the width;
    /// asking the actual rectangle instead returns nearly eleven tiles sideways at
    /// this zoom against five up and down, which is both fair and a real fight.
    static let tileSize: CGFloat = 36

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
