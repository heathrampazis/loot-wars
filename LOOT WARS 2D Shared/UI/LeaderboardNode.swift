//
//  LeaderboardNode.swift
//  Loot Wars
//
//  Who is winning, in the top-right corner. All eight, always.
//
//  Two columns of four rather than one column of eight, and that is what makes the
//  whole thing simple. The problem was only ever VERTICAL - eight rows reached 50
//  points over the item button on a 15 and 68 on an SE - while the top-right corner
//  has width going spare. Turned on its side it is 84 points tall instead of 164,
//  which is shorter than the four-row board it replaces and shows twice as much.
//
//  So there is no folding, no chevron, no timer, and no rank list that jumps from
//  3 to 7 with nothing to explain the gap. Places 1 to 4 run down the left, 5 to 8
//  down the right.
//
//  Its origin is its own top-RIGHT corner, mirroring the HUD's top-left, so
//  positioning it is an inset from the edge rather than arithmetic with its width.
//
//  Rows are rebuilt in place: eight nodes exist for the life of the match and only
//  their text and colour change. Tearing down and rebuilding them sixty times a
//  second would be the most expensive thing on screen and the least deserving of it.
//

import SpriteKit

final class LeaderboardNode: SKNode {

    private static let rowHeight: CGFloat = 17
    private static let padding: CGFloat = 8
    private static let columnWidth: CGFloat = 84
    private static let columnGap: CGFloat = 8
    private static let swatch: CGFloat = 10

    private static let rowsPerColumn = TeamID.count / 2

    static var size: CGSize {
        CGSize(width: padding * 2 + columnWidth * 2 + columnGap,
               height: padding * 2 + rowHeight * CGFloat(rowsPerColumn))
    }

    private struct Row {
        let highlight: SKShapeNode
        let swatch: SKShapeNode
        let rank: SKLabelNode
        let score: SKLabelNode
    }

    private var rows: [Row] = []
    private var lastDrawn: [Int] = []

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

        // Fixed positions, assigned once. A place never moves between cells, so
        // only what is written in them ever has to change.
        for place in 0..<TeamID.count {
            rows.append(makeRow(at: place))
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func makeRow(at place: Int) -> Row {
        let column = place / LeaderboardNode.rowsPerColumn
        let indexInColumn = place % LeaderboardNode.rowsPerColumn

        // Measured from the right edge, which is this node's origin, so the right
        // hand column is the one nearest x = 0.
        let columnRight = -LeaderboardNode.padding
            - (1 - CGFloat(column)) * (LeaderboardNode.columnWidth + LeaderboardNode.columnGap)
        let columnLeft = columnRight - LeaderboardNode.columnWidth

        let holder = SKNode()
        holder.position = CGPoint(
            x: 0,
            y: -LeaderboardNode.padding
                - LeaderboardNode.rowHeight * (CGFloat(indexInColumn) + 0.5))
        addChild(holder)

        let highlight = SKShapeNode(path: CGPath(
            roundedRect: CGRect(x: columnLeft, y: -LeaderboardNode.rowHeight / 2,
                                width: LeaderboardNode.columnWidth,
                                height: LeaderboardNode.rowHeight),
            cornerWidth: 5, cornerHeight: 5, transform: nil))
        highlight.fillColor = SKColor(white: 1, alpha: 0.16)
        highlight.strokeColor = .clear
        highlight.isHidden = true
        holder.addChild(highlight)

        let rank = SKLabelNode(fontNamed: "AvenirNext-Bold")
        rank.fontSize = 10
        rank.fontColor = SKColor(white: 1, alpha: 0.55)
        rank.horizontalAlignmentMode = .left
        rank.verticalAlignmentMode = .center
        rank.position = CGPoint(x: columnLeft + 6, y: 0)
        rank.text = "\(place + 1)"        // a cell's place never changes
        holder.addChild(rank)

        let side = LeaderboardNode.swatch
        let swatch = SKShapeNode(path: CGPath(
            roundedRect: CGRect(x: 0, y: -side / 2, width: side, height: side),
            cornerWidth: 3, cornerHeight: 3, transform: nil))
        swatch.strokeColor = .black
        swatch.lineWidth = 1.5
        swatch.position = CGPoint(x: columnLeft + 18, y: 0)
        holder.addChild(swatch)

        let score = SKLabelNode(fontNamed: "AvenirNext-Bold")
        score.fontSize = 11
        score.fontColor = .white
        score.horizontalAlignmentMode = .right
        score.verticalAlignmentMode = .center
        score.position = CGPoint(x: columnRight - 6, y: 0)
        holder.addChild(score)

        return Row(highlight: highlight, swatch: swatch, rank: rank, score: score)
    }

    func update(with world: World) {
        let standings = world.standings
        let you = world.localPlayer?.team

        // Only redraw when the order or a number actually changed. Scores move a few
        // times a minute; this runs sixty times a second.
        let fingerprint = standings.flatMap { [$0.team.raw, $0.score] }
        guard fingerprint != lastDrawn else { return }
        lastDrawn = fingerprint

        for (place, standing) in standings.enumerated() {
            let row = rows[place]
            let mine = standing.team == you

            row.score.text = "\(standing.score)"
            row.swatch.fillColor = RenderPalette.colour(for: standing.team)
            row.highlight.isHidden = !mine

            // Your own row at full strength, everybody else's set back a little, so
            // you can find yourself without hunting for a colour.
            row.score.fontColor = SKColor(white: 1, alpha: mine ? 1.0 : 0.75)
        }
    }
}
