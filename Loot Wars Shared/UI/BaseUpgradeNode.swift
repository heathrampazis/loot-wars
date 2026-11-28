//
//  BaseUpgradeNode.swift
//  Loot Wars
//
//  The base upgrade tag (Nov 2026): a small tag with a house and a token on
//  it, standing over your flag while you are in your own base AND can pay
//  for the next level. One tap takes arcades, turrets and walls up a level
//  together - see BaseUpgrade.
//
//  It belongs to the base, the way a shop sign belongs to its shop: it stands
//  just OUTSIDE the top wall, stays put on the map as you walk about, and only
//  moves to get out of your way when you come right up to it, gliding home
//  again once you step off. Kept on screen if the wall is further away than
//  you can see. Heath: "it should be locked to a base... move dynamically out
//  the way when the player moves too close", then "it needs to be a bigger
//  button and it needs to be more out of the way, like out of the base
//  walls". GameScene places it - see updateBaseUpgrade.
//

import SpriteKit

final class BaseUpgradeNode: SKNode {

    static let size = CGSize(width: 86, height: 34)

    private let body = SKNode()
    private let plate = SKShapeNode()
    private let flash = SKShapeNode()
    private let icon = SKSpriteNode(texture: Glyphs.home)
    private let price = GameLabel(fontNamed: "AvenirNext-Bold")
    private let token = SKSpriteNode()

    private(set) var showing = false
    private(set) var awaiting = false
    private var drawnPrice: Int?

    override init() {
        super.init()
        zPosition = 500
        isHidden = true
        addChild(body)

        let box = BaseUpgradeNode.size
        let path = CGPath(roundedRect: CGRect(x: -box.width / 2, y: -box.height / 2,
                                              width: box.width, height: box.height),
                          cornerWidth: box.height / 2, cornerHeight: box.height / 2,
                          transform: nil)
        plate.path = path
        plate.fillColor = RenderPalette.offerPlate
        plate.strokeColor = RenderPalette.placementValid
        plate.lineWidth = 2
        body.addChild(plate)

        flash.path = path
        flash.lineWidth = 3
        flash.alpha = 0
        flash.zPosition = 5
        body.addChild(flash)

        icon.size = CGSize(width: 19, height: 19)
        icon.position = CGPoint(x: -box.width / 2 + 17, y: 1)
        icon.zPosition = 1
        body.addChild(icon)

        price.fontSize = 17
        price.fontColor = .white
        price.horizontalAlignmentMode = .right
        price.verticalAlignmentMode = .center
        price.position = CGPoint(x: box.width / 2 - 28, y: 0)
        price.zPosition = 1
        body.addChild(price)

        let coin = ItemArt.texture(for: .token(1))
        token.texture = coin
        token.size = ItemArt.size(of: coin, fittingInto: 18)
        token.position = CGPoint(x: box.width / 2 - 15, y: 0)
        token.zPosition = 1
        body.addChild(token)

        // A small, slow bob, so it reads as something to tap.
        let up = SKAction.moveBy(x: 0, y: 2, duration: 0.8)
        up.timingMode = .easeInEaseOut
        body.run(.repeatForever(.sequence([up, up.reversed()])))
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Shows the tag at this price, or hides it when nil.
    func update(price cost: Int?) {
        guard !awaiting else { return }
        guard let cost else {
            hide()
            return
        }

        if drawnPrice != cost {
            drawnPrice = cost
            price.text = "\(cost)"
        }

        guard !showing else { return }
        showing = true
        removeAction(forKey: "life")
        isHidden = false
        alpha = 0
        setScale(0.7)
        run(.group([.fadeIn(withDuration: 0.12), Motion.pop(to: 1, duration: 0.32, overshoot: 2)]),
            withKey: "life")
    }

    func hide() {
        guard showing, !awaiting else { return }
        showing = false
        removeAction(forKey: "life")
        run(.sequence([.fadeOut(withDuration: 0.15), .hide()]), withKey: "life")
    }

    func isPressed(atLocalPoint point: CGPoint) -> Bool {
        guard showing, !awaiting else { return false }
        let box = BaseUpgradeNode.size
        return abs(point.x) <= box.width / 2 + 10 && abs(point.y) <= box.height / 2 + 10
    }

    /// Sent; waiting for the purchase to come back as an event. Let go after a
    /// second if it never does, so the tag cannot stick.
    func arm() {
        awaiting = true
        run(.sequence([.wait(forDuration: 1),
                       .run { [weak self] in self?.awaiting = false }]), withKey: "armed")
    }

    func confirm() {
        removeAction(forKey: "armed")
        awaiting = false
        answer(in: RenderPalette.placementValid, strength: 0.6)
    }

    func refuse() {
        removeAction(forKey: "armed")
        awaiting = false
        answer(in: RenderPalette.placementBlocked, strength: 0.42)
    }

    private func answer(in colour: SKColor, strength: CGFloat) {
        flash.removeAllActions()
        flash.fillColor = colour
        flash.strokeColor = colour
        flash.alpha = strength
        flash.run(.fadeAlpha(to: 0, duration: 0.4))
        removeAction(forKey: "shake")
        zRotation = 0
        run(.sequence([
            .rotate(toAngle: -0.08, duration: 0.05),
            .rotate(toAngle: 0.08, duration: 0.08),
            .rotate(toAngle: -0.04, duration: 0.06),
            .rotate(toAngle: 0, duration: 0.05)
        ]), withKey: "shake")
    }
}
