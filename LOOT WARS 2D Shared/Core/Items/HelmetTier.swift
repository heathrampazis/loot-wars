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
    case epic
    case legendary
    case mythical
    case cosmic

    /// Each tier is 29% tougher than the one below it.
    ///
    /// A rule rather than a table, so it stays tunable with one number: change the
    /// step and the whole ladder re-spaces itself, instead of a column of figures
    /// needing to be re-balanced against each other by hand.
    ///
    /// Up from 1.2, and the change is arithmetic rather than a buff. Two rungs came
    /// off the middle of this ladder - Uncommon and Rare - and with the step left
    /// alone that would have quietly cut the best helmet in the game from 3.58
    /// times a bare head to 2.49, which is not a decision anybody made. 1.29 to the
    /// fifth is 3.57, so the two ENDS of the ladder are where they were and the
    /// rungs between them simply re-space. That matters beyond feel: the design
    /// spec's readable facts are about the ends - a top blaster kills a bare head
    /// in three shots, a starter needs thirty against a Cosmic - and both are still
    /// exactly true.
    static let healthStep = 1.29

    var maxHealth: Int {
        let base = Double(GameConfig.Player.baseHealth)
        return Int((base * pow(HelmetTier.healthStep, Double(rawValue))).rounded())
    }

    /// Chance this survives its owner's death and lands on the ground.
    var dropChance: Double {
        guard self > .none else { return 0 }

        let above = Double(rawValue - 1)
        return min(GameConfig.Drops.maximumChance,
                   GameConfig.Drops.baseChance + GameConfig.Drops.chancePerTier * above)
    }

    var name: String {
        switch self {
        case .none:      return "None"
        case .common:    return "Common"
        case .epic:      return "Epic"
        case .legendary: return "Legendary"
        case .mythical:  return "Mythical"
        case .cosmic:    return "Cosmic"
        }
    }

    static func < (a: HelmetTier, b: HelmetTier) -> Bool { a.rawValue < b.rawValue }
}
