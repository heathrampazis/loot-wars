//
//  GroundItem.swift
//  Loot Wars
//
//  An item lying on the map, waiting to be walked over.
//

struct GroundItemID: Hashable {
    let raw: Int

    init(_ raw: Int) {
        self.raw = raw
    }
}

struct GroundItem {
    let id: GroundItemID
    let pickup: Pickup
    let position: Vec2

    /// Counts down to vanishing.
    var timeRemaining: Double

    /// Where it was flung from, when it was flung - a machine coming apart, say.
    /// Nothing in the simulation reads it: the item is where `position` says from
    /// the moment it exists. It is only so the screen can show it flying there.
    var launchedFrom: Vec2? = nil
}
