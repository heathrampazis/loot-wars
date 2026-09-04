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

    /// While the shop is open the bar stops being what you carry and becomes what
    /// you can sell: every slot wears the shop's offer for it, and a tap sells
    /// rather than selects.
    ///
    /// The bar itself rather than a tab inside the shop, which is what this
    /// replaced. A tab meant a fourth heading, a second row of slots drawn to look
    /// like the first, and a panel that had run out of width to hold them. The bar
    /// is already on screen, already shows exactly these four things, and the
    /// player already knows what it is.
    private(set) var selling = false

    private var slots: [ItemSlotNode] = []
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
    func reward(slot index: Int, tokens: Int) {
        guard slots.indices.contains(index), tokens > 0 else { return }

        let payout = SKNode()
        payout.position = CGPoint(x: HotbarNode.centreX(of: index),
                                  y: HotbarNode.slotSize * 0.35)
        payout.zPosition = 20
        addChild(payout)

        let texture = ItemArt.texture(for: Pickup.token(1))
        let coin = SKSpriteNode(texture: texture)
        let side = HotbarNode.slotSize * 0.42
        coin.size = ItemArt.size(of: texture, fittingInto: side)
        coin.position = CGPoint(x: -side * 0.45, y: 0)
        payout.addChild(coin)

        // Drawn five times: four dark copies a point and a half out in each
        // direction, then the bright one over them. SKLabelNode has no outline, and
        // this is a vivid green number over pale green grass - the two are a long
        // way apart in hue and almost identical in brightness, which is the pairing
        // the eye is worst at. The ring of dark copies is the outline the class
        // does not have, and it costs four labels for three quarters of a second.
        let outline: [CGPoint] = [CGPoint(x: 1.6, y: 1.6), CGPoint(x: -1.6, y: 1.6),
                                  CGPoint(x: 1.6, y: -1.6), CGPoint(x: -1.6, y: -1.6)]

        var copies: [(CGPoint, SKColor)] = outline.map { ($0, RenderPalette.payoutShadow) }
        copies.append((CGPoint.zero, RenderPalette.payout))

        for (offset, colour) in copies {
            let amount = SKLabelNode(fontNamed: "AvenirNext-Bold")
            amount.text = "+\(tokens)"
            amount.fontSize = HotbarNode.slotSize * 0.36
            amount.fontColor = colour
            amount.horizontalAlignmentMode = .left
            amount.verticalAlignmentMode = .center
            amount.position = CGPoint(x: side * 0.2 + offset.x, y: offset.y)
            payout.addChild(amount)
        }

        // Pops, climbs, goes. The pop is what makes it read as being handed to you
        // rather than as a caption that faded in.
        payout.setScale(0.4)
        payout.run(.sequence([
            .group([
                .sequence([.scale(to: 1.18, duration: 0.12),
                           .scale(to: 1.0, duration: 0.1)]),
                .moveBy(x: 0, y: HotbarNode.slotSize * 0.85, duration: 0.75),
                .sequence([.wait(forDuration: 0.42),
                           .fadeOut(withDuration: 0.33)])
            ]),
            .removeFromParent()
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
