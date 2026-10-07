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
//  It STAYS UP for as long as there is something you can afford, and that is a
//  reversal. The first version appeared for six seconds on a change and then hid
//  for twenty, on the theory that a signal which is always on stops being a signal.
//  True of a warning; not true of a shop. Nobody ignores a price tag for being
//  permanently attached to the thing it is pricing - they ignore it until they want
//  the thing, which is exactly the moment it has to still be there. The timed
//  version was reliably absent at that moment, and the tokens went unspent.
//
//  What keeps it from becoming wallpaper is that it is never idle: the offer
//  changes as the match does. It is a rung of the ladder while you are healthy and
//  the biggest healing item you can afford the moment you drop below the line the
//  hotbar uses for the same word, so a glance at it answers "what should I do with
//  my tokens right now" rather than "what is for sale".
//

import SpriteKit

final class QuickBuyNode: SKNode {

    /// Small, because it lives under the health panel rather than across the
    /// bottom of the screen, and because a picture and a number is all it holds.
    static let size = CGSize(width: 104, height: 44)

    private let plate = SKShapeNode()

    /// Lit for a moment when a tap is answered - green for a sale, red for a
    /// refusal. Its own node rather than a colour on the plate, for the reason the
    /// shop's card learned the hard way: the plate is redrawn by the next offer,
    /// and a colour written onto it is wiped before it has been seen.
    private let flash = SKShapeNode()
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

    /// Whether it is on screen AT ALL - up, or on its way out.
    ///
    /// The latch dismiss needs, and the reason it did not work before. dismiss is
    /// called every frame while a panel is open and has to run exactly once per
    /// appearance; it used to decide that from `offer` and `isHidden`, and
    /// `isHidden` is set by the tail of the fade-out it was itself restarting, so
    /// the condition it was waiting for could never arrive. See dismiss.
    private var showing = false

    /// A tap has been sent and the answer has not come back yet.
    ///
    /// One frame, usually - the command goes into the queue, the world runs, and
    /// the purchase arrives as an event on the way out. It matters anyway: without
    /// it a fast double tap sends two buys, and the second one spends tokens on a
    /// prompt that is already leaving.
    private(set) var awaiting = false

    /// True for a moment after you take an offer.
    ///
    /// Just long enough for the green confirmation to be seen. It used to be twelve
    /// seconds, to stop the prompt pestering you for having done what it asked;
    /// with a prompt that stays up anyway, re-offering is not pestering, it is the
    /// prompt doing its job - if you are still hurt and can still afford a bandage,
    /// a bandage is still the right answer.
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
        plate.fillColor = RenderPalette.offerPlate
        plate.strokeColor = RenderPalette.placementValid
        plate.lineWidth = 2
        addChild(plate)

        flash.path = plate.path
        flash.fillColor = RenderPalette.placementValid
        flash.strokeColor = RenderPalette.placementValid
        flash.lineWidth = 3
        flash.alpha = 0
        flash.zPosition = 5
        addChild(flash)

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
        guard live, !awaiting else { return false }
        let box = QuickBuyNode.size
        return abs(point.x) <= box.width / 2 + 8 && abs(point.y) <= box.height / 2 + 8
    }

    /// Puts it away, and forgets the offer so the same one can appear again later
    /// when it next becomes newly affordable.
    func dismiss() {
        // Nothing goes away while an answer is owed.
        //
        // This guard is the whole reason the celebration is ever seen. Buying
        // something spends tokens, the scene re-asks ShopSystem for an offer on the
        // very next frame, the answer is now "you cannot afford anything" - and the
        // prompt would take itself off screen a frame before the purchase event
        // arrived to be celebrated. The shop card had the identical bug for weeks.
        guard !awaiting else { return }

        // Called every frame by the scene while a panel is open, so it has to run
        // exactly once per appearance. The comment that used to sit here said as
        // much - "running a fade-out sixty times a second would leave the node
        // permanently mid-animation" - and then guarded it on `offer != nil ||
        // !isHidden`, which cannot do that job.
        //
        // isHidden is set by the .hide() on the END of the fade below, and the
        // first thing this does is removeAction on that very fade. So every frame
        // tore up the animation and started a fresh one: isHidden stayed false,
        // the guard never engaged, .hide() never ran, and the alpha crept down
        // asymptotically instead of the node going away. Open the shop and the
        // quick offer sat there beside it, which is what it was reported as.
        //
        // A latch fixes it because a latch is what was missing. `showing` is set
        // by show and cleared here, so the second call and every one after it
        // leaves the fade alone to finish.
        guard showing else { return }
        showing = false

        offer = nil
        live = false

        // Keyed like the appearance it replaces, so an offer arriving during the
        // fade-out cancels it rather than the two animating over each other.
        removeAction(forKey: "life")
        run(.sequence([.fadeOut(withDuration: 0.18), .hide()]), withKey: "life")
    }

    /// A tap went through to the simulation. Nothing visible yet - the answer
    /// comes back as confirm or refuse.
    func arm() {
        awaiting = true
    }

    /// The purchase went through: wash it green, shake it, and away.
    ///
    /// The same answer the shop card gives, in the same colour and the same motion,
    /// because they are the same act. Somebody who has learned what a green shake
    /// means at a shop card has learned it here, and a prompt that celebrated
    /// differently would be a second thing to learn for no reason.
    func confirm() {
        // Stays armed until take() runs, which is what keeps dismiss off it for the
        // length of the celebration.
        answer(in: RenderPalette.placementValid, strength: 0.6)

        // Held just long enough to be seen before it leaves. The prompt's whole job
        // is done at this point; what is left is telling you it worked.
        run(.sequence([
            .wait(forDuration: 0.28),
            .run { [weak self] in self?.take() }
        ]), withKey: "answered")
    }

    /// The purchase was refused: wash it red and leave it up.
    ///
    /// It STAYS, which is the opposite of a sale. A refusal means you could not
    /// afford it or had nowhere to put it, and both of those can change in the next
    /// few seconds - taking the offer away would be the game punishing you for
    /// asking.
    func refuse() {
        awaiting = false
        answer(in: RenderPalette.placementBlocked, strength: 0.42)
    }

    /// A small shake when the offer arrives or changes.
    ///
    /// Motion on a CHANGE rather than motion always, which is the distinction this
    /// prompt got wrong in both directions. It used to appear for six seconds and
    /// hide for twenty, so it was absent whenever you wanted it; then it became
    /// permanent and completely still, and a thing that never moves in the corner
    /// of a busy screen is furniture. Watching people play, nobody saw it at all.
    ///
    /// So it holds still while it is saying the same thing, and moves for a fifth
    /// of a second whenever what it is saying changes. Rotation and scale only -
    /// the POSITION belongs to the layout, and an interrupted move would leave the
    /// prompt parked somewhere the layout never put it.
    private func wiggle() {
        removeAction(forKey: "shake")

        // The same key the purchase shake uses, because both animate zRotation and
        // two actions driving one property is a node that never settles. Whichever
        // fires last wins, which is the right answer: a confirmation should cut off
        // an arrival wiggle rather than fight it.
        run(.sequence([
            .rotate(toAngle: -0.07, duration: 0.05),
            .rotate(toAngle: 0.07, duration: 0.08),
            .rotate(toAngle: -0.04, duration: 0.06),
            .rotate(toAngle: 0, duration: 0.05)
        ]), withKey: "shake")
    }

    private func answer(in colour: SKColor, strength: CGFloat) {
        flash.removeAllActions()
        flash.fillColor = colour
        flash.strokeColor = colour
        flash.alpha = strength
        flash.run(.fadeAlpha(to: 0, duration: 0.4))

        // Rotation and scale only, the same as the shop's card: this node's
        // POSITION is owned by the layout, and an interrupted move would leave the
        // prompt parked somewhere the layout never put it.
        removeAction(forKey: "answered")
        setScale(1)
        zRotation = 0

        run(.sequence([
            .group([.rotate(toAngle: -0.055, duration: 0.05),
                    .scale(to: 0.95, duration: 0.05)]),
            .rotate(toAngle: 0.055, duration: 0.09),
            .rotate(toAngle: -0.035, duration: 0.07),
            .group([.rotate(toAngle: 0, duration: 0.06),
                    .scale(to: 1.0, duration: 0.06)])
        ]), withKey: "shake")
    }

    /// The offer was taken. Away it goes, and it stays away for a bit.
    func take() {
        awaiting = false
        dismiss()
        cooling = true
        run(.sequence([
            .wait(forDuration: GameConfig.Shop.quickBuySettle),
            .run { [weak self] in self?.cooling = false }
        ]), withKey: "cooling")
    }

    private func show(_ item: GameConfig.Shop.Item) {
        // Already up, and the offer has simply changed underneath it - which
        // happens every time your health crosses the line or you climb a rung. The
        // card is re-dressed in place rather than popped again: a prompt that
        // jumps every time the answer changes reads as a notification arriving,
        // and this one has not gone anywhere.
        let swapping = !isHidden && live

        offer = item.type
        live = true
        showing = true

        removeAction(forKey: "life")
        isHidden = false

        guard swapping else {
            dress(item)
            alpha = 0
            setScale(0.9)
            run(.group([.fadeIn(withDuration: 0.14), .scale(to: 1, duration: 0.14)]),
                withKey: "life")
            wiggle()
            return
        }

        // Through the middle rather than a cut, so the eye follows one card
        // changing its mind instead of catching two.
        icon.removeAction(forKey: "swap")
        icon.run(.sequence([
            .fadeAlpha(to: 0, duration: 0.09),
            .run { [weak self] in self?.dress(item) },
            .fadeAlpha(to: 1, duration: 0.12)
        ]), withKey: "swap")

        wiggle()
    }

    /// The picture, the price and the colour behind them. Split out of show()
    /// because a swap has to change all three halfway through a fade, and an
    /// arrival has to change them before one.
    private func dress(_ item: GameConfig.Shop.Item) {
        glow.color = RenderPalette.colour(of: item.type.rarity)
        glow.alpha = 0.7 * RenderPalette.glowStrength(of: item.type.rarity)

        let texture = ItemArt.texture(for: item.type)
        icon.texture = texture
        icon.size = ItemArt.size(of: texture, fittingInto: 34)
        price.text = "\(item.price)"
    }

}
