//
//  LeaderboardNode.swift
//  Loot Wars
//
//  Who is winning, in the top-right corner.
//
//  Its origin is its own top-RIGHT corner, mirroring the HUD's top-left, so
//  positioning it is an inset from the edge rather than arithmetic with its width.
//
//  Rows are rebuilt in place rather than recreated: eight nodes exist for the life
//  of the match and only their text, colour and position change. A leaderboard that
//  tore down and rebuilt eight rows every frame would be the most expensive thing
//  on screen and the least deserving of it.
//

import SpriteKit

final class LeaderboardNode: SKNode {

    private static let rowHeight: CGFloat = 19
    private static let padding: CGFloat = 10
    private static let width: CGFloat = 104
    private static let swatch: CGFloat = 11

    static var size: CGSize {
        CGSize(width: width,
               height: padding * 2 + rowHeight * CGFloat(TeamID.count))
    }

    private struct Row {
        let holder: SKNode
        let highlight: SKShapeNode
        let swatch: SKShapeNode
        let rank: SKLabelNode
        let score: SKLabelNode
    }

    private var rows: [Row] = []
    private var lastStandings: [Int] = []

    override init() {
        super.init()
        zPosition = 1000

        let size = LeaderboardNode.size
        let panel = SKShapeNode(path: CGPath(
            roundedRect: CGRect(x: -size.width, y: -size.height,
                                width: size.width, height: size.height),
            cornerWidth: 12, cornerHeight: 12, transform: nil))
        panel.fillColor = RenderPalette.hudPanel
        panel.strokeColor = .clear
        addChild(panel)

        for index in 0..<TeamID.count {
            rows.append(makeRow(at: index))
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func makeRow(at index: Int) -> Row {
        let holder = SKNode()
        holder.position = CGPoint(
            x: 0,
            y: -LeaderboardNode.padding - LeaderboardNode.rowHeight * (CGFloat(index) + 0.5))
        addChild(holder)

        let width = LeaderboardNode.width
        let inset = LeaderboardNode.padding * 0.4

        // Sits behind the row and marks which one is you. Hidden for everybody else.
        let highlight = SKShapeNode(path: CGPath(
            roundedRect: CGRect(x: -width + inset, y: -LeaderboardNode.rowHeight / 2,
                                width: width - inset * 2, height: LeaderboardNode.rowHeight),
            cornerWidth: 5, cornerHeight: 5, transform: nil))
        highlight.fillColor = SKColor(white: 1, alpha: 0.16)
        highlight.strokeColor = .clear
        highlight.isHidden = true
        holder.addChild(highlight)

        let rank = SKLabelNode(fontNamed: "AvenirNext-Bold")
        rank.fontSize = 11
        rank.fontColor = SKColor(white: 1, alpha: 0.55)
        rank.horizontalAlignmentMode = .left
        rank.verticalAlignmentMode = .center
        rank.position = CGPoint(x: -width + LeaderboardNode.padding, y: 0)
        holder.addChild(rank)

        let side = LeaderboardNode.swatch
        let swatch = SKShapeNode(path: CGPath(
            roundedRect: CGRect(x: 0, y: -side / 2, width: side, height: side),
            cornerWidth: 3, cornerHeight: 3, transform: nil))
        swatch.strokeColor = .black
        swatch.lineWidth = 1.5
        swatch.position = CGPoint(x: -width + LeaderboardNode.padding + 15, y: 0)
        holder.addChild(swatch)

        let score = SKLabelNode(fontNamed: "AvenirNext-Bold")
        score.fontSize = 12
        score.fontColor = .white
        score.horizontalAlignmentMode = .right
        score.verticalAlignmentMode = .center
        score.position = CGPoint(x: -LeaderboardNode.padding, y: 0)
        holder.addChild(score)

        return Row(holder: holder, highlight: highlight, swatch: swatch,
                   rank: rank, score: score)
    }

    func update(with world: World) {
        let standings = world.standings

        // Only redraw when the order or a number actually changed. Scores move a few
        // times a minute; this runs sixty times a second.
        let fingerprint = standings.flatMap { [$0.team.raw, $0.score] }
        guard fingerprint != lastStandings else { return }
        lastStandings = fingerprint

        let you = world.localPlayer?.team

        for (place, standing) in standings.enumerated() {
            let row = rows[place]
            row.rank.text = "\(place + 1)"
            row.score.text = "\(standing.score)"
            row.swatch.fillColor = RenderPalette.colour(for: standing.team)
            row.highlight.isHidden = standing.team != you

            // Your own row reads at full strength; everybody else's sits back a
            // little, so you can find yourself without hunting for the colour.
            let mine = standing.team == you
            row.score.fontColor = SKColor(white: 1, alpha: mine ? 1.0 : 0.75)
        }
    }
}
