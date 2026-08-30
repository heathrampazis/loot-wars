//
//  HelmetTier.swift
//  Loot Wars
//
//  What you are wearing, and therefore how much punishment you can take.
//
//  Everyone starts bare-headed and everyone goes back to bare-headed when they
//  die - a helmet is something you are carrying through the match, not something
//  you own. That is what makes a well-equipped player worth hunting, and what
//  stops an early lead compounding for eight minutes.
//

import Foundation

enum HelmetTier: Int, CaseIterable, Comparable {
    case none = 0
    case common
    case uncommon
    case rare
    case epic
    case legendary
    case mythical
    case cosmic

    /// Each tier is a fifth tougher than the one below it.
    ///
    /// A rule rather than a table, so it stays tunable with one number: change the
    /// step and the whole ladder re-spaces itself, instead of eight figures
    /// needing to be re-balanced against each other by hand.
    static let healthStep = 1.2

    var maxHealth: Int {
        let base = Double(GameConfig.Player.baseHealth)
        return Int((base * pow(HelmetTier.healthStep, Double(rawValue))).rounded())
    }

    var name: String {
        switch self {
        case .none:      return "None"
        case .common:    return "Common"
        case .uncommon:  return "Uncommon"
        case .rare:      return "Rare"
        case .epic:      return "Epic"
        case .legendary: return "Legendary"
        case .mythical:  return "Mythical"
        case .cosmic:    return "Cosmic"
        }
    }

    static func < (a: HelmetTier, b: HelmetTier) -> Bool { a.rawValue < b.rawValue }
}
