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

    /// The window this zoom was tuned against, in tiles.
    ///
    /// Straight off the reasoning above: nearly eleven tiles sideways and five up
    /// and down are HALF extents, so the whole window is twenty-two by ten. Every
    /// balance number that reads the screen was solved against this rectangle -
    /// AIBrain.canOpenFire, which decides whether a bot may shoot you, is the one
    /// that matters most.
    static let referenceWindow = CGSize(width: 22, height: 10)

    /// How far the camera has to be pulled in on a screen this size to show the
    /// same amount of world.
    ///
    /// scaleMode is .resizeFill, so the scene is the view's size in points and a
    /// tile is 36 points on everything. That is the right answer for a phone and
    /// the wrong one for anything bigger: an iPad does not draw the game smaller,
    /// it simply shows far more of it - about 38 by 28 tiles against a phone's 23
    /// by 11 - which reads as being zoomed out because you are looking at three
    /// times as much map.
    ///
    /// It is not only how it looks. GameScene pushes the visible rectangle into the
    /// simulation and the bots read it: a player on a big screen was seeing most of
    /// a base's surroundings at once AND being shot at from correspondingly further
    /// away, neither of which the balance was solved for.
    ///
    /// Matched by AREA rather than by width or height, because the shape of the
    /// window is not something this can hold constant - a phone is more than twice
    /// as wide as it is tall and an iPad is a third wider. Holding the width would
    /// hand an iPad half the map vertically; holding the height would leave it
    /// looking down a narrow slot. Holding the area means the same AMOUNT of world
    /// through a differently shaped window, which is the honest reading of "the
    /// same zoom" when the window is a different shape.
    ///
    /// Never above 1, so this can only ever pull the camera IN. A screen smaller
    /// than the reference - an SE is about a fifth short - keeps what it has rather
    /// than being zoomed out to match, because the fix for a small screen is not
    /// showing the same amount of world at a size nobody can read.
    static func zoom(for screen: CGSize) -> CGFloat {
        guard screen.width > 1, screen.height > 1 else { return 1 }

        let wanted = referenceWindow.width * referenceWindow.height * tileSize * tileSize
        let have = screen.width * screen.height

        return min(1, (wanted / have).squareRoot())
    }

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

    /// Where a point on screen falls in tile space, KEEPING the fraction.
    ///
    /// The tile-rounded version below cannot centre a footprint: half of an even
    /// width is half a tile, and that half is exactly what this preserves.
    static func position(for point: CGPoint) -> Vec2 {
        Vec2(x: Double(point.x / tileSize), y: Double(point.y / tileSize))
    }

    /// The tile a point on screen falls in. The inverse of the functions above, and
    /// the only way a touch is allowed to become a coordinate.
    static func gridPoint(for point: CGPoint) -> GridPoint {
        GridPoint(col: Int(floor(point.x / tileSize)),
                  row: Int(floor(point.y / tileSize)))
    }
}
