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

    var position: Vec2 { tile.center }

    /// Lootboxes are solid. The size comes from GameConfig, and the renderer draws
    /// the sprite at exactly these dimensions, so the crate you see is the crate you
    /// bump into.
    var hitbox: Box {
        Box(centre: position, size: GameConfig.Loot.lootboxSize)
    }
}
