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

    private var slots: [ItemSlotNode] = []
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

    /// Rings one slot, or none. Kept out of `update` because arming is scene state
    /// rather than world state - the simulation has no idea a chest is selected.
    func setSelected(_ index: Int?) {
        for (slot, node) in slots.enumerated() {
            node.setSelected(slot == index)
        }
    }

    func update(with world: World) {
        guard let player = world.localPlayer else { return }

        // Whether each slot can be used is the actor's own answer, so a greyed slot
        // always means the simulation would refuse it. A bandage greys out at full
        // health; a bomb and a chest never do.
        let usable = (0..<Inventory.slotCount).map { player.canUse(slot: $0) }

        guard player.inventory != lastInventory || usable != lastUsable else { return }
        lastInventory = player.inventory
        lastUsable = usable

        for (index, stack) in player.inventory.slots.enumerated() {
            slots[index].show(stack, dimmed: !usable[index])
        }
    }
}
