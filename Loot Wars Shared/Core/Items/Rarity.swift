//
//  Rarity.swift
//  Loot Wars
//
//  How good a thing is, on one scale, for everything you can carry.
//
//  Five rungs, named after the gear tiers they belong to, and the names now MATCH:
//  an Epic helmet is Epic and glows green, a Cosmic is Cosmic and glows gold. That
//  sounds like the obvious arrangement and it was not the old one. There were six
//  rungs and eight helmet tiers, so the ladders were shifted a rung apart to fit -
//  an Epic helmet came out "rare" and wore blue - and every table, price and glow
//  in the game had to be read through that offset by anybody trying to change one.
//
//  What fixed it was deleting two rungs rather than adding one. The orange and red
//  helmets sat where a loot ladder conventionally has its cheap tiers, and orange
//  and red are the two hues this map cannot hold: the grass is warm green, the
//  tokens are gold, a blast is pink-white, and a warm pool under an item landed in
//  the middle of colours it half matched. Cutting them leaves grey, green, blue,
//  purple, gold - which is the sequence a player has known for fifteen years, in
//  the order they already know it, with nothing left over to shift.
//
//  It lives in Core with the items rather than in the renderer with the colours,
//  because it is a fact ABOUT an item - how hard it is to come by and how much it
//  changes a fight - and the same answer is wanted in three places that draw
//  nothing alike: a slot in a bag, a glow on the ground, the tile behind a shop
//  card. What each of those does with it is Render's business.
//

enum Rarity: Int, Comparable {
    case common = 0
    case epic
    case legendary
    case mythical
    case cosmic

    static func < (a: Rarity, b: Rarity) -> Bool { a.rawValue < b.rawValue }
}

extension ItemType {

    /// The gear ladders map straight across, at last. A helmet's tier IS its rung,
    /// a blaster is paired with the helmet it turns up beside, and Cosmic is the
    /// only thing wearing gold - the one rung you cannot find, only buy, and most
    /// matches nobody has.
    ///
    /// The supplies moved UP rather than down when the middle rungs went. They were
    /// sitting on the two that were deleted, and the choice was between pushing
    /// them to the bottom - where a medkit on the grass would look exactly like a
    /// bandage, which is a real thing lost - or letting them climb into the green
    /// and blue. Climbing is right: those colours are about what a thing is WORTH
    /// picking up, and a medkit is a whole health bar in one press. It does mean
    /// green now covers both a good helmet and a good supply, which is the honest
    /// cost of a shorter ladder and a smaller one than losing the medkit.
    var rarity: Rarity {
        switch self {
        // The things you trip over.
        case .bandage: return .common
        case .chest:   return .common

        // A whole health bar in one press, and the only reason to keep a slot free
        // on the way home.
        case .medkit:  return .epic

        // The key to somebody else's base, and the entire second half of the game
        // is behind that door. Worth crossing a map for in a way no helmet is, so
        // it wears purple: a find, not a supply.
        case .bomb:    return .mythical

        // A rung below a bomb. It takes ground away from somebody for a while, but
        // it cannot open a base, and opening a base is what the colour is about.
        case .stink:   return .legendary

        // The safest income on the map once it is standing behind a wall, and the
        // rung comes off the SIZE - Mythical for a cabinet, Legendary for a mini.
        // Asked of the kind rather than answered here for the same reason the perk
        // below is: the rung is a fact about the thing, and the loot table, the
        // pool on the grass and the glow on the crate are all already reading it
        // from one place.
        case .arcade(let kind): return kind.rarity

        // Legendary, the mini machine's rung. The two are found about as often and
        // are worth about as much to a base - one earns, one guards - and putting
        // them on the same rung says so before anybody has learned what either does.
        case .turret: return .mythical   // purple - a find, not furniture

        // The power-up carries its own rung - see Perk.rarity - rather than being
        // given one here. There is one perk and it is Mythical, so this line could
        // say so directly and be correct today; asking the perk keeps the rung a
        // fact about the ITEM, which is where the loot table and the glow were
        // already reading it from.
        case .perk(let which): return which.rarity

        // Bare-headed and a Common helmet are the same rung deliberately. There is
        // no colour below grey, and a helmet nobody would cross a tile for should
        // not be the thing that introduces one.
        case .helmet(let tier):
            switch tier {
            case .none, .common: return .common
            case .epic:          return .epic
            case .legendary:     return .legendary
            case .mythical:      return .mythical
            case .cosmic:        return .cosmic
            }

        // Paired with the helmets rung for rung, the same way the loot tables pair
        // them - a Blaster 3 turns up alongside an Epic, so they wear the same
        // colour and a glance at somebody tells you both.
        //
        // Six blasters against five rungs, so one rung takes two of them, and it is
        // the bottom one: Blaster 1 is what everybody respawns holding and Blaster 2
        // is the first thing any crate hands out. Neither is worth a colour of its
        // own, and doubling up anywhere higher would have cost a real distinction.
        case .blaster(let tier):
            switch tier {
            case .one, .two: return .common
            case .three:     return .epic
            case .four:      return .legendary
            case .five:      return .mythical
            case .six:       return .cosmic
            }
        }
    }
}
