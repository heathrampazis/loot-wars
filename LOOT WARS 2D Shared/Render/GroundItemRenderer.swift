//
//  GroundItemRenderer.swift
//  Loot Wars
//
//  Items lying on the map. They bob gently so they read as "pick me up" rather than
//  as scenery.
//

import SpriteKit

final class GroundItemRenderer {

    let node = SKNode()

    /// The square an item is drawn to fit inside on the ground, in tiles.
    private static let widthInTiles: Double = 0.8

    /// Tokens are drawn smaller. They arrive in threes and are worth less than
    /// anything else on the floor, so at full size a machine looks like it is
    /// surrounded by treasure.
    private static let tokenWidthInTiles: Double = 0.5

    private static func width(of pickup: Pickup) -> Double {
        if case .token = pickup { return tokenWidthInTiles }
        return widthInTiles
    }

    private var nodesByItem: [GroundItemID: SKSpriteNode] = [:]

    func sync(with world: World) {
        for (id, item) in world.groundItems {
            guard let sprite = nodesByItem[id] else {
                makeNode(for: item)
                continue
            }

            // Flash once it is nearly gone, so nothing disappears from under
            // somebody who was running for it.
            if item.timeRemaining <= GameConfig.Loot.itemWarningTime,
               sprite.action(forKey: "expiring") == nil {
                sprite.run(.repeatForever(.sequence([
                    .fadeAlpha(to: 0.25, duration: 0.22),
                    .fadeAlpha(to: 1.0, duration: 0.22)
                ])), withKey: "expiring")
            }
        }

        for (id, sprite) in Array(nodesByItem) where world.groundItems[id] == nil {
            nodesByItem[id] = nil
            sprite.removeAction(forKey: "expiring")
            // Snap towards the player's hand rather than vanishing.
            sprite.run(.sequence([
                .group([.scale(to: 0.2, duration: 0.16), .fadeOut(withDuration: 0.16)]),
                .removeFromParent()
            ]))
        }
    }

    private func makeNode(for item: GroundItem) {
        let texture = ItemArt.texture(for: item.pickup)

        let box = GridGeometry.length(ofTiles: GroundItemRenderer.width(of: item.pickup))

        let sprite = SKSpriteNode(texture: texture,
                                  size: ItemArt.size(of: texture, fittingInto: box))
        sprite.position = GridGeometry.point(for: item.position)
        sprite.zPosition = 4

        // A pool of light under it, the colour of what it is. This is the whole
        // rarity indicator on the map: at the size an item is drawn you cannot read
        // a border, but you can see from across a base whether the thing lying by
        // the crate is grey or gold - which is the difference between a detour and
        // a sprint.
        //
        // A golden token gets one, and ordinary tokens do not. Money is not loot
        // and a puddle of light under every coin would turn a machine into a disco -
        // but ten tokens lying on the grass is worth crossing a map for, and the
        // only way to know that from across one is for it to be lit.
        if case .token(let value) = item.pickup,
           value >= GameConfig.Arcade.goldenValue {
            let glow = SKSpriteNode(texture: GlowArt.pool)
            glow.size = CGSize(width: box * 2.1, height: box * 2.1)
            glow.color = RenderPalette.colour(of: .mythical)
            glow.colorBlendFactor = 1
            glow.alpha = 0.85
            glow.zPosition = -1
            sprite.addChild(glow)

            glow.run(.repeatForever(.sequence([
                .group([.fadeAlpha(to: 0.5, duration: 0.7), .scale(to: 0.85, duration: 0.7)]),
                .group([.fadeAlpha(to: 0.85, duration: 0.7), .scale(to: 1.0, duration: 0.7)])
            ])))
        }

        if case .item(let type) = item.pickup {
            let glow = SKSpriteNode(texture: GlowArt.pool)
            glow.size = CGSize(width: box * 1.5, height: box * 1.5)
            glow.color = RenderPalette.colour(of: type.rarity)
            glow.colorBlendFactor = 1
            glow.alpha = 0.85
            glow.zPosition = -1
            sprite.addChild(glow)

            // A slow breath, so it reads as something glowing rather than as a
            // sticker printed on the grass. Offset per item by its own id, or
            // twenty items would pulse in unison like a warning light.
            let phase = Double(item.id.raw % 7) * 0.14
            glow.run(.sequence([
                .wait(forDuration: phase),
                .repeatForever(.sequence([
                    .group([.fadeAlpha(to: 0.55, duration: 0.9),
                            .scale(to: 0.88, duration: 0.9)]),
                    .group([.fadeAlpha(to: 0.85, duration: 0.9),
                            .scale(to: 1.0, duration: 0.9)])
                ]))
            ]))
        }

        // The same sheen the hotbar puts on it, so a power-up is recognisable
        // lying under a tree before you have ever picked one up.
        if case .item(let type) = item.pickup, type.isEnchanted {
            sprite.addChild(EnchantArt.overlay(box: box * 1.15))
        }

        let bob: CGFloat = 4
        sprite.run(.repeatForever(.sequence([
            .moveBy(x: 0, y: bob, duration: 0.6),
            .moveBy(x: 0, y: -bob, duration: 0.6)
        ])))

        // Tokens arrive rather than appear.
        //
        // A machine pays out every couple of seconds and the coin simply existed,
        // one frame to the next, a tile away from the cabinet - so the two things
        // never looked connected, and the payout was easy to miss entirely. It
        // spins up out of nothing now and settles, which is a fifth of a second of
        // animation that turns two separate facts into one event.
        //
        // Only tokens: a bandage that popped and spun would read as being thrown at
        // you, and everything else on the ground was dropped rather than issued.
        if case .token = item.pickup {
            sprite.setScale(0.1)
            sprite.zRotation = -0.9
            sprite.run(.group([
                .sequence([.scale(to: 1.25, duration: 0.14),
                           .scale(to: 1.0, duration: 0.12)]),
                .rotate(toAngle: 0, duration: 0.26)
            ]))
        }

        node.addChild(sprite)
        nodesByItem[item.id] = sprite
    }
}
