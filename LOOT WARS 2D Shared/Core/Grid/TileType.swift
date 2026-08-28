//
//  TileType.swift
//  Loot Wars
//

enum TileType {
    case floor
    case stone

    var isSolid: Bool {
        switch self {
        case .floor: return false
        case .stone: return true
        }
    }
}
