//
//  ResultsNode.swift
//  Loot Wars
//
//  The end of the match, about you: where you came, your score, your level, and
//  how your match went - fights, loot and money. Nobody else's numbers.
//
//  Dressed like the title screen rather than like the in-match interface: the same
//  near-white card and the same chunky buttons as the menu sheets, because this is
//  the moment the game stops being a match and starts being a menu again. The map
//  stays visible behind a dark veil, since the world has genuinely stopped.
//
//  It arrives in a short sequence: the card rises, a trophy pops for a top three
//  finish with a burst of confetti, your score counts up, then your stats fill in
//  one at a time. A new personal best gets a tag beside the score.
//

import SpriteKit
import UIKit

final class ResultsNode: SKNode {

    private static let cardWidth: CGFloat = 360
    private static let tileSize = CGSize(width: 104, height: 50)
    private static let tilesPerRow = 3
    private static let tileGap: CGFloat = 8
    private static let trophySide: CGFloat = 64

    private let scrim = SKShapeNode()
    private let card = SKShapeNode()
    private let trophy = SKSpriteNode()
    private let headline = SKLabelNode()
    private let points = SKLabelNode()
    private let best = SKNode()

    /// The card's height for this result: taller with a trophy on it.
    private var cardHeight: CGFloat = 300

    // Your level: the number, the bar filling with this match's XP, and how much.
    private let levelRow = SKNode()
    private let levelLabel = SKLabelNode()
    private let xpFill = SKShapeNode()
    private let xpGained = SKLabelNode()
    private static let xpBarWidth: CGFloat = 196

    /// Your match in six numbers, two rows of three.
    private let statsGrid = SKNode()
    private var tiles: [SKNode] = []

    /// The card that says what a level-up unlocked, beside the results.
    private let unlockCard = SKNode()
    private var screen: CGSize = .zero
    private let again: MenuButtonNode
    private let menu: MenuButtonNode

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

        card.fillColor = SKColor(white: 0.99, alpha: 1)
        card.strokeColor = SKColor(white: 0.78, alpha: 1)
        card.lineWidth = 3
        addChild(card)

        trophy.zPosition = 3
        card.addChild(trophy)

        headline.verticalAlignmentMode = .center
        headline.zPosition = 2
        card.addChild(headline)

        points.verticalAlignmentMode = .center
        points.zPosition = 2
        card.addChild(points)

        buildBest()
        buildLevel()

        statsGrid.zPosition = 2
        card.addChild(statsGrid)

        for button in [again, menu] {
            button.zPosition = 2
            card.addChild(button)
        }

        unlockCard.zPosition = 5
        addChild(unlockCard)

        arrange(podium: false)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Building

    /// NEW BEST, a small green tag beside the points. Built once, shown when earned.
    private func buildBest() {
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

    /// LEVEL 7, a bar, +245 XP - one row under your score.
    private func buildLevel() {
        let width = ResultsNode.xpBarWidth
        levelRow.zPosition = 2
        card.addChild(levelRow)

        levelLabel.horizontalAlignmentMode = .right
        levelLabel.verticalAlignmentMode = .center
        levelLabel.position = CGPoint(x: -width / 2 - 10, y: 0)
        levelRow.addChild(levelLabel)

        let track = SKShapeNode(path: CGPath(
            roundedRect: CGRect(x: -width / 2, y: -6, width: width, height: 12),
            cornerWidth: 6, cornerHeight: 6, transform: nil))
        track.fillColor = SKColor(white: 0.86, alpha: 1)
        track.strokeColor = .clear
        levelRow.addChild(track)

        xpFill.fillColor = RenderPalette.menuPlay.face
        xpFill.strokeColor = .clear
        xpFill.position = CGPoint(x: -width / 2, y: 0)
        xpFill.zPosition = 1
        levelRow.addChild(xpFill)

        xpGained.horizontalAlignmentMode = .left
        xpGained.verticalAlignmentMode = .center
        xpGained.position = CGPoint(x: width / 2 + 10, y: 0)
        levelRow.addChild(xpGained)
    }

    private func setXPBar(_ share: CGFloat) {
        let width = ResultsNode.xpBarWidth * max(0, min(1, share))
        xpFill.path = CGPath(roundedRect: CGRect(x: 0, y: -6, width: max(12, width), height: 12),
                             cornerWidth: 6, cornerHeight: 6, transform: nil)
        xpFill.isHidden = share <= 0
    }

    private func setLevel(_ level: Int) {
        levelLabel.attributedText = ResultsNode.ink("LEVEL \(level)", size: 13, weight: .heavy)
    }

    /// Places everything down the card, top to bottom, and sizes the card to fit.
    /// The trophy only takes room when there is one.
    private func arrange(podium: Bool) {
        let tile = ResultsNode.tileSize
        let gap = ResultsNode.tileGap
        let gridHeight = tile.height * 2 + gap

        // Distances down from the card's top edge.
        let headlineDown: CGFloat = podium ? 96 : 38
        let pointsDown = headlineDown + 25
        let levelDown = pointsDown + 29
        let gridTopDown = levelDown + 22
        let buttonDown = gridTopDown + gridHeight + 16 + 26
        cardHeight = buttonDown + 26 + 18

        let top = cardHeight / 2
        let width = ResultsNode.cardWidth
        card.path = CGPath(roundedRect: CGRect(x: -width / 2, y: -top, width: width, height: cardHeight),
                           cornerWidth: 22, cornerHeight: 22, transform: nil)

        trophy.position = CGPoint(x: 0, y: top - 18 - ResultsNode.trophySide / 2)
        headline.position = CGPoint(x: 0, y: top - headlineDown)
        points.position = CGPoint(x: 0, y: top - pointsDown)
        levelRow.position = CGPoint(x: 0, y: top - levelDown)
        statsGrid.position = CGPoint(x: 0, y: top - gridTopDown)

        let span = again.box.width + 16 + menu.box.width
        again.position = CGPoint(x: -span / 2 + again.box.width / 2, y: top - buttonDown)
        menu.position = CGPoint(x: span / 2 - menu.box.width / 2, y: top - buttonDown)

        fit()
    }

    /// One stat: the number big, what it is small underneath, on a soft tile.
    private func makeTile(value: String, label: String) -> SKNode {
        let size = ResultsNode.tileSize
        let node = SKNode()

        let plate = SKShapeNode(path: CGPath(
            roundedRect: CGRect(x: -size.width / 2, y: -size.height / 2,
                                width: size.width, height: size.height),
            cornerWidth: 12, cornerHeight: 12, transform: nil))
        plate.fillColor = SKColor(white: 0.93, alpha: 1)
        plate.strokeColor = .clear
        node.addChild(plate)

        let number = SKLabelNode()
        number.attributedText = ResultsNode.ink(value, size: 19, weight: .heavy)
        number.verticalAlignmentMode = .center
        number.position = CGPoint(x: 0, y: 6)
        number.zPosition = 1
        node.addChild(number)

        let caption = SKLabelNode()
        caption.attributedText = ResultsNode.ink(label, size: 9.5, weight: .bold, faint: true)
        caption.verticalAlignmentMode = .center
        caption.position = CGPoint(x: 0, y: -13)
        caption.zPosition = 1
        node.addChild(caption)

        return node
    }

    private func fillStats(_ stats: MatchStats) {
        statsGrid.removeAllChildren()
        tiles = []

        let accuracy = stats.accuracy.map { "\(Int(($0 * 100).rounded()))%" } ?? "0%"
        let entries: [(String, String)] = [
            ("\(stats.kills)", "KILLS"),
            ("\(stats.deaths)", "DEATHS"),
            (accuracy, "ACCURACY"),
            (ResultsNode.grouped(stats.damageDealt), "DAMAGE"),
            ("\(stats.chestsRaided)", "RAIDS"),
            (ResultsNode.grouped(stats.tokensEarned), "TOKENS"),
        ]

        let size = ResultsNode.tileSize
        let gap = ResultsNode.tileGap
        let perRow = ResultsNode.tilesPerRow
        let rowWidth = size.width * CGFloat(perRow) + gap * CGFloat(perRow - 1)

        for (index, entry) in entries.enumerated() {
            let column = CGFloat(index % perRow)
            let row = CGFloat(index / perRow)
            let tile = makeTile(value: entry.0, label: entry.1)
            tile.position = CGPoint(x: -rowWidth / 2 + size.width / 2 + column * (size.width + gap),
                                    y: -size.height / 2 - row * (size.height + gap))
            statsGrid.addChild(tile)
            tiles.append(tile)
        }
    }

    // MARK: - Layout and taps

    /// The veil covers the screen, and the card shrinks to fit a short one.
    func layOut(for screen: CGSize) {
        self.screen = screen
        scrim.path = CGPath(rect: CGRect(x: -screen.width / 2, y: -screen.height / 2,
                                         width: screen.width, height: screen.height),
                            transform: nil)
        fit()
    }

    private func fit() {
        guard screen != .zero else { return }
        let needed = cardHeight + 24
        card.setScale(min(1, screen.height / needed))
        card.position = .zero
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

    func show(with world: World, award: Progress.Award? = nil) {
        guard isHidden else { return }
        isHidden = false
        pressed = false

        let standings = world.standings
        let you = world.localPlayer?.team
        let place = standings.firstIndex { $0.team == you }
        let yourScore = place.map { standings[$0].score } ?? 0
        let podium = place.map { $0 < 3 } ?? false

        // Read before Prefs records this match, so "better than ever before".
        let newBest = place != nil && yourScore > Prefs.bestScore && yourScore > 0

        arrange(podium: podium)

        // MARK: Header

        if let place {
            headline.attributedText = ResultsNode.ink(place == 0 ? "YOU WON" : "\(ResultsNode.ordinal(place + 1)) PLACE",
                                                      size: 26, weight: .heavy)
        } else {
            headline.attributedText = ResultsNode.ink("TIME", size: 26, weight: .heavy)
        }

        trophy.isHidden = !podium
        if let place, podium {
            let texture = ResultsNode.trophyTexture(place: place)
            trophy.texture = texture
            trophy.size = CGSize(width: ResultsNode.trophySide, height: ResultsNode.trophySide)
        }
        setPoints(0)

        fillStats(world.stats[world.localPlayerID] ?? MatchStats())

        // MARK: Entrance

        scrim.alpha = 0
        scrim.run(.fadeIn(withDuration: 0.25))

        let rest = card.position
        card.alpha = 0
        card.position = CGPoint(x: rest.x, y: rest.y - 40)
        let rise = SKAction.move(to: rest, duration: 0.32)
        rise.timingMode = .easeOut
        card.run(.group([rise, .fadeIn(withDuration: 0.2)]))

        if podium, let place {
            trophy.setScale(0)
            trophy.run(.sequence([
                .wait(forDuration: 0.28),
                .scale(to: 1.25, duration: 0.14),
                .scale(to: 1, duration: 0.12),
                .run { [weak self] in
                    guard let self else { return }
                    self.confetti(from: self.trophy, pieces: place == 0 ? 60 : 36)
                }
            ]))
            // A gentle wobble once it has landed, so it stays alive on the card.
            let wobble = SKAction.sequence([.rotate(toAngle: 0.06, duration: 0.9),
                                            .rotate(toAngle: -0.06, duration: 0.9)])
            wobble.timingMode = .easeInEaseOut
            trophy.run(.sequence([.wait(forDuration: 0.6), .repeatForever(wobble)]), withKey: "wobble")
        }

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

        // Your stats pop in one at a time.
        for (index, tile) in tiles.enumerated() {
            tile.alpha = 0
            tile.setScale(0.8)
            tile.run(.sequence([
                .wait(forDuration: 0.5 + Double(index) * 0.06),
                .group([.fadeIn(withDuration: 0.15),
                        .sequence([.scale(to: 1.08, duration: 0.1), .scale(to: 1, duration: 0.08)])])
            ]))
        }

        for button in [again, menu] {
            button.alpha = 0
            button.run(.sequence([.wait(forDuration: 0.9), .fadeIn(withDuration: 0.2)]))
        }

        playLevel(award)
    }

    // MARK: - Level

    /// The bar fills with this match's XP, rolling over at each level-up with a
    /// bump on the number, and any unlock is shown once it has finished.
    private func playLevel(_ award: Progress.Award?) {
        unlockCard.removeAllChildren()

        guard let award else {
            levelLabel.isHidden = true
            xpGained.isHidden = true
            setXPBar(0)
            return
        }

        let start = Roadmap.level(forXP: award.xpBefore)
        setLevel(start.level)
        setXPBar(CGFloat(start.into) / CGFloat(start.needed))
        xpGained.attributedText = ResultsNode.ink("+\(award.gained) XP", size: 13,
                                                  weight: .bold, faint: true)

        // One step per level crossed, then the remainder.
        var steps: [SKAction] = [.wait(forDuration: 1.25)]
        var xp = award.xpBefore
        var left = award.gained

        while left > 0 {
            let here = Roadmap.level(forXP: xp)
            let room = here.needed - here.into
            let from = CGFloat(here.into) / CGFloat(here.needed)

            if left >= room {
                steps.append(fill(from: from, to: 1, duration: 0.35))
                let next = here.level + 1
                steps.append(.run { [weak self] in
                    self?.setLevel(next)
                    self?.setXPBar(0)
                    self?.levelLabel.run(.sequence([.scale(to: 1.3, duration: 0.08),
                                                    .scale(to: 1, duration: 0.14)]))
                })
                xp += room
                left -= room
            } else {
                let to = CGFloat(here.into + left) / CGFloat(here.needed)
                steps.append(fill(from: from, to: to, duration: 0.45))
                xp += left
                left = 0
            }
        }

        if !award.unlocked.isEmpty {
            steps.append(.run { [weak self] in self?.showUnlocks(award.unlocked) })
        }

        run(.sequence(steps), withKey: "level")
    }

    private func fill(from: CGFloat, to: CGFloat, duration: TimeInterval) -> SKAction {
        .customAction(withDuration: duration) { [weak self] _, elapsed in
            let t = min(1, elapsed / CGFloat(duration))
            self?.setXPBar(from + (to - from) * t)
        }
    }

    /// NEW UNLOCK, beside the results: each feature this match unlocked, with its
    /// art and what it does. Pops in, and stays.
    private func showUnlocks(_ features: [Feature]) {
        unlockCard.removeAllChildren()

        let width: CGFloat = 150
        let rowHeight: CGFloat = 92
        let height = 36 + rowHeight * CGFloat(features.count)

        let plate = SKShapeNode(path: CGPath(
            roundedRect: CGRect(x: -width / 2, y: -height / 2, width: width, height: height),
            cornerWidth: 18, cornerHeight: 18, transform: nil))
        plate.fillColor = SKColor(white: 0.99, alpha: 1)
        plate.strokeColor = RenderPalette.menuPlay.face
        plate.lineWidth = 3
        unlockCard.addChild(plate)

        let heading = SKLabelNode()
        heading.attributedText = MenuButtonNode.text("NEW UNLOCK", size: 12, weight: .heavy,
                                                     colour: RenderPalette.menuPlay.edge)
        heading.verticalAlignmentMode = .center
        heading.position = CGPoint(x: 0, y: height / 2 - 18)
        heading.zPosition = 1
        unlockCard.addChild(heading)

        for (index, feature) in features.enumerated() {
            let y = height / 2 - 36 - rowHeight * (CGFloat(index) + 0.5)

            let texture = ItemArt.texture(for: feature.item)
            let art = SKSpriteNode(texture: texture, size: ItemArt.size(of: texture, fittingInto: 44))
            art.position = CGPoint(x: 0, y: y + 14)
            art.zPosition = 1
            unlockCard.addChild(art)

            let name = SKLabelNode()
            name.attributedText = ResultsNode.ink(feature.title, size: 13, weight: .heavy)
            name.verticalAlignmentMode = .center
            name.position = CGPoint(x: 0, y: y - 20)
            name.zPosition = 1
            unlockCard.addChild(name)

            let blurb = SKLabelNode()
            blurb.attributedText = ResultsNode.ink(feature.blurb, size: 11, weight: .semibold, faint: true)
            blurb.verticalAlignmentMode = .center
            blurb.position = CGPoint(x: 0, y: y - 36)
            blurb.zPosition = 1
            unlockCard.addChild(blurb)
        }

        // Beside the card where there is room, otherwise over its top corner.
        let scale = card.xScale
        let cardRight = card.position.x + ResultsNode.cardWidth / 2 * scale
        let roomRight = screen.width / 2 - cardRight
        unlockCard.setScale(scale)
        if roomRight >= (width + 24) * scale {
            unlockCard.position = CGPoint(x: cardRight + 12 * scale + width / 2 * scale,
                                          y: card.position.y)
        } else {
            unlockCard.position = CGPoint(x: cardRight - width / 2 * scale,
                                          y: card.position.y + cardHeight / 2 * scale - height / 2 * scale)
        }

        let rest = unlockCard.xScale
        unlockCard.setScale(0)
        unlockCard.run(.sequence([.scale(to: rest * 1.15, duration: 0.16),
                                  .scale(to: rest, duration: 0.12)]))
        SoundPlayer.shared.play(.upgrade)
        confetti(from: unlockCard, pieces: 24)
    }

    // MARK: - Pieces

    private func setPoints(_ value: Int) {
        points.attributedText = ResultsNode.ink("\(ResultsNode.grouped(value)) POINTS", size: 15,
                                                weight: .bold, faint: true)
        best.position = CGPoint(x: points.frame.maxX + 46, y: points.position.y)
    }

    private func revealBest() {
        best.isHidden = false
        best.setScale(0)
        best.run(.sequence([.scale(to: 1.2, duration: 0.12), .scale(to: 1, duration: 0.1)]))
    }

    /// A burst of confetti out of a node: little flat strips in the menu's
    /// colours, thrown up and out, then fluttering down as they spin and fade.
    private func confetti(from origin: SKNode, pieces: Int) {
        let centre = convert(CGPoint.zero, from: origin)
        let colours: [SKColor] = [RenderPalette.menuPlay.face, RenderPalette.menuInfo.face,
                                  RenderPalette.menuCaution.face, RenderPalette.menuDanger.face,
                                  RenderPalette.menuProfile.face, RenderPalette.menuSettings.face]

        for index in 0..<pieces {
            let piece = SKSpriteNode(color: colours[index % colours.count],
                                     size: CGSize(width: CGFloat.random(in: 5...8),
                                                  height: CGFloat.random(in: 9...13)))
            piece.position = centre
            piece.zPosition = 10
            piece.zRotation = CGFloat.random(in: 0...(2 * .pi))
            addChild(piece)

            // Up and out in a fan, then a long fall that drifts sideways.
            let angle = CGFloat.random(in: 0.25...(CGFloat.pi - 0.25))
            let burst = CGFloat.random(in: 90...190)
            let peak = CGPoint(x: centre.x + cos(angle) * burst,
                               y: centre.y + sin(angle) * burst)
            let landing = CGPoint(x: peak.x + CGFloat.random(in: -50...50),
                                  y: peak.y - CGFloat.random(in: 160...260))

            let up = SKAction.move(to: peak, duration: Double.random(in: 0.35...0.5))
            up.timingMode = .easeOut
            let fall = SKAction.move(to: landing, duration: Double.random(in: 1.1...1.6))
            fall.timingMode = .easeIn
            let spin = SKAction.rotate(byAngle: CGFloat.random(in: -10...10), duration: 2)
            // Flips as it falls: squashing the width reads as the strip turning over.
            let flutter = SKAction.repeatForever(.sequence([
                .scaleX(to: 0.2, duration: 0.18), .scaleX(to: 1, duration: 0.18)]))

            piece.run(flutter)
            piece.run(.group([
                spin,
                .sequence([up, .group([fall, .sequence([.wait(forDuration: 0.7),
                                                         .fadeOut(withDuration: 0.6)])]),
                           .removeFromParent()])
            ]))
        }
    }

    // MARK: - Trophy

    /// A trophy in the game's own style - a cup, two handles, a stem and a base,
    /// flat colour with a darker shade on the lower right, the black outline and
    /// one shine - in gold, silver or bronze. Drawn once per finish.
    private static func trophyTexture(place: Int) -> SKTexture {
        let colours: [(face: UIColor, shade: UIColor)] = [
            (UIColor(red: 1.00, green: 0.76, blue: 0.10, alpha: 1),     // gold
             UIColor(red: 0.89, green: 0.60, blue: 0.00, alpha: 1)),
            (UIColor(red: 0.80, green: 0.84, blue: 0.89, alpha: 1),     // silver
             UIColor(red: 0.60, green: 0.66, blue: 0.73, alpha: 1)),
            (UIColor(red: 0.88, green: 0.58, blue: 0.33, alpha: 1),     // bronze
             UIColor(red: 0.73, green: 0.44, blue: 0.22, alpha: 1)),
        ]
        let face = colours[min(max(place, 0), 2)].face
        let shade = colours[min(max(place, 0), 2)].shade

        let side: CGFloat = 128
        let format = UIGraphicsImageRendererFormat.default()
        format.opaque = false
        let image = UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: format).image { context in
            let gc = context.cgContext
            let ink = UIColor(white: 0.07, alpha: 1)
            let outline: CGFloat = 6

            // Handles first, so the cup sits over their inner ends.
            for flip in [-1.0, 1.0] as [CGFloat] {
                let handle = UIBezierPath()
                handle.move(to: CGPoint(x: 64 + flip * 30, y: 30))
                handle.addCurve(to: CGPoint(x: 64 + flip * 26, y: 62),
                                controlPoint1: CGPoint(x: 64 + flip * 58, y: 28),
                                controlPoint2: CGPoint(x: 64 + flip * 56, y: 62))
                handle.lineCapStyle = .round
                ink.setStroke()
                handle.lineWidth = 16
                handle.stroke()
                shade.setStroke()
                handle.lineWidth = 16 - outline * 1.6
                handle.stroke()
            }

            func shaded(_ path: UIBezierPath, nudge: CGFloat) {
                gc.saveGState()
                path.addClip()
                shade.setFill()
                path.fill()
                gc.translateBy(x: -nudge, y: -nudge)
                face.setFill()
                path.fill()
                gc.restoreGState()
                ink.setStroke()
                path.lineWidth = outline
                path.lineJoinStyle = .round
                path.stroke()
            }

            // Base, stem, cup - back to front.
            shaded(UIBezierPath(roundedRect: CGRect(x: 36, y: 100, width: 56, height: 18), cornerRadius: 6), nudge: 4)
            shaded(UIBezierPath(rect: CGRect(x: 56, y: 82, width: 16, height: 20)), nudge: 3)

            let cup = UIBezierPath()
            cup.move(to: CGPoint(x: 32, y: 16))
            cup.addLine(to: CGPoint(x: 96, y: 16))
            cup.addLine(to: CGPoint(x: 96, y: 40))
            cup.addCurve(to: CGPoint(x: 64, y: 84),
                         controlPoint1: CGPoint(x: 96, y: 66), controlPoint2: CGPoint(x: 82, y: 84))
            cup.addCurve(to: CGPoint(x: 32, y: 40),
                         controlPoint1: CGPoint(x: 46, y: 84), controlPoint2: CGPoint(x: 32, y: 66))
            cup.close()
            shaded(cup, nudge: 9)

            // One shine, top left of the cup.
            gc.saveGState()
            gc.translateBy(x: 46, y: 34)
            gc.rotate(by: -0.3)
            UIColor(white: 1, alpha: 0.55).setFill()
            UIBezierPath(ovalIn: CGRect(x: -4, y: -9, width: 8, height: 18)).fill()
            gc.restoreGState()
        }
        return SKTexture(image: image)
    }

    // MARK: - Helpers

    private static func ink(_ text: String, size: CGFloat, weight: UIFont.Weight,
                            faint: Bool = false) -> NSAttributedString {
        MenuButtonNode.text(text, size: size, weight: weight,
                            colour: faint ? SKColor(white: 0.45, alpha: 1) : RenderPalette.menuInk)
    }

    /// 1240 as "1,240".
    private static func grouped(_ n: Int) -> String {
        let digits = String(abs(n))
        var out = ""
        for (index, character) in digits.enumerated() {
            if index > 0, (digits.count - index) % 3 == 0 { out.append(",") }
            out.append(character)
        }
        return n < 0 ? "-" + out : out
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
