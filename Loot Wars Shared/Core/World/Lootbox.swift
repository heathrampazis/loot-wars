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

    /// Whether this is one of the good ones.
    ///
    /// A crate is the one thing on this map everybody walks past constantly, which
    /// makes it the cheapest place to put a decision: two crates in sight, one of
    /// them worth crossing an extra ten tiles for, and suddenly there is a reason
    /// to be somewhere in particular. That only works if you can tell them apart
    /// from a distance, which is what the separate artwork is for.
    var rare = false

    /// Whether this is a SUPPLY DROP: the golden crate that lands late in a
    /// match, holds one piece of top-tier gear, and cannot be opened until its
    /// countdown runs out - see SupplyDropSystem. It never comes back once opened.
    var supply = false

    /// Seconds until a supply drop can be opened. Zero for every ordinary crate.
    var lockTimer: Double = 0

    var isLocked: Bool { lockTimer > 0 }

    var position: Vec2 { tile.center }

    /// Lootboxes are solid. The size comes from GameConfig, and the renderer draws
    /// the sprite at exactly these dimensions, so the crate you see is the crate you
    /// bump into.
    var hitbox: Box {
        Box(centre: position, size: GameConfig.Loot.lootboxSize)
    }
}
