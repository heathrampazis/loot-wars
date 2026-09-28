//
//  SupplyDropRenderer.swift
//  Loot Wars
//
//  The golden crates that land late in a match - see SupplyDropSystem.
//
//  Kept apart from LootboxRenderer because almost nothing about drawing one is
//  the same. An ordinary crate stands still and rocks; this one falls out of the
//  sky, throws a column of light up so it can be seen from across the map, and
//  wears a countdown over its head until it can be opened.
//
//  Everything is noticed from the world rather than announced: a supply drop that
//  appears is one that has just landed, its lock timer is the countdown, and one
//  that disappears has been opened. The fanfare on opening comes from
//  WorldEvent.supplyDropOpened, because a crate vanishing cannot say it was a win.
//

import SpriteKit
import UIKit

final class SupplyDropRenderer {

    let node = SKNode()

    private struct Parts {
        let root: SKNode
        let crate: SKSpriteNode
        let shadow: SKShapeNode
        let rim: SKShapeNode
        let badge: SKNode
        let pill: SKShapeNode
        let label: SKLabelNode
    }

    private var parts: [LootboxID: Parts] = [:]

    /// What each badge last said, so the label is only rebuilt when the number
    /// changes - once a second - rather than every frame.
    private var shown: [LootboxID: String] = [:]

    private var lit: LootboxID?

    /// See ArcadeRenderer.hasSynced: drops already on the map when this renderer
    /// first looks are drawn standing, not dropped in.
    private var hasSynced = false

    private lazy var texture: SKTexture = {
        let made = SKTexture(imageNamed: "LootboxGold")
        made.usesMipmaps = true
        return made
    }()

    /// A little bigger than an ordinary crate, so it reads as special before the
    /// colour does.
    private static let scale: CGFloat = 1.15

    func sync(with world: World) {
        for drop in world.supplyDrops where parts[drop.id] == nil {
            make(drop)
            if hasSynced { land(drop.id) }
        }
        hasSynced = true

        for drop in world.supplyDrops {
            guard let drawn = parts[drop.id] else { continue }
            setBadge(for: drop, on: drawn)
        }

        for (id, gone) in Array(parts) where world.lootboxes[id] == nil {
            parts[id] = nil
            shown[id] = nil
            gone.root.run(.sequence([
                .group([.scale(to: 1.35, duration: 0.14), .fadeOut(withDuration: 0.18)]),
                .removeFromParent()
            ]))
        }

        // The reach rim, asked with the same question the Open button uses, so it
        // can never light on a drop that is still locked.
        let reachable = world.localPlayer.flatMap { player -> LootboxID? in
            guard player.isAlive, let box = world.reachableLootbox(for: player),
                  box.supply else { return nil }
            return box.id
        }
        guard reachable != lit else { return }
        if let lit, let old = parts[lit] { old.rim.run(.fadeAlpha(to: 0, duration: 0.18)) }
        lit = reachable
        if let reachable, let now = parts[reachable] { now.rim.run(.fadeAlpha(to: 0.9, duration: 0.12)) }
    }

    // MARK: - Countdown

    private func setBadge(for drop: Lootbox, on drawn: Parts) {
        let text = drop.isLocked ? "\(Int(drop.lockTimer.rounded(.up)))" : "OPEN"
        guard shown[drop.id] != text else { return }
        let wasLocked = shown[drop.id].map { $0 != "OPEN" } ?? true
        shown[drop.id] = text

        let size: CGFloat = drop.isLocked ? 15 : 13
        drawn.label.attributedText = NSAttributedString(string: text, attributes: [
            .font: UIFont.systemFont(ofSize: size, weight: .heavy),
            .foregroundColor: drop.isLocked ? SKColor.white : RenderPalette.treasure
        ])

        let width = max(34, drawn.label.frame.width + 18)
        let rect = CGRect(x: -width / 2, y: -12, width: width, height: 24)
        drawn.pill.path = CGPath(roundedRect: rect, cornerWidth: 12, cornerHeight: 12, transform: nil)
        // Black either way, like the rest of the interface; OPEN is said in gold.
        drawn.pill.fillColor = SKColor(white: 0, alpha: 0.72)

        if drop.isLocked {
            // A tick on every second: the badge nods, so a glance at it says the
            // clock is running without having to read it.
            drawn.badge.run(.sequence([.scale(to: 1.18, duration: 0.06),
                                       .scale(to: 1, duration: 0.14)]))
        } else if wasLocked {
            // Unlocked: a pop, then a steady pulse for as long as nobody takes it.
            drawn.badge.removeAllActions()
            drawn.badge.run(.sequence([
                .scale(to: 1.4, duration: 0.1),
                .scale(to: 1, duration: 0.16),
                .repeatForever(.sequence([.scale(to: 1.12, duration: 0.35),
                                          .scale(to: 1, duration: 0.35)]))
            ]))
            drawn.crate.run(.sequence([
                .scaleX(to: 1.12, y: 0.88, duration: 0.07),
                .scaleX(to: 0.96, y: 1.06, duration: 0.09),
                .scale(to: 1, duration: 0.12)
            ]))
        }
    }

    // MARK: - Landing

    /// Out of the sky: the crate falls from well above its spot while its shadow
    /// grows underneath it, lands with a squash, and a ring of dust goes out.
    private func land(_ id: LootboxID) {
        guard let drawn = parts[id] else { return }
        let height = GridGeometry.length(ofTiles: 9)

        drawn.crate.position.y = height
        drawn.crate.alpha = 0
        drawn.shadow.setScale(0.25)
        drawn.shadow.alpha = 0.1
        drawn.badge.alpha = 0

        let fall = SKAction.moveTo(y: 0, duration: 0.55)
        fall.timingMode = .easeIn
        drawn.crate.run(.sequence([
            .group([fall, .fadeIn(withDuration: 0.2)]),
            .scaleX(to: 1.25, y: 0.75, duration: 0.06),
            .scaleX(to: 0.92, y: 1.1, duration: 0.1),
            .scale(to: 1, duration: 0.12)
        ]))
        drawn.shadow.run(.group([.scale(to: 1, duration: 0.55),
                                 .fadeAlpha(to: 0.28, duration: 0.55)]))
        drawn.badge.run(.sequence([.wait(forDuration: 0.7), .fadeIn(withDuration: 0.2)]))

        let dust = SKShapeNode(circleOfRadius: GridGeometry.length(ofTiles: 0.6))
        dust.fillColor = .clear
        dust.strokeColor = SKColor(white: 1, alpha: 0.85)
        dust.lineWidth = 5
        dust.alpha = 0
        dust.zPosition = -0.5
        drawn.root.addChild(dust)
        dust.run(.sequence([
            .wait(forDuration: 0.55),
            .fadeAlpha(to: 1, duration: 0.01),
            .group([.scale(to: 3.2, duration: 0.4), .fadeOut(withDuration: 0.4)]),
            .removeFromParent()
        ]))
    }

    // MARK: - Building

    private func make(_ drop: Lootbox) {
        let size = CGSize(
            width: GridGeometry.length(ofTiles: GameConfig.Loot.lootboxSize.x) * SupplyDropRenderer.scale,
            height: GridGeometry.length(ofTiles: GameConfig.Loot.lootboxSize.y) * SupplyDropRenderer.scale)

        let root = SKNode()
        root.position = GridGeometry.point(for: drop.position)
        root.zPosition = 3      // with the crates: above trees, below walls and actors

        let shadow = SKShapeNode(ellipseOf: CGSize(width: size.width * 1.05, height: size.height * 0.5))
        shadow.fillColor = .black
        shadow.strokeColor = .clear
        shadow.alpha = 0.28
        shadow.position = CGPoint(x: 0, y: -size.height * 0.45)
        shadow.zPosition = -2
        root.addChild(shadow)

        // A pool of gold light on the ground, breathing.
        let glow = SKSpriteNode(texture: GlowArt.pool)
        glow.size = CGSize(width: size.width * 2.8, height: size.width * 2.8)
        glow.color = RenderPalette.treasure
        glow.colorBlendFactor = 1
        glow.alpha = 0.75
        glow.zPosition = -1
        root.addChild(glow)
        glow.run(.repeatForever(.sequence([
            .group([.fadeAlpha(to: 0.45, duration: 0.8), .scale(to: 0.88, duration: 0.8)]),
            .group([.fadeAlpha(to: 0.75, duration: 0.8), .scale(to: 1.0, duration: 0.8)])
        ])))

        // And a column of it going up, which is what lets you spot one from across
        // the map before the compass has told you where to look.
        let beam = SKSpriteNode(texture: SupplyDropRenderer.beamTexture)
        beam.size = CGSize(width: size.width * 0.9, height: GridGeometry.length(ofTiles: 6))
        beam.anchorPoint = CGPoint(x: 0.5, y: 0)
        beam.color = RenderPalette.treasure
        beam.colorBlendFactor = 1
        beam.blendMode = .add
        beam.alpha = 0.55
        beam.zPosition = -0.8
        root.addChild(beam)
        beam.run(.repeatForever(.sequence([.fadeAlpha(to: 0.3, duration: 0.9),
                                           .fadeAlpha(to: 0.55, duration: 0.9)])))

        let crate = SKSpriteNode(texture: texture, size: size)
        root.addChild(crate)

        let rim = SKShapeNode(rect: CGRect(x: -size.width / 2 - 3, y: -size.height / 2 - 3,
                                           width: size.width + 6, height: size.height + 6),
                              cornerRadius: 6)
        rim.strokeColor = .white
        rim.lineWidth = 2
        rim.fillColor = .clear
        rim.alpha = 0
        rim.zPosition = 1
        crate.addChild(rim)

        // The countdown, over its head. Up in the actors' band so a person standing
        // behind the crate does not hide the one number everybody is watching.
        let badge = SKNode()
        badge.position = CGPoint(x: 0, y: size.height / 2 + 22)
        badge.zPosition = 70

        let pill = SKShapeNode()
        pill.strokeColor = .black
        pill.lineWidth = 2.5
        badge.addChild(pill)

        let label = SKLabelNode()
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        label.zPosition = 1
        badge.addChild(label)
        root.addChild(badge)

        node.addChild(root)
        parts[drop.id] = Parts(root: root, crate: crate, shadow: shadow, rim: rim,
                               badge: badge, pill: pill, label: label)
    }

    /// A soft vertical fade, white at the bottom to nothing at the top, tinted
    /// gold where it is used.
    private static let beamTexture: SKTexture = {
        let size = CGSize(width: 32, height: 128)
        let format = UIGraphicsImageRendererFormat.default()
        format.opaque = false

        let image = UIGraphicsImageRenderer(size: size, format: format).image { context in
            let colours = [SKColor(white: 1, alpha: 0).cgColor,
                           SKColor(white: 1, alpha: 0.9).cgColor]
            guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                            colors: colours as CFArray,
                                            locations: [0, 1]) else { return }
            // Image space runs top-down: transparent at the top, solid at the foot.
            context.cgContext.drawLinearGradient(gradient,
                                                 start: CGPoint(x: 0, y: 0),
                                                 end: CGPoint(x: 0, y: size.height),
                                                 options: [])

            // Softened at the sides so it reads as light rather than a bar.
            context.cgContext.setBlendMode(.destinationIn)
            let sides = [SKColor(white: 1, alpha: 0).cgColor,
                         SKColor(white: 1, alpha: 1).cgColor,
                         SKColor(white: 1, alpha: 0).cgColor]
            if let fade = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                     colors: sides as CFArray, locations: [0, 0.5, 1]) {
                context.cgContext.drawLinearGradient(fade,
                                                     start: CGPoint(x: 0, y: 0),
                                                     end: CGPoint(x: size.width, y: 0),
                                                     options: [])
            }
        }

        let texture = SKTexture(image: image)
        texture.usesMipmaps = true
        return texture
    }()
}
