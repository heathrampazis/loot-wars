//
//  EnchantArt.swift
//  Loot Wars
//
//  The sheen on a power-up.
//
//  One drawing used in two places - the slot in your hotbar and the item lying on
//  the grass - for the reason ItemSlotNode was extracted: an enchanted thing that
//  looks enchanted in the bar and ordinary on the ground is two items as far as a
//  player is concerned.
//
//  Sparkles rather than a coloured frame, and the difference matters at this size.
//  Every other thing this game says about an item is said with COLOUR - the rarity
//  pool under it, the green of a sell tab, the red of a price you cannot pay - so
//  one more colour would have had to compete with all of them to mean anything. A
//  thing that MOVES says something none of the colours can: this is not just a
//  better version of an item, it is a different kind of object.
//

import SpriteKit
import UIKit

enum EnchantArt {

    /// A four-pointed star with a bright core, drawn once and tinted at use.
    static let spark: SKTexture = {
        let side: CGFloat = 64
        let centre = CGPoint(x: side / 2, y: side / 2)

        let format = UIGraphicsImageRendererFormat.default()
        format.opaque = false

        let image = UIGraphicsImageRenderer(
            size: CGSize(width: side, height: side), format: format
        ).image { context in
            let path = UIBezierPath()
            let long = side * 0.5
            let waist = side * 0.085

            // Two concave arms crossed: straight diagonals would draw a diamond,
            // and a diamond reads as a gem rather than as a glint.
            path.move(to: CGPoint(x: centre.x, y: centre.y - long))
            path.addQuadCurve(to: CGPoint(x: centre.x + long, y: centre.y),
                              controlPoint: CGPoint(x: centre.x + waist, y: centre.y - waist))
            path.addQuadCurve(to: CGPoint(x: centre.x, y: centre.y + long),
                              controlPoint: CGPoint(x: centre.x + waist, y: centre.y + waist))
            path.addQuadCurve(to: CGPoint(x: centre.x - long, y: centre.y),
                              controlPoint: CGPoint(x: centre.x - waist, y: centre.y + waist))
            path.addQuadCurve(to: CGPoint(x: centre.x, y: centre.y - long),
                              controlPoint: CGPoint(x: centre.x - waist, y: centre.y - waist))
            path.close()

            SKColor.white.setFill()
            path.fill()
        }

        let texture = SKTexture(image: image)
        texture.usesMipmaps = true
        return texture
    }()

    /// The overlay itself: sparkles that come and go around something.
    ///
    /// - Parameter box: the width the item is drawn at. Everything scales off it,
    ///   so a 66-point hotbar slot and an item on the map are the same drawing.
    ///
    /// Four of them on a slow, staggered loop, each fading in on its own beat.
    /// Four is the number where at any instant one or two are visible and the
    /// pattern never repeats obviously enough to be counted; at eight it read as a
    /// border made of stars, which is the coloured frame this was avoiding.
    static func overlay(box: CGFloat) -> SKNode {
        let overlay = SKNode()

        let radius = box * 0.44
        let places: [(CGFloat, CGFloat)] = [
            (0.35, 0.9), (-0.75, 0.4), (0.8, -0.35), (-0.3, -0.85)
        ]

        for (index, place) in places.enumerated() {
            let star = SKSpriteNode(texture: spark)
            let size = box * CGFloat.random(in: 0.20...0.30)

            star.size = CGSize(width: size, height: size)
            star.color = RenderPalette.perkSpark
            star.colorBlendFactor = 1
            star.position = CGPoint(x: place.0 * radius, y: place.1 * radius)
            star.alpha = 0
            star.zPosition = 3
            star.blendMode = .add

            // Each on its own quarter of the cycle, so they twinkle in turn rather
            // than flashing together like an alarm.
            star.run(.sequence([
                .wait(forDuration: Double(index) * 0.55),
                .repeatForever(.sequence([
                    .group([.fadeAlpha(to: 0.95, duration: 0.28),
                            .scale(to: 1.25, duration: 0.28),
                            .rotate(byAngle: 0.5, duration: 0.28)]),
                    .group([.fadeAlpha(to: 0, duration: 0.42),
                            .scale(to: 0.55, duration: 0.42),
                            .rotate(byAngle: 0.5, duration: 0.42)]),
                    .wait(forDuration: 1.4)
                ]))
            ]))

            overlay.addChild(star)
        }

        // And a violet wash sitting ON the artwork, which is what makes the item
        // itself look treated rather than merely decorated.
        let sheen = SKSpriteNode(texture: GlowArt.pool)
        sheen.size = CGSize(width: box * 0.95, height: box * 0.95)
        sheen.color = RenderPalette.perkAura
        sheen.colorBlendFactor = 1
        sheen.alpha = 0.30
        sheen.zPosition = 2
        sheen.blendMode = .add

        sheen.run(.repeatForever(.sequence([
            .fadeAlpha(to: 0.14, duration: 1.1),
            .fadeAlpha(to: 0.30, duration: 1.1)
        ])))

        overlay.addChild(sheen)
        return overlay
    }
}
