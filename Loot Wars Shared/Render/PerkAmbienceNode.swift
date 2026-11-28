//
//  PerkAmbienceNode.swift
//  Loot Wars
//
//  A quiet feel on your screen while one of your power-ups runs (Nov 2026).
//  Heath: "slightly more tame animations but similar to disco when using
//  speed/resistance/regen/strength. not a disco coloured thing but some sort
//  of visual aspect".
//
//  Each one is its candy's colour, glowing faintly in from the edges of the
//  screen, with a little of its own movement on top:
//    Strength - the glow beats like a pulse, and sparks flick at the edges.
//    Speed - speed lines streak outward past the edges.
//    Regeneration - soft motes drift up the screen.
//    Resistance - the glow holds steady like a shield, with slow glints.
//  All faint and over the map, under every control, like the Disco Ball's
//  lights. Only for the person it is running for.
//

import SpriteKit
import UIKit

final class PerkAmbienceNode: SKNode {

    private let glow = SKSpriteNode(texture: PerkAmbienceNode.edgeTexture)
    private let bits = SKNode()
    private var area: CGSize = .zero
    private(set) var showing: Perk?

    override init() {
        super.init()
        zPosition = 498
        alpha = 0
        isHidden = true
        glow.blendMode = .alpha
        glow.colorBlendFactor = 1
        addChild(glow)
        bits.zPosition = 1
        addChild(bits)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func layOut(for size: CGSize) {
        area = size
        glow.size = CGSize(width: size.width * 1.05, height: size.height * 1.05)
    }

    /// Which power-up's feel to show, or nil for none. Cheap every frame.
    func set(_ perk: Perk?) {
        guard perk != showing else { return }
        showing = perk
        removeAction(forKey: "fade")
        guard let perk else {
            run(.sequence([Motion.eased(.fadeOut(withDuration: 0.5), Motion.cubicIn),
                           .run { [weak self] in self?.stop() }]), withKey: "fade")
            return
        }
        start(perk)
        isHidden = false
        run(Motion.eased(.fadeIn(withDuration: 0.35), Motion.cubicOut), withKey: "fade")
    }

    private func stop() {
        glow.removeAllActions()
        bits.removeAllActions()
        bits.removeAllChildren()
        if showing == nil { isHidden = true }
    }

    private func start(_ perk: Perk) {
        glow.removeAllActions()
        bits.removeAllActions()
        let colour = RenderPalette.colours(for: perk, at: 0).bright
        glow.color = colour
        let half = CGSize(width: area.width / 2, height: area.height / 2)

        switch perk {
        case .strength:
            // A heartbeat: two quick beats and a rest.
            glow.alpha = 0.14
            let beat = SKAction.sequence([
                Motion.eased(.fadeAlpha(to: 0.3, duration: 0.1), Motion.cubicOut),
                Motion.eased(.fadeAlpha(to: 0.16, duration: 0.18), Motion.cubicIn),
                Motion.eased(.fadeAlpha(to: 0.26, duration: 0.1), Motion.cubicOut),
                Motion.eased(.fadeAlpha(to: 0.14, duration: 0.3), Motion.cubicIn),
                .wait(forDuration: 0.5)
            ])
            glow.run(.repeatForever(beat))
            spawn(every: 0.16) { [weak self] in self?.spark(colour, in: half) }

        case .speed:
            glow.alpha = 0.14
            glow.run(.repeatForever(breathe(low: 0.12, high: 0.2, period: 0.9)))
            spawn(every: 0.05) { [weak self] in self?.streak(colour, in: half) }

        case .regeneration:
            glow.alpha = 0.14
            glow.run(.repeatForever(breathe(low: 0.12, high: 0.22, period: 1.6)))
            spawn(every: 0.12) { [weak self] in self?.mote(colour, in: half) }

        case .resistance:
            glow.alpha = 0.2
            glow.run(.repeatForever(breathe(low: 0.17, high: 0.24, period: 2.2)))
            spawn(every: 0.22) { [weak self] in self?.spark(colour, in: half, slow: true) }

        case .overdrive, .invisibility:
            // The Disco Ball has its own (DiscoLightsNode); invisibility none.
            glow.alpha = 0
        }
    }

    private func breathe(low: CGFloat, high: CGFloat, period: TimeInterval) -> SKAction {
        .sequence([Motion.eased(.fadeAlpha(to: high, duration: period / 2), Motion.inOut),
                   Motion.eased(.fadeAlpha(to: low, duration: period / 2), Motion.inOut)])
    }

    private func spawn(every gap: TimeInterval, _ make: @escaping () -> Void) {
        bits.run(.repeatForever(.sequence([.run(make), .wait(forDuration: gap, withRange: gap * 0.6)])))
    }

    /// Somewhere near the edge of the screen.
    private func edgePoint(in half: CGSize) -> CGPoint {
        let side = Int.random(in: 0..<4)
        let inset = CGFloat.random(in: 0.78...0.98)
        switch side {
        case 0:  return CGPoint(x: -half.width * inset, y: CGFloat.random(in: -half.height...half.height))
        case 1:  return CGPoint(x: half.width * inset, y: CGFloat.random(in: -half.height...half.height))
        case 2:  return CGPoint(x: CGFloat.random(in: -half.width...half.width), y: half.height * inset)
        default: return CGPoint(x: CGFloat.random(in: -half.width...half.width), y: -half.height * inset)
        }
    }

    /// A small star flicking on and off at the edge.
    private func spark(_ colour: SKColor, in half: CGSize, slow: Bool = false) {
        let star = SKSpriteNode(texture: ImpactArt.star)
        let side = CGFloat.random(in: 8...14)
        star.size = CGSize(width: side, height: side)
        star.color = colour
        star.colorBlendFactor = 0.7
        star.alpha = 0
        star.position = edgePoint(in: half)
        star.setScale(0.3)
        bits.addChild(star)
        let life: TimeInterval = slow ? 0.9 : 0.45
        star.run(.sequence([
            .group([.fadeAlpha(to: 0.6, duration: life * 0.3),
                    Motion.pop(to: 1, duration: life * 0.4, overshoot: 2),
                    .rotate(byAngle: 0.8, duration: life)]),
            Motion.eased(.fadeOut(withDuration: life * 0.5), Motion.cubicIn),
            .removeFromParent()
        ]))
    }

    /// A speed line, shooting out past the edge.
    private func streak(_ colour: SKColor, in half: CGSize) {
        let from = edgePoint(in: half)
        let away = CGVector(dx: from.x, dy: from.y)
        let length = max(1, hypot(away.dx, away.dy))
        let direction = CGVector(dx: away.dx / length, dy: away.dy / length)
        let line = SKSpriteNode(texture: GlowArt.pool)
        line.size = CGSize(width: CGFloat.random(in: 40...80), height: 3)
        line.color = colour
        line.colorBlendFactor = 1
        line.alpha = 0
        line.zRotation = atan2(direction.dy, direction.dx)
        line.position = CGPoint(x: from.x - direction.dx * 40, y: from.y - direction.dy * 40)
        bits.addChild(line)
        line.run(.sequence([
            .group([.fadeAlpha(to: 0.4, duration: 0.05),
                    Motion.eased(.moveBy(x: direction.dx * 90, y: direction.dy * 90, duration: 0.28),
                                 Motion.cubicIn),
                    .sequence([.wait(forDuration: 0.16), .fadeOut(withDuration: 0.12)])]),
            .removeFromParent()
        ]))
    }

    /// A soft mote drifting up.
    private func mote(_ colour: SKColor, in half: CGSize) {
        let dot = SKSpriteNode(texture: GlowArt.pool)
        let side = CGFloat.random(in: 10...20)
        dot.size = CGSize(width: side, height: side)
        dot.color = colour
        dot.colorBlendFactor = 1
        dot.alpha = 0
        let x = CGFloat.random(in: -half.width...half.width)
        // Mostly towards the sides, so the middle of the screen stays clear.
        let edgeX = x < 0 ? min(x, -half.width * 0.55) : max(x, half.width * 0.55)
        dot.position = CGPoint(x: edgeX, y: -half.height * CGFloat.random(in: 0.5...1))
        bits.addChild(dot)
        dot.run(.sequence([
            .group([.fadeAlpha(to: 0.4, duration: 0.3),
                    .moveBy(x: CGFloat.random(in: -12...12), y: half.height * 0.8, duration: 1.6),
                    .sequence([.wait(forDuration: 1.0), .fadeOut(withDuration: 0.6)])]),
            .removeFromParent()
        ]))
    }

    /// Clear in the middle, solid at the edges: the glow comes in from the
    /// sides of the screen and never covers what you are looking at.
    private static let edgeTexture: SKTexture = {
        let size = CGSize(width: 128, height: 128)
        let format = UIGraphicsImageRendererFormat.default()
        format.opaque = false
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: size, format: format).image { context in
            let colours = [UIColor(white: 1, alpha: 0).cgColor,
                           UIColor(white: 1, alpha: 0).cgColor,
                           UIColor(white: 1, alpha: 1).cgColor] as CFArray
            guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                            colors: colours, locations: [0, 0.55, 1]) else { return }
            let centre = CGPoint(x: size.width / 2, y: size.height / 2)
            context.cgContext.drawRadialGradient(gradient, startCenter: centre, startRadius: 0,
                                                 endCenter: centre, endRadius: size.width * 0.72,
                                                 options: [.drawsAfterEndLocation])
        }
        return SKTexture(image: image)
    }()
}
