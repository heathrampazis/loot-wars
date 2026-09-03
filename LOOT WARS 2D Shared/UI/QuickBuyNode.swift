//
//  QuickBuyNode.swift
//  Loot Wars
//
//  One offer, unasked, for a few seconds.
//
//  The shop is three taps away - open it, find the tab, find the card - and the
//  moments it matters most are the ones you have no taps to spare in: bleeding,
//  mid-fight, or one token past a rung you have been saving for and not noticing.
//  This is the shop coming to you for those moments, and only those.
//
//  ONE offer, never a menu, and no words on it: the picture and the price. A
//  prompt that appears while you are being shot at has to be answerable without
//  READING, and a name is the part of a card you skip anyway when you already know
//  what a bandage looks like. The moment it needs comparing it has become a shop -
//  which is what the shop is for. Which offer is Core's answer, not this file's:
//  see ShopSystem.quickOffer.
//
//  It also shows itself only on a CHANGE. Left to appear whenever something was
//  affordable it would be permanently on screen, which is the same mistake the
//  greyed-out hotbar made in the other direction: a signal that is always on stops
//  being a signal.
//

import SpriteKit

final class QuickBuyNode: SKNode {

    /// Small, because it lives under the health panel rather than across the
    /// bottom of the screen, and because a picture and a number is all it holds.
    static let size = CGSize(width: 104, height: 44)

    private let plate = SKShapeNode()
    private let glow = SKSpriteNode(texture: GlowArt.pool)
    private let icon = SKSpriteNode()
    private let price = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private let token = SKSpriteNode()

    /// What is currently being offered, so the same offer is not re-announced
    /// every frame - and so a tap knows what it is buying.
    private(set) var offer: ItemType?

    /// Whether it is up and can be pressed. Not the same as `isHidden`: it fades
    /// out over a quarter of a second, and a tap landing during the fade should
    /// miss rather than buy something that is on its way out.
    private var live = false

    /// True for a while after you take an offer.
    ///
    /// Without it, buying the bandage you were offered while still hurt and still
    /// able to afford another one puts the same prompt straight back on screen -
    /// the prompt pestering you for having done what it asked.
    private var cooling = false

    override init() {
        super.init()
        zPosition = 1050
        isHidden = true

        let box = QuickBuyNode.size
        plate.path = CGPath(roundedRect: CGRect(x: -box.width / 2, y: -box.height / 2,
                                                width: box.width, height: box.height),
                            cornerWidth: box.height / 2, cornerHeight: box.height / 2,
                            transform: nil)
        plate.fillColor = RenderPalette.hudPanel
        plate.strokeColor = RenderPalette.placementValid
        plate.lineWidth = 2
        addChild(plate)

        // Behind the artwork, like everywhere else loot is drawn. The plate's own
        // outline goes on meaning "you can afford this", which is a different fact
        // and deserves its own colour.
        glow.size = CGSize(width: 46, height: 46)
        glow.colorBlendFactor = 1
        glow.alpha = 0.7
        glow.position = CGPoint(x: -box.width / 2 + 26, y: 0)
        addChild(glow)

        icon.position = CGPoint(x: -box.width / 2 + 26, y: 0)
        icon.zPosition = 1
        addChild(icon)

        price.fontSize = 17
        price.fontColor = .white
        price.horizontalAlignmentMode = .right
        price.verticalAlignmentMode = .center
        price.position = CGPoint(x: box.width / 2 - 30, y: 0)
        addChild(price)

        token.texture = ItemArt.texture(for: .token(1))
        token.size = ItemArt.size(of: ItemArt.texture(for: .token(1)), fittingInto: 20)
        token.position = CGPoint(x: box.width / 2 - 16, y: 0)
        addChild(token)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Called every frame with whatever the shop would offer right now.
    func update(with item: GameConfig.Shop.Item?) {
        guard !cooling else { return }

        guard let item else {
            // The offer stopped being available - spent, or no longer affordable.
            // Taken away rather than left up, because an offer you cannot take is
            // worse than no offer at all.
            if offer != nil { dismiss() }
            return
        }

        guard item.type != offer else { return }
        show(item)
    }

    /// Whether a tap at this point in the node's own space takes the offer.
    func isPressed(atLocalPoint point: CGPoint) -> Bool {
        guard live else { return false }
        let box = QuickBuyNode.size
        return abs(point.x) <= box.width / 2 + 8 && abs(point.y) <= box.height / 2 + 8
    }

    /// Puts it away, and forgets the offer so the same one can appear again later
    /// when it next becomes newly affordable.
    func dismiss() {
        // Called every frame by the scene while a panel is open, so it has to be
        // cheap and idempotent - running a fade-out sixty times a second would
        // leave the node permanently mid-animation.
        guard offer != nil || !isHidden else { return }

        offer = nil
        live = false

        // Keyed like the appearance it replaces, so an offer arriving during the
        // fade-out cancels it rather than the two animating over each other.
        removeAction(forKey: "life")
        run(.sequence([.fadeOut(withDuration: 0.18), .hide()]), withKey: "life")
    }

    /// The offer was taken. Away it goes, and it stays away for a bit.
    func take() {
        dismiss()
        cooling = true
        run(.sequence([
            .wait(forDuration: GameConfig.Shop.quickBuySeconds * 2),
            .run { [weak self] in self?.cooling = false }
        ]), withKey: "cooling")
    }

    private func show(_ item: GameConfig.Shop.Item) {
        offer = item.type
        live = true

        glow.color = RenderPalette.colour(of: item.type.rarity)

        let texture = ItemArt.texture(for: item.type)
        icon.texture = texture
        icon.size = ItemArt.size(of: texture, fittingInto: 34)
        price.text = "\(item.price)"

        removeAction(forKey: "life")
        isHidden = false
        alpha = 0
        setScale(0.9)

        // Up quickly, held, then away by itself. The wait comes out of the config
        // so the prompt and the button that nudges alongside it are tuned together.
        run(.sequence([
            .group([.fadeIn(withDuration: 0.14), .scale(to: 1, duration: 0.14)]),
            .wait(forDuration: GameConfig.Shop.quickBuySeconds),
            .run { [weak self] in self?.live = false },
            .fadeOut(withDuration: 0.25),
            .hide(),

            // And then it is forgotten, so the same offer counts as new again and
            // is put back in front of you. An upgrade you have been able to afford
            // for half a minute is one you have not noticed - see
            // GameConfig.Shop.quickBuyReappear.
            .wait(forDuration: GameConfig.Shop.quickBuyReappear),
            .run { [weak self] in self?.offer = nil }
        ]), withKey: "life")
    }

}
