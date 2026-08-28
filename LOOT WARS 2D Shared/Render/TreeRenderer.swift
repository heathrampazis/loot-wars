//
//  TreeRenderer.swift
//  Loot Wars
//
//  One sprite per tree clump, not one per tile.
//
//  That is the whole reason MapFactory hands back TreePatch rectangles instead of
//  just marking tiles: a clump is one thing, so it gets one sprite and, when the art
//  arrives, one image. Only makeTexture below has to change.
//
//  The placeholder is a star, matching the reference: a 2x2 clump is a six-pointed
//  star and a 3x3 clump an eight-pointed one, both with a point straight up. The
//  point counts and radius ratios were measured off the reference drawing rather
//  than guessed.
//
//  Textures are generated per clump size and cached, so the whole forest costs a
//  couple of draw calls.
//

import SpriteKit
import UIKit

final class TreeRenderer {

    let node = SKNode()

    /// Pixels drawn per tile. Only affects placeholder crispness, not game scale.
    private static let pixelsPerTile: CGFloat = 64
    /// Outline thickness in pixels at the resolution above - about a tenth of a
    /// tile, which is the same weight as the outline on walls.
    private static let strokeWidth: CGFloat = 7

    /// How a clump of each size is drawn. Add a row to support a new clump size.
    private static let shapes: [Int: (points: Int, innerRatio: CGFloat)] = [
        2: (points: 6, innerRatio: 0.744),
        3: (points: 8, innerRatio: 0.827)
    ]

    private var textureCache: [Int: SKTexture] = [:]

    func build(patches: [TreePatch]) {
        node.removeAllChildren()

        for patch in patches {
            let side = GridGeometry.length(ofTiles: Double(patch.size))

            let sprite = SKSpriteNode(texture: texture(forSize: patch.size),
                                      size: CGSize(width: side, height: side))
            // Anchored bottom-left so the sprite sits exactly on the tiles the clump
            // occupies. The star is inscribed in that square, so what you see is
            // slightly smaller than what you collide with.
            sprite.anchorPoint = CGPoint(x: 0, y: 0)
            sprite.position = GridGeometry.point(for: Vec2(x: Double(patch.origin.col),
                                                           y: Double(patch.origin.row)))
            sprite.zPosition = 2    // above the ground and claim tints, below walls

            node.addChild(sprite)
        }
    }

    private func texture(forSize size: Int) -> SKTexture {
        if let cached = textureCache[size] { return cached }
        let made = TreeRenderer.makeTexture(size: size)
        textureCache[size] = made
        return made
    }

    /// Replace this with a loaded image when the art is ready.
    private static func makeTexture(size: Int) -> SKTexture {
        let side = CGFloat(size) * pixelsPerTile
        let centre = CGPoint(x: side / 2, y: side / 2)

        // Fall back to the small shape rather than crashing if a new clump size
        // turns up before it has a row in the table above.
        let shape = shapes[size] ?? (points: 6, innerRatio: 0.744)

        // The stroke straddles the path, so pull the star in by half of it to keep
        // the whole outline inside the sprite.
        let outerRadius = side / 2 - strokeWidth / 2

        let format = UIGraphicsImageRendererFormat.default()
        format.opaque = false

        let image = UIGraphicsImageRenderer(
            size: CGSize(width: side, height: side),
            format: format
        ).image { _ in
            let star = starPath(centre: centre,
                                points: shape.points,
                                outerRadius: outerRadius,
                                innerRatio: shape.innerRatio)
            star.lineWidth = strokeWidth
            star.lineJoin = .round      // blunts the tips, like the reference

            RenderPalette.tree.setFill()
            star.fill()

            SKColor.black.setStroke()
            star.stroke()
        }

        return SKTexture(image: image)
    }

    /// A star polygon: alternating outer and inner vertices, starting straight up.
    private static func starPath(centre: CGPoint,
                                 points: Int,
                                 outerRadius: CGFloat,
                                 innerRatio: CGFloat) -> UIBezierPath {
        let path = UIBezierPath()
        let step = CGFloat.pi / CGFloat(points)   // half a point's worth of turn

        for vertex in 0..<(points * 2) {
            let radius = vertex.isMultiple(of: 2) ? outerRadius : outerRadius * innerRatio
            // -pi/2 puts the first point straight up (image coordinates run downward).
            let angle = -CGFloat.pi / 2 + CGFloat(vertex) * step
            let corner = CGPoint(x: centre.x + cos(angle) * radius,
                                 y: centre.y + sin(angle) * radius)

            if vertex == 0 {
                path.move(to: corner)
            } else {
                path.addLine(to: corner)
            }
        }

        path.close()
        return path
    }
}
