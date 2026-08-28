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

    /// Width on the ground, in tiles. Height follows the art's proportions.
    private static let widthInTiles: Double = 0.95

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
            // Pop rather than blink out, so opening a box reads as an event.
            sprite.run(.sequence([
                .group([.scale(to: 1.35, duration: 0.14), .fadeOut(withDuration: 0.14)]),
                .removeFromParent()
            ]))
        }
    }

    private func makeNode(for id: LootboxID, at position: Vec2) {
        let width = GridGeometry.length(ofTiles: LootboxRenderer.widthInTiles)
        let art = texture.size()
        let height = art.width > 0 ? width * (art.height / art.width) : width

        let sprite = SKSpriteNode(texture: texture,
                                  size: CGSize(width: width, height: height))
        sprite.position = GridGeometry.point(for: position)
        sprite.zPosition = 3    // above trees, below walls and actors

        node.addChild(sprite)
        nodesByBox[id] = sprite
    }
}
