//
//  ActionButtonNode.swift
//  Loot Wars
//
//  A round hold-to-use button.
//
//  Like the joystick, it reports state and nothing more: it does not know what
//  shooting is. GameScene turns isPressed into a Command, and WeaponSystem decides
//  what that means - which is why holding it down cannot outrun the fire rate.
//

import Foundation
import SpriteKit

final class ActionButtonNode: SKNode {

    private static let radius: CGFloat = 62
    /// Generous, like the joystick - thumbs are imprecise.
    private static let grabRadius: CGFloat = 105

    /// Longest side a glyph is allowed to be. Art of any shape is fitted inside it.
    private static let glyphSize: CGFloat = 62

    private let base = SKShapeNode(circleOfRadius: ActionButtonNode.radius)
    private let glyph = SKSpriteNode()

    private(set) var isPressed = false

    init(glyph texture: SKTexture) {
        super.init()
        setGlyph(texture)

        base.fillColor = RenderPalette.controlBackground
        base.strokeColor = .clear

        glyph.alpha = 0.85

        zPosition = 1000
        addChild(base)
        addChild(glyph)
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
            ? min(ActionButtonNode.glyphSize / art.width, ActionButtonNode.glyphSize / art.height)
            : 1
        glyph.size = CGSize(width: art.width * scale, height: art.height * scale)
    }

    /// - Parameter localPoint: the touch, in this node's own coordinate space.
    /// - Returns: true if the button is taking ownership of this touch.
    func begin(atLocalPoint localPoint: CGPoint) -> Bool {
        guard hypot(localPoint.x, localPoint.y) <= ActionButtonNode.grabRadius else {
            return false
        }
        isPressed = true
        setScale(0.92)
        return true
    }

    func end() {
        isPressed = false
        setScale(1.0)
    }
}
