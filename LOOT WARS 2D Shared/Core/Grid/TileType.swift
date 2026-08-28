//
//  TileType.swift
//  Loot Wars
//

enum TileType: Equatable {
    case floor
    /// The map edge. Never destroyed, never placed.
    case stone
    /// Scenery you cannot walk through. Occupies exactly one tile of collision,
    /// even though it is drawn a bit larger than that.
    case tree
    /// A wall placed by a team. Unlike terrain, these come and go during a match,
    /// and whether they block you depends on whose they are.
    case block(owner: TeamID)

    var blockOwner: TeamID? {
        guard case .block(let owner) = self else { return nil }
        return owner
    }
}
