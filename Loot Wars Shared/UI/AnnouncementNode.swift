//
//  AnnouncementNode.swift
//  Loot Wars
//
//  The one moment of a match that gets a banner: losing your flag (Nov 2026).
//  It first carried raids opening, flags opening and the final thirty too;
//  Heath found those "very distracting", and raids and flags are now live
//  from the start anyway, so the final thirty went back to the hint pill.
//
//  A dark ribbon wipes open across the upper middle of the screen, the title
//  pops onto it, a smaller coloured line slides in under it, and after a
//  moment it folds away. Kept compact and soft so it does not cover the fight.
//

import SpriteKit
import UIKit

final class AnnouncementNode: SKNode {

    /// Smaller and calmer than it was (Nov 2026): Heath, "the big banners in
    /// your face are also very distracting... make it less in your face".
    private static let ribbonSize = CGSize(width: 340, height: 46)
    private static let hold: TimeInterval = 1.6

    private let ribbon = SKSpriteNode(texture: AnnouncementNode.ribbonTexture)
    private let title = SKLabelNode()
    private let titleShade = SKLabelNode()
    private let subtitle = SKLabelNode()

    override init() {
        super.init()
        zPosition = 1080
        isHidden = true

        ribbon.size = AnnouncementNode.ribbonSize
        addChild(ribbon)

        for label in [titleShade, title, subtitle] {
            label.verticalAlignmentMode = .center
            label.horizontalAlignmentMode = .center
            addChild(label)
        }
        titleShade.zPosition = 1
        title.zPosition = 2
        subtitle.zPosition = 2
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Says it. A second call while one is up replaces it.
    func show(_ text: String, subtitle line: String? = nil,
              accent: SKColor = SKColor(red: 1, green: 0.82, blue: 0.29, alpha: 1)) {
        removeAllActions()
        for node in [ribbon, title, titleShade, subtitle] as [SKNode] { node.removeAllActions() }
        isHidden = false
        alpha = 1

        let words = MenuButtonNode.text(text, size: 21, weight: .heavy, colour: .white)
        title.attributedText = words
        titleShade.attributedText = MenuButtonNode.text(text, size: 21, weight: .heavy,
                                                        colour: SKColor(white: 0, alpha: 0.4))
        let lift: CGFloat = line == nil ? 0 : 6
        title.position = CGPoint(x: 0, y: lift)
        titleShade.position = CGPoint(x: 0, y: lift - 2)

        if let line, !line.isEmpty {
            subtitle.attributedText = MenuButtonNode.text(line, size: 10.5, weight: .heavy, colour: accent)
            subtitle.isHidden = false
        } else {
            subtitle.attributedText = nil
            subtitle.isHidden = true
        }
        subtitle.position = CGPoint(x: 0, y: -13)
        subtitle.setScale(1)

        // The ribbon wipes open from the middle.
        ribbon.alpha = 1
        ribbon.xScale = 0.05
        ribbon.yScale = 1
        ribbon.run(Motion.eased(.scaleX(to: 1, duration: 0.24), Motion.cubicOut))

        // The title slams down onto it and settles.
        for label in [title, titleShade] {
            label.alpha = 0
            label.setScale(0.8)
            label.run(.sequence([
                .wait(forDuration: 0.06),
                .group([.fadeIn(withDuration: 0.1), Motion.pop(to: 1, duration: 0.3, overshoot: 1.6)])
            ]))
        }

        // The line under it slides in a beat later.
        if !subtitle.isHidden {
            Motion.slideIn(subtitle, delay: 0.16, from: CGVector(dx: 0, dy: -5), duration: 0.26)
        }

        SoundPlayer.shared.play(.notification)

        run(.sequence([
            .wait(forDuration: AnnouncementNode.hold + 0.3),
            .run { [weak self] in self?.fold() }
        ]), withKey: "life")
    }

    /// Folds away early - the match ending, say.
    func dismiss() {
        removeAllActions()
        isHidden = true
    }

    private func fold() {
        let out: TimeInterval = 0.2
        for label in [title, titleShade, subtitle] {
            label.run(.group([Motion.eased(.fadeOut(withDuration: out), Motion.cubicIn),
                              Motion.eased(.scale(to: 0.85, duration: out), Motion.cubicIn)]))
        }
        ribbon.run(.sequence([
            .wait(forDuration: 0.06),
            .group([Motion.eased(.scaleX(to: 0.05, duration: out), Motion.cubicIn),
                    Motion.eased(.fadeOut(withDuration: out), Motion.cubicIn)])
        ]))
        run(.sequence([.wait(forDuration: out + 0.08), .hide()]), withKey: "life")
    }

    /// Dark in the middle, clear at both ends, so the ribbon has no hard edge
    /// against the map.
    private static let ribbonTexture: SKTexture = {
        let size = CGSize(width: 128, height: 8)
        let format = UIGraphicsImageRendererFormat.default()
        format.opaque = false
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: size, format: format).image { context in
            let dark = UIColor(white: 0, alpha: 0.5).cgColor
            let clear = UIColor(white: 0, alpha: 0).cgColor
            let colours = [clear, dark, dark, clear] as CFArray
            guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                            colors: colours, locations: [0, 0.22, 0.78, 1]) else { return }
            context.cgContext.drawLinearGradient(gradient, start: .zero,
                                                 end: CGPoint(x: size.width, y: 0), options: [])
        }
        return SKTexture(image: image)
    }()
}
