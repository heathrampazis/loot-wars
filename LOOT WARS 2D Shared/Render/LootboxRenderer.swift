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

    private lazy var ordinary: SKTexture = Self.load("LootboxRed")
    private lazy var rare: SKTexture = Self.load("LootboxRare")

    private static func load(_ name: String) -> SKTexture {
        let texture = SKTexture(imageNamed: name)
        texture.usesMipmaps = true
        return texture
    }

    func sync(with world: World) {
        for (id, box) in world.lootboxes where nodesByBox[id] == nil {
            makeNode(for: box)
        }

        for (id, sprite) in Array(nodesByBox) where world.lootboxes[id] == nil {
            nodesByBox[id] = nil
            sprite.removeFromParent()
        }
    }

    private func makeNode(for box: Lootbox) {
        // Drawn at exactly the collision size, so the crate you see is the crate
        // you bump into. GameConfig.Loot.lootboxSize matches the art's proportions.
        let size = CGSize(width: GridGeometry.length(ofTiles: GameConfig.Loot.lootboxSize.x),
                          height: GridGeometry.length(ofTiles: GameConfig.Loot.lootboxSize.y))

        let sprite = SKSpriteNode(texture: box.rare ? rare : ordinary, size: size)
        sprite.position = GridGeometry.point(for: box.position)
        sprite.zPosition = 3    // above trees, below walls and actors

        // A rare crate is lit from underneath, in the same blue the gear inside it
        // will be wearing - the same pool of light that sits under a dropped item,
        // scaled up. That consistency is the point: nobody has to be taught what
        // the glow means twice.
        //
        // Blue rather than gold, because a rare crate is a crate with better GEAR
        // in it rather than a jackpot, and it should read as worth crossing the map
        // for rather than as worth abandoning a fight for.
        if box.rare {
            let glow = SKSpriteNode(texture: GlowArt.pool)
            glow.size = CGSize(width: size.width * 2.1, height: size.height * 2.1)
            glow.color = RenderPalette.colour(of: .rare)
            glow.colorBlendFactor = 1
            glow.alpha = 0.7
            glow.zPosition = -1
            sprite.addChild(glow)

            glow.run(.repeatForever(.sequence([
                .group([.fadeAlpha(to: 0.45, duration: 1.1), .scale(to: 0.9, duration: 1.1)]),
                .group([.fadeAlpha(to: 0.7, duration: 1.1), .scale(to: 1.0, duration: 1.1)])
            ])))
        }

        node.addChild(sprite)
        nodesByBox[box.id] = sprite
    }
}
