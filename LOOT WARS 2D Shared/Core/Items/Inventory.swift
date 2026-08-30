//
//  Inventory.swift
//  Loot Wars
//
//  Four slots, matching the hotbar.
//

struct Inventory: Equatable {

    static let slotCount = 4

    private(set) var slots: [ItemStack?] = Array(repeating: nil, count: slotCount)

    var isFull: Bool { slots.allSatisfy { $0 != nil } }

    /// Total healing carried, in health points. What a bot uses to decide whether
    /// it is stocked well enough to go looking for a fight.
    func totalHealing(of maxHealth: Int) -> Int {
        slots.compactMap { $0 }.reduce(0) {
            $0 + $1.type.healAmount(of: maxHealth) * $1.count
        }
    }

    /// Whether this item would actually fit. Not the same as "not full": a full
    /// inventory can still take more of something it already has room to stack.
    func canAccept(_ type: ItemType) -> Bool {
        for slot in slots {
            guard let stack = slot else { return true }
            if stack.type == type, stack.count < type.maxStack { return true }
        }
        return false
    }

    /// Tops up a matching stack first, then takes the first empty slot.
    ///
    /// Returns false when there is nowhere for it to go. The caller is expected to
    /// leave the item where it is rather than quietly destroying it - picking
    /// something up and having it vanish is the worst possible outcome.
    mutating func add(_ type: ItemType) -> Bool {
        for index in slots.indices {
            guard var stack = slots[index],
                  stack.type == type,
                  stack.count < type.maxStack else { continue }

            stack.count += 1
            slots[index] = stack
            return true
        }

        for index in slots.indices where slots[index] == nil {
            slots[index] = ItemStack(type: type, count: 1)
            return true
        }

        return false
    }

    /// Takes one item out of a slot, emptying the slot if that was the last of them.
    /// Returns what was taken, or nil if the slot was empty.
    mutating func consume(at index: Int) -> ItemType? {
        guard slots.indices.contains(index), var stack = slots[index] else { return nil }

        let taken = stack.type
        stack.count -= 1
        slots[index] = stack.count > 0 ? stack : nil

        return taken
    }
}
