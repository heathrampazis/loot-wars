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
        // As wide as the box it stands on, and as tall as the art says - measured,
        // so the exported canvas's transparent margin does not shrink the chest
        // inside its own footprint.
        //
        // Not stretched to the box, which is what it was for one commit. The box is
        // shorter than the picture on purpose now (see GameConfig.Chest.size), so
        // covering it squashed the chest by a sixth. Instead the chest STANDS on the
        // box - its base on the box's base - and the lid overhangs the top, which is
        // both what a chest looks like and what keeps the gap behind it walkable.
        let fit = ArtFit.spanning("Chest", width: GameConfig.Chest.size.x)

        let sprite = SKSpriteNode(texture: texture, size: fit.size)

        let standing = GridGeometry.point(for: chest.position)
        let footing = standing.y - GridGeometry.length(ofTiles: GameConfig.Chest.size.y / 2)

        sprite.position = CGPoint(x: standing.x - fit.content.midX,
                                  y: footing - fit.content.minY)
        sprite.zPosition = 3    // with the crates: above trees, below walls and actors

        // A short landing, so a chest you just put down reads as having arrived
        // rather than having always been there.
        sprite.setScale(0.4)
        sprite.run(.scale(to: 1, duration: 0.18))

        node.addChild(sprite)
        nodesByChest[chest.id] = sprite
    }
}
