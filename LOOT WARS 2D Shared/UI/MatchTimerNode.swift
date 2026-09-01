//
//  MatchTimerNode.swift
//  Loot Wars
//
//  The clock, along the top edge.
//
//  Centred, because that is the one strip of the top edge nothing else wants: the
//  HUD holds the left corner and the leaderboard the right, and the middle is empty
//  on every screen size the two of them fit on.
//

import SpriteKit

final class MatchTimerNode: SKNode {

    /// Not private: the scene lines the shop button up against this edge, and a
    /// second copy of the number would drift the moment either changed.
    static let size = CGSize(width: 86, height: 32)

    /// When the clock starts warning you, in seconds.
    private static let urgentBelow: Double = 30

    private let label = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private var lastShown = -1
    private var lastUrgent: Bool?

    override init() {
        super.init()
        zPosition = 1000

        let size = MatchTimerNode.size
        let panel = SKShapeNode(path: CGPath(
            roundedRect: CGRect(x: -size.width / 2, y: -size.height,
                                width: size.width, height: size.height),
            cornerWidth: 12, cornerHeight: 12, transform: nil))
        panel.fillColor = RenderPalette.hudPanel
        panel.strokeColor = .clear
        addChild(panel)

        label.fontSize = 19
        label.fontColor = .white
        label.horizontalAlignmentMode = .center
        label.verticalAlignmentMode = .center
        label.position = CGPoint(x: 0, y: -size.height / 2)
        addChild(label)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(with world: World) {
        // Rounded UP, so the clock reads 5:00 for the whole first second and only
        // shows 0:00 when the time is actually gone. Rounding down would start the
        // match at 4:59 and spend the last second lying about being finished.
        let seconds = Int(world.timeRemaining.rounded(.up))

        let urgent = world.timeRemaining <= MatchTimerNode.urgentBelow
        if urgent != lastUrgent {
            lastUrgent = urgent
            label.fontColor = urgent ? RenderPalette.healthBar : .white
        }

        guard seconds != lastShown else { return }
        lastShown = seconds

        label.text = String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}
