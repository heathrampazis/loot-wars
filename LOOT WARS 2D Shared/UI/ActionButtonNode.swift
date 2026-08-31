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

    /// Grab radius is generous, like the joystick - thumbs are imprecise. Note the
    /// small button's is proportionally MORE generous than the big one's, because
    /// a small target needs the help and the big one does not.
    private let grabRadius: CGFloat
    private let glyphSize: CGFloat

    private let base: SKShapeNode
    private let glyph = SKSpriteNode()

    private(set) var isPressed = false
    private(set) var isEnabled = true

    init(glyph texture: SKTexture, radius: CGFloat = 62, grabRadius: CGFloat = 105) {
        self.grabRadius = grabRadius
        self.glyphSize = radius
        self.base = SKShapeNode(circleOfRadius: radius)

        super.init()

        base.fillColor = RenderPalette.controlBackground
        base.strokeColor = .clear

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
    func setEnabled(_ enabled: Bool) {
        guard enabled != isEnabled else { return }
        isEnabled = enabled
        alpha = enabled ? 1.0 : 0.4
    }

    /// - Parameter localPoint: the touch, in this node's own coordinate space.
    /// - Returns: true if the button is taking ownership of this touch.
    func begin(atLocalPoint localPoint: CGPoint) -> Bool {
        guard hypot(localPoint.x, localPoint.y) <= grabRadius else { return false }
        isPressed = true
        setScale(0.92)
        return true
    }

    func end() {
        isPressed = false
        setScale(1.0)
    }
}
