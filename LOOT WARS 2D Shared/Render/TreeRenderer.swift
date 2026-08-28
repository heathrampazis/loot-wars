//
//  TreeRenderer.swift
//  Loot Wars
//
//  One sprite per tree clump, not one per tile.
//
//  That is the whole reason MapFactory hands back TreePatch rectangles instead of
//  just marking tiles: when real art turns up, a 2x2 clump is one image and a 3x3
//  clump is another, and only makeTexture below has to change.
//
//  Textures are generated per clump size and cached, so the whole forest is a couple
//  of draw calls.
//

import SpriteKit
import UIKit

final class TreeRenderer {

    let node = SKNode()

    /// Pixels drawn per tile. Only affects placeholder crispness, not game scale.
    private static let pixelsPerTile: CGFloat = 64
    private static let outline: CGFloat = 14

    private var textureCache: [Int: SKTexture] = [:]

    func build(patches: [TreePatch]) {
        node.removeAllChildren()

        for patch in patches {
            let side = GridGeometry.length(ofTiles: Double(patch.size))

            let sprite = SKSpriteNode(texture: texture(forSize: patch.size),
                                      size: CGSize(width: side, height: side))
            // Anchored bottom-left so the sprite covers exactly the tiles the clump
            // occupies - what you see is precisely what you collide with.
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

    /// Replace this with a loaded image when the art is ready. Because the canvas
    /// scales with the clump size, the outline stays the same thickness on screen
    /// whether the clump is 2x2 or 3x3.
    private static func makeTexture(size: Int) -> SKTexture {
        let side = CGFloat(size) * pixelsPerTile

        let format = UIGraphicsImageRendererFormat.default()
        format.opaque = false

        let image = UIGraphicsImageRenderer(
            size: CGSize(width: side, height: side),
            format: format
        ).image { _ in
            SKColor.black.setFill()
            UIBezierPath(roundedRect: CGRect(x: 0, y: 0, width: side, height: side),
                         cornerRadius: 18).fill()

            RenderPalette.tree.setFill()
            UIBezierPath(roundedRect: CGRect(x: outline,
                                             y: outline,
                                             width: side - outline * 2,
                                             height: side - outline * 2),
                         cornerRadius: 10).fill()
        }

        return SKTexture(image: image)
    }
}
