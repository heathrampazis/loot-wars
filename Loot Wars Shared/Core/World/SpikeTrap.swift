//
//  SpikeTrap.swift
//  Loot Wars
//
//  A spike trap set into a base's floor (Nov 2026) - see SpikeSystem and
//  ItemType.spikes. Heath: "spikes as a defensive trap for bases. You should
//  not be able to see enemy spikes, they should appear when you walk on them
//  and cause a lot of damage, making raiding riskier and more difficult."
//

struct SpikeTrap {
    /// The bottom-left of the floor it is set into - two by two (Nov 2026:
    /// "spikes should be 2x2"). The key it is stored under in World.spikes.
    let tile: GridPoint

    /// Whose base it guards. It never hurts them.
    let owner: TeamID

    /// Seconds it stays showing for everybody after it bites - see
    /// GameConfig.Spikes.revealTime. Hidden from enemies while this is 0.
    var revealed: Double = 0

    /// Seconds until it can bite again.
    var rearm: Double = 0

    /// Tiles a side.
    static let size = 2

    /// Every tile it covers.
    var tiles: [GridPoint] {
        (0..<SpikeTrap.size).flatMap { dx in
            (0..<SpikeTrap.size).map { dy in GridPoint(col: tile.col + dx, row: tile.row + dy) }
        }
    }

    func covers(_ point: GridPoint) -> Bool {
        point.col >= tile.col && point.col < tile.col + SpikeTrap.size
            && point.row >= tile.row && point.row < tile.row + SpikeTrap.size
    }

    /// The middle of it, in tiles.
    var centre: Vec2 {
        Vec2(x: Double(tile.col) + Double(SpikeTrap.size) / 2,
             y: Double(tile.row) + Double(SpikeTrap.size) / 2)
    }
}
