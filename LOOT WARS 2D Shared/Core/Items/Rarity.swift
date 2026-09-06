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

    /// The gear ladders sit one rung LOWER than their names suggest, and that is
    /// deliberate. There are eight helmet tiers and six colours, so something has to
    /// give, and the honest place to give is the top: an Epic is a good helmet you
    /// will own several of in a match, and painting it the same purple a game
    /// normally reserves for its second-best item oversells it. Shifted down, blue
    /// means Epic, purple means Legendary, orange means Mythical, and gold is
    /// Cosmic and nothing else - the one thing on the ladder you cannot find, only
    /// buy, and most matches nobody has.
    ///
    /// The supplies are judged by what it takes to get one and what it does. A
    /// bandage and a chest are things you trip over; a medkit is a whole health bar
    /// in one press; a machine is the most expensive thing anybody buys.
    var rarity: Rarity {
        switch self {
        case .bandage: return .common
        case .chest:   return .common
        case .bomb:    return .uncommon
        // A rung above a bomb: rarer in every table it appears in, and the only
        // thing in the game that takes ground away from somebody without taking
        // any of the map with it.
        case .stink:   return .rare
        case .medkit:  return .uncommon
        case .arcade:  return .epic

        // The power-up carries its own rung - see Perk.rarity - rather than being
        // given one here. There is one perk and it is Epic, so this line could say
        // so directly and be correct today; asking the perk keeps the rung a fact
        // about the ITEM, which is where it was already being read from by the
        // loot table and the glow.
        case .perk(let which): return which.rarity

        case .helmet(let tier):
            switch tier {
            case .none, .common, .uncommon: return .common
            case .rare:      return .uncommon
            case .epic:      return .rare
            case .legendary: return .epic
            case .mythical:  return .legendary
            case .cosmic:    return .mythical
            }

        // Paired with the helmets rung for rung, the same way the loot tables pair
        // them - a Blaster 4 turns up alongside an Epic, so they wear the same
        // colour and a glance at somebody tells you both.
        case .blaster(let tier):
            switch tier {
            case .one, .two: return .common
            case .three:     return .uncommon
            case .four:      return .rare
            case .five:      return .epic
            case .six:       return .legendary
            }
        }
    }
}
