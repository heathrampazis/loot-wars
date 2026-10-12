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

    private static let iconHeight: CGFloat = 15
    private static let gap: CGFloat = 6

    private let icon = SKSpriteNode()

    /// Where the icon sits in the row. The icon's own position is left free for
    /// the hop and the shake, which re-centring would otherwise cancel.
    private let iconHolder = SKNode()
    private let label = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private var lastValue = Int.min

    init(iconNamed iconName: String) {
        super.init()

        let texture = SKTexture(imageNamed: iconName)
        let art = texture.size()

        // Sized by height, not width. The icons are not all the same shape, and a
        // fixed width would make a wide one tower over a narrow one.
        let height = StatCounterNode.iconHeight
        let width = art.height > 0 ? height * (art.width / art.height) : height

        icon.texture = texture
        icon.size = CGSize(width: width, height: height)
        addChild(iconHolder)
        iconHolder.addChild(icon)

        label.fontSize = 16
        label.fontColor = .white
        label.horizontalAlignmentMode = .left
        label.verticalAlignmentMode = .center
        addChild(label)

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
        centre()
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

    /// The coin itself: a flip and a hop when tokens come in, with a few
    /// sparks thrown off it; a shake when they go out.
    private func animateIcon(gained: Bool) {
        icon.removeAction(forKey: "coin")
        icon.xScale = 1
        icon.position = .zero

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

    /// Re-centres the icon and the number as one pair.
    ///
    /// Measured rather than assumed, and only on a change, so the cost lands on the
    /// frame a token was picked up rather than on all of them.
    private func centre() {
        let width = icon.size.width + StatCounterNode.gap + label.frame.width
        iconHolder.position = CGPoint(x: -width / 2 + icon.size.width / 2, y: 0)
        label.position = CGPoint(x: -width / 2 + icon.size.width + StatCounterNode.gap, y: 0)
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
        float.position = CGPoint(x: 0, y: -StatCounterNode.height / 2 - 4)
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
