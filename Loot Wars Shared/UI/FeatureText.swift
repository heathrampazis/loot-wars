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

    /// One or two short lines on what it does, for its page on the roadmap.
    var detail: String {
        switch self {
        case .strength:
            return "Your shots hit harder for a few seconds. Use it just before a fight."
        case .miniArcade:
            return "A small machine for your base. It pays out tokens to spend in the shop."
        case .speed:
            return "Run faster for a few seconds. Good for reaching a supply drop first."
        case .stinkBombs:
            return "Throw it to leave a cloud of gas. Anyone inside takes damage."
        case .regeneration:
            return "Heal a little every second for a while. Works mid-fight."
        case .fullArcade:
            return "The big machine. It pays out far more, so raiders will come for it."
        case .resistance:
            return "Take much less damage for a few seconds. Good for pushing into a base."
        case .turrets:
            return "Place it in your base. It shoots any enemy who walks in."
        case .discoBall:
            return "Every power-up at once. It's rare, so save it for a big fight."
        case .cosmicHelmet:
            return "The toughest helmet in the game. Find it late in a match or buy it in the shop."
        case .cosmicBlaster:
            return "The strongest blaster in the game. Find it late in a match or buy it in the shop."
        }
    }
}
