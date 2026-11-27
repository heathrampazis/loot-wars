//
//  SpikeRenderer.swift
//  Loot Wars
//
//  Spike traps on the floor (Nov 2026) - see SpikeSystem. Drawn as part of
//  the floor rather than as an object on it: rows of little steel points set
//  into a faint shadow, two tiles by two. Yours are always drawn, faintly, so
//  you know where you set them. An enemy's are not drawn
//  at all until one bites somebody; then it springs up, plainly visible to
//  everybody, and fades back out of sight when its reveal runs out.
//

import SpriteKit

final class SpikeRenderer {

    let node = SKNode()

    private var sprites: [GridPoint: SKSpriteNode] = [:]
    private var lastRevealed: [GridPoint: Double] = [:]

    /// How strongly your own traps show.
    private static let ownAlpha: CGFloat = 0.6
    /// How quickly a trap fades in and out of sight.
    private static let fadeRate: Double = 8

    init() {
        // On the floor: over the ground and claim tints, under walls and people.
        node.zPosition = 3
    }

    func sync(with world: World, dt: TimeInterval) {
        let mine = world.localPlayer?.team

        for (tile, sprite) in sprites where world.spikes[tile] == nil {
            sprites[tile] = nil
            lastRevealed[tile] = nil
            sprite.run(.sequence([.fadeOut(withDuration: 0.15), .removeFromParent()]))
        }

        for (tile, trap) in world.spikes {
            let sprite = sprites[tile] ?? make(for: trap)

            // It just bit somebody: spring up.
            if trap.revealed > (lastRevealed[tile] ?? 0) + 0.01 {
                sprite.removeAction(forKey: "spring")
                sprite.setScale(0.6)
                let up = SKAction.scale(to: 1.15, duration: 0.08)
                up.timingMode = .easeOut
                sprite.run(.sequence([up, .scale(to: 1, duration: 0.12)]), withKey: "spring")
            }
            lastRevealed[tile] = trap.revealed

            let wanted: CGFloat
            if trap.owner == mine {
                wanted = trap.revealed > 0 ? 1 : SpikeRenderer.ownAlpha
            } else {
                wanted = trap.revealed > 0 ? 1 : 0
            }
            let ease = CGFloat(1 - exp(-dt * SpikeRenderer.fadeRate))
            sprite.alpha += (wanted - sprite.alpha) * ease
        }
    }

    /// The floor art, not the item's (Nov 2026): the item is a little plate of
    /// spikes you pick up; set into the floor it is just rows of points.
    static let floorTexture: SKTexture = {
        let texture = SKTexture(imageNamed: "SpikeTrap")
        texture.usesMipmaps = true
        return texture
    }()

    private func make(for trap: SpikeTrap) -> SKSpriteNode {
        let texture = SpikeRenderer.floorTexture
        let sprite = SKSpriteNode(texture: texture)
        // The whole two by two, set into the floor.
        let side = GridGeometry.length(ofTiles: Double(SpikeTrap.size) * 0.96)
        sprite.size = CGSize(width: side, height: side)
        sprite.position = GridGeometry.point(for: trap.centre)
        sprite.alpha = 0
        node.addChild(sprite)
        sprites[trap.tile] = sprite
        return sprite
    }
}
