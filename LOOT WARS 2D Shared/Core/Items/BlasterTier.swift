//
//  BlasterTier.swift
//  Loot Wars
//
//  What you are shooting with.
//
//  Unlike helmets there is no bare-handed state: everybody starts holding a
//  Blaster1 and drops back to one when they die. Only the upgrades are worth
//  dropping, so the map never fills with starter weapons nobody wants.
//
//  Damage figures are straight from the design spec. Together with the helmet
//  ladder they are what keeps a fight readable: a top blaster kills a bare head in
//  three shots, and a starter blaster needs thirty against a Cosmic.
//

enum BlasterTier: Int, CaseIterable, Comparable {
    case one = 1
    case two, three, four, five, six

    static let starting = BlasterTier.one

    var damage: Int {
        switch self {
        case .one:   return 12
        case .two:   return 16
        case .three: return 21
        case .four:  return 27
        case .five:  return 34
        case .six:   return 42
        }
    }

    /// Grip to barrel tip, in tiles. Bigger guns are longer, and this is what puts
    /// a shot at the end of the barrel rather than somewhere inside the character.
    var barrelLength: Double {
        0.45 + 0.05 * Double(rawValue - 1)
    }

    /// How far in front of an actor's centre its shots appear.
    var muzzleOffset: Double {
        GameConfig.Blaster.holdDistance + barrelLength
    }

    /// Chance this survives its owner's death and lands on the ground. A starter
    /// blaster never does - everybody already has one.
    var dropChance: Double {
        guard self > .starting else { return 0 }

        let above = Double(rawValue - BlasterTier.starting.rawValue - 1)
        return min(GameConfig.Drops.maximumChance,
                   GameConfig.Drops.baseChance + GameConfig.Drops.chancePerTier * above)
    }

    var assetName: String { "Blaster\(rawValue)" }

    static func < (a: BlasterTier, b: BlasterTier) -> Bool { a.rawValue < b.rawValue }
}
