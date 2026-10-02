//
//  KillBannerNode.swift
//  Loot Wars
//
//  The confirmation that YOU took somebody out.
//
//  A body vanishing on the far side of a fight is easy to miss, and the only
//  other sign - a number floating off the spot - is somewhere your eyes are not.
//  This sits under the match panel, where the score and the clock already are: a
//  small panel in the same see-through black as the rest of the interface, with a
//  crosshair and the one word ELIMINATION.
//
//  Kills close together stack rather than queue. The panel stays up and shows a
//  count, so a double reads as a double rather than as two banners in a row.
//
//  Only ever yours. Every kill on the map is already marked where it happens; this
//  is the one that is about you.
//

import SpriteKit

final class KillBannerNode: SKNode {

    static let height: CGFloat = 32

    /// How long it holds, and how close the next kill has to be to stack onto it.
    private static let holdTime: TimeInterval = 1.8

    private let panel = SKShapeNode()
    private let mark = SKSpriteNode(texture: Glyphs.crosshair)
    private let title = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private let badge = SKShapeNode(circleOfRadius: 9)
    private let count = SKLabelNode(fontNamed: "AvenirNext-Bold")

    private var streak = 0

    override init() {
        super.init()
        zPosition = 1100
        alpha = 0
        isHidden = true

        panel.fillColor = RenderPalette.hudPanel
        panel.strokeColor = .clear
        addChild(panel)

        mark.size = CGSize(width: 18, height: 18)
        mark.color = RenderPalette.countBadge
        mark.colorBlendFactor = 1
        mark.zPosition = 1
        addChild(mark)

        title.text = "ELIMINATION"
        title.fontSize = 14
        title.fontColor = .white
        title.verticalAlignmentMode = .center
        title.horizontalAlignmentMode = .left
        title.zPosition = 1
        addChild(title)

        badge.fillColor = RenderPalette.countBadge
        badge.strokeColor = .clear
        badge.zPosition = 2
        badge.isHidden = true
        addChild(badge)

        count.fontSize = 11
        count.fontColor = .white
        count.verticalAlignmentMode = .center
        count.horizontalAlignmentMode = .center
        badge.addChild(count)

        layOut()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Mark and word in a row, centred, with the panel fitted round them.
    private func layOut() {
        let gap: CGFloat = 8
        let markWidth = mark.size.width
        let titleWidth = title.frame.width
        let inner = markWidth + gap + titleWidth
        let width = inner + 26
        let height = KillBannerNode.height

        panel.path = CGPath(roundedRect: CGRect(x: -width / 2, y: -height / 2,
                                                width: width, height: height),
                            cornerWidth: height / 2, cornerHeight: height / 2, transform: nil)

        var x = -inner / 2
        mark.position = CGPoint(x: x + markWidth / 2, y: 0)
        x += markWidth + gap
        title.position = CGPoint(x: x, y: 0)

        badge.position = CGPoint(x: width / 2 - 2, y: height / 2 - 2)
    }

    /// Somebody just went down to you.
    func confirm() {
        let stacking = !isHidden && action(forKey: "hold") != nil
        streak = stacking ? streak + 1 : 1

        badge.isHidden = streak < 2
        count.text = "\u{00D7}\(streak)"

        removeAllActions()
        isHidden = false

        if stacking {
            // Already up: a bump rather than a second entrance.
            alpha = 1
            position.y = restingY
            run(.sequence([.scale(to: 1.12, duration: 0.07),
                           .scale(to: 1, duration: 0.12)]))
            badge.removeAllActions()
            badge.setScale(1.4)
            badge.run(.scale(to: 1, duration: 0.15))
        } else {
            alpha = 0
            setScale(0.7)
            position.y = restingY
            run(.group([.fadeIn(withDuration: 0.12),
                        .sequence([.scale(to: 1.08, duration: 0.12),
                                   .scale(to: 1, duration: 0.1)])]))
        }

        // The crosshair turns a quarter as it lands, which is the "got them".
        mark.removeAllActions()
        mark.zRotation = -.pi / 4
        mark.setScale(1.5)
        mark.run(.group([.rotate(toAngle: 0, duration: 0.2),
                         .scale(to: 1, duration: 0.2)]))

        run(.sequence([
            .wait(forDuration: KillBannerNode.holdTime),
            .group([.fadeOut(withDuration: 0.25),
                    .moveBy(x: 0, y: 6, duration: 0.25)]),
            .run { [weak self] in
                guard let self else { return }
                self.isHidden = true
                self.position.y = self.restingY
                self.streak = 0
            }
        ]), withKey: "hold")
    }

    /// Where it sits. Set by the scene; the exit drifts up from here and the next
    /// entrance starts from here again.
    var restingY: CGFloat = 0 {
        didSet { if action(forKey: "hold") == nil { position.y = restingY } }
    }

    /// Put away at once, for the end of the match.
    func dismiss() {
        removeAllActions()
        isHidden = true
        alpha = 0
        streak = 0
    }
}
