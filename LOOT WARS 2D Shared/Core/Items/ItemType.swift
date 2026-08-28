//
//  ItemType.swift
//  Loot Wars
//
//  What an item IS. Deliberately says nothing about what it looks like - the art
//  for each type lives in Render/ItemArt, so Core never learns about textures.
//

enum ItemType: Hashable {
    case soda

    /// How many fit in one inventory slot.
    var maxStack: Int {
        switch self {
        case .soda: return 9
        }
    }
}
