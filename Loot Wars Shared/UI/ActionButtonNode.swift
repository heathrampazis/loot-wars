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

    private let base: SKShapeNode
    private let glyph = SKSpriteNode()

    private(set) var isPressed = false
    private(set) var isEnabled = true
    private(set) var isHighlighted = false

    init(glyph texture: SKTexture,
         radius: CGFloat = 62,
         grabRadius: CGFloat = 105,
         shape: Shape = .circle,
         fill: SKColor = RenderPalette.controlBackground,
         glyphSize: CGFloat? = nil,
         glass: Bool = false,
         shadow: Bool = false) {
        self.grabRadius = grabRadius
        // Defaults to half the button, which is right for art that already has its
        // own margin. The drawn glyphs do not, so they say how big they want to be.
        self.glyphSize = glyphSize ?? radius
        self.shape = shape

        switch shape {
        case .circle:
            self.base = SKShapeNode(circleOfRadius: radius)
        case .roundedSquare:
            // Corner radius measured off the reference at 0.16 of the side.
            self.base = SKShapeNode(
                rect: CGRect(x: -radius, y: -radius, width: radius * 2, height: radius * 2),
                cornerRadius: radius * 2 * 0.16)
        }

        super.init()

        base.fillColor = fill
        base.strokeColor = RenderPalette.glassRim
        base.lineWidth = RenderPalette.glassRimWidth
        // Frosted map behind it - see GlassNode. Only where asked.
        if glass, let path = base.path { base.addChild(GlassNode(path: path)) }

        // A soft shadow under it, the menu buttons' own, lighter here so it lifts
        // the button off the map without drawing a dark ring round it. A sibling
        // of the base rather than a child, so it stays put while the base breathes.
        if shadow {
            let under = MenuButtonNode.dropShadow(
                width: radius * 2, height: radius * 2,
                corner: shape == .circle ? radius : radius * 2 * 0.16)
            under.zPosition = -2
            under.alpha = 0.7
            addChild(under)
        }

        glyph.alpha = 0.85

        zPosition = 1000
        addChild(base)
        addChild(glyph)

        setGlyph(texture)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Swaps what the button does the job of. The caller decides when that is safe -
    /// changing it under a thumb that is already pressing would be the worst
    /// possible moment.
    func setGlyph(_ texture: SKTexture) {
        glyph.texture = texture

        // Fit the art inside the glyph box rather than squashing it to a square.
        let art = texture.size()
        let scale = art.width > 0 && art.height > 0
            ? min(glyphSize / art.width, glyphSize / art.height)
            : 1
        glyph.size = CGSize(width: art.width * scale, height: art.height * scale)
    }

    /// Drawn faint when the simulation would refuse the press, exactly as a hotbar
    /// slot greys out - so a button you can see but not use looks the part rather
    /// than looking broken.
    /// Green: the button is recommending itself - a heal you should take, a bomb
    /// lined up on a wall. A bright green rim round the usual see-through disc,
    /// and the disc breathes gently while it stays green, so it reads as "press
    /// me" rather than as a colour change.
    func setHighlighted(_ on: Bool) {
        guard on != isHighlighted else { return }
        isHighlighted = on
        base.strokeColor = on ? RenderPalette.recommend : RenderPalette.glassRim
        base.lineWidth = on ? 4 : RenderPalette.glassRimWidth
        glyph.alpha = on ? 1 : 0.85

        // The breathing is on the disc alone: the whole button's scale belongs to
        // the press, and the art staying still keeps it easy to read.
        base.removeAction(forKey: "invite")
        base.setScale(1)
        guard on else { return }

        base.run(.sequence([
            .scale(to: 1.14, duration: 0.1),
            .scale(to: 1, duration: 0.12),
            .repeatForever(.sequence([
                .scale(to: 1.07, duration: 0.55),
                .scale(to: 1, duration: 0.55)
            ]))
        ]), withKey: "invite")
    }

    func setEnabled(_ enabled: Bool) {
        guard enabled != isEnabled else { return }
        isEnabled = enabled
        alpha = enabled ? 1.0 : 0.4
    }

    /// - Parameter localPoint: the touch, in this node's own coordinate space.
    /// - Returns: true if the button is taking ownership of this touch.
    func begin(atLocalPoint localPoint: CGPoint) -> Bool {
        // The catch follows the shape, so a square button is not quietly pressable
        // at its corners' diagonal and a round one is not pressable off its edge.
        let caught: Bool
        switch shape {
        case .circle:
            caught = hypot(localPoint.x, localPoint.y) <= grabRadius
        case .roundedSquare:
            caught = abs(localPoint.x) <= grabRadius && abs(localPoint.y) <= grabRadius
        }

        guard caught else { return false }
        isPressed = true
        setScale(0.92)
        return true
    }

    /// A small wave, for a button nobody has pressed.
    ///
    /// Rotation and scale only, never position: the scene's layout owns where a
    /// button sits, and an interrupted move would leave it parked somewhere the
    /// layout would not put it back from until the next size change.
    func nudge() {
        removeAction(forKey: "nudge")
        zRotation = 0
        setScale(1)

        run(.sequence([
            .group([.scale(to: 1.14, duration: 0.11), .rotate(toAngle: -0.10, duration: 0.11)]),
            .rotate(toAngle: 0.10, duration: 0.14),
            .group([.scale(to: 1.0, duration: 0.12), .rotate(toAngle: 0, duration: 0.12)])
        ]), withKey: "nudge")
    }

    func end() {
        isPressed = false
        setScale(1.0)
    }
}
