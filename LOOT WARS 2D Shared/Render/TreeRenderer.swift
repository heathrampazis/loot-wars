//
//  TreeRenderer.swift
//  Loot Wars
//
//  Draws every tree tile as a sprite sharing ONE texture, so a few hundred trees
//  still cost a single draw call.
//
//  Trees are not baked into the terrain texture like the ground is, because they
//  are drawn taller than the tile they occupy - they need to overlap whatever is
//  above them.
//
//  The texture is generated in code for now. Swapping in real art later means
//  deleting makeTexture() and loading an image instead; nothing else changes.
//

import SpriteKit
import UIKit

final class TreeRenderer {

    let node = SKNode()

    private lazy var texture: SKTexture = TreeRenderer.makeTexture()

    func build(from map: TileMap) {
        node.removeAllChildren()

        let size = CGSize(width: GridGeometry.length(ofTiles: GameConfig.Trees.visualWidth),
                          height: GridGeometry.length(ofTiles: GameConfig.Trees.visualHeight))

        for row in 0..<map.height {
            for col in 0..<map.width where map[GridPoint(col: col, row: row)] == .tree {
                let sprite = SKSpriteNode(texture: texture, size: size)

                // Anchored at the foot of the tree so it stands on its own tile and
                // grows upward into the one above.
                sprite.anchorPoint = CGPoint(x: 0.5, y: 0)
                sprite.position = GridGeometry.point(for: Vec2(x: Double(col) + 0.5,
                                                               y: Double(row)))

                // Trees further down the screen overlap the ones behind them.
                // The range is tiny on purpose, so every tree still sits below the
                // actors, which live at zPosition 10.
                sprite.zPosition = 1.0 + Double(map.height - row) * 0.001

                node.addChild(sprite)
            }
        }
    }

    // MARK: - Texture

    private static func makeTexture() -> SKTexture {
        let canvas = CGSize(width: 96, height: 120)
        let outline: CGFloat = 7

        // Three overlapping circles make a canopy that reads as a tree rather than
        // a lollipop.
        let canopy: [(centre: CGPoint, radius: CGFloat)] = [
            (CGPoint(x: 48, y: 42), 34),
            (CGPoint(x: 24, y: 60), 24),
            (CGPoint(x: 72, y: 60), 24)
        ]
        let trunk = CGRect(x: 39, y: 74, width: 18, height: 36)

        let format = UIGraphicsImageRendererFormat.default()
        format.opaque = false

        let image = UIGraphicsImageRenderer(size: canvas, format: format).image { _ in

            // Pass 1: one black silhouette, slightly larger than everything else.
            // Outlining each shape separately would leave seams where they overlap.
            SKColor.black.setFill()
            for part in canopy {
                circle(part.centre, part.radius + outline).fill()
            }
            UIBezierPath(roundedRect: trunk.insetBy(dx: -outline, dy: -outline),
                         cornerRadius: 8).fill()

            // Pass 2: the colours, sitting inside the silhouette so it reads as an
            // outline around the whole tree.
            RenderPalette.treeTrunk.setFill()
            UIBezierPath(roundedRect: trunk, cornerRadius: 4).fill()

            RenderPalette.treeCanopy.setFill()
            for part in canopy {
                circle(part.centre, part.radius).fill()
            }

            RenderPalette.treeHighlight.setFill()
            circle(CGPoint(x: 39, y: 35), 11).fill()
        }

        return SKTexture(image: image)
    }

    private static func circle(_ centre: CGPoint, _ radius: CGFloat) -> UIBezierPath {
        UIBezierPath(ovalIn: CGRect(x: centre.x - radius,
                                    y: centre.y - radius,
                                    width: radius * 2,
                                    height: radius * 2))
    }
}
