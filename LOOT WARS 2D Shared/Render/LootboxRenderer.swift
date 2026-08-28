//
//  LootboxRenderer.swift
//  Loot Wars
//
//  Lootboxes never move, so their sprites are positioned once and then left alone.
//  The renderer only watches for boxes appearing and disappearing.
//

import SpriteKit

final class LootboxRenderer {

    let node = SKNode()

    private var nodesByBox: [LootboxID: SKSpriteNode] = [:]
    private lazy var texture: SKTexture = {
        let texture = SKTexture(imageNamed: "LootboxRed")
        texture.usesMipmaps = true
        return texture
    }()

    func sync(with world: World) {
        for (id, box) in world.lootboxes where nodesByBox[id] == nil {
            makeNode(for: id, at: box.position)
        }

        for (id, sprite) in Array(nodesByBox) where world.lootboxes[id] == nil {
            nodesByBox[id] = nil
            sprite.removeFromParent()
        }
    }

    private func makeNode(for id: LootboxID, at position: Vec2) {
        // Drawn at exactly the collision size, so the crate you see is the crate
        // you bump into. GameConfig.Loot.lootboxSize matches the art's proportions.
        let size = CGSize(width: GridGeometry.length(ofTiles: GameConfig.Loot.lootboxSize.x),
                          height: GridGeometry.length(ofTiles: GameConfig.Loot.lootboxSize.y))

        let sprite = SKSpriteNode(texture: texture, size: size)
        sprite.position = GridGeometry.point(for: position)
        sprite.zPosition = 3    // above trees, below walls and actors

        node.addChild(sprite)
        nodesByBox[id] = sprite
    }
}
