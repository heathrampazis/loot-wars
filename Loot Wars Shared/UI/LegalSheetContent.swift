//
//  LegalSheetContent.swift
//  Loot Wars
//
//  The Privacy Policy or the Terms of Use, inside the menu sheet: a column of
//  headings and paragraphs that scrolls up and down, with Back underneath.
//  Opened from Settings > About. The words live in LegalText.swift.
//

import SpriteKit
import UIKit

final class LegalSheetContent: MenuSheetContent {

    let node = SKNode()

    /// Called when Back is tapped.
    var onBack: (() -> Void)?

    /// Which document to show. Set before the sheet lays it out.
    var document: LegalDocument = .privacy

    private static let backHeight: CGFloat = 44

    private var width: CGFloat = 0
    private var backTop: CGFloat = 0

    private let crop = SKCropNode()
    private let column = SKEffectNode()

    private var scrollMax: CGFloat = 0
    private var dragStart: CGPoint?
    private var columnStart: CGFloat = 0
    private var velocity: CGFloat = 0
    private var lastDragY: CGFloat = 0
    private var lastDragTime: TimeInterval = 0

    func preferredCardWidth(for screen: CGSize) -> CGFloat? {
        min(screen.width * 0.7, 520)
    }

    func layOut(width: CGFloat, maxHeight: CGFloat) -> CGFloat {
        self.width = width
        node.removeAllChildren()
        crop.removeAllChildren()
        column.removeAllChildren()
        column.removeAllActions()

        // The text, top down. Drawn once into a texture - it never changes while
        // it is open, and that is what keeps the scroll smooth.
        column.shouldRasterize = true
        var y: CGFloat = 0
        let textWidth = width - 8

        func add(_ text: String, size: CGFloat, weight: UIFont.Weight,
                 colour: SKColor, gapAfter: CGFloat) {
            let label = SKLabelNode()
            let paragraph = NSMutableParagraphStyle()
            paragraph.lineSpacing = 3
            label.attributedText = NSAttributedString(string: text, attributes: [
                .font: UIFont.systemFont(ofSize: size, weight: weight),
                .foregroundColor: colour,
                .paragraphStyle: paragraph
            ])
            label.numberOfLines = 0
            label.preferredMaxLayoutWidth = textWidth
            label.horizontalAlignmentMode = .left
            label.verticalAlignmentMode = .top
            label.position = CGPoint(x: -textWidth / 2, y: y)
            column.addChild(label)
            y -= label.frame.height + gapAfter
        }

        add(LegalDocument.updated, size: 12, weight: .semibold,
            colour: SKColor(white: 0, alpha: 0.45), gapAfter: 10)
        add(document.intro, size: 14, weight: .regular,
            colour: RenderPalette.menuInk, gapAfter: 16)

        for section in document.sections {
            add(section.heading, size: 15, weight: .bold,
                colour: RenderPalette.menuInk, gapAfter: 6)
            add(section.body, size: 14, weight: .regular,
                colour: SKColor(white: 0, alpha: 0.7), gapAfter: 16)
        }

        let contentHeight = -y

        // The window it scrolls in: as tall as the sheet allows, never taller
        // than the text.
        let window = min(contentHeight,
                         max(120, maxHeight - LegalSheetContent.backHeight - 12))
        scrollMax = max(0, contentHeight - window)

        let mask = SKSpriteNode(color: .white, size: CGSize(width: width + 8, height: window))
        mask.anchorPoint = CGPoint(x: 0.5, y: 1)
        crop.maskNode = mask
        crop.addChild(column)
        node.addChild(crop)
        column.position = .zero

        // Back, under the window.
        backTop = -window - 8
        let back = SKLabelNode()
        back.attributedText = MenuButtonNode.text("‹  Back", size: 14, weight: .bold,
                                                  colour: RenderPalette.menuInfo.edge)
        back.verticalAlignmentMode = .center
        back.position = CGPoint(x: 0, y: backTop - LegalSheetContent.backHeight / 2)
        node.addChild(back)

        return -backTop + LegalSheetContent.backHeight
    }

    func tap(at point: CGPoint) {
        guard abs(point.x) <= width / 2,
              point.y <= backTop, point.y >= backTop - LegalSheetContent.backHeight else { return }
        SoundPlayer.shared.play(.exit)
        onBack?()
    }

    // MARK: - Scrolling

    func dragBegan(at point: CGPoint) {
        column.removeAction(forKey: "glide")
        dragStart = point
        columnStart = column.position.y
        velocity = 0
        lastDragY = point.y
        lastDragTime = CACurrentMediaTime()
    }

    func dragMoved(to point: CGPoint) {
        guard let start = dragStart else { return }

        let now = CACurrentMediaTime()
        let elapsed = now - lastDragTime
        if elapsed > 0.001 {
            velocity = velocity * 0.15 + (point.y - lastDragY) / CGFloat(elapsed) * 0.85
        }
        lastDragY = point.y
        lastDragTime = now

        // Dragging up moves the text up, which is a larger y here.
        let target = columnStart + (point.y - start.y)
        let clamped = clamp(target)
        column.position.y = clamped + (target - clamped) * 0.3
    }

    func dragEnded(at point: CGPoint) {
        guard dragStart != nil else { return }
        dragStart = nil

        if CACurrentMediaTime() - lastDragTime > 0.08 { velocity = 0 }

        // The same glide the roadmap uses - see RoadmapSheetContent.dragEnded.
        let carry: CGFloat = 0.35
        let speed = max(-4000, min(4000, velocity))
        let target = clamp(column.position.y + speed * carry)
        let duration = TimeInterval(abs(speed) < 50 ? 0.22 : carry * 2)

        let glide = SKAction.moveTo(y: target, duration: duration)
        glide.timingMode = .easeOut
        column.run(glide, withKey: "glide")
    }

    private func clamp(_ y: CGFloat) -> CGFloat {
        min(scrollMax, max(0, y))
    }
}
