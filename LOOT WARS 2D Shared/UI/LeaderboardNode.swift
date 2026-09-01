//
//  LeaderboardNode.swift
//  Loot Wars
//
//  Who is winning, in the top-right corner.
//
//  It shows four rows, not eight, and that is a fix rather than a compromise. Eight
//  rows at a readable size reach down into the item button - measured, 50 points of
//  overlap on a 15 and 68 on an SE - and the room between the top inset and that
//  button only fits three or four rows at any size you would want to read.
//
//  Four is also the more useful answer. What you want at a glance is who is winning
//  and where you stand, so the collapsed board is the top three plus your own row,
//  wherever you happen to be. Tap it for the full eight; it folds itself back up
//  after a few seconds so it can never sit over the button for long.
//
//  Its origin is its own top-RIGHT corner, mirroring the HUD's top-left, so
//  positioning it is an inset from the edge rather than arithmetic with its width.
//
//  Rows are rebuilt in place: eight nodes exist for the life of the match and only
//  their text, colour and position change. Tearing down and rebuilding eight rows
//  sixty times a second would be the most expensive thing on screen and the least
//  deserving of it.
//

import SpriteKit

final class LeaderboardNode: SKNode {

    private static let rowHeight: CGFloat = 17
    private static let padding: CGFloat = 8
    private static let width: CGFloat = 104
    private static let swatch: CGFloat = 10
    private static let chevronHeight: CGFloat = 12

    /// Rows shown when folded up: the leaders, and you.
    private static let collapsedRows = 4

    /// How long the full board stays open before folding itself away.
    private static let peekDuration: TimeInterval = 4

    static func height(expanded: Bool) -> CGFloat {
        let rows = expanded ? TeamID.count : collapsedRows
        return padding * 2 + rowHeight * CGFloat(rows) + chevronHeight
    }

    private struct Row {
        let holder: SKNode
        let highlight: SKShapeNode
        let swatch: SKShapeNode
        let rank: SKLabelNode
        let score: SKLabelNode
    }

    private let panel = SKShapeNode()
    private let chevron = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private var rows: [Row] = []
    private var lastDrawn: [Int] = []

    private(set) var isExpanded = false

    override init() {
        super.init()
        zPosition = 1000

        panel.fillColor = RenderPalette.hudPanel
        panel.strokeColor = .clear
        addChild(panel)

        for index in 0..<TeamID.count {
            rows.append(makeRow(at: index))
        }

        chevron.fontSize = 9
        chevron.fontColor = SKColor(white: 1, alpha: 0.5)
        chevron.horizontalAlignmentMode = .center
        chevron.verticalAlignmentMode = .center
        chevron.position = CGPoint(x: -LeaderboardNode.width / 2, y: 0)
        addChild(chevron)

        reshape()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func makeRow(at index: Int) -> Row {
        let holder = SKNode()
        addChild(holder)

        let width = LeaderboardNode.width
        let inset = LeaderboardNode.padding * 0.5

        let highlight = SKShapeNode(path: CGPath(
            roundedRect: CGRect(x: -width + inset, y: -LeaderboardNode.rowHeight / 2,
                                width: width - inset * 2, height: LeaderboardNode.rowHeight),
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
        rank.position = CGPoint(x: -width + LeaderboardNode.padding, y: 0)
        holder.addChild(rank)

        let side = LeaderboardNode.swatch
        let swatch = SKShapeNode(path: CGPath(
            roundedRect: CGRect(x: 0, y: -side / 2, width: side, height: side),
            cornerWidth: 3, cornerHeight: 3, transform: nil))
        swatch.strokeColor = .black
        swatch.lineWidth = 1.5
        swatch.position = CGPoint(x: -width + LeaderboardNode.padding + 16, y: 0)
        holder.addChild(swatch)

        let score = SKLabelNode(fontNamed: "AvenirNext-Bold")
        score.fontSize = 11
        score.fontColor = .white
        score.horizontalAlignmentMode = .right
        score.verticalAlignmentMode = .center
        score.position = CGPoint(x: -LeaderboardNode.padding, y: 0)
        holder.addChild(score)

        return Row(holder: holder, highlight: highlight, swatch: swatch,
                   rank: rank, score: score)
    }

    // MARK: - Folding

    /// Whether a touch landed on the board. Only meaningful in its own space.
    func contains(localPoint point: CGPoint) -> Bool {
        let height = LeaderboardNode.height(expanded: isExpanded)
        return point.x >= -LeaderboardNode.width && point.x <= 0
            && point.y <= 0 && point.y >= -height
    }

    func toggle() {
        isExpanded.toggle()
        lastDrawn = []          // the row set changed, so redraw whatever it holds
        reshape()

        removeAction(forKey: "peek")

        // Folds itself back up. The full board reaches over the item button on a
        // phone, so it is a glance rather than a mode - you cannot leave it open
        // and then wonder why healing is hard to reach.
        guard isExpanded else { return }
        run(.sequence([.wait(forDuration: LeaderboardNode.peekDuration),
                       .run { [weak self] in self?.collapse() }]), withKey: "peek")
    }

    func collapse() {
        guard isExpanded else { return }
        isExpanded = false
        lastDrawn = []
        reshape()
        removeAction(forKey: "peek")
    }

    private func reshape() {
        let height = LeaderboardNode.height(expanded: isExpanded)

        panel.path = CGPath(roundedRect: CGRect(x: -LeaderboardNode.width, y: -height,
                                                width: LeaderboardNode.width, height: height),
                            cornerWidth: 12, cornerHeight: 12, transform: nil)

        chevron.text = isExpanded ? "▲" : "▼"
        chevron.position = CGPoint(x: -LeaderboardNode.width / 2,
                                   y: -height + LeaderboardNode.chevronHeight / 2)
    }

    // MARK: - Drawing

    func update(with world: World) {
        let standings = world.standings
        let you = world.localPlayer?.team

        let shown = isExpanded
            ? Array(standings.indices)
            : LeaderboardNode.collapsedPlaces(in: standings, you: you)

        // Only redraw when the order, a number, or the fold actually changed.
        // Scores move a few times a minute; this runs sixty times a second.
        let fingerprint = shown.flatMap { [$0, standings[$0].team.raw, standings[$0].score] }
        guard fingerprint != lastDrawn else { return }
        lastDrawn = fingerprint

        for (slot, row) in rows.enumerated() {
            guard slot < shown.count else {
                row.holder.isHidden = true
                continue
            }

            let place = shown[slot]
            let standing = standings[place]
            let mine = standing.team == you

            row.holder.isHidden = false
            row.holder.position = CGPoint(
                x: 0,
                y: -LeaderboardNode.padding - LeaderboardNode.rowHeight * (CGFloat(slot) + 0.5))

            // The REAL place, not the row it happens to be sitting in - so a player
            // lying seventh still reads as seventh on a four-row board.
            row.rank.text = "\(place + 1)"
            row.score.text = "\(standing.score)"
            row.swatch.fillColor = RenderPalette.colour(for: standing.team)
            row.highlight.isHidden = !mine
            row.score.fontColor = SKColor(white: 1, alpha: mine ? 1.0 : 0.75)
        }
    }

    /// The leaders, plus you if you are not among them.
    private static func collapsedPlaces(in standings: [(team: TeamID, score: Int)],
                                        you: TeamID?) -> [Int] {
        let mine = standings.firstIndex { $0.team == you }

        // Already near the top: just show the top four, rather than the top three
        // and then your own row repeating one of them.
        guard let mine, mine >= collapsedRows - 1 else {
            return Array(0..<min(collapsedRows, standings.count))
        }

        return Array(0..<(collapsedRows - 1)) + [mine]
    }
}
