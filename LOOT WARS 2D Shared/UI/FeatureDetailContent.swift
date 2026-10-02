//
//  FeatureDetailContent.swift
//  Loot Wars
//
//  One roadmap unlock, up close: the art, the level it comes at, what it does,
//  and how far away it is. Opened by tapping a card on the roadmap; Back returns
//  to the roadmap where you left it.
//

import SpriteKit
import UIKit

final class FeatureDetailContent: MenuSheetContent {

    let node = SKNode()

    /// Called when Back is tapped.
    var onBack: (() -> Void)?

    /// The feature on show, and the level it unlocks at.
    var feature: Feature = .strength
    var level: Int = 5

    private static let backHeight: CGFloat = 44
    private var width: CGFloat = 0
    private var backTop: CGFloat = 0

    func preferredCardWidth(for screen: CGSize) -> CGFloat? {
        min(screen.width * 0.7, 480)
    }

    func layOut(width: CGFloat, maxHeight: CGFloat) -> CGFloat {
        self.width = width
        node.removeAllChildren()

        let current = Progress.level
        let unlocked = feature.isUnlocked(atLevel: current, unlockLevel: level)

        // The art, on the left, on a soft plate.
        let artSide: CGFloat = 96
        let plate = SKShapeNode(path: CGPath(
            roundedRect: CGRect(x: -artSide / 2, y: -artSide / 2, width: artSide, height: artSide),
            cornerWidth: 18, cornerHeight: 18, transform: nil))
        plate.fillColor = SKColor(white: unlocked ? 0.95 : 0.92, alpha: 1)
        plate.strokeColor = unlocked ? RenderPalette.menuPlay.face : SKColor(white: 0.84, alpha: 1)
        plate.lineWidth = 3
        plate.position = CGPoint(x: -width / 2 + artSide / 2 + 4, y: -artSide / 2 - 6)
        node.addChild(plate)

        let texture = ItemArt.texture(for: feature.item)
        let art = SKSpriteNode(texture: texture, size: ItemArt.size(of: texture, fittingInto: artSide * 0.72))
        art.zPosition = 1
        if !unlocked {
            art.color = SKColor(white: 0.55, alpha: 1)
            art.colorBlendFactor = 0.6
        }
        plate.addChild(art)

        // The words, on the right.
        let left = plate.position.x + artSide / 2 + 18
        let textWidth = width / 2 - left - 4

        let tag = SKLabelNode()
        tag.attributedText = MenuButtonNode.text("LEVEL \(level)", size: 12, weight: .heavy,
                                                 colour: unlocked ? RenderPalette.menuPlay.edge
                                                                  : SKColor(white: 0, alpha: 0.45))
        tag.horizontalAlignmentMode = .left
        tag.verticalAlignmentMode = .top
        tag.position = CGPoint(x: left, y: -6)
        node.addChild(tag)

        let status = SKLabelNode()
        let toGo = level - current
        let statusText = unlocked ? "Unlocked"
            : (toGo == 1 ? "Unlocks next level" : "Unlocks in \(toGo) levels")
        status.attributedText = MenuButtonNode.text(statusText, size: 12, weight: .bold,
                                                    colour: unlocked ? RenderPalette.menuPlay.edge
                                                                     : RenderPalette.menuSettings.edge)
        status.horizontalAlignmentMode = .left
        status.verticalAlignmentMode = .top
        status.position = CGPoint(x: left, y: -24)
        node.addChild(status)

        let body = SKLabelNode()
        body.attributedText = MenuButtonNode.text(feature.detail, size: 14, weight: .regular,
                                                  colour: RenderPalette.menuInk)
        body.numberOfLines = 0
        body.preferredMaxLayoutWidth = textWidth
        body.horizontalAlignmentMode = .left
        body.verticalAlignmentMode = .top
        body.position = CGPoint(x: left, y: -46)
        node.addChild(body)

        // Back, under whichever is taller.
        let contentBottom = min(plate.position.y - artSide / 2, body.position.y - body.frame.height)
        backTop = contentBottom - 14

        let back = SKLabelNode()
        back.attributedText = MenuButtonNode.text("‹  Back to roadmap", size: 14, weight: .bold,
                                                  colour: RenderPalette.menuInfo.edge)
        back.verticalAlignmentMode = .center
        back.position = CGPoint(x: 0, y: backTop - FeatureDetailContent.backHeight / 2)
        node.addChild(back)

        return -backTop + FeatureDetailContent.backHeight
    }

    func tap(at point: CGPoint) {
        guard abs(point.x) <= width / 2,
              point.y <= backTop, point.y >= backTop - FeatureDetailContent.backHeight else { return }
        SoundPlayer.shared.play(.exit)
        onBack?()
    }
}

private extension Feature {
    func isUnlocked(atLevel current: Int, unlockLevel: Int) -> Bool {
        Prefs.devMode || current >= unlockLevel
    }
}
