//
//  TileType.swift
//  Loot Wars
//
//  Note there is no tree here. Trees are round obstacles, not tiles - see TreePatch.
//

enum TileType: Equatable {
    case floor
    /// The map edge. Never destroyed, never placed.
    case stone
    /// A wall placed by a team. Unlike terrain, these come and go during a match,
    /// and whether they block you depends on whose they are.
    case block(owner: TeamID)

    var blockOwner: TeamID? {
        guard case .block(let owner) = self else { return nil }
        return owner
    }
}
