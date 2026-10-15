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
//  is empty on every screen size the two of them fit on.
//
//  Its width fits what is in it. Each count keeps room for the digits it has, so
//  the plate stays tight while the numbers are small and widens a step when one
//  gains a digit. The pause button hangs off its left edge and moves with it.
//

import SpriteKit

final class MatchPanelNode: SKNode {

    /// The height, which never changes. The WIDTH does - see `width` - so this
    /// carries the widest it is drawn at a match's start, for anything that
    /// only needs a rough size.
    static let size = CGSize(width: 200, height: 32)

    /// Red for the final stretch, when points count double - see Match.finalStretch.
    private static let urgentBelow: Double = GameConfig.Match.finalStretch

    private static let iconSize: CGFloat = 18
    private static let iconGap: CGFloat = 7

    /// Air inside each end, and between the three readings.
    private static let padding: CGFloat = 12
    private static let spacing: CGFloat = 16

    /// The clock's number always reads M:SS, so its room is measured once, on
    /// the widest digits, and never moves - a panel that twitched every second
    /// as a 1 became a 0 would be worse than one a little too wide.
    private static let clockTextWidth: CGFloat = {
        let probe = SKLabelNode(fontNamed: "AvenirNext-Bold")
        probe.fontSize = 19
        probe.text = "8:88"
        return ceil(probe.frame.width)
    }()

    private let panel = SKShapeNode()
    private var glass: GlassNode?
    private let clockIcon = SKSpriteNode(texture: Glyphs.clock)
    private let label = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private let purse = StatCounterNode(iconNamed: "Token")

    /// Your eliminations this match, beside the same crosshair the elimination
    /// banner uses. Pops when it goes up - see StatCounterNode.
    private let kills = StatCounterNode(icon: Glyphs.crosshair, motion: .target, iconHeight: 18)

    /// How wide the panel is drawn right now. It fits what is in it, and only
    /// changes when a count gains or loses a digit - a pickup that leaves the
    /// digit count alone moves nothing. GameScene hangs the pause button off it.
    var width: CGFloat {
        MatchPanelNode.padding * 2 + MatchPanelNode.spacing * 2
            + clockWidth + purseRoom + killsRoom
    }

    /// The room each count has right now, eased towards what it needs, so a new
    /// digit opens up smoothly and everything after it slides rather than jumps.
    private var purseRoom: CGFloat = 0
    private var killsRoom: CGFloat = 0
    private var drawnWidth: CGFloat = -1

    private var lastShown = -1
    private var lastUrgent: Bool?

    override init() {
        super.init()
        // Over the edge markers (1040), which slide past it - see BaseCompassNode.
        zPosition = 1045

        panel.fillColor = RenderPalette.hudPanel
        panel.strokeColor = RenderPalette.glassRim
        panel.lineWidth = RenderPalette.glassRimWidth
        addChild(panel)

        // The origin is the panel's TOP, so everything inside it hangs downward and
        // the scene can hand it a top edge and nothing else.
        let middle = -MatchPanelNode.size.height / 2

        let iconSide = MatchPanelNode.iconSize
        clockIcon.size = CGSize(width: iconSide, height: iconSide)
        clockIcon.alpha = 0.9
        clockIcon.position.y = middle
        addChild(clockIcon)

        label.fontSize = 19
        label.fontColor = .white
        label.horizontalAlignmentMode = .left
        label.verticalAlignmentMode = .center
        label.position.y = middle
        addChild(label)

        purse.position.y = middle
        addChild(purse)

        kills.position.y = middle
        addChild(kills)

        purseRoom = purse.reservedWidth
        killsRoom = kills.reservedWidth
        layOut()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Size

    private var clockWidth: CGFloat {
        MatchPanelNode.iconSize + MatchPanelNode.iconGap + MatchPanelNode.clockTextWidth
    }

    /// Steps a room towards what its count needs. True while it is still moving.
    private static func ease(_ room: inout CGFloat, to target: CGFloat) -> Bool {
        guard room != target else { return false }
        room = abs(target - room) > 0.25 ? room + (target - room) * 0.25 : target
        return true
    }

    /// The readings left to right, each count at the left of its room, and the
    /// plate drawn round them.
    private func layOut() {
        let middle = -MatchPanelNode.size.height / 2
        let width = self.width
        var x = -width / 2 + MatchPanelNode.padding

        clockIcon.position = CGPoint(x: x + MatchPanelNode.iconSize / 2, y: middle)
        label.position = CGPoint(x: x + MatchPanelNode.iconSize + MatchPanelNode.iconGap, y: middle)
        x += clockWidth + MatchPanelNode.spacing

        purse.position = CGPoint(x: x, y: middle)
        x += purseRoom + MatchPanelNode.spacing

        kills.position = CGPoint(x: x, y: middle)

        guard abs(width - drawnWidth) > 0.25 else { return }
        drawnWidth = width

        let height = MatchPanelNode.size.height
        let path = CGPath(roundedRect: CGRect(x: -width / 2, y: -height,
                                              width: width, height: height),
                          cornerWidth: 12, cornerHeight: 12, transform: nil)
        panel.path = path

        // Frosted map behind it - see GlassNode. Reshaped, not remade, so it
        // does not blink while the plate eases wider.
        if let glass {
            glass.reshape(to: path)
        } else {
            let pane = GlassNode(path: path)
            panel.addChild(pane)
            glass = pane
        }
    }

    func update(with world: World) {
        if let player = world.localPlayer { purse.setValue(player.tokens) }
        kills.setValue(world.stats[world.localPlayerID]?.kills ?? 0)

        // Nothing is laid out again unless a room is actually changing size.
        let pursing = MatchPanelNode.ease(&purseRoom, to: purse.reservedWidth)
        let killing = MatchPanelNode.ease(&killsRoom, to: kills.reservedWidth)
        if pursing || killing { layOut() }

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
