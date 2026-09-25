//
//  MatchPanelNode.swift
//  Loot Wars
//
//  The panel along the top middle: how long is left, and what you have to spend.
//
//  ONE ROW, side by side. It has been two rows once and it has been two separate
//  places twice, and the thing that settles it is that these are the two numbers
//  you read WITHOUT looking - the glance up mid-fight that asks how long and how
//  much. Two readings on one line is one glance. Stacked, or split across the
//  screen, it is two.
//
//  The clock is a fact about the match and the purse is a fact about you, which is
//  the one argument against putting them in the same plate and is worth answering
//  rather than ignoring. But a HUD panel is a place on the screen, not a category -
//  the leaderboard opposite carries eight teams' scores and your own standing in
//  the same box for exactly the same reason.
//
//  Centred, because that is the one strip of the top edge nothing else wants: the
//  shop button holds the left corner and the leaderboard the right, and the middle
//  is empty on every screen size the two of them fit on. At 176 across it still
//  finishes clear of both on an SE, which is the tightest one.
//

import SpriteKit

final class MatchPanelNode: SKNode {

    /// Not private: the scene lines the panel up against the top edge, and a second
    /// copy of the height would drift the moment this one changed.
    static let size = CGSize(width: 176, height: 32)

    /// When the clock starts warning you, in seconds.
    private static let urgentBelow: Double = 30

    private static let iconSize: CGFloat = 18

    // Where each reading sits along the row.
    //
    // The clock's pair is 62 points across - an 18pt icon, 7pt of air, and a four
    // character time - and is always exactly that, so it can be hung off a fixed
    // centre. The purse cannot: a token count is one, two or three characters and
    // it re-centres ITSELF on every change. So it gets a REGION rather than a
    // point, 50 wide, which is the three-digit case. Centring the two as a measured
    // block instead would slide the whole row sideways the first time you crossed
    // ten.
    private static let clockCentre: CGFloat = -38
    private static let purseCentre: CGFloat = 44

    private let label = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private let purse = StatCounterNode(iconNamed: "Token")

    private var lastShown = -1
    private var lastUrgent: Bool?

    override init() {
        super.init()
        zPosition = 1000

        let size = MatchPanelNode.size

        let panel = SKShapeNode(path: CGPath(
            roundedRect: CGRect(x: -size.width / 2, y: -size.height,
                                width: size.width, height: size.height),
            cornerWidth: 12, cornerHeight: 12, transform: nil))

        panel.fillColor = RenderPalette.hudPanel
        panel.strokeColor = .clear
        addChild(panel)

        // The origin is the panel's TOP, so everything inside it hangs downward and
        // the scene can hand it a top edge and nothing else.
        let middle = -size.height / 2

        // Icon then time, the pair centred together rather than the text centred and
        // the icon hung off it - otherwise the clock looks lopsided in its half.
        let icon = SKSpriteNode(texture: Glyphs.clock)
        let iconSide = MatchPanelNode.iconSize
        icon.size = CGSize(width: iconSide, height: iconSide)
        icon.position = CGPoint(x: MatchPanelNode.clockCentre - 22, y: middle)
        icon.alpha = 0.9
        addChild(icon)

        label.fontSize = 19
        label.fontColor = .white
        label.horizontalAlignmentMode = .left
        label.verticalAlignmentMode = .center
        label.position = CGPoint(x: icon.position.x + iconSide / 2 + 7, y: middle)
        addChild(label)

        purse.position = CGPoint(x: MatchPanelNode.purseCentre, y: middle)
        addChild(purse)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(with world: World) {
        if let player = world.localPlayer { purse.setValue(player.tokens) }

        // Rounded UP, so the clock reads 5:00 for the whole first second and only
        // shows 0:00 when the time is actually gone. Rounding down would start the
        // match at 4:59 and spend the last second lying about being finished.
        let seconds = Int(world.timeRemaining.rounded(.up))
        let urgent = world.timeRemaining <= MatchPanelNode.urgentBelow

        if urgent != lastUrgent {
            lastUrgent = urgent
            label.fontColor = urgent ? RenderPalette.healthBar : .white
        }

        guard seconds != lastShown else { return }
        lastShown = seconds
        label.text = String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}
