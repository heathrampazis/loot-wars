//
//  Pickup.swift
//  Loot Wars
//
//  Something lying on the ground waiting to be walked over.
//
//  Two kinds, and they behave completely differently: a drink goes into a hotbar
//  slot to be used later, while a helmet is worn the moment you touch it. Keeping
//  them as one type here - rather than forcing helmets through the inventory -
//  means the four hotbar slots stay for things you choose to use.
//

enum Pickup: Hashable {
    case item(ItemType)
    case helmet(HelmetTier)
    case blaster(BlasterTier)
}
