//
//  LevelBadgeNode.swift
//  Loot Wars
//
//  Your profile corner on the title screen, bottom left: a profile icon, your
//  level and an XP bar. Built like the menu's buttons - a flat face edged in a
//  darker shade, on a soft drop shadow - in its own purple. Tap it for the
//  roadmap.
//

import SpriteKit
import UIKit

final class LevelBadgeNode: SKNode {

    static let size = CGSize(width: 156, height: 56)

    private static let edge: CGFloat = 4
    private static let corner: CGFloat = 13
    private static let padding: CGFloat = 8

    override init() {
        super.init()

        let size = LevelBadgeNode.size
        let tone = RenderPalette.menuProfile
        let progress = Roadmap.level(forXP: Prefs.totalXP)

        // The button body, centred - the node's origin is its top-left corner.
        let body = SKNode()
        body.position = CGPoint(x: size.width / 2, y: -size.height / 2)
        addChild(body)

        body.addChild(MenuButtonNode.dropShadow(width: size.width, height: size.height,
                                                corner: LevelBadgeNode.corner))
        body.addChild(MenuButtonNode.slab(width: size.width, height: size.height,
                                          edge: LevelBadgeNode.edge,
                                          corner: LevelBadgeNode.corner,
                                          tone: tone))

        // The profile tile: the edge colour, set into the face.
        let pad = LevelBadgeNode.padding
        let square = size.height - pad * 2
        let tile = SKShapeNode(path: CGPath(
            roundedRect: CGRect(x: pad, y: -pad - square, width: square, height: square),
            cornerWidth: 9, cornerHeight: 9, transform: nil))
        tile.fillColor = tone.edge
        tile.strokeColor = .clear
        tile.zPosition = 1
        addChild(tile)

        let icon = SKSpriteNode(texture: Glyphs.profile,
                                size: CGSize(width: square * 0.64, height: square * 0.64))
        icon.position = CGPoint(x: pad + square / 2, y: -size.height / 2)
        icon.zPosition = 2
        addChild(icon)

        // "LEVEL 12" over a white XP bar.
        let left = pad + square + 10
        let right = size.width - 14

        let title = SKLabelNode()
        title.attributedText = MenuButtonNode.text("LEVEL \(progress.level)",
                                                   size: 14, weight: .heavy, colour: .white)
        title.horizontalAlignmentMode = .left
        title.verticalAlignmentMode = .center
        title.position = CGPoint(x: left, y: -size.height / 2 + 8)
        title.zPosition = 2
        addChild(title)

        let barY = -size.height / 2 - 10
        let barHeight: CGFloat = 8
        let barWidth = right - left

        let track = SKShapeNode(path: CGPath(
            roundedRect: CGRect(x: left, y: barY - barHeight / 2, width: barWidth, height: barHeight),
            cornerWidth: barHeight / 2, cornerHeight: barHeight / 2, transform: nil))
        track.fillColor = tone.edge
        track.strokeColor = .clear
        track.zPosition = 2
        addChild(track)

        let share = CGFloat(progress.into) / CGFloat(max(1, progress.needed))
        if share > 0 {
            let fill = SKShapeNode(path: CGPath(
                roundedRect: CGRect(x: left, y: barY - barHeight / 2,
                                    width: max(barHeight, barWidth * min(1, share)),
                                    height: barHeight),
                cornerWidth: barHeight / 2, cornerHeight: barHeight / 2, transform: nil))
            fill.fillColor = .white
            fill.strokeColor = .clear
            fill.zPosition = 3
            addChild(fill)
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
        run(.sequence([.scale(to: 0.95, duration: 0.05),
                       .scale(to: 1, duration: 0.1),
                       .run(done)]))
    }
}
