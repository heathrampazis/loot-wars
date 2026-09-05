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
    private let menu = SKNode()
    private var rows: [(swatch: SKShapeNode, rank: SKLabelNode, score: SKLabelNode, highlight: SKShapeNode)] = []

    private static let againSize = CGSize(width: 156, height: 42)

    /// Smaller than PLAY AGAIN, and beside it rather than under it.
    ///
    /// The two are not equals. Almost everybody who finishes a match wants another
    /// one, so that stays the big pink pill and this is the quiet way out - a menu
    /// button the same size as the thing it competes with would make the common
    /// answer harder to hit for the sake of the rare one.
    private static let menuSize = CGSize(width: 96, height: 42)
    /// Wide enough that the two hit boxes do not overlap: PLAY AGAIN is generous
    /// on every side because it is the answer almost everybody wants, and a
    /// generous target that reaches into its neighbour is how somebody ends up
    /// back at a title screen they did not ask for.
    private static let buttonGap: CGFloat = 20

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
        let menuBox = ResultsNode.menuSize

        // The pair is centred as a group, so neither sits under the standings by
        // accident when one of them changes width.
        let span = box.width + ResultsNode.buttonGap + menuBox.width
        let bottom = -size.height / 2 + 34

        again.position = CGPoint(x: -span / 2 + box.width / 2, y: bottom)

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

        menu.position = CGPoint(x: span / 2 - menuBox.width / 2, y: bottom)

        let menuPill = SKShapeNode(path: CGPath(
            roundedRect: CGRect(x: -menuBox.width / 2, y: -menuBox.height / 2,
                                width: menuBox.width, height: menuBox.height),
            cornerWidth: menuBox.height / 2, cornerHeight: menuBox.height / 2,
            transform: nil))

        // Dark rather than coloured: on this panel, colour means "press this", and
        // there is only one thing here anybody presses twice.
        menuPill.fillColor = SKColor(white: 0, alpha: 0.35)
        menuPill.strokeColor = .black
        menuPill.lineWidth = 3
        menu.addChild(menuPill)

        let menuLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
        menuLabel.text = "MENU"
        menuLabel.fontSize = 15
        menuLabel.fontColor = SKColor(white: 1, alpha: 0.85)
        menuLabel.verticalAlignmentMode = .center
        menu.addChild(menuLabel)

        addChild(menu)
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
        // Grown a little, because it is the way out most people want.
        return abs(local.x) <= box.width / 2 + 14 && abs(local.y) <= box.height / 2 + 16
    }

    func isMenu(atLocalPoint point: CGPoint) -> Bool {
        let box = ResultsNode.menuSize
        let local = CGPoint(x: point.x - menu.position.x, y: point.y - menu.position.y)

        // A tighter margin than PLAY AGAIN's, and deliberately: the two hit boxes
        // are neighbours, and the one that must not be hit by accident is the one
        // that throws away the match you have just finished reading about.
        return abs(local.x) <= box.width / 2 + 6 && abs(local.y) <= box.height / 2 + 12
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
