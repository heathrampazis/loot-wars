//
//  LeaderboardNode.swift
//  Loot Wars
//
//  Which teams are left, in the top-right corner, by COLOUR (Nov 2026, flags).
//
//  Every team gets a cell: its colour swatch, the colour's name, and a little
//  flag while it still has one to lose - faint before it goes up, white while
//  it stands, gone once it is taken. Teams that are out are greyed back. No
//  names, no points and no place
//  numbers: a match is won by being the last team in, and the board says who
//  is still in and who can still respawn. Heath: "show the teams left. use
//  colours instead of names".
//
//  Two columns of four, so all eight fit in the height the old five rows had.
//  Teams still in come first - flag standing, then flag gone - then the teams
//  that are out, last out first; your own cell is lit.
//
//  Its origin is its own top-RIGHT corner, mirroring the HUD's top-left, so
//  positioning it is an inset from the edge rather than arithmetic with its
//  width.
//

import SpriteKit

final class LeaderboardNode: SKNode {

    /// 158 -> 180 (Nov 2026): the longer colour names (PURPLE, ORANGE,
    /// YELLOW) ran into the flag mark at 158.
    private static let width: CGFloat = 180
    private static let rowHeight: CGFloat = 17
    private static let padding: CGFloat = 6
    private static let columns = 2
    private static let swatch: CGFloat = 10

    private static var rows: Int { (TeamID.count + columns - 1) / columns }
    private static var height: CGFloat { padding * 2 + rowHeight * CGFloat(rows) }
    private static var cellWidth: CGFloat { (width - padding * 2) / CGFloat(columns) }

    static var size: CGSize { CGSize(width: width, height: height) }

    private final class Cell {
        let holder = SKNode()
        let highlight: SKShapeNode
        let swatch: SKShapeNode
        let name = GameLabel(fontNamed: "AvenirNext-Bold")
        let flag = SKSpriteNode(texture: Glyphs.flag)
        let out = GameLabel(fontNamed: "AvenirNext-Bold")

        init() {
            let w = LeaderboardNode.cellWidth
            highlight = SKShapeNode(path: CGPath(
                roundedRect: CGRect(x: 0, y: -LeaderboardNode.rowHeight / 2 + 1,
                                    width: w - 2, height: LeaderboardNode.rowHeight - 2),
                cornerWidth: 5, cornerHeight: 5, transform: nil))
            highlight.fillColor = SKColor(white: 1, alpha: 0.16)
            highlight.strokeColor = .clear
            highlight.isHidden = true
            holder.addChild(highlight)

            let side = LeaderboardNode.swatch
            swatch = SKShapeNode(rect: CGRect(x: -side / 2, y: -side / 2, width: side, height: side),
                                 cornerRadius: 3)
            swatch.strokeColor = .black
            swatch.lineWidth = 1.5
            swatch.position = CGPoint(x: 4 + side / 2, y: 0)
            holder.addChild(swatch)

            name.fontSize = 10
            name.horizontalAlignmentMode = .left
            name.verticalAlignmentMode = .center
            name.position = CGPoint(x: 4 + side + 5, y: 0)
            holder.addChild(name)

            flag.size = CGSize(width: 11, height: 11)
            flag.colorBlendFactor = 1
            flag.position = CGPoint(x: w - 10, y: 0)
            holder.addChild(flag)

            out.fontSize = 8
            out.text = "OUT"
            out.fontColor = SKColor(white: 1, alpha: 0.45)
            out.horizontalAlignmentMode = .right
            out.verticalAlignmentMode = .center
            out.position = CGPoint(x: w - 4, y: 0)
            out.isHidden = true
            holder.addChild(out)
        }
    }

    private let panel = SKShapeNode()
    private var cells: [Cell] = []
    private var lastDrawn: [Int] = []

    override init() {
        super.init()
        // Over the edge markers (1040), which slide past it - see BaseCompassNode.
        zPosition = 1045

        let width = LeaderboardNode.width, height = LeaderboardNode.height
        panel.path = CGPath(roundedRect: CGRect(x: -width, y: -height, width: width, height: height),
                            cornerWidth: 12, cornerHeight: 12, transform: nil)
        panel.fillColor = RenderPalette.hudPanel
        panel.strokeColor = RenderPalette.glassRim
        panel.lineWidth = RenderPalette.glassRimWidth
        addChild(panel)
        if let path = panel.path { panel.addChild(GlassNode(path: path)) }

        for index in 0..<TeamID.count {
            let cell = Cell()
            let column = index % LeaderboardNode.columns
            let row = index / LeaderboardNode.columns
            cell.holder.position = CGPoint(
                x: -width + LeaderboardNode.padding + CGFloat(column) * LeaderboardNode.cellWidth,
                y: -LeaderboardNode.padding - LeaderboardNode.rowHeight * (CGFloat(row) + 0.5))
            addChild(cell.holder)
            cells.append(cell)
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(with world: World) {
        let standings = world.standings
        let you = world.localPlayer?.team

        // Only redrawn when the order, a flag or who is out changes.
        let fingerprint = standings.map { $0.team.raw }
            + standings.map { (world.hasFlag($0.team) ? 1 : 0) + (world.flagLost($0.team) ? 2 : 0) }
            + [you?.raw ?? -1, world.knockedOut.count]
        guard fingerprint != lastDrawn else { return }
        lastDrawn = fingerprint

        for (index, cell) in cells.enumerated() {
            guard index < standings.count else {
                cell.holder.isHidden = true
                continue
            }
            cell.holder.isHidden = false
            fill(cell, team: standings[index].team, world: world, you: you)
        }
    }

    private func fill(_ cell: Cell, team: TeamID, world: World, you: TeamID?) {
        let mine = team == you
        let out = world.isKnockedOut(team)
        // Faint while it has not gone up yet, white once it has, red once lost.
        let flagged = !world.flagLost(team)
        let raised = world.hasFlag(team)

        cell.highlight.isHidden = !mine
        cell.swatch.fillColor = RenderPalette.vibrantColour(for: team)
        // Out: the whole cell greyed back, no OUT label (Nov 2026).
        cell.swatch.alpha = out ? 0.3 : 1

        cell.name.text = mine ? "YOU" : RenderPalette.colourName(for: team)
        cell.name.fontColor = SKColor(white: 1, alpha: out ? 0.3 : (mine ? 1 : 0.85))

        // The flag mark only while they still have one to lose: faint before it
        // goes up, white while it stands, and simply gone once it is taken.
        cell.flag.isHidden = out || !flagged
        cell.flag.color = .white
        cell.flag.alpha = raised ? 0.9 : 0.3
        cell.out.isHidden = true
    }
}
