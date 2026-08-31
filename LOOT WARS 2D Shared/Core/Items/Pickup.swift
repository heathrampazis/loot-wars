//
//  Pickup.swift
//  Loot Wars
//
//  Something lying on the ground waiting to be walked over.
//
//  Two kinds, and they behave completely differently: a bandage goes into a hotbar
//  slot to be used later, while a helmet is worn the moment you touch it. Keeping
//  them as one type here - rather than forcing helmets through the inventory -
//  means the four hotbar slots stay for things you choose to use.
//

enum Pickup: Hashable {
    case item(ItemType)
    case helmet(HelmetTier)
    case blaster(BlasterTier)
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
        case .item, .helmet, .blaster:
            return GameConfig.Loot.itemLifetime
        case .token:
            return GameConfig.Arcade.tokenLifetime
        }
    }
}
