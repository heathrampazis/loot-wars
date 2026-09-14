//
//  StatCounterNode.swift
//  Loot Wars
//
//  Your purse, worn on the shop button.
//
//  It has been three things. A row on the HUD panel, which is where its icon size
//  and spacing came from - they were StatBarNode's, so a counter lined up with the
//  bars above it. Then a plate of its own beside the button when the panel went.
//  Now a badge ON the button, which is where it should have gone first.
//
//  The plate beside the button was the mistake, and it is worth naming: a purse is
//  not a readout, it is a property of the shop. Standing it next to the button as
//  its own object said they were two things that happened to be near each other,
//  and it put a bar of furniture out across the corner of the map for a number
//  that is three characters long. Clipped to the button's lower edge it is
//  unmistakably the button's, costs no ground at all, and disappears with the
//  button when the shop is open - which is correct, because the shop shows you
//  your tokens itself.
//
//  Its origin is its own CENTRE, unlike the row it used to be, so hanging it off
//  the middle of a round button is one coordinate rather than arithmetic.
//

import SpriteKit

final class StatCounterNode: SKNode {

    /// Sized for three digits, which is more tokens than anybody holds at once -
    /// a match pays somewhere between seventy and three hundred and they are spent
    /// as they arrive. Fixed rather than hugging the number: this is centred on a
    /// button, so a plate that grew would push out from both sides every time you
    /// picked one up.
    static let size = CGSize(width: 56, height: 22)

    private static let iconHeight: CGFloat = 14

    private let label = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private var lastValue = Int.min

    init(iconNamed iconName: String) {
        super.init()

        let plate = SKShapeNode(path: CGPath(
            roundedRect: CGRect(x: -StatCounterNode.size.width / 2,
                                y: -StatCounterNode.size.height / 2,
                                width: StatCounterNode.size.width,
                                height: StatCounterNode.size.height),
            cornerWidth: StatCounterNode.size.height / 2,
            cornerHeight: StatCounterNode.size.height / 2,
            transform: nil))

        plate.fillColor = RenderPalette.hudPanel
        plate.strokeColor = .clear
        addChild(plate)

        let texture = SKTexture(imageNamed: iconName)
        let art = texture.size()

        // Sized by height, not width. The icons are not all the same shape, and a
        // fixed width would make a wide one tower over a narrow one.
        let height = StatCounterNode.iconHeight
        let width = art.height > 0 ? height * (art.width / art.height) : height

        let icon = SKSpriteNode(texture: texture, size: CGSize(width: width, height: height))
        icon.position = CGPoint(x: -StatCounterNode.size.width / 2 + 4 + width / 2, y: 0)
        addChild(icon)

        label.fontSize = 13
        label.fontColor = .white
        label.horizontalAlignmentMode = .left
        label.verticalAlignmentMode = .center
        label.position = CGPoint(x: icon.position.x + width / 2 + 4, y: 0)
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
        float.verticalAlignmentMode = .center
        // Above the badge and centred on it, rather than off its right-hand end.
        // The old offset was measured from a label that started at the node's
        // origin; this one hangs off the middle of a pill, and +12 off the side of
        // a 56-point plate would have floated the number into the map.
        float.horizontalAlignmentMode = .center
        float.position = CGPoint(x: 0, y: StatCounterNode.size.height / 2 + 2)
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
