//
//  TileType.swift
//  Loot Wars
//

enum TileType {
    case floor
    /// The map edge. Never destroyed, never placed.
    case stone
    /// Scenery you cannot walk through. Occupies exactly one tile of collision,
    /// even though it is drawn a bit larger than that.
    case tree
    /// A wall placed by a player. Unlike terrain, these come and go during a match.
    case block

    var isSolid: Bool {
        switch self {
        case .floor: return false
        case .stone: return true
        case .tree:  return true
        case .block: return true
        }
    }
}
