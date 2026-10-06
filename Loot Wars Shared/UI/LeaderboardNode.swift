//
//  LeaderboardNode.swift
//  Loot Wars
//
//  Who is winning, in the top-right corner, by name.
//
//  The top four, one to a row: place, team dot, name and score. If you are not
//  in the top four, a thin line and then your own row underneath with your real
//  place, so you always know where you stand without the board growing to eight.
//
//  Height is what this corner is short of: eight rows reached 50 points over the
//  item button on a 15 and 68 on an SE. Five rows and the line come to 96, which
//  is what an SE has room for.
//
//  Its origin is its own top-RIGHT corner, mirroring the HUD's top-left, so
//  positioning it is an inset from the edge rather than arithmetic with its width.
//
//  Five rows exist for the life of the match and only their text and colour
//  change, and only when the order or a score actually moves.
//

import SpriteKit

final class LeaderboardNode: SKNode {

    private static let width: CGFloat = 158
    private static let rowHeight: CGFloat = 16
    private static let padding: CGFloat = 6
    private static let dividerGap: CGFloat = 4
    private static let dot: CGFloat = 9
    private static let shown = 4

    private static var shortHeight: CGFloat { padding * 2 + rowHeight * CGFloat(shown) }
    private static var tallHeight: CGFloat { shortHeight + dividerGap + rowHeight }

    /// The most room it ever takes: the top four, the line and your row.
    static var size: CGSize { CGSize(width: width, height: tallHeight) }

    // Columns, measured from the right edge, which is this node's origin.
    private static var left: CGFloat { -width + padding }
    private static var rankX: CGFloat { left + 8 }
    private static var dotX: CGFloat { left + 21 }
    private static var nameX: CGFloat { left + 30 }
    private static var scoreRight: CGFloat { -padding - 6 }
    private static let scoreRoom: CGFloat = 30

    private final class Row {
        let holder = SKNode()
        let highlight: SKShapeNode
        let dot: SKShapeNode
        let rank = SKLabelNode(fontNamed: "AvenirNext-Bold")
        let name = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        let score = SKLabelNode(fontNamed: "AvenirNext-Bold")

        init() {
            let w = LeaderboardNode.width - LeaderboardNode.padding * 2
            highlight = SKShapeNode(path: CGPath(
                roundedRect: CGRect(x: LeaderboardNode.left, y: -LeaderboardNode.rowHeight / 2,
                                    width: w, height: LeaderboardNode.rowHeight),
                cornerWidth: 6, cornerHeight: 6, transform: nil))
            dot = SKShapeNode(circleOfRadius: LeaderboardNode.dot / 2)

            highlight.fillColor = SKColor(white: 1, alpha: 0.16)
            highlight.strokeColor = .clear
            highlight.isHidden = true
            holder.addChild(highlight)

            rank.fontSize = 10
            rank.horizontalAlignmentMode = .center
            rank.verticalAlignmentMode = .center
            rank.position = CGPoint(x: LeaderboardNode.rankX, y: 0)
            holder.addChild(rank)

            dot.strokeColor = .black
            dot.lineWidth = 1.5
            dot.position = CGPoint(x: LeaderboardNode.dotX, y: 0)
            holder.addChild(dot)

            name.fontSize = 11
            name.horizontalAlignmentMode = .left
            name.verticalAlignmentMode = .center
            name.position = CGPoint(x: LeaderboardNode.nameX, y: 0)
            holder.addChild(name)

            score.fontSize = 11
            score.horizontalAlignmentMode = .right
            score.verticalAlignmentMode = .center
            score.position = CGPoint(x: LeaderboardNode.scoreRight, y: 0)
            holder.addChild(score)
        }
    }

    private let panel = SKShapeNode()
    private let divider: SKShapeNode
    private var rows: [Row] = []
    private var lastDrawn: [Int] = []
    private var tall: Bool?

    override init() {
        let lineWidth = LeaderboardNode.width - LeaderboardNode.padding * 2 - 8
        divider = SKShapeNode(rect: CGRect(x: -lineWidth / 2, y: -0.5, width: lineWidth, height: 1))
        super.init()
        zPosition = 1000

        panel.fillColor = RenderPalette.hudPanel
        panel.strokeColor = .clear
        addChild(panel)

        divider.fillColor = SKColor(white: 1, alpha: 0.2)
        divider.strokeColor = .clear
        divider.position = CGPoint(
            x: -LeaderboardNode.width / 2,
            y: -LeaderboardNode.shortHeight + LeaderboardNode.padding - LeaderboardNode.dividerGap / 2)
        addChild(divider)

        for slot in 0...LeaderboardNode.shown {
            let row = Row()
            var y = -LeaderboardNode.padding - LeaderboardNode.rowHeight * (CGFloat(slot) + 0.5)
            if slot == LeaderboardNode.shown { y -= LeaderboardNode.dividerGap }
            row.holder.position = CGPoint(x: 0, y: y)
            addChild(row.holder)
            rows.append(row)
        }
        setTall(false)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Short with you in the top four, tall with the line and your row under it.
    private func setTall(_ wanted: Bool) {
        guard tall != wanted else { return }
        tall = wanted
        let height = wanted ? LeaderboardNode.tallHeight : LeaderboardNode.shortHeight
        panel.path = CGPath(
            roundedRect: CGRect(x: -LeaderboardNode.width, y: -height,
                                width: LeaderboardNode.width, height: height),
            cornerWidth: 12, cornerHeight: 12, transform: nil)
        divider.isHidden = !wanted
        rows[LeaderboardNode.shown].holder.isHidden = !wanted
    }

    func update(with world: World) {
        let standings = world.standings
        let you = world.localPlayer?.team

        // Only redraw when the order or a number actually changed. Scores move a few
        // times a minute; this runs sixty times a second.
        let fingerprint = standings.flatMap { [$0.team.raw, $0.score] } + [you?.raw ?? -1]
        guard fingerprint != lastDrawn else { return }
        lastDrawn = fingerprint

        for place in 0..<min(LeaderboardNode.shown, standings.count) {
            fill(rows[place], place: place, standing: standings[place], world: world, you: you)
        }

        let yourPlace = standings.firstIndex { $0.team == you }
        if let yourPlace, yourPlace >= LeaderboardNode.shown {
            fill(rows[LeaderboardNode.shown], place: yourPlace,
                 standing: standings[yourPlace], world: world, you: you)
            setTall(true)
        } else {
            setTall(false)
        }
    }

    private func fill(_ row: Row, place: Int, standing: (team: TeamID, score: Int),
                      world: World, you: TeamID?) {
        let mine = standing.team == you
        let first = place == 0

        row.highlight.isHidden = !mine
        row.dot.fillColor = RenderPalette.vibrantColour(for: standing.team)

        row.rank.text = "\(place + 1)"
        row.rank.fontColor = first ? RenderPalette.treasure : SKColor(white: 1, alpha: 0.55)

        row.score.text = "\(standing.score)"
        row.score.fontColor = SKColor(white: 1, alpha: mine ? 1 : 0.75)

        // First place and you in bold, everybody else a step lighter.
        row.name.fontName = first || mine ? "AvenirNext-Bold" : "AvenirNext-DemiBold"
        row.name.fontColor = SKColor(white: 1, alpha: mine || first ? 1 : 0.8)
        let room = LeaderboardNode.scoreRight - LeaderboardNode.scoreRoom - LeaderboardNode.nameX
        LeaderboardNode.fit(row.name, world.name(of: standing.team), width: room)
    }

    /// Writes the name, trimming it with an ellipsis if it would run into the score.
    private static func fit(_ label: SKLabelNode, _ text: String, width: CGFloat) {
        label.text = text
        var trimmed = text
        while label.frame.width > width, trimmed.count > 1 {
            trimmed.removeLast()
            label.text = trimmed + "…"
        }
    }
}
