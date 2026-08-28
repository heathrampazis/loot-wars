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
}
