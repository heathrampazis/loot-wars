//
//  HotbarNode.swift
//  Loot Wars
//
//  Four slots along the bottom of the screen, mirroring Inventory.slotCount.
//
//  Like the HUD it only reads the world, and only redraws when the inventory
//  actually changes - which is why Inventory is Equatable.
//
//  Its origin is the centre of the bar, so it sits at the bottom of the screen with
//  no arithmetic against its own width. The slots themselves are ItemSlotNodes, the
//  same ones the chest panel uses.
//
//  The measurements came off the reference art, scaled by its tile size: a slot is
//  1.64 tiles and the gap 0.39.
//

import SpriteKit

final class HotbarNode: SKNode {

    static let slotSize: CGFloat = 66
    private static let gap: CGFloat = 16

    static var size: CGSize {
        let count = CGFloat(Inventory.slotCount)
        return CGSize(width: count * slotSize + (count - 1) * gap, height: slotSize)
    }

    /// Sell mode: every slot wears the shop's offer for it, and a tap sells rather
    /// than selects.
    ///
    /// NOTHING TURNS THIS ON at the moment, and it is kept rather than deleted on
    /// purpose. It was how you sold things while the shop was open, and the shop
    /// stopped doing that for a good reason - the bar and the panel were two
    /// interfaces with two rules stacked on one screen - but selling by holding a
    /// slot could easily want a way to SHOW what a slot is worth before you commit
    /// to it, and this is that, already built and already matching the rest of the
    /// bar.
    private(set) var selling = false

    private var slots: [ItemSlotNode] = []

    /// The payout currently climbing out of each slot, so a second sale out of the
    /// same square replaces it rather than stacking on top of it.
    private var payouts: [Int: SKNode] = [:]
    private var heldSlot: Int?

    /// The "SELL +3" tag over a slot that is being held - see beginHold.
    private var holdTag: SKNode?
    private var lastInventory: Inventory?

    /// The refusal currently sitting over the bar. Only ever one: tapping two
    /// things you cannot use should replace the message, not stack a second one on
    /// top of it.
    private var note: SKNode?

    override init() {
        super.init()
        zPosition = 1000

        for index in 0..<Inventory.slotCount {
            let slot = ItemSlotNode(side: HotbarNode.slotSize)
            slot.position = CGPoint(x: HotbarNode.centreX(of: index), y: 0)
            addChild(slot)
            slots.append(slot)
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private static func centreX(of index: Int) -> CGFloat {
        -size.width / 2 + slotSize / 2 + CGFloat(index) * (slotSize + gap)
    }

    /// Which slot a touch landed on, or nil if it missed the bar entirely.
    ///
    /// The slots are treated as touching each other rather than separated by their
    /// gap: a thumb landing in the crack between two slots meant to hit one of them.
    func slotIndex(atLocalPoint point: CGPoint) -> Int? {
        let half = HotbarNode.slotSize / 2
        guard abs(point.y) <= half + 12 else { return nil }

        for index in 0..<Inventory.slotCount {
            let centreX = HotbarNode.centreX(of: index)
            if abs(point.x - centreX) <= half + HotbarNode.gap / 2 { return index }
        }

        return nil
    }

    /// Starts the squeeze on a slot being held down, and stops it again.
    /// - Parameter price: what selling this would pay, or nil for something the
    ///   shop will not take - which gets the squeeze but no tag.
    func beginHold(_ index: Int, duration: TimeInterval, price: Int? = nil) {
        endHold()
        guard slots.indices.contains(index) else { return }
        heldSlot = index
        slots[index].beginHold(duration: duration)

        if let price, price > 0 {
            showHoldTag(over: index, price: price, duration: duration)
        }
    }

    func endHold() {
        if let held = heldSlot { slots[held].endHold() }
        heldSlot = nil

        holdTag?.removeAllActions()
        holdTag?.run(.sequence([.fadeOut(withDuration: 0.08), .removeFromParent()]))
        holdTag = nil
    }

    /// Says what a hold is doing WHILE it does it: "SELL +3", over the slot, with
    /// green filling it from the left until the sale goes through.
    ///
    /// Selling was the one thing on the bar nobody was told about - people found
    /// it by holding something by accident and watching it vanish. A held finger
    /// now explains itself, so an accidental hold is the lesson rather than the
    /// surprise, and letting go before the green reaches the end is the way out.
    ///
    /// Held back for a tenth of a second, so an ordinary tap - which is over
    /// before then - never flashes it.
    private func showHoldTag(over index: Int, price: Int, duration: TimeInterval) {
        let tag = SKNode()
        tag.position = CGPoint(x: HotbarNode.centreX(of: index),
                               y: HotbarNode.slotSize / 2 + 22)
        tag.zPosition = 25
        tag.alpha = 0

        let word = SKLabelNode(fontNamed: "AvenirNext-Bold")
        word.text = "SELL"
        word.fontSize = 14
        word.fontColor = .white
        word.horizontalAlignmentMode = .left
        word.verticalAlignmentMode = .center
        word.zPosition = 2

        let amount = SKLabelNode(fontNamed: "AvenirNext-Bold")
        amount.text = "+\(price)"
        amount.fontSize = 14
        amount.fontColor = .white
        amount.horizontalAlignmentMode = .left
        amount.verticalAlignmentMode = .center
        amount.zPosition = 2

        let texture = ItemArt.texture(for: Pickup.token(1))
        let coin = SKSpriteNode(texture: texture)
        coin.size = ItemArt.size(of: texture, fittingInto: 16)
        coin.zPosition = 2

        // Laid out from what it holds, so "+1" and "+14" both sit centred.
        let gap: CGFloat = 6
        let padding: CGFloat = 11
        let content = word.frame.width + gap + amount.frame.width + 3 + coin.size.width
        let width = content + padding * 2
        let height: CGFloat = 28

        var x = -content / 2
        word.position = CGPoint(x: x, y: 0)
        x += word.frame.width + gap
        amount.position = CGPoint(x: x, y: 0)
        x += amount.frame.width + 3
        coin.position = CGPoint(x: x + coin.size.width / 2, y: 0)

        let outline = CGPath(roundedRect: CGRect(x: -width / 2, y: -height / 2,
                                                 width: width, height: height),
                             cornerWidth: height / 2, cornerHeight: height / 2,
                             transform: nil)

        let back = SKShapeNode(path: outline)
        back.fillColor = SKColor(white: 0, alpha: 0.6)
        back.strokeColor = .clear
        tag.addChild(back)

        // The fill, cropped to the pill so its square end never shows.
        let mask = SKShapeNode(path: outline)
        mask.fillColor = .white
        mask.strokeColor = .clear

        let crop = SKCropNode()
        crop.maskNode = mask
        crop.zPosition = 1
        tag.addChild(crop)

        let fill = SKSpriteNode(color: RenderPalette.sellButton,
                                size: CGSize(width: width, height: height))
        fill.anchorPoint = CGPoint(x: 0, y: 0.5)
        fill.position = CGPoint(x: -width / 2, y: 0)
        fill.xScale = 0
        crop.addChild(fill)

        tag.addChild(word)
        tag.addChild(amount)
        tag.addChild(coin)
        addChild(tag)
        holdTag = tag

        let delay: TimeInterval = 0.1
        tag.run(.sequence([.wait(forDuration: delay), .fadeIn(withDuration: 0.08)]))
        fill.run(.scaleX(to: 1, duration: duration))
    }

    /// Rings one slot, or none. Kept out of `update` because arming is scene state
    /// rather than world state - the simulation has no idea a chest is selected.
    func setSelected(_ index: Int?) {
        for (slot, node) in slots.enumerated() {
            node.setSelected(slot == index)
        }
    }

    /// The payout, thrown up out of the slot the item came from.
    ///
    /// At the slot rather than up at the token counter, and that is the whole
    /// point of it. The counter in the corner already went up by three; what it
    /// cannot say is that the three came from THAT square, and the square you were
    /// holding when it happened is the only place a player is looking. A number
    /// arriving somewhere else on screen is a number nobody connects to the gesture
    /// they just made.
    ///
    /// It rises and fades rather than flying to the counter. An arc across to the
    /// corner was the other option and is what a PURCHASE does in reverse - but a
    /// purchase has to explain where the thing went, and a sale does not: you can
    /// see the slot is empty. This only has to say it was worth something.
    ///
    /// One pill, on a dark ground. The version before this drew the number five
    /// times - four dark copies as a fake outline - and at this size the copies
    /// did not read as an outline, they read as the text being printed twice. A
    /// panel behind it does the same job properly, and it is the language the rest
    /// of this bar already speaks: the count badge and the shop's price pill are
    /// both a colour on a dark plate.
    func reward(slot index: Int, tokens: Int) {
        guard slots.indices.contains(index), tokens > 0 else { return }

        // Only ever one per slot. Selling four things in four seconds used to leave
        // four of these climbing over each other out of the same square, which is
        // the one thing a payout must not look like - a mess where a reward is.
        payouts[index]?.removeFromParent()

        let payout = SKNode()
        payout.position = CGPoint(x: HotbarNode.centreX(of: index),
                                  y: HotbarNode.slotSize * 0.42)
        payout.zPosition = 20
        addChild(payout)
        payouts[index] = payout

        let amount = SKLabelNode(fontNamed: "AvenirNext-Bold")
        amount.text = "+\(tokens)"
        amount.fontSize = HotbarNode.slotSize * 0.3
        amount.fontColor = RenderPalette.payout
        amount.horizontalAlignmentMode = .left
        amount.verticalAlignmentMode = .center
        amount.zPosition = 1

        let texture = ItemArt.texture(for: Pickup.token(1))
        let coin = SKSpriteNode(texture: texture)
        let side = HotbarNode.slotSize * 0.3

        coin.size = ItemArt.size(of: texture, fittingInto: side)
        coin.zPosition = 1

        // Laid out from the two things it holds rather than from guessed numbers,
        // so "+1" and "+14" both sit centred in a pill that fits them.
        let gap = side * 0.24
        let padding = side * 0.42
        let content = coin.size.width + gap + amount.frame.width
        let height = max(side, amount.frame.height) + padding

        coin.position = CGPoint(x: -content / 2 + coin.size.width / 2, y: 0)
        amount.position = CGPoint(x: coin.position.x + coin.size.width / 2 + gap,
                                  y: 0)

        let pill = SKShapeNode(
            rect: CGRect(x: -content / 2 - padding, y: -height / 2,
                         width: content + padding * 2, height: height),
            cornerRadius: height / 2
        )

        pill.fillColor = RenderPalette.payoutPill
        pill.strokeColor = .clear

        payout.addChild(pill)
        payout.addChild(coin)
        payout.addChild(amount)

        // Pops, climbs, goes. The pop is what makes it read as being handed to you
        // rather than as a caption that faded in.
        payout.setScale(0.4)
        payout.run(.sequence([
            .group([
                .sequence([.scale(to: 1.14, duration: 0.12),
                           .scale(to: 1.0, duration: 0.1)]),
                .moveBy(x: 0, y: HotbarNode.slotSize * 0.8, duration: 0.75),
                .sequence([.wait(forDuration: 0.45),
                           .fadeOut(withDuration: 0.3)])
            ]),
            .removeFromParent(),
            .run { [weak self] in
                // Only if it is still the one being tracked: a replacement will
                // have claimed the slot by now if a second sale came through.
                if self?.payouts[index] === payout { self?.payouts[index] = nil }
            }
        ]))

        // And the slot it came out of flinches, so the two are one event.
        slots[index].flinch()
    }

    /// Turns the bar into a sell counter, or back into a bar.
    func setSelling(_ selling: Bool) {
        guard selling != self.selling else { return }
        self.selling = selling
        lastInventory = nil      // force the prices on or off
    }

    /// Shakes a slot red and says nothing.
    ///
    /// The wordless half of refuse, for a no that some OTHER panel is explaining.
    /// Storing into a full chest is the case: the tap lands here, so this is what
    /// has to answer it, but the bar's own note would be drawn underneath the chest
    /// panel sitting on top of it. The shake belongs to the finger; the words
    /// belong to whatever is in front.
    func deny(slot index: Int) {
        guard slots.indices.contains(index) else { return }
        slots[index].refuse()
    }

    /// What is drawn in a slot, so a panel can fly a copy of it somewhere.
    ///
    /// Asked of the SLOT rather than worked out from the inventory, so the picture
    /// that flies is the picture that was on screen - including when the two are a
    /// frame apart, which is exactly when somebody is moving things about.
    func artwork(inSlot index: Int) -> (texture: SKTexture, size: CGSize)? {
        guard slots.indices.contains(index) else { return nil }
        return slots[index].artwork
    }

    /// Acknowledges a tap that spent something, so the slot answers the finger
    /// even though what it held is on its way out.
    func acknowledge(_ index: Int) {
        guard slots.indices.contains(index) else { return }
        slots[index].flinch()
    }

    /// Says no to a tap: the slot shakes red and the bar says why.
    ///
    /// Both halves matter and they are doing different jobs. The shake is the
    /// answer - it is instant, it is where the finger is, and it says "that tap
    /// landed and the answer is no". The words are the reason, and they are over
    /// the BAR rather than over the slot, because a sentence in a 66-point square
    /// either does not fit or covers the item it is about.
    ///
    /// Centred, so it reads the same whichever of the four was pressed and cannot
    /// run off the edge of the screen from an outside slot. Its own note rather
    /// than the hint panel at the top of the screen: that one is hidden whenever
    /// anybody is shooting at you, which is exactly when somebody fumbles for the
    /// wrong slot.
    func refuse(slot index: Int, saying reason: String) {
        guard slots.indices.contains(index) else { return }
        slots[index].refuse()

        note?.removeFromParent()

        let note = SKNode()
        note.position = CGPoint(x: 0, y: HotbarNode.slotSize * 0.88)
        note.zPosition = 20
        addChild(note)
        self.note = note

        let label = SKLabelNode(fontNamed: "AvenirNext-Bold")
        label.text = reason
        label.fontSize = HotbarNode.slotSize * 0.26
        label.fontColor = .white
        label.horizontalAlignmentMode = .center
        label.verticalAlignmentMode = .center
        label.zPosition = 1

        // Cut to the words rather than to a guessed width, the same way the hint
        // panel is, so a short reason does not sit in a long plate.
        let padding = HotbarNode.slotSize * 0.2
        let height = label.frame.height + padding
        let pill = SKShapeNode(
            rect: CGRect(x: -label.frame.width / 2 - padding, y: -height / 2,
                         width: label.frame.width + padding * 2, height: height),
            cornerRadius: height / 2)

        pill.fillColor = RenderPalette.placementBlocked
        pill.strokeColor = .clear

        note.addChild(pill)
        note.addChild(label)

        // Pops in with the shake, holds long enough to be read, and goes. Removed
        // rather than left hidden, so nothing accumulates over a match.
        note.setScale(0.7)
        note.run(.sequence([
            .scale(to: 1.0, duration: 0.11),
            .wait(forDuration: 1.1),
            .fadeOut(withDuration: 0.3),
            .removeFromParent(),
            .run { [weak self] in
                if self?.note === note { self?.note = nil }
            }
        ]))
    }

    func update(with world: World) {
        guard let player = world.localPlayer else { return }

        // Which slot is worth tapping RIGHT NOW, which is not what this used to
        // mean. It marked the slots a tap would SPEND rather than pick out, back
        // when most taps only picked out - a warning that this one was different.
        // Every tap spends now, so a warning would be on everything always; what is
        // left is the useful half, which is a heal recommending itself once you are
        // hurt enough for it to be worth the seconds.
        //
        // Asked every frame rather than folded into the redraw below, because it
        // turns on when your health crosses a line - and nothing about your
        // inventory changes at that moment, so the redraw would not fire.
        // The line where a tap on a heal USES it rather than picking it out - see
        // GameScene.tapHotbar - so the ring means exactly "tap this now".
        let urgent = Double(player.health)
            < Double(player.maxHealth) * GameConfig.Player.instantHealBelow

        for (index, stack) in player.inventory.slots.enumerated() {
            let spends = urgent && !selling && player.isAlive
                && stack?.type.isHealing == true

            slots[index].setUrgent(spends)
        }

        // NOTHING IS DIMMED any more, and that is why this redraw is back to
        // watching the inventory alone. It used to also track which slots the
        // simulation would refuse, because those were drawn faint - see
        // Actor.canUse for what a tap is allowed to do: the refusal lives on the
        // tap now rather than in the slot's appearance. A bar that is only ever redrawn when its contents change
        // is what this was before the dimming, and what it is again.
        guard player.inventory != lastInventory else { return }
        lastInventory = player.inventory

        for (index, stack) in player.inventory.slots.enumerated() {
            slots[index].show(stack)

            if selling, let stack {
                slots[index].setPrice(ShopSystem.sellPrice(of: stack.type))
            } else {
                slots[index].setPrice(nil)
            }
        }
    }
}
