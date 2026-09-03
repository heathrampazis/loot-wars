//
//  Rarity.swift
//  Loot Wars
//
//  How good a thing is, on one scale, for everything you can carry.
//
//  Six rungs, because that is what people already know: the colours have meant the
//  same thing in every game with loot in it for fifteen years, and a player who has
//  ever seen a purple item knows it beats a green one without being told. Borrowing
//  a convention this well established is worth more than inventing a truer one.
//
//  It lives in Core with the items rather than in the renderer with the colours,
//  because it is a fact ABOUT an item - how hard it is to come by and how much it
//  changes a fight - and the same answer is wanted in three places that draw
//  nothing alike: a slot in a bag, a glow on the ground, the tile behind a shop
//  card. What each of those does with it is Render's business.
//
//  The gear ladders map straight across. The rest is judged by what it takes to get
//  one and what it does when you use it: a bandage is the commonest thing on the
//  map, a medkit is a whole health bar in one press, and a machine is the single
//  most expensive thing anybody buys.
//

enum Rarity: Int, Comparable {
    case common = 0
    case uncommon
    case rare
    case epic
    case legendary
    case mythical

    static func < (a: Rarity, b: Rarity) -> Bool { a.rawValue < b.rawValue }
}

extension ItemType {

    var rarity: Rarity {
        switch self {
        case .bandage: return .common
        case .bomb:    return .uncommon
        case .chest:   return .uncommon
        case .medkit:  return .rare
        case .arcade:  return .epic

        case .helmet(let tier):
            switch tier {
            case .none, .common:    return .common
            case .uncommon:         return .uncommon
            case .rare:             return .rare
            case .epic:             return .epic
            case .legendary:        return .legendary
            case .mythical, .cosmic: return .mythical
            }

        case .blaster(let tier):
            switch tier {
            case .one:   return .common
            case .two:   return .uncommon
            case .three: return .rare
            case .four:  return .epic
            case .five:  return .legendary
            case .six:   return .mythical
            }
        }
    }
}
