//
//  ChestRenderer.swift
//  Loot Wars
//
//  Chests standing in bases. Placed during a match rather than at generation, so
//  unlike the arcades this syncs each frame instead of being built once.
//

import SpriteKit

final class ChestRenderer {

    let node = SKNode()

    private var nodesByChest: [ChestID: SKSpriteNode] = [:]
    private lazy var texture: SKTexture = {
        let texture = SKTexture(imageNamed: "Chest")
        texture.usesMipmaps = true
        return texture
    }()

    func sync(with world: World) {
        for (id, chest) in world.chests where nodesByChest[id] == nil {
            make(chest)
        }

        for (id, sprite) in Array(nodesByChest) where world.chests[id] == nil {
            nodesByChest[id] = nil

            // Broken open rather than switched off. A chest stripped by a raider
            // stops existing, and it should look like something happened to it.
            sprite.run(.sequence([
                .group([.scale(to: 1.25, duration: 0.08),
                        .fadeAlpha(to: 0.9, duration: 0.08)]),
                .group([.scale(to: 0.2, duration: 0.18),
                        .fadeOut(withDuration: 0.18)]),
                .removeFromParent()
            ]))
        }
    }

    private func make(_ chest: Chest) {
        // Sized so the CHEST covers its collision box, not so the exported canvas
        // does - the picture carries an eighth of its height as empty space, and
        // drawing to the canvas left the chest visibly smaller than the thing you
        // bump into.
        let fit = ArtFit.covering("Chest", GameConfig.Chest.size)

        let sprite = SKSpriteNode(texture: texture, size: fit.size)

        let standing = GridGeometry.point(for: chest.position)
        sprite.position = CGPoint(x: standing.x - fit.content.midX,
                                  y: standing.y - fit.content.midY)
        sprite.zPosition = 3    // with the crates: above trees, below walls and actors

        // A short landing, so a chest you just put down reads as having arrived
        // rather than having always been there.
        sprite.setScale(0.4)
        sprite.run(.scale(to: 1, duration: 0.18))

        node.addChild(sprite)
        nodesByChest[chest.id] = sprite
    }
}
