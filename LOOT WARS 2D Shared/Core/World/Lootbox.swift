//
//  Lootbox.swift
//  Loot Wars
//

struct LootboxID: Hashable {
    let raw: Int

    init(_ raw: Int) {
        self.raw = raw
    }
}

struct Lootbox {
    let id: LootboxID
    let tile: GridPoint

    /// You can walk over a lootbox - it is a thing on the ground, not an obstacle.
    var position: Vec2 { tile.center }
}
