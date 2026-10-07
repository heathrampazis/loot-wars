//
//  HealButtonNode.swift
//  Loot Wars
//
//  The heal button, above the shoot corner.
//
//  Healing from the hotbar means taking a thumb off the aim stick and reaching to
//  the bottom of the screen, mid-fight, while somebody is shooting at you. This is
//  one short move up from where that thumb already is.
//
//  It always uses the RIGHT heal rather than a chosen one - ConsumableSystem's
//  bestHeal: the smallest thing that fills you up, or the biggest you have if
//  nothing does - so there is nothing to pick out first. It is the same plain
//  button as the bomb's, wearing the art of what it will use, and it turns green
//  once you are hurt enough that healing is the right call.
//
//  The hotbar still heals exactly as before. This is the quick way, not the only
//  one.
//

import SpriteKit

final class HealButtonNode: SKNode {

    static let radius: CGFloat = 40
    static let grabRadius: CGFloat = 48

    private let button = ActionButtonNode(glyph: SKTexture(imageNamed: "Bandage"),
                                          radius: HealButtonNode.radius,
                                          grabRadius: HealButtonNode.grabRadius,
                                          fill: RenderPalette.stickBackground,
                                          glass: true, shadow: true)
    private var shownType: ItemType?

    override init() {
        super.init()
        zPosition = 1000
        addChild(button)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// What it would use, and whether it is recommending itself. Cheap to call
    /// every frame: only a change does any work.
    func show(_ type: ItemType, recommended: Bool) {
        if shownType != type {
            shownType = type
            button.setGlyph(ItemArt.texture(for: type))
        }

        button.setHighlighted(recommended)
    }

    func begin(atLocalPoint point: CGPoint) -> Bool {
        button.begin(atLocalPoint: point)
    }

    func end() {
        button.end()
    }

    /// A press that did nothing - full health. A small shake, nothing more.
    func refuse() {
        button.removeAction(forKey: "refuse")
        button.zRotation = 0
        button.run(.sequence([
            .rotate(toAngle: -0.12, duration: 0.05),
            .rotate(toAngle: 0.12, duration: 0.09),
            .rotate(toAngle: 0, duration: 0.07)
        ]), withKey: "refuse")
    }
}
