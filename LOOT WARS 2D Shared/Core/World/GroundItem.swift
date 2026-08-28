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
    let type: ItemType
    let position: Vec2
}
