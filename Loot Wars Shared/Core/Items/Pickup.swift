//
//  Pickup.swift
//  Loot Wars
//
//  Something lying on the ground waiting to be walked over.
//
//  Helmets and blasters used to have cases of their own here, because they were
//  worn on touch and could not be carried. Now that they can be carried they are
//  ItemTypes like everything else, and this is down to two cases: a thing, or
//  money. Two ways of saying "a helmet" would have been one too many.
//
//  Being an ItemType does not make gear behave like a bandage. LootSystem still
//  puts a better one straight onto your head; what changed is that a worse one now
//  has somewhere to go instead of being left in the grass.
//

enum Pickup: Hashable {
    case item(ItemType)
    /// Currency. Goes straight to a running total rather than a hotbar slot, so
    /// picking one up can never cost you a bandage you were carrying.
    case token(Int)

    /// How long this lies on the ground before it vanishes.
    ///
    /// Loot is on a short clock so the map does not silt up with everything anyone
    /// ever dropped. Tokens are not loot - they are meant to accumulate into a pile
    /// worth walking to - so they get their own, much longer one.
    var groundLifetime: Double {
        switch self {
        case .item:
            return GameConfig.Loot.itemLifetime
        case .token:
            return GameConfig.Arcade.tokenLifetime
        }
    }
}
