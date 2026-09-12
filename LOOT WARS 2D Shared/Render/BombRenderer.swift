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

    /// Where each bomb last threw a spark.
    ///
    /// The trail is spaced by DISTANCE rather than by time, which is why this is
    /// here at all. A renderer gets no dt, and a spark every frame would be a solid
    /// ribbon on a fast device and a dotted line on a slow one - measuring the gap
    /// in tiles makes the fuse look the same whatever the frame rate is doing, and
    /// makes it stretch when the bomb is moving fast, which is what a trail does.
    private var lastSpark: [BombID: Vec2] = [:]

    /// One texture per kind. Both are drawn by this renderer because both FLY the
    /// same way - it is only what happens when they stop that differs - but they
    /// are different objects and have to look it: a stink bomb that tumbles through
    /// the air wearing a blast bomb's art tells the person it is heading towards
    /// exactly the wrong thing about what to do next.
    private lazy var blastTexture: SKTexture = Self.load("Bomb")
    private lazy var stinkTexture: SKTexture = Self.load("StinkBomb")

    private static func load(_ name: String) -> SKTexture {
        let texture = SKTexture(imageNamed: name)
        texture.usesMipmaps = true
        return texture
    }

    func sync(with world: World) {
        for bomb in world.bombs {
            let sprite = nodesByBomb[bomb.id] ?? makeNode(for: bomb)
            sprite.position = GridGeometry.point(for: bomb.position)
            trail(bomb)
        }

        let inFlight = Set(world.bombs.map(\.id))
        for (id, sprite) in Array(nodesByBomb) where !inFlight.contains(id) {
            nodesByBomb[id] = nil
            lastSpark[id] = nil
            sprite.removeFromParent()
        }
    }

    // MARK: - The fuse

    /// How close to landing the fuse starts visibly burning down, in tiles.
    private static let fuseTail: Double = 1.6
    /// Tiles between sparks, far out and about to land.
    private static let sparkGap: ClosedRange<Double> = 0.18...0.36
    /// How big one is, on the same two ends.
    private static let sparkSize: ClosedRange<Double> = 0.14...0.24
    private static let sparkLife: TimeInterval = 0.26

    /// Sparks coming off a bomb in flight, faster and fatter the closer it is to
    /// going off.
    ///
    /// A bomb used to simply tumble across the screen and then detonate, so the
    /// only warning a defender got was the object itself - and a small dark thing
    /// spinning over grass is not much of a warning. The fuse is the tell: it says
    /// this is lit, it is going to go off, and by how hard it is spitting, roughly
    /// when.
    ///
    /// Sparks are thrown into the WORLD rather than parented to the bomb, which is
    /// the whole reason it reads as a trail. A child node travels with its parent
    /// and would look like a halo bolted to the side of it; one left behind at the
    /// position the bomb has just vacated stays where it was dropped and the bomb
    /// flies away from it.
    ///
    /// Deliberately nothing to do with the bomb's artwork. It keys off the
    /// position and the distance left to run, so a new sprite drops straight in
    /// underneath it without any of this needing to know what changed.
    private func trail(_ bomb: Bomb) {
        // Nought far out, one as it lands. distanceRemaining is what the simulation
        // already counts down to decide when it goes off, so this is the same fuse
        // the world is burning rather than a second one kept in step by hand.
        let heat = max(0, min(1, 1 - bomb.distanceRemaining / BombRenderer.fuseTail))

        let gap = BombRenderer.sparkGap.upperBound
            - (BombRenderer.sparkGap.upperBound - BombRenderer.sparkGap.lowerBound) * heat

        // First frame of its flight: mark the spot and let the next one throw.
        guard let last = lastSpark[bomb.id] else {
            lastSpark[bomb.id] = bomb.position
            return
        }
        guard (bomb.position - last).length >= gap else { return }
        lastSpark[bomb.id] = bomb.position

        spark(at: bomb.position, along: bomb.velocity, kind: bomb.kind, heat: heat)
    }

    private func spark(at position: Vec2, along velocity: Vec2, kind: Bomb.Kind, heat: Double) {
        // Broken into named steps rather than written as one expression. This file
        // has cost an afternoon to a Swift type-checker timeout on exactly this
        // shape before - a compound of literals, range bounds and a Double, inside
        // a call that wants a CGFloat.
        let small = BombRenderer.sparkSize.lowerBound
        let large = BombRenderer.sparkSize.upperBound
        let side = GridGeometry.length(ofTiles: small + (large - small) * heat)

        let flare = SKSpriteNode(texture: ImpactArt.star,
                                 size: CGSize(width: side, height: side))
        flare.position = GridGeometry.point(for: position)

        // Under the bomb, so the bomb stays the thing you are looking at.
        flare.zPosition = 8

        // A stink bomb sparks in its own colour. Both kinds fly identically and the
        // file already argues that they must not LOOK identical doing it - somebody
        // deciding whether to run needs to know which one is coming, and by the time
        // it lands that decision has been made.
        if kind == .stink {
            flare.color = RenderPalette.gas
            flare.colorBlendFactor = 0.85
        }

        node.addChild(flare)

        // Thrown backwards off the flight, so it falls away behind rather than
        // spraying in every direction like an impact.
        let back = velocity.length > 0.001
            ? Vec2(x: -velocity.x, y: -velocity.y).normalized()
            : Vec2(x: 0, y: -1)

        let sideways = Vec2(x: -back.y, y: back.x)
        let drift = Double.random(in: 0.2...0.55)
        let wander = Double.random(in: -0.28...0.28)

        let away = CGVector(
            dx: GridGeometry.length(ofTiles: back.x * drift + sideways.x * wander),
            dy: GridGeometry.length(ofTiles: back.y * drift + sideways.y * wander))

        let life = BombRenderer.sparkLife * Double.random(in: 0.7...1.1)

        let fly = SKAction.move(by: away, duration: life)
        fly.timingMode = .easeOut

        flare.zRotation = CGFloat.random(in: 0..<(2 * .pi))
        flare.run(.sequence([
            .group([fly,
                    .rotate(byAngle: CGFloat.random(in: -3...3), duration: life),
                    .scale(to: 0.25, duration: life),
                    .sequence([.wait(forDuration: life * 0.35),
                               .fadeOut(withDuration: life * 0.65)])]),
            .removeFromParent()
        ]))
    }

    private func makeNode(for bomb: Bomb) -> SKSpriteNode {
        let side = GridGeometry.length(ofTiles: GameConfig.Bomb.spriteSize)

        let sprite = SKSpriteNode(
            texture: bomb.kind == .stink ? stinkTexture : blastTexture,
            size: CGSize(width: side, height: side)
        )
        sprite.zPosition = 9    // over walls and shots, under actors

        // Tumbling reads as thrown rather than fired.
        sprite.run(.repeatForever(.rotate(byAngle: .pi * 2, duration: 0.9)))

        node.addChild(sprite)
        nodesByBomb[bomb.id] = sprite
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
