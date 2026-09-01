//
//  StatCounterNode.swift
//  Loot Wars
//
//  An icon and a number, for the things you count rather than the things that run
//  down. Same icon size and spacing as StatBarNode, so a counter row lines up with
//  the bars above it.
//

import SpriteKit

final class StatCounterNode: SKNode {

    /// Its own number rather than the icon's size, which it used to borrow. The
    /// counter row is the only one with no bar in it, so it can afford to be
    /// shorter than a bar row - and at 84 points the panel needed it to be.
    static let height: CGFloat = 20

    private let label = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private var lastValue = Int.min

    /// Local origin is the left edge of the icon, vertically centred on the row.
    init(iconNamed iconName: String) {
        super.init()

        let texture = SKTexture(imageNamed: iconName)
        let art = texture.size()

        // Sized by height, not width. The icons are not all the same shape, and a
        // fixed width would make a wide one tower over a narrow one.
        let height = StatCounterNode.height * 0.8
        let width = art.height > 0 ? height * (art.width / art.height) : height

        let icon = SKSpriteNode(texture: texture, size: CGSize(width: width, height: height))
        icon.position = CGPoint(x: StatBarNode.iconSize / 2, y: 0)
        addChild(icon)

        label.fontSize = 16
        label.fontColor = .white
        label.horizontalAlignmentMode = .left
        label.verticalAlignmentMode = .center
        label.position = CGPoint(x: StatBarNode.iconSize + StatBarNode.gap, y: 0)
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
        label.text = "\(value)"

        // The first paint is not a change - the counter opening on zero should not
        // announce itself.
        guard previous != Int.min else { return }
        announce(value - previous)
    }

    /// Says what just happened to the number.
    ///
    /// Tokens arrive from four places and leave from one, and until now all five
    /// were silent: the number simply differed from the number you last happened to
    /// look at. A kill paid eleven and nothing on screen said so, and a purchase
    /// took fifteen out with no more ceremony than the shop card going faint.
    ///
    /// It lives on the counter rather than on any of the five, so every source is
    /// covered by construction - including the ones added later - and the one place
    /// it can be seen is the place you already look to find out how rich you are.
    private func announce(_ delta: Int) {
        guard delta != 0 else { return }

        let gained = delta > 0

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
        float.horizontalAlignmentMode = .left
        float.verticalAlignmentMode = .center
        float.position = CGPoint(x: label.position.x + 26, y: 0)
        float.zPosition = 2
        addChild(float)

        float.run(.sequence([
            .group([.moveBy(x: 0, y: 22, duration: 0.7),
                    .sequence([.wait(forDuration: 0.28),
                               .fadeOut(withDuration: 0.42)])]),
            .removeFromParent()
        ]))
    }
}
