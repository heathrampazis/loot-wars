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
        case .foamBombs:     return "Foam Bombs"
        case .confettiPoppers: return "Confetti Poppers"
        case .spikes:        return "Spikes"
        case .fireworks:     return "Fireworks"
        case .fullArcade:    return "Arcade"
        case .resistance:    return "Resistance"
        case .invisibility:  return "Invisibility"
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
        case .foamBombs:     return "Hide in the foam"
        case .confettiPoppers: return "Small bombs for fights"
        case .spikes:        return "A hidden trap"
        case .fireworks:     return "Through any wall"
        case .fullArcade:    return "Earns tickets"
        case .resistance:    return "Take less damage"
        case .invisibility:  return "Vanish from view"
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
        case .foamBombs:
            return "Throw it to leave a cloud of pink foam. Anyone inside can't be seen."
        case .confettiPoppers:
            return "Like a small bomb. Less damage, but you get two or three at a time. Weak against walls."
        case .spikes:
            return "Set them in your base. Enemies can't see them until they step on one, and it hurts."
        case .fireworks:
            return "The biggest blast in the game. Opens any wall. Only found in raid chests and supply drops."
        case .regeneration:
            return "Heal a little every second for a while. Works mid-fight."
        case .fullArcade:
            return "The big machine. It pays out far more, so raiders will come for it."
        case .resistance:
            return "Take much less damage for a few seconds. Good for pushing into a base."
        case .invisibility:
            return "Enemies can't see you for a few seconds. Getting hit shows your outline."
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
