//
//  TreeRenderer.swift
//  Loot Wars
//
//  One sprite per tree clump, not one per tile.
//
//  That is the whole reason MapFactory hands back TreePatch objects instead of just
//  marking tiles: a clump is one thing, so it gets one sprite and one image.
//
//  The idle spin is a pure SKAction. It never touches the simulation, which is
//  exactly right: the hitbox is a circle, so no amount of rotation changes what the
//  clump collides with. The drawing can be as lively as it likes and the physics
//  stays identical.
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
            // Centred, so it turns about its own middle - which is also where the
            // collision circle sits.
            sprite.position = GridGeometry.point(for: patch.centre)
            sprite.zRotation = CGFloat(patch.initialRotation)
            sprite.zPosition = 2    // above the ground and claim tints, below walls

            sprite.run(spinAction(radiansPerSecond: patch.spin))

            node.addChild(sprite)
        }
    }

    /// A full turn, repeated forever. Direction comes from the sign of the speed.
    private func spinAction(radiansPerSecond: Double) -> SKAction {
        let fullTurn = 2 * Double.pi
        let duration = fullTurn / abs(radiansPerSecond)
        let angle = radiansPerSecond < 0 ? -fullTurn : fullTurn

        return SKAction.repeatForever(
            SKAction.rotate(byAngle: CGFloat(angle), duration: duration)
        )
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
