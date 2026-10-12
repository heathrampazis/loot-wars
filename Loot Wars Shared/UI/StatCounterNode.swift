//
//  StatCounterNode.swift
//  Loot Wars
//
//  An icon and a number, for the things you count rather than the things that run
//  down.
//
//  NO PLATE. It has had one twice and been wrong both times, which is worth
//  recording because the mistake was the same mistake in two shapes: a plate makes
//  a thing an OBJECT, and a purse is not an object. Beside the shop button it read
//  as a bar of furniture laid across the corner of the map; clipped to the button
//  it read as a sticker. It is a row, and a row belongs inside somebody else's
//  panel - which is where it started, on the HUD, and where it lives now, beside
//  the clock in the match panel.
//
//  Its origin is its own centre, and the pair centres ITSELF on every change. The
//  clock next to it can hardcode its offset because a time is always four
//  characters wide; a token count is one, two or three, and a pair hung off a
//  fixed offset would sit visibly left of centre all match and then jump.
//

import SpriteKit

final class StatCounterNode: SKNode {

    static let height: CGFloat = 24

    static let iconHeight: CGFloat = 15

    /// The air between the icon and the number. Wide enough that nothing either
    /// of them does - the number's pulse, the icon's punch - ever closes it: the
    /// number grows away from the icon (it is anchored on its left edge), and the
    /// icon's punch takes at most three points of it on each side.
    private static let gap: CGFloat = 9

    /// How the icon reacts to the number going up.
    enum Motion {
        /// A coin: flips twice and hops, throwing off gold sparks.
        case coin
        /// The crosshair: punches up and turns a quarter as it settles, the same
        /// "got them" the elimination banner's crosshair gives, with a ring
        /// going out from it.
        case target
    }
    private let motion: Motion

    private let icon = SKSpriteNode()

    /// The icon's resting width, kept apart from `icon.size`. A sprite's size
    /// follows its scale, so the coin's flip and the crosshair's punch would
    /// otherwise change the room the counter asks for, and the panel would
    /// twitch wider and narrower every time one played.
    private var iconWidth: CGFloat = 0

    /// Where the icon sits in the row. The icon's own position is left free for
    /// the hop and the shake, which re-centring would otherwise cancel.
    private let iconHolder = SKNode()
    private let label = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private var lastValue = Int.min

    convenience init(iconNamed iconName: String) {
        self.init(icon: SKTexture(imageNamed: iconName), motion: .coin)
    }

    /// - Parameter iconHeight: how tall the icon is drawn. A thin line icon like
    ///   the crosshair needs a little more than a solid coin to read as the same
    ///   weight beside it.
    init(icon texture: SKTexture, motion: Motion, iconHeight: CGFloat = StatCounterNode.iconHeight) {
        self.motion = motion
        super.init()

        let art = texture.size()

        // Sized by height, not width. The icons are not all the same shape, and a
        // fixed width would make a wide one tower over a narrow one.
        let height = iconHeight
        let width = art.height > 0 ? height * (art.width / art.height) : height

        icon.texture = texture
        icon.size = CGSize(width: width, height: height)
        iconWidth = width
        addChild(iconHolder)
        iconHolder.addChild(icon)

        label.fontSize = 16
        label.fontColor = .white
        label.horizontalAlignmentMode = .left
        label.verticalAlignmentMode = .center
        addChild(label)

        place()
        setValue(0)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setValue(_ value: Int) {
        // Runs every frame; setting a label's text rebuilds its glyphs.
        guard value != lastValue else { return }

        let previous = lastValue
        lastValue = value

        // The first paint is not a change - the counter opening on zero should not
        // announce itself.
        guard previous != Int.min else {
            show(value)
            return
        }
        roll(from: previous, to: value)
        announce(value - previous)
    }

    private func show(_ value: Int) {
        label.text = "\(value)"
    }

    /// Counts up (or down) to the new number over a moment rather than jumping,
    /// so a payment reads as tokens arriving rather than a digit changing.
    private func roll(from start: Int, to end: Int) {
        label.removeAction(forKey: "roll")
        let steps = abs(end - start)
        guard steps > 1 else {
            show(end)
            return
        }
        let duration = min(0.45, 0.12 + Double(steps) * 0.02)
        label.run(.sequence([
            .customAction(withDuration: duration) { [weak self] _, elapsed in
                let share = Double(elapsed) / duration
                let eased = 1 - (1 - share) * (1 - share)
                self?.show(start + Int((Double(end - start) * eased).rounded()))
            },
            .run { [weak self] in self?.show(end) }
        ]), withKey: "roll")
    }

    /// The crosshair: a punch up and back, a quarter turn, and a ring going out
    /// from it - one more down. Never bigger than 1.4, so it never reaches the
    /// number beside it.
    private func punch() {
        let up = SKAction.scale(to: 1.4, duration: 0.08)
        up.timingMode = .easeOut
        let back = SKAction.scale(to: 1, duration: 0.18)
        back.timingMode = .easeIn
        icon.run(.group([
            .sequence([up, back]),
            .rotate(byAngle: -.pi / 2, duration: 0.26)
        ]), withKey: "coin")

        let ring = SKShapeNode(circleOfRadius: icon.size.height / 2)
        ring.strokeColor = .white
        ring.lineWidth = 2
        ring.fillColor = .clear
        ring.position = iconHolder.position
        ring.zPosition = -1
        addChild(ring)
        let spread = SKAction.scale(to: 2.2, duration: 0.35)
        spread.timingMode = .easeOut
        ring.run(.sequence([
            .group([spread, .fadeOut(withDuration: 0.35)]),
            .removeFromParent()
        ]))
    }

    /// The coin itself: a flip and a hop when tokens come in, with a few
    /// sparks thrown off it; a shake when they go out.
    private func animateIcon(gained: Bool) {
        icon.removeAction(forKey: "coin")
        icon.xScale = 1
        icon.yScale = 1
        // The crosshair is the same every quarter turn, so this snap back is
        // invisible and keeps the angle from piling up.
        icon.zRotation = 0
        icon.position = .zero

        if case .target = motion {
            punch()
            return
        }

        if gained {
            let up = SKAction.moveBy(x: 0, y: 4, duration: 0.1)
            up.timingMode = .easeOut
            let down = SKAction.moveBy(x: 0, y: -4, duration: 0.12)
            down.timingMode = .easeIn
            icon.run(.group([
                .sequence([up, down]),
                .sequence([.scaleX(to: 0.15, duration: 0.07), .scaleX(to: 1, duration: 0.07),
                           .scaleX(to: 0.15, duration: 0.07), .scaleX(to: 1, duration: 0.07)])
            ]), withKey: "coin")

            for index in 0..<5 {
                let angle = CGFloat(index) / 5 * .pi * 2 + 0.3
                let spark = SKShapeNode(circleOfRadius: 1.8)
                spark.fillColor = RenderPalette.treasure
                spark.strokeColor = .clear
                spark.position = iconHolder.position
                spark.zPosition = 3
                addChild(spark)
                let out = SKAction.moveBy(x: cos(angle) * 13, y: sin(angle) * 13, duration: 0.3)
                out.timingMode = .easeOut
                spark.run(.sequence([
                    .group([out, .sequence([.wait(forDuration: 0.12), .fadeOut(withDuration: 0.18)])]),
                    .removeFromParent()
                ]))
            }
        } else {
            icon.run(.sequence([
                .moveBy(x: -2.5, y: 0, duration: 0.03),
                .moveBy(x: 5, y: 0, duration: 0.05),
                .moveBy(x: -5, y: 0, duration: 0.05),
                .moveBy(x: 2.5, y: 0, duration: 0.03)
            ]), withKey: "coin")
        }
    }

    /// The room this counter needs for its number: the icon, the gap, and one
    /// widest-digit's width per digit. Steady while the number rolls, and it
    /// only grows when the number gains a digit - see MatchPanelNode.
    var reservedWidth: CGFloat {
        let digits = max(1, String(max(lastValue, 0)).count)
        return iconWidth + StatCounterNode.gap + StatCounterNode.digitWidth * CGFloat(digits)
    }

    private static let digitWidth: CGFloat = {
        let probe = SKLabelNode(fontNamed: "AvenirNext-Bold")
        probe.fontSize = 16
        probe.text = "88888888"
        return ceil(probe.frame.width / 8)
    }()

    /// The icon at the counter's origin, which is its LEFT edge, and the number
    /// after it.
    ///
    /// Never measured off the number's real width. A 1 is narrower than an 8,
    /// and centring on the real width made the pair slide on every pickup, so
    /// the icon now stays put and only the digits change.
    private func place() {
        iconHolder.position = CGPoint(x: iconWidth / 2, y: 0)
        label.position = CGPoint(x: iconWidth + StatCounterNode.gap, y: 0)
    }

    private func announce(_ delta: Int) {
        guard delta != 0 else { return }
        let gained = delta > 0
        animateIcon(gained: gained)

        label.removeAction(forKey: "pulse")
        label.setScale(1)
        label.run(.sequence([
            .scale(to: gained ? 1.35 : 0.82, duration: 0.09),
            .scale(to: 1.0, duration: 0.16)
        ]), withKey: "pulse")

        // A number that rises off the counter and fades. Made fresh each time
        // rather than reused, so two payments a moment apart both get seen instead
        // of the second one restarting the first.
        let float = SKLabelNode(fontNamed: "AvenirNext-Bold")
        float.text = gained ? "+\(delta)" : "\(delta)"
        float.fontSize = 15
        float.fontColor = gained ? RenderPalette.placementValid : RenderPalette.placementBlocked
        float.horizontalAlignmentMode = .center
        float.verticalAlignmentMode = .center

        // Below rather than above, because this row sits inside the match panel and
        // anything rising off the top of it would climb through the panel's own top
        // edge and then off the screen. Downward, the strip underneath is clear.
        float.position = CGPoint(x: reservedWidth / 2, y: -StatCounterNode.height / 2 - 4)
        float.zPosition = 2
        addChild(float)

        float.run(.sequence([
            .group([.moveBy(x: 0, y: -20, duration: 0.7),
                    .sequence([.wait(forDuration: 0.28),
                               .fadeOut(withDuration: 0.42)])]),
            .removeFromParent()
        ]))
    }
}
