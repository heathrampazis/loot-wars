//
//  TreeRenderer.swift
//  Loot Wars
//
//  One sprite per tree clump, not one per tile.
//
//  That is the whole reason MapFactory hands back TreePatch rectangles instead of
//  just marking tiles: a clump is one thing, so it gets one sprite and one image.
//
//  Textures are looked up once per clump size and cached, so the whole forest costs
//  a couple of draw calls.
//

import SpriteKit

final class TreeRenderer {

    let node = SKNode()

    /// Art for each clump size. Add a row to support a new size.
    private static let assetNames: [Int: String] = [
        2: "Tree1",
        3: "Tree2"
    ]

    private var textureCache: [Int: SKTexture] = [:]

    func build(patches: [TreePatch]) {
        node.removeAllChildren()

        for patch in patches {
            let side = GridGeometry.length(ofTiles: Double(patch.size))

            let sprite = SKSpriteNode(texture: texture(forSize: patch.size),
                                      size: CGSize(width: side, height: side))
            // Anchored bottom-left so the sprite sits exactly on the tiles the clump
            // occupies - the art's own padding is what insets it from the edges.
            sprite.anchorPoint = CGPoint(x: 0, y: 0)
            sprite.position = GridGeometry.point(for: Vec2(x: Double(patch.origin.col),
                                                           y: Double(patch.origin.row)))
            sprite.zPosition = 2    // above the ground and claim tints, below walls

            node.addChild(sprite)
        }
    }

    private func texture(forSize size: Int) -> SKTexture {
        if let cached = textureCache[size] { return cached }

        let name = TreeRenderer.assetNames[size] ?? "Tree1"
        let texture = SKTexture(imageNamed: name)
        // The art is far larger than it is ever drawn, so let the GPU pick a
        // properly downscaled level instead of resampling the full image each frame.
        texture.usesMipmaps = true

        textureCache[size] = texture
        return texture
    }
}
