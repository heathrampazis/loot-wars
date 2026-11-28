//
//  ActionButtonNode.swift
//  Loot Wars
//
//  A round button.
//
//  It reports state and nothing more: it does not know what it is for. GameScene
//  turns a press into a Command and the simulation decides what that means.
//
//  Two of these exist. The big one shares the aim stick's corner, only ever one of
//  them on screen - the stick while there is shooting to do, the button while there
//  is something in reach to open. The small one sits above it and uses whatever you
//  have picked out of the hotbar. See GameScene.updateRightControl for why the
//  corner's swap waits for a lull.
//
//  RAISED (Nov 2026): Heath wanted the buttons to stop being "super static" and
//  chose the chunky 3D look for all of them. Given a tone, a button is a solid
//  coloured face standing on a darker lip (see ButtonArt): a finger pushes the
//  face down onto the lip and letting go springs it back up. Without a tone it
//  is the dark glass disc, exactly as it always was (the shop keeps it).
//

import Foundation
import SpriteKit

final class ActionButtonNode: SKNode {

    /// Round for the things you press mid-fight, square for the ones that open a
    /// menu. Not decoration: a shape is the fastest thing to tell apart without
    /// reading, so a control and a way out of the game should not share one.
    enum Shape {
        case circle
        case roundedSquare
    }

    /// Grab radius is generous, like the joystick - thumbs are imprecise. Note the
    /// small button's is proportionally MORE generous than the big one's, because
    /// a small target needs the help and the big one does not.
    private let grabRadius: CGFloat
    private let glyphSize: CGFloat
    private let shape: Shape

    /// The glass disc, or - on a raised button - the ring that lights up when
    /// the button is recommending itself.
    private let base: SKShapeNode
    private let glyph = SKSpriteNode()

    /// What moves when pressed: the face and everything on it. The lip and the
    /// shadow stay put.
    private let face = SKNode()
    /// The glyph's darker copy just under it, on a raised button.
    private let glyphShade = SKSpriteNode()
    private let raised: Bool
    /// How far the face goes down when pressed: the lip's height.
    private let depth: CGFloat

    /// How strongly the glyph shows when the button is not recommending itself.
    private let restingGlyphAlpha: CGFloat

    private(set) var isPressed = false
    private(set) var isEnabled = true
    private(set) var isHighlighted = false

    init(glyph texture: SKTexture,
         radius: CGFloat = 62,
         grabRadius: CGFloat = 105,
         shape: Shape = .circle,
         fill: SKColor = RenderPalette.controlBackground,
         tone: RenderPalette.MenuTone? = nil,
         glyphSize: CGFloat? = nil,
         glass: Bool = false,
         shadow: Bool = false,
         glyphAlpha: CGFloat = 0.85,
         caption: String? = nil) {
        self.grabRadius = grabRadius
        self.raised = tone != nil
        self.restingGlyphAlpha = tone != nil ? 1 : glyphAlpha
        self.glyphSize = glyphSize ?? radius
        self.shape = shape
        let side = radius * 2
        let corner = shape == .circle ? radius : side * 0.16
        // A glass button is exactly as it always was (Nov 2026): a shallow lip
        // under it was tried and read as "weird layering".
        self.depth = tone != nil ? ButtonArt.depth(for: side) : 0

        if tone != nil {
            // The ring that lights up: a little outside the face.
            let ring = radius + 5
            switch shape {
            case .circle:
                self.base = SKShapeNode(circleOfRadius: ring)
            case .roundedSquare:
                self.base = SKShapeNode(rect: CGRect(x: -ring, y: -ring, width: ring * 2, height: ring * 2),
                                        cornerRadius: corner + 5)
            }
        } else {
            switch shape {
            case .circle:
                self.base = SKShapeNode(circleOfRadius: radius)
            case .roundedSquare:
                self.base = SKShapeNode(
                    rect: CGRect(x: -radius, y: -radius, width: side, height: side),
                    cornerRadius: corner)
            }
        }
        super.init()
        zPosition = 1000

        // No drop shadow under a raised button (Nov 2026): the lip is its
        // depth, and a shadow under the lip too read as one layer too many -
        // Heath, "the game buttons have a weird layering".
        if shadow && tone == nil {
            let under = MenuButtonNode.dropShadow(width: side, height: side, corner: corner)
            under.zPosition = -2
            under.alpha = 0.7
            under.position = CGPoint(x: 0, y: -depth)
            addChild(under)
        }

        if let tone {
            base.fillColor = .clear
            base.strokeColor = .clear
            base.lineWidth = 4
            base.position = CGPoint(x: 0, y: -depth / 2)
            base.zPosition = -1
            addChild(base)

            let parts = ButtonArt.parts(size: CGSize(width: side, height: side), corner: corner, tone: tone)
            addChild(parts.lip)
            addChild(face)
            face.addChild(parts.face)

            // No darker copy under the glyph in game (Nov 2026) - another
            // layer that made these look stacked. Kept as a node, hidden, so
            // setGlyph stays simple.
            glyphShade.isHidden = true
            face.addChild(glyphShade)
        } else {
            base.fillColor = fill
            base.strokeColor = RenderPalette.glassRim
            base.lineWidth = RenderPalette.glassRimWidth
            if glass, let path = base.path { base.addChild(GlassNode(path: path)) }
            addChild(face)
            face.addChild(base)
        }

        glyph.alpha = restingGlyphAlpha
        glyph.zPosition = 0.2
        face.addChild(glyph)

        // A word under the glyph, set in the logo's lettering rather than plain
        // type so it reads as part of the button - the shop's SHOP.
        if let caption {
            let art = LogoArt.make(caption, size: radius * 0.4, bounce: false)
            let word = SKSpriteNode(texture: art.texture, size: art.size)
            word.position = CGPoint(x: 0, y: -radius + radius * 0.1 + art.size.height / 2)
            word.zPosition = 0.3
            face.addChild(word)
            glyph.position = CGPoint(x: 0, y: radius * 0.2)
        }

        setGlyph(texture)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Swaps the picture, fitted to the same box whatever its proportions.
    func setGlyph(_ texture: SKTexture) {
        glyph.texture = texture
        let art = texture.size()
        let scale = art.width > 0 && art.height > 0
            ? min(glyphSize / art.width, glyphSize / art.height)
            : 1
        glyph.size = CGSize(width: art.width * scale, height: art.height * scale)

        guard raised else { return }
        glyphShade.texture = texture
        glyphShade.size = glyph.size
        glyphShade.position = CGPoint(x: glyph.position.x,
                                      y: glyph.position.y - max(1.5, (glyphSize * 0.05).rounded()))
    }

    /// Lit up when pressing this is the right call right now: a ring round it
    /// and a slow swell. Eased in and out rather than straight lines.
    func setHighlighted(_ on: Bool) {
        guard on != isHighlighted else { return }
        isHighlighted = on

        if raised {
            base.strokeColor = on ? RenderPalette.recommend : .clear
        } else {
            base.strokeColor = on ? RenderPalette.recommend : RenderPalette.glassRim
            base.lineWidth = on ? 4 : RenderPalette.glassRimWidth
        }
        glyph.alpha = on ? 1 : restingGlyphAlpha

        let pulse: SKNode = raised ? face : base
        pulse.removeAction(forKey: "invite")
        pulse.setScale(1)
        base.removeAction(forKey: "invite")
        base.setScale(1)
        guard on else { return }
        let swell = Motion.eased(.scale(to: 1.06, duration: 0.6), Motion.inOut)
        let back = Motion.eased(.scale(to: 1, duration: 0.6), Motion.inOut)
        pulse.run(.sequence([
            Motion.eased(.scale(to: 1.12, duration: 0.1), Motion.cubicOut),
            Motion.pop(to: 1, duration: 0.26, overshoot: 2),
            .repeatForever(.sequence([swell, back]))
        ]), withKey: "invite")
        if raised {
            base.run(.repeatForever(.sequence([
                Motion.eased(.scale(to: 1.06, duration: 0.6), Motion.inOut),
                Motion.eased(.scale(to: 1, duration: 0.6), Motion.inOut)
            ])), withKey: "invite")
        }
    }

    func setEnabled(_ enabled: Bool) {
        guard enabled != isEnabled else { return }
        isEnabled = enabled
        alpha = enabled ? 1.0 : 0.4
    }

    /// Returns true if the touch landed close enough to count as pressing this.
    func begin(atLocalPoint localPoint: CGPoint) -> Bool {
        let caught: Bool
        switch shape {
        case .circle:
            caught = hypot(localPoint.x, localPoint.y) <= grabRadius
        case .roundedSquare:
            caught = abs(localPoint.x) <= grabRadius && abs(localPoint.y) <= grabRadius
        }
        guard caught else { return false }

        isPressed = true
        removeAction(forKey: "nudge")
        removeAction(forKey: "press")
        face.removeAction(forKey: "press")
        zRotation = 0

        if raised {
            // Down onto the lip, and held there.
            setScale(1)
            face.run(.group([
                Motion.eased(.moveTo(y: -depth, duration: Motion.Time.tap), Motion.cubicOut),
                Motion.eased(.scaleX(to: 1.03, y: 0.95, duration: Motion.Time.tap), Motion.cubicOut)
            ]), withKey: "press")
        } else {
            // The glass button's original squeeze.
            let squash = SKAction.scale(to: 0.86, duration: 0.05)
            squash.timingMode = .easeOut
            run(squash, withKey: "press")
        }
        return true
    }

    /// A small shake to draw the eye - a heal ready, say.
    func nudge() {
        removeAction(forKey: "nudge")
        zRotation = 0
        setScale(1)
        run(.sequence([
            .group([Motion.eased(.scale(to: 1.14, duration: 0.11), Motion.cubicOut),
                    Motion.eased(.rotate(toAngle: -0.10, duration: 0.11), Motion.cubicOut)]),
            Motion.eased(.rotate(toAngle: 0.10, duration: 0.14), Motion.inOut),
            .group([Motion.pop(to: 1, duration: 0.24, overshoot: 2),
                    Motion.eased(.rotate(toAngle: 0, duration: 0.2), Motion.cubicOut)])
        ]), withKey: "nudge")
    }

    /// Let go: springs back up past where it rests and settles.
    func end() {
        let wasPressed = isPressed
        isPressed = false
        removeAction(forKey: "press")

        guard wasPressed else {
            if action(forKey: "nudge") == nil { setScale(1.0) }
            return
        }

        if raised {
            face.removeAction(forKey: "press")
            face.run(.group([
                Motion.eased(.moveTo(y: 0, duration: 0.3)) { Motion.backOut($0, overshoot: 3) },
                Motion.eased(.scaleX(to: 1, y: 1, duration: 0.3)) { Motion.backOut($0, overshoot: 3) }
            ]), withKey: "press")
        } else {
            // The glass button's original spring.
            let spring = SKAction.scale(to: 1.1, duration: 0.08)
            spring.timingMode = .easeOut
            let settle = SKAction.scale(to: 1.0, duration: 0.12)
            settle.timingMode = .easeInEaseOut
            run(.sequence([spring, settle]), withKey: "press")
        }
    }
}
