//
//  HowToPlayContent.swift
//  Loot Wars
//
//  The Info button: How to Play, as a row of pages you swipe through.
//
//  Each page is a picture and two lines. The picture is a little scene built from
//  the game's own art (HowToPlayScenes), so it always matches what a newcomer is
//  about to see - and a screenshot named HowTo1, HowTo2 ... in the asset catalogue
//  replaces the scene for that page, with no code change, for the day real
//  screenshots are worth taking.
//
//  Swipe left and right, or tap the arrows. The dots underneath say how many
//  there are and where you are.
//

import SpriteKit
import UIKit

final class HowToPlayContent: MenuSheetContent {

    struct Page {
        let title: String
        let body: String
        let scene: HowToPlayScenes.Kind
    }

    /// The whole of How to Play. Short on purpose: one idea a page, in the order
    /// a first match asks for them.
    static var pages: [Page] {
        let (move, aim) = Prefs.leftHanded ? ("right", "left") : ("left", "right")
        return [
            Page(title: "Win the match",
                 body: "Eight teams, a few minutes. Score the most points to win.",
                 scene: .win),
            Page(title: "Move and shoot",
                 body: "The \(move) stick moves you. Hold the \(aim) stick to aim and fire.",
                 scene: .moveAndShoot),
            Page(title: "Open crates",
                 body: "Walk up to a crate and tap to open it. Purple crates hold better loot.",
                 scene: .crates),
            Page(title: "Gear up",
                 body: "Walk over a better helmet or blaster to put it on. Rarer colours are stronger.",
                 scene: .gear),
            Page(title: "Heal up",
                 body: "Tap a bandage or medkit to heal. Medkits heal more.",
                 scene: .heal),
            Page(title: "Power-ups",
                 body: "Tap a power-up for a short boost. The disco ball gives you all of them.",
                 scene: .perks),
            Page(title: "Build your base",
                 body: "Tap inside your base to place walls. Close the ring to seal it and get chests.",
                 scene: .build),
            Page(title: "Earn and spend",
                 body: "Arcades pay out tokens. Collect them and spend them in the shop.",
                 scene: .earn),
            Page(title: "Raid other bases",
                 body: "Bomb a hole in an enemy wall, then shoot their chest open for loot.",
                 scene: .raid),
            Page(title: "Turrets and supply drops",
                 body: "Take out turrets before you raid. Golden supply drops land late with the best gear.",
                 scene: .supply)
        ]
    }

    let node = SKNode()

    private var width: CGFloat = 0
    private var pictureHeight: CGFloat = 0
    private var total: CGFloat = 0

    private let crop = SKCropNode()
    private let strip = SKNode()
    private var dots: [SKShapeNode] = []
    private var leftArrow = SKNode()
    private var rightArrow = SKNode()

    private var index = 0
    private var pageCount = 0

    /// Where a drag started, and where the strip was when it did.
    private var dragStart: CGPoint?
    private var stripStart: CGFloat = 0

    func preferredCardWidth(for screen: CGSize) -> CGFloat? {
        min(screen.width * 0.82, 640)
    }

    func layOut(width: CGFloat, maxHeight: CGFloat) -> CGFloat {
        self.width = width
        // Stop the old pages' loops before letting them go. Their actions hold
        // their own nodes, so a page thrown away still running would never be
        // freed.
        strip.enumerateChildNodes(withName: "//*") { child, _ in child.removeAllActions() }
        node.removeAllChildren()
        crop.removeAllChildren()
        strip.removeAllChildren()
        dots = []

        let pages = HowToPlayContent.pages
        pageCount = pages.count
        index = min(index, pageCount - 1)

        // The picture takes whatever height the text and dots leave.
        let textBlock: CGFloat = 96
        pictureHeight = max(110, min(230, maxHeight - textBlock))
        total = pictureHeight + textBlock

        // Pages slide inside this window and nowhere else.
        let window = SKSpriteNode(color: .white,
                                  size: CGSize(width: width, height: total))
        window.anchorPoint = CGPoint(x: 0.5, y: 1)
        crop.maskNode = window
        crop.addChild(strip)
        node.addChild(crop)

        for (number, page) in pages.enumerated() {
            let built = makePage(page, number: number)
            built.position = CGPoint(x: CGFloat(number) * width, y: 0)
            strip.addChild(built)
        }
        strip.position = CGPoint(x: -CGFloat(index) * width, y: 0)

        addArrows()
        addDots()
        refresh(animated: false)

        return total
    }

    // MARK: - Pages

    private func makePage(_ page: Page, number: Int) -> SKNode {
        let root = SKNode()

        // The picture, on a panel the colour of the map.
        let panelSize = CGSize(width: width, height: pictureHeight)
        let panel = SKShapeNode(rect: CGRect(x: -panelSize.width / 2, y: -panelSize.height,
                                             width: panelSize.width, height: panelSize.height),
                                cornerRadius: 16)
        panel.fillColor = RenderPalette.floorLight
        panel.strokeColor = RenderPalette.floorDark
        panel.lineWidth = 3
        root.addChild(panel)

        let picture = HowToPlayContent.picture(for: page, number: number,
                                               size: CGSize(width: panelSize.width - 12,
                                                            height: panelSize.height - 12))
        picture.position = CGPoint(x: 0, y: -panelSize.height / 2)
        picture.zPosition = 1
        root.addChild(picture)

        let title = SKLabelNode()
        title.attributedText = HowToPlayContent.text(page.title, size: 17, weight: .bold,
                                                     colour: RenderPalette.menuInk)
        title.verticalAlignmentMode = .center
        title.position = CGPoint(x: 0, y: -pictureHeight - 20)
        root.addChild(title)

        let body = SKLabelNode()
        body.attributedText = HowToPlayContent.text(page.body, size: 13, weight: .regular,
                                                    colour: SKColor(white: 0, alpha: 0.55))
        body.numberOfLines = 0
        body.preferredMaxLayoutWidth = width - 30
        body.verticalAlignmentMode = .top
        body.position = CGPoint(x: 0, y: -pictureHeight - 34)
        root.addChild(body)

        return root
    }

    /// A screenshot if the catalogue has one for this page, the built scene if not.
    private static func picture(for page: Page, number: Int, size: CGSize) -> SKNode {
        let name = "HowTo\(number + 1)"
        if UIImage(named: name) != nil {
            let texture = SKTexture(imageNamed: name)
            let art = texture.size()
            let scale = min(size.width / max(art.width, 1), size.height / max(art.height, 1))
            return SKSpriteNode(texture: texture,
                                size: CGSize(width: art.width * scale, height: art.height * scale))
        }
        return HowToPlayScenes.make(page.scene, in: size)
    }

    // MARK: - Chrome

    private func addArrows() {
        leftArrow = HowToPlayContent.arrow(pointingRight: false)
        rightArrow = HowToPlayContent.arrow(pointingRight: true)
        let y = -pictureHeight / 2
        leftArrow.position = CGPoint(x: -width / 2 + 22, y: y)
        rightArrow.position = CGPoint(x: width / 2 - 22, y: y)
        // Above the picture, which is a little match with its own interface in it.
        leftArrow.zPosition = 3000
        rightArrow.zPosition = 3000
        node.addChild(leftArrow)
        node.addChild(rightArrow)
    }

    private func addDots() {
        let gap: CGFloat = 16
        let start = -gap * CGFloat(pageCount - 1) / 2
        for number in 0..<pageCount {
            let dot = SKShapeNode(circleOfRadius: 4)
            dot.strokeColor = .clear
            dot.position = CGPoint(x: start + CGFloat(number) * gap, y: -total + 8)
            node.addChild(dot)
            dots.append(dot)
        }
    }

    /// A round dark button with a white chevron - the same see-through black as
    /// the in-game controls.
    private static func arrow(pointingRight: Bool) -> SKNode {
        let button = SKShapeNode(circleOfRadius: 16)
        button.fillColor = SKColor(white: 0, alpha: 0.35)
        button.strokeColor = .clear

        let flip: CGFloat = pointingRight ? 1 : -1
        let path = CGMutablePath()
        path.move(to: CGPoint(x: -3 * flip, y: 6))
        path.addLine(to: CGPoint(x: 3 * flip, y: 0))
        path.addLine(to: CGPoint(x: -3 * flip, y: -6))
        let chevron = SKShapeNode(path: path)
        chevron.strokeColor = .white
        chevron.lineWidth = 3
        chevron.lineCap = .round
        chevron.lineJoin = .round
        button.addChild(chevron)
        return button
    }

    private func refresh(animated: Bool) {
        for (number, dot) in dots.enumerated() {
            dot.fillColor = number == index ? RenderPalette.menuInk : SKColor(white: 0, alpha: 0.18)
            dot.setScale(number == index ? 1.25 : 1)
        }
        leftArrow.alpha = index > 0 ? 1 : 0
        rightArrow.alpha = index < pageCount - 1 ? 1 : 0

        let target = -CGFloat(index) * width
        strip.removeAction(forKey: "slide")
        guard animated else {
            strip.position.x = target
            return
        }
        let slide = SKAction.moveTo(x: target, duration: 0.26)
        slide.timingMode = .easeOut
        strip.run(slide, withKey: "slide")
    }

    private func go(to page: Int) {
        let clamped = max(0, min(pageCount - 1, page))
        if clamped != index { SoundPlayer.shared.play(.tap) }
        index = clamped
        refresh(animated: true)
    }

    // MARK: - Touches

    /// Taps are read at the END of a touch rather than the start, so a swipe that
    /// happens to begin on an arrow is a swipe and not a press of the arrow.
    func tap(at point: CGPoint) {}

    func dragBegan(at point: CGPoint) {
        guard point.y <= 0, point.y >= -total, abs(point.x) <= width / 2 + 20 else {
            dragStart = nil
            return
        }
        dragStart = point
        strip.removeAction(forKey: "slide")
        stripStart = strip.position.x
    }

    func dragMoved(to point: CGPoint) {
        guard let start = dragStart else { return }
        var offset = point.x - start.x

        // Past the first or last page it gives, but only a little - the edge is
        // felt rather than hit.
        let atStart = index == 0 && offset > 0
        let atEnd = index == pageCount - 1 && offset < 0
        if atStart || atEnd { offset *= 0.3 }

        strip.position.x = stripStart + offset
    }

    func dragEnded(at point: CGPoint) {
        guard let start = dragStart else { return }
        dragStart = nil
        let offset = point.x - start.x

        // Barely moved: a tap. Arrows first, then either side of the picture.
        if abs(offset) < 8, abs(point.y - start.y) < 8 {
            if point.y <= 0, point.y >= -pictureHeight {
                if point.x < -width / 2 + 60, index > 0 { go(to: index - 1); return }
                if point.x > width / 2 - 60, index < pageCount - 1 { go(to: index + 1); return }
            }
            refresh(animated: true)
            return
        }

        if offset < -width * 0.15 {
            go(to: index + 1)
        } else if offset > width * 0.15 {
            go(to: index - 1)
        } else {
            refresh(animated: true)
        }
    }

    // MARK: - Type

    private static func text(_ string: String, size: CGFloat, weight: UIFont.Weight,
                             colour: SKColor) -> NSAttributedString {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.lineSpacing = 3
        return NSAttributedString(string: string, attributes: [
            .font: UIFont.systemFont(ofSize: size, weight: weight),
            .foregroundColor: colour,
            .paragraphStyle: paragraph
        ])
    }
}
