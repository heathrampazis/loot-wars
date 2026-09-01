//
//  ResultsNode.swift
//  Loot Wars
//
//  The end of the match: where you came, what everybody scored, and a way back in.
//
//  Headed by YOUR placing rather than by naming a winner, because teams have colours
//  and no names - "TEAL WINS" would need Core to learn what its colours are called,
//  and the thing you actually want to know is where you came anyway.
//
//  Unlike the chest panel this one DOES dim the map behind it, and for the opposite
//  reason: the world has genuinely stopped. Nothing is moving back there and nothing
//  can hurt you, so pulling focus is telling the truth.
//

import SpriteKit

final class ResultsNode: SKNode {

    private static let panelSize = CGSize(width: 300, height: 244)
    private static let rowHeight: CGFloat = 19
    private static let swatch: CGFloat = 11

    private let scrim = SKShapeNode()
    private let headline = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private let subhead = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private let again = SKNode()
    private var rows: [(swatch: SKShapeNode, rank: SKLabelNode, score: SKLabelNode, highlight: SKShapeNode)] = []

    private static let againSize = CGSize(width: 156, height: 42)

    override init() {
        super.init()
        zPosition = 1500
        isHidden = true

        scrim.fillColor = SKColor(white: 0, alpha: 0.55)
        scrim.strokeColor = .clear
        addChild(scrim)

        let size = ResultsNode.panelSize
        let panel = SKShapeNode(path: CGPath(
            roundedRect: CGRect(x: -size.width / 2, y: -size.height / 2,
                                width: size.width, height: size.height),
            cornerWidth: 20, cornerHeight: 20, transform: nil))
        panel.fillColor = RenderPalette.hudPanel
        panel.strokeColor = .clear
        panel.alpha = 0.98
        addChild(panel)

        headline.fontSize = 26
        headline.fontColor = .white
        headline.verticalAlignmentMode = .center
        headline.position = CGPoint(x: 0, y: size.height / 2 - 32)
        addChild(headline)

        subhead.fontSize = 12
        subhead.fontColor = SKColor(white: 1, alpha: 0.6)
        subhead.verticalAlignmentMode = .center
        subhead.position = CGPoint(x: 0, y: size.height / 2 - 54)
        addChild(subhead)

        buildRows(in: size)
        buildAgainButton(in: size)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func buildRows(in size: CGSize) {
        // Two columns of four, the same shape the in-match board settled on, so the
        // final table reads like the one you were watching all game.
        let columnWidth: CGFloat = 124
        let top = size.height / 2 - 78

        for place in 0..<TeamID.count {
            let column = place / (TeamID.count / 2)
            let index = place % (TeamID.count / 2)

            let left = -columnWidth - 8 + CGFloat(column) * (columnWidth + 16)
            let y = top - ResultsNode.rowHeight * (CGFloat(index) + 0.5)

            let highlight = SKShapeNode(path: CGPath(
                roundedRect: CGRect(x: left, y: y - ResultsNode.rowHeight / 2,
                                    width: columnWidth, height: ResultsNode.rowHeight),
                cornerWidth: 5, cornerHeight: 5, transform: nil))
            highlight.fillColor = SKColor(white: 1, alpha: 0.16)
            highlight.strokeColor = .clear
            highlight.isHidden = true
            addChild(highlight)

            let rank = SKLabelNode(fontNamed: "AvenirNext-Bold")
            rank.fontSize = 11
            rank.fontColor = SKColor(white: 1, alpha: 0.55)
            rank.horizontalAlignmentMode = .left
            rank.verticalAlignmentMode = .center
            rank.position = CGPoint(x: left + 10, y: y)
            rank.text = "\(place + 1)"
            addChild(rank)

            let side = ResultsNode.swatch
            let swatch = SKShapeNode(path: CGPath(
                roundedRect: CGRect(x: left + 26, y: y - side / 2, width: side, height: side),
                cornerWidth: 3, cornerHeight: 3, transform: nil))
            swatch.strokeColor = .black
            swatch.lineWidth = 1.5
            addChild(swatch)

            let score = SKLabelNode(fontNamed: "AvenirNext-Bold")
            score.fontSize = 12
            score.fontColor = .white
            score.horizontalAlignmentMode = .right
            score.verticalAlignmentMode = .center
            score.position = CGPoint(x: left + columnWidth - 10, y: y)
            addChild(score)

            rows.append((swatch, rank, score, highlight))
        }
    }

    private func buildAgainButton(in size: CGSize) {
        let box = ResultsNode.againSize
        again.position = CGPoint(x: 0, y: -size.height / 2 + 34)

        let pill = SKShapeNode(path: CGPath(
            roundedRect: CGRect(x: -box.width / 2, y: -box.height / 2,
                                width: box.width, height: box.height),
            cornerWidth: box.height / 2, cornerHeight: box.height / 2, transform: nil))
        pill.fillColor = RenderPalette.healthBar
        pill.strokeColor = .black
        pill.lineWidth = 3
        again.addChild(pill)

        let label = SKLabelNode(fontNamed: "AvenirNext-Bold")
        label.text = "PLAY AGAIN"
        label.fontSize = 16
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        again.addChild(label)

        addChild(again)
    }

    /// The scrim has to cover whatever the screen happens to be.
    func layOut(for screen: CGSize) {
        scrim.path = CGPath(rect: CGRect(x: -screen.width / 2, y: -screen.height / 2,
                                         width: screen.width, height: screen.height),
                            transform: nil)
    }

    func isPlayAgain(atLocalPoint point: CGPoint) -> Bool {
        let box = ResultsNode.againSize
        let local = CGPoint(x: point.x - again.position.x, y: point.y - again.position.y)
        // Grown a little, because it is the only way out of this screen.
        return abs(local.x) <= box.width / 2 + 16 && abs(local.y) <= box.height / 2 + 16
    }

    func show(with world: World) {
        guard isHidden else { return }
        isHidden = false

        let standings = world.standings
        let you = world.localPlayer?.team
        let place = standings.firstIndex { $0.team == you }

        if let place {
            headline.text = place == 0 ? "YOU WIN" : "\(ResultsNode.ordinal(place + 1)) PLACE"
            subhead.text = "\(standings[place].score) points"
        } else {
            headline.text = "TIME"
            subhead.text = ""
        }

        for (index, standing) in standings.enumerated() {
            let row = rows[index]
            row.score.text = "\(standing.score)"
            row.swatch.fillColor = RenderPalette.colour(for: standing.team)
            row.highlight.isHidden = standing.team != you
        }
    }

    private static func ordinal(_ n: Int) -> String {
        switch n {
        case 1: return "1ST"
        case 2: return "2ND"
        case 3: return "3RD"
        default: return "\(n)TH"
        }
    }
}
