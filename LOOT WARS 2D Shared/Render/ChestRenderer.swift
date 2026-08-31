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
            sprite.removeFromParent()
        }
    }

    private func make(_ chest: Chest) {
        let sprite = SKSpriteNode(
            texture: texture,
            size: CGSize(width: GridGeometry.length(ofTiles: GameConfig.Chest.size.x),
                         height: GridGeometry.length(ofTiles: GameConfig.Chest.size.y)))
        sprite.position = GridGeometry.point(for: chest.position)
        sprite.zPosition = 3    // with the crates: above trees, below walls and actors

        // A short landing, so a chest you just put down reads as having arrived
        // rather than having always been there.
        sprite.setScale(0.4)
        sprite.run(.scale(to: 1, duration: 0.18))

        node.addChild(sprite)
        nodesByChest[chest.id] = sprite
    }
}
