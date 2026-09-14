//
//  MatchPanelNode.swift
//  Loot Wars
//
//  The panel along the top middle: how long is left, and what you have to spend.
//
//  It was MatchTimerNode and it was only the clock. The purse joined it because
//  standing alone it had nowhere to be that did not look like litter - beside the
//  shop button it was a bar of furniture across the corner of the map, clipped to
//  the button it was a sticker. Two rows in one plate is neither, and the top edge
//  now reads as three panels of the same colour rather than as a button, a pill
//  and two panels.
//
//  Those two numbers have nothing to do with each other, which is the one argument
//  against this and is worth answering rather than ignoring. The clock is a fact
//  about the match and the purse is a fact about you. But a HUD panel is a place on
//  the screen, not a category - the leaderboard opposite carries eight teams'
//  scores and your own standing in the same box for exactly the same reason - and
//  the alternative here was a third plate on a top edge that has room for three.
//
//  Centred, because that is the one strip of the top edge nothing else wants: the
//  shop button holds the left corner and the leaderboard the right, and the middle
//  is empty on every screen size the two of them fit on.
//

import SpriteKit

final class MatchPanelNode: SKNode {

    /// The clock's row, and then the purse's underneath it.
    private static let clockHeight: CGFloat = 32
    private static let purseHeight: CGFloat = 26

    static let size = CGSize(width: 104, height: clockHeight + purseHeight)

    private static let urgentBelow: Double = 30
    private static let iconSize: CGFloat = 18

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

        // Icon then time, the pair centred together rather than the text centred
        // and the icon hung off it - otherwise the panel looks lopsided.
        let icon = SKSpriteNode(texture: Glyphs.clock)
        let iconSide = MatchPanelNode.iconSize
        icon.size = CGSize(width: iconSide, height: iconSide)

        // The pair is centred as a unit: an 18pt icon, 7pt of air, and a four
        // character time is 62 points across, so it starts 31 left of centre. The
        // purse below does the same sum for itself every time it changes, because
        // a token count is one, two or three characters and cannot be hardcoded.
        let clockMiddle = -MatchPanelNode.clockHeight / 2
        icon.position = CGPoint(x: -22, y: clockMiddle)
        icon.alpha = 0.9
        addChild(icon)

        label.fontSize = 19
        label.fontColor = .white
        label.horizontalAlignmentMode = .left
        label.verticalAlignmentMode = .center
        label.position = CGPoint(x: icon.position.x + iconSide / 2 + 7, y: clockMiddle)
        addChild(label)

        purse.position = CGPoint(x: 0,
                                 y: -MatchPanelNode.clockHeight
                                    - MatchPanelNode.purseHeight / 2)
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
