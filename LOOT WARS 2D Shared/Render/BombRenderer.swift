//
//  BombRenderer.swift
//  Loot Wars
//
//  Bombs in flight, and the flash where one goes off.
//
//  The blast is drawn from a list the world hands over once a frame rather than
//  from the bombs themselves - by the time anything is drawn the bomb is gone and
//  its damage already applied, so the explosion is a record of something that
//  happened, not a thing that exists.
//

import SpriteKit

final class BombRenderer {

    let node = SKNode()

    private var nodesByBomb: [BombID: SKSpriteNode] = [:]
    private lazy var texture: SKTexture = {
        let texture = SKTexture(imageNamed: "Bomb")
        texture.usesMipmaps = true
        return texture
    }()

    func sync(with world: World) {
        for bomb in world.bombs {
            let sprite = nodesByBomb[bomb.id] ?? makeNode(for: bomb.id)
            sprite.position = GridGeometry.point(for: bomb.position)
        }

        let inFlight = Set(world.bombs.map(\.id))
        for (id, sprite) in Array(nodesByBomb) where !inFlight.contains(id) {
            nodesByBomb[id] = nil
            sprite.removeFromParent()
        }

    }

    private func makeNode(for id: BombID) -> SKSpriteNode {
        let side = GridGeometry.length(ofTiles: GameConfig.Bomb.spriteSize)
        let sprite = SKSpriteNode(texture: texture,
                                  size: CGSize(width: side, height: side))
        sprite.zPosition = 9    // over walls and shots, under actors

        // Tumbling reads as thrown rather than fired.
        sprite.run(.repeatForever(.rotate(byAngle: .pi * 2, duration: 0.9)))

        node.addChild(sprite)
        nodesByBomb[id] = sprite
        return sprite
    }

    // MARK: - The bang

    /// Tuned by drawing it, not by guessing. The first attempt used 26 pieces at
    /// 0.13 tiles and read as a scatter of specks; these are the numbers that
    /// actually looked like confetti at the size the blast occupies on screen.
    private static let confettiCount = 44
    private static let pieceSize: Double = 0.22
    /// How far a piece flies, as a multiple of the blast radius. The low end
    /// matters as much as the high one - without pieces that barely leave the
    /// centre, the burst comes out as a hollow ring.
    private static let spread: ClosedRange<Double> = 0.35...2.6
    private static let duration: TimeInterval = 0.8

    /// A firework rather than a puff of smoke.
    ///
    /// Hand-thrown pieces rather than an SKEmitterNode: the game is flat colour
    /// with hard edges, and an emitter's soft round particles read as though they
    /// came from a different game.
    ///
    /// Everything here draws from the system random generator, not `world.rng`.
    /// That is deliberate - this is decoration, run after the simulation has
    /// already decided everything, and drawing must never be able to disturb a
    /// seeded match.
    /// Called by the scene when it drains a blast out of the world's events. It
    /// used to drain them itself, which was fine while blasts were the only thing
    /// being announced - now that kills and sales come the same way, one drain in
    /// one place beats three that all have to remember to run every frame.
    func flash(at position: Vec2) {
        let origin = GridGeometry.point(for: position)
        let radius = GridGeometry.length(ofTiles: GameConfig.Bomb.blastRadius)

        burstCore(at: origin, radius: radius)

        let step = (2 * Double.pi) / Double(BombRenderer.confettiCount)

        for index in 0..<BombRenderer.confettiCount {
            // Each piece gets its own size and lifespan, so they do not all wink
            // out on the same frame like a switch being thrown.
            let scale = Double.random(in: 0.65...1.35)
            let life = BombRenderer.duration * Double.random(in: 0.7...1.0)
            let side = GridGeometry.length(ofTiles: BombRenderer.pieceSize * scale)

            let shard = SKShapeNode(rectOf: CGSize(width: side, height: side),
                                    cornerRadius: side * 0.22)
            shard.fillColor = RenderPalette.confetti.randomElement() ?? .white
            shard.strokeColor = .clear
            shard.position = origin
            shard.zPosition = 21
            shard.zRotation = CGFloat.random(in: 0..<(2 * .pi))
            node.addChild(shard)

            // Spaced evenly round the circle then jittered nearly a full step, so
            // the burst covers every direction without looking like wheel spokes.
            let angle = step * Double(index) + Double.random(in: -step * 0.9...step * 0.9)
            let distance = Double(radius) * Double.random(in: BombRenderer.spread)

            let fly = SKAction.move(by: CGVector(dx: cos(angle) * distance,
                                                 dy: sin(angle) * distance),
                                    duration: life)
            // Thrown hard and slowing - the way anything flung actually moves.
            fly.timingMode = .easeOut

            let spin = SKAction.rotate(byAngle: CGFloat.random(in: -8...8), duration: life)

            let settle = SKAction.sequence([
                .wait(forDuration: life * 0.5),
                .group([.fadeOut(withDuration: life * 0.5),
                        .scale(to: 0.4, duration: life * 0.5)])
            ])

            shard.run(.sequence([.group([fly, spin, settle]), .removeFromParent()]))
        }
    }

    /// The flare underneath, which is what sells the moment of the bang - confetti
    /// on its own reads as celebration rather than detonation. It clears fast on
    /// purpose: held any longer it simply hides the confetti behind it.
    private func burstCore(at origin: CGPoint, radius: CGFloat) {
        let core = SKShapeNode(circleOfRadius: radius * 0.8)
        core.position = origin
        core.fillColor = RenderPalette.blast
        core.strokeColor = .black
        core.lineWidth = GridGeometry.length(ofTiles: 0.12)
        core.zPosition = 20
        core.setScale(0.3)

        let hot = SKShapeNode(circleOfRadius: radius * 0.4)
        hot.fillColor = .white
        hot.strokeColor = .clear
        core.addChild(hot)

        node.addChild(core)
        core.run(.sequence([
            .group([.scale(to: 1.35, duration: 0.16),
                    .sequence([.wait(forDuration: 0.06), .fadeOut(withDuration: 0.18)])]),
            .removeFromParent()
        ]))
    }
}
