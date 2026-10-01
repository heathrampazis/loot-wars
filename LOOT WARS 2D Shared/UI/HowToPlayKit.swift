//
//  HowToPlayKit.swift
//  Loot Wars
//
//  The parts the How to Play pictures are built from - the ground, a person, an
//  item lying on the grass, a crate, a wall block, a hotbar slot, a stick - each
//  drawn the way the match draws it, at the match's own proportions.
//
//  Everything is measured in TILES, `t`, exactly as the game is: a person is
//  0.9 x 1.72 of them, a crate 0.95 x 0.64, a wall one. HowToPlayScenes decides how
//  many points a tile is from the size of the picture, so a scene is the game in
//  miniature rather than a collage of stickers at whatever size looked right.
//

import SpriteKit
import UIKit

enum HowToPlayKit {

    // MARK: - Ground

    /// The checkered grass the whole game is played on, sized to the picture and
    /// with its corners rounded to sit inside the panel. Tiles are centred on the
    /// origin, so anything placed at a whole number of tiles sits on a square.
    static func ground(size: CGSize, tile t: CGFloat) -> SKSpriteNode {
        let key = "\(Int(size.width))x\(Int(size.height))@\(Int(t * 10))"
        if let cached = groundCache[key] {
            return SKSpriteNode(texture: cached, size: size)
        }

        let format = UIGraphicsImageRendererFormat.default()
        format.opaque = false
        let image = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            UIBezierPath(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 11).addClip()

            RenderPalette.floorLight.setFill()
            UIRectFill(CGRect(origin: .zero, size: size))

            // Squares centred on the middle of the picture.
            let cx = size.width / 2, cy = size.height / 2
            let across = Int(size.width / t / 2) + 2
            let down = Int(size.height / t / 2) + 2
            RenderPalette.floorDark.setFill()
            for i in -across...across {
                for j in -down...down where (i + j) % 2 != 0 {
                    UIRectFill(CGRect(x: cx + (CGFloat(i) - 0.5) * t,
                                      y: cy + (CGFloat(j) - 0.5) * t,
                                      width: t, height: t))
                }
            }
        }

        let texture = SKTexture(image: image)
        groundCache[key] = texture
        return SKSpriteNode(texture: texture, size: size)
    }

    private static var groundCache: [String: SKTexture] = [:]

    // MARK: - People

    // A figure, anchored at its feet, standing on its team ring like every person in a match.
    static func person(_ asset: String = "Player", team: TeamID, tile t: CGFloat) -> SKNode {
        let root = SKNode()

        let ring = TeamRing.make(team: team, width: CGFloat(TeamRing.widthInTiles) * t)
        ring.zPosition = -1
        root.addChild(ring)

        let body = SKSpriteNode(texture: SKTexture(imageNamed: asset),
                                size: CGSize(width: 0.9 * t, height: 1.72 * t))
        body.anchorPoint = CGPoint(x: 0.5, y: 0)
        body.position = CGPoint(x: 0, y: -0.1 * t)
        body.name = "body"
        root.addChild(body)

        return root
    }

    /// A walk: the figure bobs and leans as it goes, the way it does in a match.
    static func walk(_ person: SKNode, by offset: CGVector, duration: TimeInterval) -> SKAction {
        let steps = max(1, Int(duration / 0.16))
        let lean: CGFloat = offset.dx >= 0 ? -0.08 : 0.08
        let bounce = SKAction.repeat(.sequence([.moveBy(x: 0, y: 3, duration: 0.08),
                                                .moveBy(x: 0, y: -3, duration: 0.08)]), count: steps)
        return .group([
            .move(by: offset, duration: duration),
            .run { person.childNode(withName: "body")?.run(
                .sequence([.rotate(toAngle: lean, duration: 0.08),
                           .wait(forDuration: max(0, duration - 0.16)),
                           .rotate(toAngle: 0, duration: 0.08)])) },
            .run { person.childNode(withName: "body")?.run(bounce) }
        ])
    }

    /// Swaps what a person is wearing, with the flash a pickup gives.
    static func dress(_ person: SKNode, in asset: String) {
        guard let body = person.childNode(withName: "body") as? SKSpriteNode else { return }
        body.texture = SKTexture(imageNamed: asset)
        body.color = .white
        body.colorBlendFactor = 0.8
        body.run(.group([.colorize(withColorBlendFactor: 0, duration: 0.3),
                         .sequence([.scale(to: 1.15, duration: 0.08), .scale(to: 1, duration: 0.12)])]))
    }

    // A structure's health bar: one tile wide, in its owner's team colour.
    static func healthBar(team: TeamID, tile t: CGFloat) -> (node: SKNode, fill: SKShapeNode, full: CGFloat) {
        let full = t
        let (bar, fill) = BarArt.make(full: full, colour: RenderPalette.colour(for: team))
        return (bar, fill, full)
    }

    static func setBar(_ fill: SKShapeNode, full: CGFloat, share: CGFloat) {
        fill.path = BarArt.path(full: full, filled: max(BarArt.height, full * max(0, min(1, share))))
    }

    // A person's health bar: one tile wide, green to red as it empties, like in a match.
    static func personBar(tile t: CGFloat) -> (node: SKNode, fill: SKShapeNode, full: CGFloat) {
        let full = t
        let (bar, fill) = BarArt.make(full: full, colour: RenderPalette.healthColour(at: 1))
        return (bar, fill, full)
    }

    static func setHealth(_ fill: SKShapeNode, full: CGFloat, share: CGFloat) {
        setBar(fill, full: full, share: share)
        fill.fillColor = RenderPalette.healthColour(at: Double(share))
    }

    // MARK: - Things on the ground

    /// An item lying on the grass, on a pool of its rarity's colour.
    static func groundItem(_ pickup: Pickup, tile t: CGFloat) -> SKNode {
        let root = SKNode()

        if case .item(let type) = pickup {
            let glow = SKSpriteNode(texture: GlowArt.pool)
            glow.size = CGSize(width: 1.3 * t, height: 1.3 * t)
            glow.color = RenderPalette.colour(of: type.rarity)
            glow.colorBlendFactor = 1
            glow.alpha = 0.8
            glow.zPosition = -1
            root.addChild(glow)
            glow.run(.repeatForever(.sequence([.fadeAlpha(to: 0.5, duration: 0.8),
                                               .fadeAlpha(to: 0.8, duration: 0.8)])))
        }

        let texture = ItemArt.texture(for: pickup)
        let sprite = SKSpriteNode(texture: texture, size: ItemArt.size(of: texture, fittingInto: 0.75 * t))
        root.addChild(sprite)
        sprite.run(.repeatForever(.sequence([.moveBy(x: 0, y: 0.06 * t, duration: 0.6),
                                             .moveBy(x: 0, y: -0.06 * t, duration: 0.6)])))
        return root
    }

    /// A crate at its real size.
    static func crate(_ asset: String, tile t: CGFloat) -> SKSpriteNode {
        SKSpriteNode(texture: SKTexture(imageNamed: asset),
                     size: CGSize(width: 0.95 * t * 1.2, height: 0.64 * t * 1.2))
    }

    /// A wall block in a team's colour, one tile square.
    static func wall(team: TeamID, tile t: CGFloat) -> SKSpriteNode {
        SKSpriteNode(texture: BlockRenderer.ghostTexture(for: team),
                     size: CGSize(width: t, height: t))
    }

    /// A shot in flight.
    static func shot(tile t: CGFloat) -> SKShapeNode {
        let shot = SKShapeNode(circleOfRadius: 0.13 * t)
        shot.fillColor = RenderPalette.projectile
        shot.strokeColor = RenderPalette.projectileOutline
        shot.lineWidth = max(1.5, 0.05 * t)
        return shot
    }

    // MARK: - Interface

    /// A hotbar slot with an item in it, and a count if there is more than one.
    static func slot(_ type: ItemType?, count: Int = 1, side: CGFloat) -> SKNode {
        let root = SKNode()
        let panel = SKShapeNode(rect: CGRect(x: -side / 2, y: -side / 2, width: side, height: side),
                                cornerRadius: side * 0.22)
        panel.fillColor = RenderPalette.hotbarSlot
        panel.strokeColor = .clear
        root.addChild(panel)

        guard let type else { return root }

        let glow = SKSpriteNode(texture: GlowArt.pool)
        glow.size = CGSize(width: side, height: side)
        glow.color = RenderPalette.colour(of: type.rarity)
        glow.colorBlendFactor = 1
        glow.alpha = 0.6
        root.addChild(glow)

        let texture = ItemArt.texture(for: type)
        let art = SKSpriteNode(texture: texture, size: ItemArt.size(of: texture, fittingInto: side * 0.68))
        art.zPosition = 1
        root.addChild(art)

        if count > 1 {
            let badge = SKShapeNode(circleOfRadius: side * 0.17)
            badge.fillColor = RenderPalette.countBadge
            badge.strokeColor = .clear
            badge.position = CGPoint(x: side * 0.34, y: side * 0.34)
            badge.zPosition = 2
            let number = SKLabelNode()
            number.attributedText = label("\(count)", size: side * 0.22, colour: .white)
            number.verticalAlignmentMode = .center
            badge.addChild(number)
            root.addChild(badge)
        }
        return root
    }

    /// A thumbstick: the see-through base, and a knob that moves.
    static func stick(radius: CGFloat, glyph: SKTexture? = nil) -> SKNode {
        let base = SKShapeNode(circleOfRadius: radius)
        base.fillColor = RenderPalette.controlBackground
        base.strokeColor = .clear

        let knob = SKShapeNode(circleOfRadius: radius * 0.45)
        knob.name = "knob"
        knob.fillColor = RenderPalette.controlForeground
        knob.strokeColor = .clear
        knob.zPosition = 1
        base.addChild(knob)

        if let glyph {
            let mark = SKSpriteNode(texture: glyph, size: CGSize(width: radius * 0.55, height: radius * 0.55))
            mark.zPosition = 1
            knob.addChild(mark)
        }
        return base
    }

    /// A small dark pill with an icon and a number - the token counter.
    static func counter(icon: SKTexture, text: String, height: CGFloat) -> (node: SKNode, label: SKLabelNode) {
        let root = SKNode()
        let width = height * 2.3
        let pill = SKShapeNode(rect: CGRect(x: -width / 2, y: -height / 2, width: width, height: height),
                               cornerRadius: height / 2)
        pill.fillColor = RenderPalette.hudPanel
        pill.strokeColor = .clear
        root.addChild(pill)

        let mark = SKSpriteNode(texture: icon, size: ItemArt.size(of: icon, fittingInto: height * 0.7))
        mark.position = CGPoint(x: -width / 2 + height * 0.55, y: 0)
        root.addChild(mark)

        let number = SKLabelNode()
        number.attributedText = label(text, size: height * 0.5, colour: .white)
        number.verticalAlignmentMode = .center
        number.horizontalAlignmentMode = .left
        number.position = CGPoint(x: -width / 2 + height * 1.05, y: 0)
        root.addChild(number)
        return (root, number)
    }

    // MARK: - Effects

    /// A burst of stars, the game's hit and pop effect.
    static func burst(at point: CGPoint, in parent: SKNode, colour: SKColor, tile t: CGFloat, count: Int = 6) {
        for n in 0..<count {
            let star = SKSpriteNode(texture: ImpactArt.star)
            let side = 0.35 * t
            star.size = CGSize(width: side, height: side)
            star.color = colour
            star.colorBlendFactor = 0.6
            star.position = point
            star.zPosition = 20
            parent.addChild(star)
            let angle = CGFloat(n) / CGFloat(count) * .pi * 2 + 0.3
            star.run(.sequence([
                .group([.moveBy(x: cos(angle) * 0.8 * t, y: sin(angle) * 0.8 * t, duration: 0.3),
                        .scale(to: 0.3, duration: 0.3),
                        .fadeOut(withDuration: 0.3),
                        .rotate(byAngle: 1.5, duration: 0.3)]),
                .removeFromParent()
            ]))
        }
    }

    /// A number that pops up and floats away, like points on a kill.
    static func popText(_ text: String, at point: CGPoint, in parent: SKNode,
                        colour: SKColor, tile t: CGFloat) {
        let label = SKLabelNode()
        label.attributedText = NSAttributedString(string: text, attributes: [
            .font: UIFont.systemFont(ofSize: 0.5 * t, weight: .heavy),
            .foregroundColor: colour,
            .strokeColor: SKColor.black,
            .strokeWidth: -4.0
        ])
        label.position = point
        label.zPosition = 30
        label.setScale(0.4)
        parent.addChild(label)
        label.run(.sequence([
            .scale(to: 1.15, duration: 0.12),
            .scale(to: 1, duration: 0.08),
            .group([.moveBy(x: 0, y: 0.7 * t, duration: 0.7), .fadeOut(withDuration: 0.7)]),
            .removeFromParent()
        ]))
    }

    static func label(_ text: String, size: CGFloat, colour: SKColor) -> NSAttributedString {
        NSAttributedString(string: text, attributes: [
            .font: UIFont.systemFont(ofSize: size, weight: .heavy),
            .foregroundColor: colour
        ])
    }

    /// A timeline: each step's block runs, then the wait, then the next - and
    /// the whole thing repeats forever.
    static func loop(_ node: SKNode, _ steps: [(TimeInterval, () -> Void)]) {
        var actions: [SKAction] = []
        for (wait, block) in steps {
            actions.append(.run(block))
            actions.append(.wait(forDuration: wait))
        }
        node.run(.repeatForever(.sequence(actions)))
    }
}
