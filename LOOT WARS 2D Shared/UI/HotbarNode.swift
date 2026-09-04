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
    private var lastInventory: Inventory?
    private var lastUsable: [Bool] = []

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
    func beginHold(_ index: Int, duration: TimeInterval) {
        endHold()
        guard slots.indices.contains(index) else { return }
        heldSlot = index
        slots[index].beginHold(duration: duration)
    }

    func endHold() {
        if let held = heldSlot { slots[held].endHold() }
        heldSlot = nil
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

    func update(with world: World) {
        guard let player = world.localPlayer else { return }

        // Whether each slot can be used is the actor's own answer, so a greyed slot
        // always means the simulation would refuse it. A bandage greys out at full
        // health; a bomb and a chest never do.
        // Not canUse: see Actor.showsAsUnusable for why the hotbar and the use
        // button are asking two different questions on purpose.
        let usable = (0..<Inventory.slotCount).map { !player.showsAsUnusable(slot: $0) }

        guard player.inventory != lastInventory || usable != lastUsable else { return }
        lastInventory = player.inventory
        lastUsable = usable

        for (index, stack) in player.inventory.slots.enumerated() {
            // Nothing is greyed while selling. A bandage at full health cannot be
            // USED, which is exactly why you might want to sell it, and a faint
            // slot would be the screen discouraging the one action it is offering.
            slots[index].show(stack, dimmed: selling ? false : !usable[index])

            if selling, let stack {
                slots[index].setPrice(ShopSystem.sellPrice(of: stack.type))
            } else {
                slots[index].setPrice(nil)
            }
        }
    }
}
