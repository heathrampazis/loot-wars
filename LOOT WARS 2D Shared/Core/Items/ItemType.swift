//
//  ItemType.swift
//  Loot Wars
//
//  What an item IS. Deliberately says nothing about what it looks like - the art
//  for each type lives in Render/ItemArt, so Core never learns about textures.
//
//  Note the trade the three supplies make: the bigger the heal, the fewer you can
//  carry. Five bandaids restore more in total than two medkits, but a medkit is the
//  one that saves you mid-fight.
//

enum ItemType: Hashable, CaseIterable {
    case bandaid
    case bandage
    case medkit
    case bomb

    /// How many fit in one inventory slot.
    var maxStack: Int {
        switch self {
        case .bandaid: return 5
        case .bandage: return 4
        case .medkit:  return 2
        case .bomb:    return 3
        }
    }

    /// Whether this is something you patch yourself up with. A bomb sits in the
    /// same four slots but is thrown at a wall - and without this the hotbar would
    /// happily let you dress a wound with one.
    var isHealing: Bool { healFraction > 0 }

    /// Share of maximum health restored when used.
    var healFraction: Double {
        switch self {
        case .bandaid: return 0.25
        case .bandage: return 0.50
        case .medkit:  return 1.00
        case .bomb:    return 0
        }
    }

    /// Health restored, in points, for an actor with this much health at full.
    ///
    /// A share rather than a fixed number, so a bandage is worth proportionally the
    /// same whether you are bare-headed or wearing a Cosmic.
    func healAmount(of maxHealth: Int) -> Int {
        Int((Double(maxHealth) * healFraction).rounded())
    }
}
