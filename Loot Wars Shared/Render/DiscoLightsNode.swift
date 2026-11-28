//
//  DiscoLightsNode.swift
//  Loot Wars
//
//  The Disco Ball's party, on your screen while yours is running (Nov 2026).
//  Heath: "the disco ball could have like a background feeling disco colours
//  etc theme while the power up is on".
//
//  Soft coloured spotlights drift slowly across the screen, each changing
//  colour on its own clock, a faint wash of colour cycles underneath, and
//  little white glints wink on and off all over - the light thrown off a
//  mirror ball. All of it faint and slow, over the map and under every
//  control, so it is a mood rather than a curtain. Only for the person who
//  is dancing: it is drawn on the camera, like the perk flash.
//

import SpriteKit

final class DiscoLightsNode: SKNode {

    private let wash = SKSpriteNode(color: .white, size: .zero)
    private var spots: [SKSpriteNode] = []
    private let glints = SKNode()
    private var area: CGSize = .zero
    private(set) var isActive = false

    private static let spotCount = 5

    override init() {
        super.init()
        zPosition = 499
        alpha = 0
        isHidden = true

        wash.alpha = 0.07
        addChild(wash)

        for index in 0..<DiscoLightsNode.spotCount {
            let spot = SKSpriteNode(texture: GlowArt.pool)
            spot.blendMode = .add
            spot.colorBlendFactor = 1
            spot.color = RenderPalette.hue(at: index * 3)
            spot.alpha = 0.15
            spot.zPosition = 1
            addChild(spot)
            spots.append(spot)
        }

        glints.zPosition = 2
        addChild(glints)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// The screen area to cover, in the camera's space.
    func layOut(for size: CGSize) {
        area = size
        wash.size = CGSize(width: size.width * 1.3, height: size.height * 1.3)
        let side = max(size.width, size.height) * 0.55
        for spot in spots { spot.size = CGSize(width: side, height: side) }
    }

    /// Switches the party on or off. Cheap to call every frame.
    func setActive(_ active: Bool) {
        guard active != isActive else { return }
        isActive = active
        removeAction(forKey: "fade")
        if active {
            isHidden = false
            start()
            run(Motion.eased(.fadeIn(withDuration: 0.4), Motion.cubicOut), withKey: "fade")
        } else {
            run(.sequence([Motion.eased(.fadeOut(withDuration: 0.6), Motion.cubicIn),
                           .run { [weak self] in self?.stop() }]), withKey: "fade")
        }
    }

    private func start() {
        stop()
        let half = CGSize(width: area.width / 2, height: area.height / 2)

        // The wash: slowly through the colours.
        wash.run(.repeatForever(.sequence((0..<8).map { step in
            .colorize(with: RenderPalette.hue(at: step), colorBlendFactor: 1, duration: 0.9)
        })))

        // The spotlights: each drifting from one place to the next, and
        // changing colour as it goes, on its own pace.
        for (index, spot) in spots.enumerated() {
            spot.position = CGPoint(x: CGFloat.random(in: -half.width...half.width),
                                    y: CGFloat.random(in: -half.height...half.height))
            let pace = 1.4 + Double(index) * 0.25
            let wander = SKAction.repeatForever(.sequence([
                .run { [weak spot] in
                    guard let spot else { return }
                    let next = CGPoint(x: CGFloat.random(in: -half.width...half.width),
                                       y: CGFloat.random(in: -half.height...half.height))
                    spot.run(Motion.eased(.move(to: next, duration: pace), Motion.inOut), withKey: "move")
                },
                .wait(forDuration: pace)
            ]))
            spot.run(wander, withKey: "wander")
            spot.run(.repeatForever(.sequence((0..<8).map { step in
                .colorize(with: RenderPalette.hue(at: step + index * 3), colorBlendFactor: 1,
                          duration: pace * 0.5)
            })), withKey: "colour")
        }

        // Glints off the mirror ball, winking on and off all over.
        glints.run(.repeatForever(.sequence([
            .run { [weak self] in self?.glint(in: half) },
            .wait(forDuration: 0.07, withRange: 0.06)
        ])), withKey: "glints")
    }

    private func stop() {
        wash.removeAllActions()
        for spot in spots { spot.removeAllActions() }
        glints.removeAllActions()
        glints.removeAllChildren()
        if !isActive { isHidden = true }
    }

    private func glint(in half: CGSize) {
        let star = SKSpriteNode(texture: ImpactArt.star)
        let side = CGFloat.random(in: 8...15)
        star.size = CGSize(width: side, height: side)
        star.blendMode = .add
        star.alpha = 0
        star.position = CGPoint(x: CGFloat.random(in: -half.width...half.width),
                                y: CGFloat.random(in: -half.height...half.height))
        star.setScale(0.3)
        glints.addChild(star)
        star.run(.sequence([
            .group([.fadeAlpha(to: 0.5, duration: 0.12), Motion.pop(to: 1, duration: 0.2, overshoot: 2),
                    .rotate(byAngle: 0.6, duration: 0.45)]),
            Motion.eased(.fadeOut(withDuration: 0.25), Motion.cubicIn),
            .removeFromParent()
        ]))
    }
}
