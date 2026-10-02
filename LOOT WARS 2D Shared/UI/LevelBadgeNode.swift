//
//  LevelBadgeNode.swift
//  Loot Wars
//
//  Your level on the title screen, top left: the number, a bar for how far into
//  it you are, and the next thing coming. Tap it for the roadmap.
//
//  The same near-white card as the menu's sheets, so it reads as part of the
//  menu rather than as something left over from a match.
//

import SpriteKit
import UIKit

final class LevelBadgeNode: SKNode {

    static let size = CGSize(width: 176, height: 58)

    override init() {
        super.init()

        let size = LevelBadgeNode.size
        let plate = SKShapeNode(path: CGPath(
            roundedRect: CGRect(x: 0, y: -size.height, width: size.width, height: size.height),
            cornerWidth: 16, cornerHeight: 16, transform: nil))
        plate.fillColor = SKColor(white: 0.99, alpha: 1)
        plate.strokeColor = SKColor(white: 0.78, alpha: 1)
        plate.lineWidth = 3
        addChild(plate)

        let progress = Roadmap.level(forXP: Prefs.totalXP)

        let title = SKLabelNode()
        title.attributedText = MenuButtonNode.text("LEVEL \(progress.level)", size: 15,
                                                   weight: .heavy, colour: RenderPalette.menuInk)
        title.horizontalAlignmentMode = .left
        title.verticalAlignmentMode = .center
        title.position = CGPoint(x: 14, y: -18)
        title.zPosition = 1
        addChild(title)

        // What is next, or that the road is done.
        let next = Roadmap.milestones.first { $0.level > progress.level }
        let note = SKLabelNode()
        note.attributedText = MenuButtonNode.text(
            next.map { "Next: \($0.feature.title)" } ?? "All unlocked",
            size: 11, weight: .semibold, colour: SKColor(white: 0, alpha: 0.5))
        note.horizontalAlignmentMode = .left
        note.verticalAlignmentMode = .center
        note.position = CGPoint(x: 14, y: -size.height + 14)
        note.zPosition = 1
        addChild(note)

        let barWidth: CGFloat = 64
        let barX = size.width - 14 - barWidth
        let track = SKShapeNode(path: CGPath(
            roundedRect: CGRect(x: barX, y: -22, width: barWidth, height: 8),
            cornerWidth: 4, cornerHeight: 4, transform: nil))
        track.fillColor = SKColor(white: 0.88, alpha: 1)
        track.strokeColor = .clear
        track.zPosition = 1
        addChild(track)

        let share = CGFloat(progress.into) / CGFloat(max(1, progress.needed))
        if share > 0 {
            let fill = SKShapeNode(path: CGPath(
                roundedRect: CGRect(x: barX, y: -22, width: max(8, barWidth * share), height: 8),
                cornerWidth: 4, cornerHeight: 4, transform: nil))
            fill.fillColor = RenderPalette.menuPlay.face
            fill.strokeColor = .clear
            fill.zPosition = 2
            addChild(fill)
        }

        if Prefs.devMode {
            let dev = SKLabelNode()
            dev.attributedText = MenuButtonNode.text("DEV", size: 10, weight: .heavy,
                                                     colour: RenderPalette.menuSettings.edge)
            dev.horizontalAlignmentMode = .right
            dev.verticalAlignmentMode = .center
            dev.position = CGPoint(x: size.width - 14, y: -size.height + 14)
            dev.zPosition = 1
            addChild(dev)
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// The node's origin is its top-left corner.
    func contains(localPoint point: CGPoint) -> Bool {
        let size = LevelBadgeNode.size
        return point.x >= -8 && point.x <= size.width + 8
            && point.y <= 8 && point.y >= -size.height - 8
    }

    func press(then done: @escaping () -> Void) {
        run(.sequence([.scale(to: 0.94, duration: 0.05),
                       .scale(to: 1, duration: 0.1),
                       .run(done)]))
    }
}
