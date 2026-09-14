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

        /// A wide plate with the glyph at one end, for a button that has something
        /// standing beside it INSIDE the same panel.
        ///
        /// This is still a button that does not know what it is for. It knows it is
        /// wider than it is tall and that its glyph therefore belongs at the left
        /// rather than in the middle; whatever fills the space that leaves is added
        /// from outside, like any other child.
        case panel(CGSize)
    }

    /// How far the glyph sits in from a panel's left edge.
    private static let panelInset: CGFloat = 9

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

    init(glyph texture: SKTexture,
         radius: CGFloat = 62,
         grabRadius: CGFloat = 105,
         shape: Shape = .circle,
         fill: SKColor = RenderPalette.controlBackground,
         glyphSize: CGFloat? = nil) {
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

        case .panel(let size):
            // Twelve, which is the corner every other panel on the top edge uses -
            // the clock's and the leaderboard's. A button this shape is read as one
            // of them rather than as a control, and it should be.
            self.base = SKShapeNode(
                rect: CGRect(x: -size.width / 2, y: -size.height / 2,
                             width: size.width, height: size.height),
                cornerRadius: 12)
        }

        super.init()

        base.fillColor = fill
        base.strokeColor = .clear

        glyph.alpha = 0.85

        zPosition = 1000
        addChild(base)
        addChild(glyph)

        setGlyph(texture)

        // Left-hung rather than centred, and only for a panel. Everything else here
        // is as wide as it is tall, where the middle is the only sensible place.
        if case .panel(let size) = shape {
            glyph.position = CGPoint(
                x: -size.width / 2 + ActionButtonNode.panelInset + self.glyphSize / 2,
                y: 0)
        }
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

        case .panel(let size):
            // Its own plate rather than grabRadius. A panel is already a large
            // target - the whole of it, including whatever is standing beside the
            // glyph - and a slop margin on top would start catching taps meant for
            // the map behind it.
            caught = abs(localPoint.x) <= size.width / 2
                  && abs(localPoint.y) <= size.height / 2
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
