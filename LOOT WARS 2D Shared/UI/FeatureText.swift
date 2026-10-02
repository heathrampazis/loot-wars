//
//  FeatureText.swift
//  Loot Wars
//
//  What each unlock is called, and one line on what it does - for the roadmap
//  and the unlock card on the results screen.
//

extension Feature {

    var title: String {
        switch self {
        case .strength:      return "Strength"
        case .miniArcade:    return "Mini Arcade"
        case .speed:         return "Swiftness"
        case .turrets:       return "Turrets"
        case .regeneration:  return "Regeneration"
        case .stinkBombs:    return "Stink Bombs"
        case .fullArcade:    return "Arcade"
        case .resistance:    return "Resistance"
        case .discoBall:     return "Disco Ball"
        case .cosmicHelmet:  return "Cosmic Helmet"
        case .cosmicBlaster: return "Cosmic Blaster"
        }
    }

    var blurb: String {
        switch self {
        case .strength:      return "Hit harder"
        case .miniArcade:    return "Earns tickets"
        case .speed:         return "Run faster"
        case .turrets:       return "Bases fight back"
        case .regeneration:  return "Heal over time"
        case .stinkBombs:    return "Gas them out"
        case .fullArcade:    return "Earns tickets"
        case .resistance:    return "Take less damage"
        case .discoBall:     return "Every power-up"
        case .cosmicHelmet:  return "The best helmet"
        case .cosmicBlaster: return "The best blaster"
        }
    }

    /// A few sentences on what it does and how to use it, for its page on the
    /// roadmap.
    var detail: String {
        switch self {
        case .strength:
            return "A power-up that makes every shot hit harder for a few seconds. Tap it in your hotbar just before a fight - it turns a close duel your way."
        case .miniArcade:
            return "A small machine you place inside your base. It pays out tokens every few seconds - pick them up and spend them in the shop. Seal your walls so nobody steals them."
        case .speed:
            return "A power-up that makes you run faster for a few seconds. Use it to grab a supply drop first, chase somebody down, or get home before a raid."
        case .stinkBombs:
            return "A throwable that leaves a cloud of gas. Anyone standing in it takes damage over time - throw it into a doorway or onto a chest to clear the room."
        case .regeneration:
            return "A power-up that heals you a little every second for a few seconds. Pop it mid-fight and keep shooting while your health climbs."
        case .fullArcade:
            return "The big machine. It earns far more than the mini arcade, but it is the first thing raiders come for - put it deep inside your walls."
        case .resistance:
            return "A power-up that makes you take much less damage for a few seconds. Perfect for pushing into a base or holding a supply drop."
        case .turrets:
            return "A defence you place in your base. It shoots any enemy who comes inside your claim. Raiders have to deal with it before they can touch your chests."
        case .discoBall:
            return "The best power-up in the game: strength, swiftness, regeneration and resistance, all at once. Rare - save it for the fight that matters."
        case .cosmicHelmet:
            return "The top helmet, above Mythical. The most health in the game. Found in late crates and supply drops, or bought in the shop."
        case .cosmicBlaster:
            return "The top blaster, above Blaster 5. The most damage in the game. Found in late crates and supply drops, or bought in the shop."
        }
    }
}
