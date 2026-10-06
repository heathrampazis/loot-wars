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

    // Art for each biome and clump size; cacti stand in for trees in the desert.
    private static let assetNames: [Biome: [Int: String]] = [
        .plains: [2: "Tree1", 3: "Tree2"],
        .forest: [2: "ForestTree1", 3: "ForestTree2"],
        .snow: [2: "SnowTree1", 3: "SnowTree2"],
        .desert: [2: "Cactus1", 3: "Cactus2"]
    ]

    private struct TextureKey: Hashable {
        let biome: Biome
        let size: Int
    }

    private var textureCache: [TextureKey: SKTexture] = [:]

    func build(patches: [TreePatch], biomes: BiomeMap) {
        node.removeAllChildren()

        for patch in patches {
            let side = GridGeometry.length(ofTiles: Double(patch.size))
            let biome = biomes.biome(at: patch.centre)

            let sprite = SKSpriteNode(texture: texture(for: TextureKey(biome: biome, size: patch.size)),
                                      size: CGSize(width: side, height: side))
            sprite.position = GridGeometry.point(for: patch.centre)
            sprite.zRotation = CGFloat(patch.initialRotation)
            sprite.zPosition = 2    // above the ground and claim tints, below walls

            // Cacti stand still; only leafy trees sway round.
            if biome != .desert {
                sprite.run(spinAction(radiansPerSecond: patch.spin))
            }

            node.addChild(sprite)
        }
    }

    private func spinAction(radiansPerSecond: Double) -> SKAction {
        let fullTurn = 2 * Double.pi
        let duration = fullTurn / abs(radiansPerSecond)
        let angle = radiansPerSecond < 0 ? -fullTurn : fullTurn

        return SKAction.repeatForever(
            SKAction.rotate(byAngle: CGFloat(angle), duration: duration)
        )
    }

    private func texture(for key: TextureKey) -> SKTexture {
        if let cached = textureCache[key] { return cached }

        let name = TreeRenderer.assetNames[key.biome]?[key.size] ?? "Tree1"
        let texture = SKTexture(imageNamed: name)
        texture.usesMipmaps = true

        textureCache[key] = texture
        return texture
    }
}
