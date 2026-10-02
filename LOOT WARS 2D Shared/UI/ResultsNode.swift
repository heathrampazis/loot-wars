//
//  ResultsNode.swift
//  Loot Wars
//
//  The end of the match: where you came, what everybody scored, and a way back in.
//
//  Headed by YOUR placing rather than by naming a winner, because teams have colours
//  and no names - and the thing you actually want to know is where you came.
//
//  Dressed like the title screen rather than like the in-match interface: the same
//  near-white card and the same chunky buttons as the menu sheets, because this is
//  the moment the game stops being a match and starts being a menu again. The map
//  stays visible behind a dark veil, since the world has genuinely stopped.
//
//  It arrives in a short sequence rather than all at once: the card rises, your
//  medal pops, your score counts up, the table fills in with each team's bar
//  growing to its score. A win gets a shower of gold; a new personal best gets a
//  tag under the score.
//

import SpriteKit
import UIKit

final class ResultsNode: SKNode {

    private static let cardSize = CGSize(width: 360, height: 296)
    private static let rowHeight: CGFloat = 24
    private static let columnWidth: CGFloat = 152
    private static let columnGap: CGFloat = 16

    private let scrim = SKShapeNode()
    private let card = SKShapeNode()
    private let medal = SKNode()
    private let medalDisc = SKShapeNode(circleOfRadius: 30)
    private let medalNumber = SKLabelNode()
    private let headline = SKLabelNode()
    private let points = SKLabelNode()
    private let best = SKNode()
    private let again: MenuButtonNode
    private let menu: MenuButtonNode

    private struct Row {
        let node: SKNode
        let highlight: SKShapeNode
        let rank: SKLabelNode
        let swatch: SKShapeNode
        let bar: SKShapeNode
        let score: SKLabelNode
    }
    private var rows: [Row] = []

    /// Once a button has been pressed nothing else on here answers, so a second
    /// tap during the press cannot start a second scene change.
    private var pressed = false

    override init() {
        again = MenuButtonNode(play: 168, height: 52, tone: RenderPalette.menuPlay)
        menu = MenuButtonNode(glyph: Glyphs.home, side: 52, tone: RenderPalette.menuInfo)

        super.init()
        zPosition = 1500
        isHidden = true

        scrim.fillColor = SKColor(white: 0, alpha: 0.6)
        scrim.strokeColor = .clear
        addChild(scrim)

        let size = ResultsNode.cardSize
        card.path = CGPath(roundedRect: CGRect(x: -size.width / 2, y: -size.height / 2,
                                               width: size.width, height: size.height),
                           cornerWidth: 22, cornerHeight: 22, transform: nil)
        card.fillColor = SKColor(white: 0.99, alpha: 1)
        card.strokeColor = SKColor(white: 0.78, alpha: 1)
        card.lineWidth = 3
        addChild(card)

        buildHeader(in: size)
        buildRows(in: size)
        buildButtons(in: size)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Building

    private func buildHeader(in size: CGSize) {
        // The medal sits on the card's top edge, half over it, like a rosette
        // pinned to the card.
        medal.position = CGPoint(x: 0, y: size.height / 2)
        medal.zPosition = 3
        card.addChild(medal)

        medalDisc.lineWidth = 4
        medal.addChild(medalDisc)

        medalNumber.verticalAlignmentMode = .center
        medalNumber.horizontalAlignmentMode = .center
        medalNumber.zPosition = 1
        medal.addChild(medalNumber)

        headline.verticalAlignmentMode = .center
        headline.position = CGPoint(x: 0, y: size.height / 2 - 52)
        headline.zPosition = 2
        card.addChild(headline)

        points.verticalAlignmentMode = .center
        points.position = CGPoint(x: 0, y: size.height / 2 - 78)
        points.zPosition = 2
        card.addChild(points)

        // NEW BEST, a small green tag beside the points. Built once, shown when
        // earned.
        let tag = SKShapeNode(path: CGPath(roundedRect: CGRect(x: -38, y: -10, width: 76, height: 20),
                                           cornerWidth: 10, cornerHeight: 10, transform: nil))
        tag.fillColor = RenderPalette.menuPlay.face
        tag.strokeColor = RenderPalette.menuPlay.edge
        tag.lineWidth = 2
        best.addChild(tag)

        let word = SKLabelNode()
        word.attributedText = MenuButtonNode.text("NEW BEST", size: 11, weight: .heavy, colour: .white)
        word.verticalAlignmentMode = .center
        word.zPosition = 1
        best.addChild(word)

        best.zPosition = 2
        best.isHidden = true
        card.addChild(best)
    }

    private func buildRows(in size: CGSize) {
        // Two columns of four, the same shape as the in-match board, so the final
        // table reads like the one you were watching all game.
        let width = ResultsNode.columnWidth
        let gap = ResultsNode.columnGap
        let top = size.height / 2 - 104
        let perColumn = TeamID.count / 2

        for place in 0..<TeamID.count {
            let column = place / perColumn
            let index = place % perColumn

            let left = -width - gap / 2 + CGFloat(column) * (width + gap)
            let y = top - ResultsNode.rowHeight * (CGFloat(index) + 0.5)

            let node = SKNode()
            node.position = CGPoint(x: left, y: y)
            node.zPosition = 2
            card.addChild(node)

            let height = ResultsNode.rowHeight - 4
            let highlight = SKShapeNode(path: CGPath(
                roundedRect: CGRect(x: -4, y: -height / 2, width: width + 8, height: height),
                cornerWidth: 7, cornerHeight: 7, transform: nil))
            highlight.fillColor = SKColor(white: 0.9, alpha: 1)
            highlight.strokeColor = .clear
            highlight.isHidden = true
            node.addChild(highlight)

            let rank = SKLabelNode()
            rank.horizontalAlignmentMode = .center
            rank.verticalAlignmentMode = .center
            rank.position = CGPoint(x: 8, y: 0)
            rank.zPosition = 1
            node.addChild(rank)

            let side: CGFloat = 12
            let swatch = SKShapeNode(path: CGPath(
                roundedRect: CGRect(x: -side / 2, y: -side / 2, width: side, height: side),
                cornerWidth: 3, cornerHeight: 3, transform: nil))
            swatch.position = CGPoint(x: 28, y: 0)
            swatch.lineWidth = 2
            swatch.zPosition = 1
            node.addChild(swatch)

            // The bar: a track the full width, and a fill that grows to the score.
            let barLeft: CGFloat = 42
            let barWidth = width - barLeft - 40
            let track = SKShapeNode(path: CGPath(
                roundedRect: CGRect(x: barLeft, y: -4, width: barWidth, height: 8),
                cornerWidth: 4, cornerHeight: 4, transform: nil))
            track.fillColor = SKColor(white: 0.86, alpha: 1)
            track.strokeColor = .clear
            track.zPosition = 1
            node.addChild(track)

            let bar = SKShapeNode()
            bar.strokeColor = .clear
            bar.zPosition = 2
            bar.userData = ["left": barLeft, "width": barWidth]
            node.addChild(bar)

            let score = SKLabelNode()
            score.horizontalAlignmentMode = .right
            score.verticalAlignmentMode = .center
            score.position = CGPoint(x: width, y: 0)
            score.zPosition = 1
            node.addChild(score)

            rows.append(Row(node: node, highlight: highlight, rank: rank,
                            swatch: swatch, bar: bar, score: score))
        }
    }

    private func buildButtons(in size: CGSize) {
        // Play again the big one, home the small one beside it: almost everybody
        // who finishes a match wants another.
        let gap: CGFloat = 16
        let span = again.box.width + gap + menu.box.width
        let y = -size.height / 2 + 42

        again.position = CGPoint(x: -span / 2 + again.box.width / 2, y: y)
        again.zPosition = 2
        card.addChild(again)

        menu.position = CGPoint(x: span / 2 - menu.box.width / 2, y: y)
        menu.zPosition = 2
        card.addChild(menu)
    }

    // MARK: - Layout and taps

    /// The veil covers the screen, and the card shrinks to fit a short one.
    func layOut(for screen: CGSize) {
        scrim.path = CGPath(rect: CGRect(x: -screen.width / 2, y: -screen.height / 2,
                                         width: screen.width, height: screen.height),
                            transform: nil)

        // Room for the medal poking out of the top, and a margin all round.
        let needed = ResultsNode.cardSize.height + 30 + 24
        card.setScale(min(1, screen.height / needed))
        card.position = CGPoint(x: 0, y: -12 * card.yScale)
    }

    func isPlayAgain(atLocalPoint point: CGPoint) -> Bool {
        !pressed && again.contains(localPoint: convert(point, to: again))
    }

    func isMenu(atLocalPoint point: CGPoint) -> Bool {
        !pressed && menu.contains(localPoint: convert(point, to: menu))
    }

    /// Plays the button's press, then does the thing.
    func pressPlayAgain(then done: @escaping () -> Void) {
        pressed = true
        again.press(then: done)
    }

    func pressMenu(then done: @escaping () -> Void) {
        pressed = true
        menu.press(then: done)
    }

    // MARK: - Showing

    func show(with world: World) {
        guard isHidden else { return }
        isHidden = false
        pressed = false

        let standings = world.standings
        let you = world.localPlayer?.team
        let place = standings.firstIndex { $0.team == you }
        let yourScore = place.map { standings[$0].score } ?? 0
        let top = max(1, standings.first?.score ?? 1)

        // Read before Prefs records this match, so "better than ever before".
        let newBest = place != nil && yourScore > Prefs.bestScore && yourScore > 0

        // MARK: Header

        if let place {
            headline.attributedText = ResultsNode.ink(place == 0 ? "VICTORY!" : "\(ResultsNode.ordinal(place + 1)) PLACE",
                                                      size: 26, weight: .heavy)
            medalDisc.fillColor = ResultsNode.medalColour(for: place, team: you)
            medalDisc.strokeColor = ResultsNode.darker(medalDisc.fillColor)
            medalNumber.attributedText = MenuButtonNode.text("\(place + 1)", size: 26,
                                                             weight: .heavy, colour: .white)
        } else {
            headline.attributedText = ResultsNode.ink("TIME", size: 26, weight: .heavy)
            medal.isHidden = true
        }
        setPoints(0)

        // MARK: Table

        for (index, standing) in standings.enumerated() where index < rows.count {
            let row = rows[index]
            let mine = standing.team == you
            let colour = RenderPalette.vibrantColour(for: standing.team)

            row.rank.attributedText = ResultsNode.ink("\(index + 1)", size: 12, weight: .bold,
                                                      faint: !mine)
            row.score.attributedText = ResultsNode.ink("\(standing.score)", size: 13,
                                                       weight: mine ? .heavy : .bold)
            row.swatch.fillColor = colour
            row.swatch.strokeColor = ResultsNode.darker(colour)
            row.bar.fillColor = colour
            row.highlight.isHidden = !mine
            setBar(row.bar, share: 0)
            row.bar.userData?["share"] = CGFloat(standing.score) / CGFloat(top)
        }

        // MARK: Entrance

        scrim.alpha = 0
        scrim.run(.fadeIn(withDuration: 0.25))

        let rest = card.position
        card.alpha = 0
        card.position = CGPoint(x: rest.x, y: rest.y - 40)
        let rise = SKAction.move(to: rest, duration: 0.32)
        rise.timingMode = .easeOut
        card.run(.group([rise, .fadeIn(withDuration: 0.2)]))

        medal.setScale(0)
        medal.run(.sequence([
            .wait(forDuration: 0.28),
            .scale(to: 1.25, duration: 0.14),
            .scale(to: 1, duration: 0.12),
            .run { [weak self] in
                guard let self, place == 0 else { return }
                self.shower(from: self.medal)
            }
        ]))

        // The score counts up.
        let countTime = 0.8
        run(.sequence([
            .wait(forDuration: 0.4),
            .customAction(withDuration: countTime) { [weak self] _, elapsed in
                let share = min(1, elapsed / CGFloat(countTime))
                let eased = 1 - (1 - share) * (1 - share)
                self?.setPoints(Int((CGFloat(yourScore) * eased).rounded()))
            },
            .run { [weak self] in
                self?.setPoints(yourScore)
                if newBest { self?.revealBest() }
            }
        ]), withKey: "count")

        // The table fills in a row at a time, each bar growing to its score.
        for (index, row) in rows.enumerated() {
            row.node.alpha = 0
            let share = row.bar.userData?["share"] as? CGFloat ?? 0
            row.node.run(.sequence([
                .wait(forDuration: 0.45 + Double(index) * 0.05),
                .fadeIn(withDuration: 0.15),
                .customAction(withDuration: 0.5) { [weak self] _, elapsed in
                    let t = min(1, elapsed / 0.5)
                    let eased = 1 - (1 - t) * (1 - t)
                    self?.setBar(row.bar, share: share * eased)
                }
            ]))
        }

        for button in [again, menu] {
            button.alpha = 0
            button.run(.sequence([.wait(forDuration: 0.9), .fadeIn(withDuration: 0.2)]))
        }
    }

    // MARK: - Pieces

    private func setPoints(_ value: Int) {
        points.attributedText = ResultsNode.ink("\(value) POINTS", size: 15, weight: .bold, faint: true)
        best.position = CGPoint(x: points.frame.maxX + 46, y: points.position.y)
    }

    private func revealBest() {
        best.isHidden = false
        best.setScale(0)
        best.run(.sequence([.scale(to: 1.2, duration: 0.12), .scale(to: 1, duration: 0.1)]))
    }

    private func setBar(_ bar: SKShapeNode, share: CGFloat) {
        guard let left = bar.userData?["left"] as? CGFloat,
              let width = bar.userData?["width"] as? CGFloat else { return }
        let filled = max(8, width * max(0, min(1, share)))
        bar.path = CGPath(roundedRect: CGRect(x: left, y: -4, width: filled, height: 8),
                          cornerWidth: 4, cornerHeight: 4, transform: nil)
    }

    /// Gold stars out of the medal, for a win.
    private func shower(from origin: SKNode) {
        let centre = convert(CGPoint.zero, from: origin)
        for index in 0..<16 {
            let star = SKSpriteNode(texture: ImpactArt.star)
            let side = CGFloat.random(in: 12...20)
            star.size = CGSize(width: side, height: side)
            star.color = RenderPalette.treasure
            star.colorBlendFactor = 0.6
            star.position = centre
            star.zPosition = 10
            star.setScale(0.4)
            addChild(star)

            let angle = CGFloat(index) / 16 * .pi * 2 + CGFloat.random(in: -0.2...0.2)
            let reach = CGFloat.random(in: 60...110)
            let out = SKAction.moveBy(x: cos(angle) * reach, y: sin(angle) * reach * 0.7 + 20,
                                      duration: 0.6)
            out.timingMode = .easeOut

            star.run(.sequence([
                .group([out,
                        .rotate(byAngle: CGFloat.random(in: -3...3), duration: 0.6),
                        .sequence([.scale(to: 1.1, duration: 0.15),
                                   .wait(forDuration: 0.15),
                                   .group([.scale(to: 0.3, duration: 0.3),
                                           .fadeOut(withDuration: 0.3)])])]),
                .removeFromParent()
            ]))
        }
    }

    // MARK: - Helpers

    /// Gold, silver and bronze for the podium; your own colour otherwise.
    private static func medalColour(for place: Int, team: TeamID?) -> SKColor {
        switch place {
        case 0: return SKColor(red: 1.0, green: 0.75, blue: 0.10, alpha: 1)
        case 1: return SKColor(red: 0.64, green: 0.68, blue: 0.72, alpha: 1)
        case 2: return SKColor(red: 0.80, green: 0.50, blue: 0.24, alpha: 1)
        default: return team.map { RenderPalette.vibrantColour(for: $0) } ?? .gray
        }
    }

    /// The same colour, darker - for an edge, the way the menu buttons are edged.
    private static func darker(_ colour: SKColor?) -> SKColor {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        (colour ?? .gray).getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return SKColor(red: red * 0.78, green: green * 0.78, blue: blue * 0.78, alpha: alpha)
    }

    private static func ink(_ text: String, size: CGFloat, weight: UIFont.Weight,
                            faint: Bool = false) -> NSAttributedString {
        MenuButtonNode.text(text, size: size, weight: weight,
                            colour: faint ? SKColor(white: 0.45, alpha: 1) : RenderPalette.menuInk)
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
