//
//  RoadmapSheetContent.swift
//  Loot Wars
//
//  The road ahead: your level, and every unlock on the way, in a row you can
//  scroll through.
//
//  One card per milestone - every five levels - with the thing it unlocks, what
//  it does, and whether you have it. The next one to come is picked out with how
//  many levels are left, and the row opens scrolled to it, so the first thing
//  you see is what you are working towards.
//

import SpriteKit
import UIKit

final class RoadmapSheetContent: MenuSheetContent {

    let node = SKNode()

    /// Called when a card is tapped, with what it unlocks and at which level.
    var onSelect: ((Feature, Int) -> Void)?

    /// Where the row was scrolled to when a card was opened, so coming back from
    /// its page puts you where you were rather than back at the start.
    private var returnTo: CGFloat?

    /// Each card's centre along the row, for working out which one was tapped.
    private var cardCentres: [(x: CGFloat, feature: Feature, level: Int)] = []
    private var cardRowY: CGFloat = 0
    private var dragDistance: CGFloat = 0
    private static let cardSize = CGSize(width: 118, height: 150)
    private static let gap: CGFloat = 12
    private static let headerHeight: CGFloat = 46

    private var width: CGFloat = 0
    private let crop = SKCropNode()
    private let strip = SKNode()

    private var dragStart: CGPoint?
    private var stripStart: CGFloat = 0
    private var stripMin: CGFloat = 0
    private var stripMax: CGFloat = 0

    func preferredCardWidth(for screen: CGSize) -> CGFloat? {
        min(screen.width * 0.86, 680)
    }

    func layOut(width: CGFloat, maxHeight: CGFloat) -> CGFloat {
        self.width = width
        node.removeAllChildren()
        crop.removeAllChildren()
        strip.removeAllChildren()
        strip.removeAllActions()

        let level = Progress.level
        let progress = Roadmap.level(forXP: Prefs.totalXP)

        // MARK: Your level

        let title = SKLabelNode()
        title.attributedText = MenuButtonNode.text("LEVEL \(level)", size: 16, weight: .heavy,
                                          colour: RenderPalette.menuInk)
        title.horizontalAlignmentMode = .left
        title.verticalAlignmentMode = .center
        title.position = CGPoint(x: -width / 2 + 4, y: -14)
        node.addChild(title)

        let barLeft = title.position.x + title.frame.width + 14
        let barWidth = max(60, width / 2 - 4 - barLeft - 70)
        let track = SKShapeNode(path: CGPath(
            roundedRect: CGRect(x: barLeft, y: -20, width: barWidth, height: 12),
            cornerWidth: 6, cornerHeight: 6, transform: nil))
        track.fillColor = SKColor(white: 0.88, alpha: 1)
        track.strokeColor = .clear
        node.addChild(track)

        let share = CGFloat(progress.into) / CGFloat(max(1, progress.needed))
        let fill = SKShapeNode(path: CGPath(
            roundedRect: CGRect(x: barLeft, y: -20, width: max(12, barWidth * share), height: 12),
            cornerWidth: 6, cornerHeight: 6, transform: nil))
        fill.fillColor = RenderPalette.menuPlay.face
        fill.strokeColor = .clear
        fill.isHidden = share <= 0
        node.addChild(fill)

        let xp = SKLabelNode()
        xp.attributedText = MenuButtonNode.text("\(progress.into) / \(progress.needed) XP", size: 12,
                                       weight: .semibold, colour: SKColor(white: 0, alpha: 0.5))
        xp.horizontalAlignmentMode = .right
        xp.verticalAlignmentMode = .center
        xp.position = CGPoint(x: width / 2 - 4, y: -14)
        node.addChild(xp)

        if Prefs.devMode {
            let dev = SKLabelNode()
            dev.attributedText = MenuButtonNode.text("DEV MODE - everything is on in matches", size: 11,
                                            weight: .bold, colour: RenderPalette.menuSettings.edge)
            dev.verticalAlignmentMode = .center
            dev.position = CGPoint(x: 0, y: -38)
            node.addChild(dev)
        }

        // MARK: The cards

        let card = RoadmapSheetContent.cardSize
        let gap = RoadmapSheetContent.gap
        let top = -RoadmapSheetContent.headerHeight - 6
        let stripHeight = card.height + 8

        let window = SKSpriteNode(color: .white, size: CGSize(width: width, height: stripHeight))
        window.position = CGPoint(x: 0, y: top - stripHeight / 2)
        crop.maskNode = window
        crop.addChild(strip)
        node.addChild(crop)

        let next = Roadmap.milestones.firstIndex { $0.level > level }
        cardCentres = []
        cardRowY = top - stripHeight / 2

        for (index, milestone) in Roadmap.milestones.enumerated() {
            let unlocked = milestone.level <= level
            let isNext = index == next
            let built = makeCard(milestone.feature, level: milestone.level,
                                 unlocked: unlocked, isNext: isNext,
                                 levelsToGo: milestone.level - level)
            built.position = CGPoint(x: -width / 2 + card.width / 2
                                        + CGFloat(index) * (card.width + gap),
                                     y: top - stripHeight / 2)
            strip.addChild(built)
            cardCentres.append((built.position.x, milestone.feature, milestone.level))
        }

        // Scroll limits, and open on the next unlock (or the end).
        let total = CGFloat(Roadmap.milestones.count) * (card.width + gap) - gap
        stripMax = 0
        stripMin = min(0, width - total)
        let focus = next ?? (Roadmap.milestones.count - 1)
        let wanted = -(CGFloat(focus) * (card.width + gap)) + (width - card.width) / 2
        strip.position.x = clamp(returnTo ?? wanted)
        returnTo = nil

        return RoadmapSheetContent.headerHeight + stripHeight + 18
    }

    private func makeCard(_ feature: Feature, level: Int, unlocked: Bool,
                          isNext: Bool, levelsToGo: Int) -> SKNode {
        let size = RoadmapSheetContent.cardSize
        let root = SKNode()

        let plate = SKShapeNode(path: CGPath(
            roundedRect: CGRect(x: -size.width / 2, y: -size.height / 2,
                                width: size.width, height: size.height),
            cornerWidth: 16, cornerHeight: 16, transform: nil))
        plate.fillColor = unlocked ? SKColor(white: 1, alpha: 1) : SKColor(white: 0.94, alpha: 1)
        plate.strokeColor = isNext ? RenderPalette.menuPlay.face
            : (unlocked ? SKColor(white: 0.78, alpha: 1) : SKColor(white: 0.86, alpha: 1))
        plate.lineWidth = isNext ? 3.5 : 2.5
        root.addChild(plate)

        let tag = SKLabelNode()
        tag.attributedText = MenuButtonNode.text("LEVEL \(level)", size: 11, weight: .heavy,
                                        colour: unlocked ? RenderPalette.menuPlay.edge
                                                         : SKColor(white: 0, alpha: 0.45))
        tag.verticalAlignmentMode = .center
        tag.position = CGPoint(x: 0, y: size.height / 2 - 16)
        tag.zPosition = 1
        root.addChild(tag)

        let texture = ItemArt.texture(for: feature.item)
        let art = SKSpriteNode(texture: texture, size: ItemArt.size(of: texture, fittingInto: 54))
        art.position = CGPoint(x: 0, y: 10)
        art.zPosition = 1
        if !unlocked {
            // Seen but not yours yet: the shape, greyed.
            art.color = SKColor(white: 0.55, alpha: 1)
            art.colorBlendFactor = 0.85
            art.alpha = 0.55
        }
        root.addChild(art)

        let name = SKLabelNode()
        name.attributedText = MenuButtonNode.text(feature.title, size: 13, weight: .heavy,
                                         colour: unlocked ? RenderPalette.menuInk
                                                          : SKColor(white: 0, alpha: 0.55))
        name.verticalAlignmentMode = .center
        name.position = CGPoint(x: 0, y: -32)
        name.zPosition = 1
        root.addChild(name)

        let status: String
        if unlocked {
            status = feature.blurb
        } else if isNext {
            status = levelsToGo == 1 ? "Next level!" : "\(levelsToGo) levels to go"
        } else {
            status = "Locked"
        }
        // A small circled "?" in the corner says the card opens.
        let info = SKShapeNode(circleOfRadius: 9)
        info.fillColor = .clear
        info.strokeColor = SKColor(white: 0, alpha: 0.35)
        info.lineWidth = 2
        info.position = CGPoint(x: size.width / 2 - 15, y: size.height / 2 - 15)
        info.zPosition = 1
        root.addChild(info)

        let mark = SKLabelNode()
        mark.attributedText = MenuButtonNode.text("?", size: 12, weight: .heavy,
                                                  colour: SKColor(white: 0, alpha: 0.4))
        mark.verticalAlignmentMode = .center
        mark.horizontalAlignmentMode = .center
        info.addChild(mark)

        let line = SKLabelNode()
        line.attributedText = MenuButtonNode.text(status, size: 11, weight: .semibold,
                                         colour: isNext ? RenderPalette.menuPlay.edge
                                                        : SKColor(white: 0, alpha: 0.45))
        line.verticalAlignmentMode = .center
        line.position = CGPoint(x: 0, y: -50)
        line.zPosition = 1
        root.addChild(line)

        if isNext {
            root.run(.repeatForever(.sequence([.scale(to: 1.03, duration: 0.8),
                                               .scale(to: 1, duration: 0.8)])))
        }
        return root
    }

    // MARK: - Scrolling

    func tap(at point: CGPoint) {}

    func dragBegan(at point: CGPoint) {
        strip.removeAction(forKey: "settle")
        dragStart = point
        stripStart = strip.position.x
        dragDistance = 0
    }

    func dragMoved(to point: CGPoint) {
        guard let start = dragStart else { return }
        dragDistance = max(dragDistance, abs(point.x - start.x) + abs(point.y - start.y))
        let target = stripStart + (point.x - start.x)

        // A little give past either end, so the edge is felt rather than hit.
        let clamped = clamp(target)
        strip.position.x = clamped + (target - clamped) * 0.3
    }

    func dragEnded(at point: CGPoint) {
        // Barely moved: a tap on a card, which opens it. Decided on release so a
        // swipe that starts on a card scrolls rather than opening it.
        if dragStart != nil, dragDistance < 8, let card = card(at: point) {
            dragStart = nil
            returnTo = strip.position.x
            SoundPlayer.shared.play(.select)
            onSelect?(card.feature, card.level)
            return
        }
        dragStart = nil
        let settle = SKAction.moveTo(x: clamp(strip.position.x), duration: 0.2)
        settle.timingMode = .easeOut
        strip.run(settle, withKey: "settle")
    }

    /// The card under a point in the content's space, if any.
    private func card(at point: CGPoint) -> (feature: Feature, level: Int)? {
        let size = RoadmapSheetContent.cardSize
        guard abs(point.y - cardRowY) <= size.height / 2,
              abs(point.x) <= width / 2 else { return nil }
        let x = point.x - strip.position.x
        return cardCentres.first { abs($0.x - x) <= size.width / 2 }
            .map { ($0.feature, $0.level) }
    }

    private func clamp(_ x: CGFloat) -> CGFloat {
        min(stripMax, max(stripMin, x))
    }
}
