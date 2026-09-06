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

    /// The overlay itself: sparkles that come and go around something, over a wash
    /// the colour of whichever perk it is.
    ///
    /// - Parameter box: the width the item is drawn at. Everything scales off it,
    ///   so a 66-point hotbar slot and an item on the map are the same drawing.
    ///
    /// Four of them on a slow, staggered loop, each fading in on its own beat.
    /// Four is the number where at any instant one or two are visible and the
    /// pattern never repeats obviously enough to be counted; at eight it read as a
    /// border made of stars, which is the coloured frame this was avoiding.
    static func overlay(box: CGFloat) -> EnchantNode {
        let overlay = EnchantNode()

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
            star.name = EnchantNode.starName
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

        // And a wash sitting ON the artwork, which is what makes the item itself
        // look treated rather than merely decorated. Its colour is the perk's, set
        // by whoever shows the item - see EnchantNode.
        let sheen = SKSpriteNode(texture: GlowArt.pool)
        sheen.size = CGSize(width: box * 0.95, height: box * 0.95)
        sheen.colorBlendFactor = 1
        sheen.alpha = 0.30
        sheen.zPosition = 2
        sheen.blendMode = .add

        sheen.run(.repeatForever(.sequence([
            .fadeAlpha(to: 0.14, duration: 1.1),
            .fadeAlpha(to: 0.30, duration: 1.1)
        ])))

        overlay.addChild(sheen)
        overlay.sheen = sheen
        overlay.tint(for: .overdrive)
        return overlay
    }
}

/// An enchanted overlay whose wash can be recoloured after it is built.
///
/// The recolouring is the whole reason this is a class rather than a plain SKNode.
/// A hotbar slot builds ONE of these when the bar is built and then shows a
/// hundred different items in it over a match - rebuilding the overlay per item
/// would restart the twinkle every time anything at all happened to your
/// inventory, and the sparkles would never finish a cycle. So the node is
/// permanent and its colour is not.
final class EnchantNode: SKNode {

    /// What the twinkling stars answer to when the rainbow needs to reach them.
    fileprivate static let starName = "enchant.star"

    /// The key both recolour loops run under, so switching from a power-up to a
    /// piece of Epic gear in the same slot can stop them by name.
    private static let cycleKey = "enchant.rainbow"

    fileprivate var sheen: SKSpriteNode?

    /// What this overlay is currently wearing, and the only reason it is recorded
    /// is that asking for it again must do NOTHING.
    ///
    /// A hotbar slot rewrites itself every frame - the icon, the count, the glow,
    /// and this - which is harmless when the answer is a colour and fatal when the
    /// answer is an animation: restarting the walk sixty times a second pins it on
    /// its first hue forever, and the rainbow becomes a flat red wash that nobody
    /// can explain. Exactly the shape of bug the shop card and the quick-buy prompt
    /// both had, so it is worth naming: anything here that ANIMATES has to survive
    /// being asked for again.
    private var wearingRainbow = false
    private var flat: SKColor?

    /// A power-up refuses to settle on a colour.
    ///
    /// Every other enchanted thing in the game wears one - a rarity, held still.
    /// This walks the whole ring, slowly, and the walk is the claim: the only item
    /// that does four things at once is the only thing on screen that will not pick
    /// a colour.
    ///
    /// Slow on purpose - about six seconds for a full turn, which is most of the
    /// nine the perk itself runs for. Fast enough that a bottle sitting in a slot
    /// visibly moves through it while you decide whether to drink it, slow enough
    /// that it never reads as flashing, which is a warning everywhere else in this
    /// game and would be a lie here.
    ///
    /// The stars take the same walk a few steps ahead of the wash. Together rather
    /// than in step, so the item is never one flat colour - there is always a glint
    /// on it from further round the ring than the wash underneath.
    func shimmer() {
        guard !wearingRainbow else { return }
        wearingRainbow = true
        flat = nil

        let step = 0.75

        func walk(from offset: Int, blend: CGFloat) -> SKAction {
            .repeatForever(.sequence(RenderPalette.spectrum.indices.map { index -> SKAction in
                .colorize(with: RenderPalette.hue(at: index + offset),
                          colorBlendFactor: blend,
                          duration: step)
            }))
        }

        sheen?.removeAction(forKey: EnchantNode.cycleKey)
        sheen?.run(walk(from: 0, blend: 1), withKey: EnchantNode.cycleKey)

        for star in children where star.name == EnchantNode.starName {
            guard let star = star as? SKSpriteNode else { continue }
            star.removeAction(forKey: EnchantNode.cycleKey)

            // Never fully coloured. A sparkle is a glint before it is a hue, and a
            // star painted solid violet stops reading as light coming off a
            // surface - so the rainbow only ever gets two thirds of it and the
            // near-white underneath keeps it a glint.
            star.run(walk(from: 3, blend: 0.66), withKey: EnchantNode.cycleKey)
        }
    }

    /// The wash takes one colour and holds it, which is what everything except a
    /// power-up does.
    func tint(_ colour: SKColor) {
        if !wearingRainbow, let flat, flat.isEqual(colour) { return }
        wearingRainbow = false
        flat = colour

        sheen?.removeAction(forKey: EnchantNode.cycleKey)
        sheen?.color = colour

        for star in children where star.name == EnchantNode.starName {
            guard let star = star as? SKSpriteNode else { continue }
            star.removeAction(forKey: EnchantNode.cycleKey)
            star.color = RenderPalette.perkSpark
            star.colorBlendFactor = 1
        }
    }

    /// A perk never gets a colour, only the ring.
    ///
    /// Still takes the perk rather than ignoring it, because the day there are two
    /// again this is where the second one's colour goes - and a caller that had
    /// stopped passing it would have to be found and fixed first.
    func tint(for perk: Perk) {
        switch perk {
        case .overdrive: shimmer()
        }
    }

    /// Whatever the item's own colour is: a power-up's is the rainbow, and
    /// everything else's is its rarity.
    ///
    /// The one place that choice is made, so a Cosmic blaster in a hotbar, the same
    /// blaster lying on the grass and the same blaster on a shop card cannot end up
    /// glowing three different colours.
    func tint(for type: ItemType) {
        if let perk = type.perk {
            tint(for: perk)
            return
        }

        tint(RenderPalette.colour(of: type.rarity))
    }
}
