//
//  ItemType.swift
//  Loot Wars
//
//  What an item IS. Deliberately says nothing about what it looks like - the art
//  for each type lives in Render/ItemArt, so Core never learns about textures.
//
//  Note the trade the three drinks make: the bigger the heal, the fewer you can
//  carry. Five juices restore more in total than two slushies, but a slushy is the
//  one that saves you mid-fight.
//

enum ItemType: Hashable, CaseIterable {
    case juice
    case soda
    case slushy

    /// How many fit in one inventory slot.
    var maxStack: Int {
        switch self {
        case .juice:  return 5
        case .soda:   return 4
        case .slushy: return 2
        }
    }

    /// Share of maximum health restored when drunk.
    var healFraction: Double {
        switch self {
        case .juice:  return 0.25
        case .soda:   return 0.50
        case .slushy: return 1.00
        }
    }

    /// Health restored, in points.
    var healAmount: Int {
        Int((Double(GameConfig.Player.maxHealth) * healFraction).rounded())
    }
}
