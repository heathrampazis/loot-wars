//
//  BarArt.swift
//  Loot Wars
//
//  The little health bar, wherever one is drawn.
//
//  Extracted when machines got one. A bar over a person and a bar over a machine
//  have to be the same object as far as a player is concerned - same height, same
//  outline, same rounded ends - or the screen has two health bars and the second
//  one has to be learned. Two copies of five numbers would have been two chances
//  to change one of them.
//
//  The path is inset by half the stroke, so the outline's OUTER edge lands exactly
//  on the stated width. Same construction as the HUD bars.
//

import SpriteKit

enum BarArt {

    // Measured off the reference art: the bar over a figure is exactly one tile
    // wide, and everything else is proportioned against that.
    static let heightInTiles: Double = 0.224
    static let outlineInTiles: Double = 0.075

    static var height: CGFloat { GridGeometry.length(ofTiles: heightInTiles) }
    static var outline: CGFloat { GridGeometry.length(ofTiles: outlineInTiles) }

    /// - Parameters:
    ///   - full: the bar's whole width in points, which is what it is positioned
    ///     and outlined against.
    ///   - filled: how much of that width is coloured in.
    ///
    /// Kept as two arguments rather than a fraction because the fill has a MINIMUM:
    /// a bar at two per cent is a rounded rectangle shorter than its own corner
    /// radius, which draws as a dot or as nothing. Whoever owns the bar clamps it,
    /// and this stays a drawing.
    static func path(full: CGFloat, filled: CGFloat) -> CGPath {
        let stroke = outline
        let bar = height - stroke

        let rect = CGRect(x: -full / 2 + stroke / 2,
                          y: -bar / 2,
                          width: filled - stroke,
                          height: bar)

        return CGPath(roundedRect: rect,
                      cornerWidth: bar / 2,
                      cornerHeight: bar / 2,
                      transform: nil)
    }

    /// A whole bar: the dark track, and the coloured fill sitting on it.
    ///
    /// Returned as a pair because the caller keeps the fill - it is the half that
    /// changes - and only ever adds the node.
    static func make(full: CGFloat, colour: SKColor) -> (node: SKNode, fill: SKShapeNode) {
        let track = SKShapeNode(path: path(full: full, filled: full))
        track.fillColor = RenderPalette.hudTrack
        track.strokeColor = .black
        track.lineWidth = outline

        let fill = SKShapeNode(path: path(full: full, filled: full))
        fill.fillColor = colour
        fill.strokeColor = .black
        fill.lineWidth = outline
        fill.zPosition = 1

        let bar = SKNode()
        bar.addChild(track)
        bar.addChild(fill)
        return (bar, fill)
    }
}
