`//
//  Upgrade.swift
//  Loot Wars
//
//  Things you buy for your BASE rather than for yourself.
//
//  The distinction is worth drawing sharply, because it is the first time this shop
//  has sold anything that is not an object. A helmet goes on your head and dies
//  with you; an upgrade is bought once and belongs to the team for the rest of the
//  match, however many times its owner is killed. That is what makes them worth
//  their prices, and it is also why they cannot be items: there is nothing to put
//  in a slot, nothing to drop, and nothing to steal.
//
//  Three tiers each, and the ceiling matters as much as the steps. Two upgrades
//  that could be bought forever would end every match the same way - whoever found
//  the most tokens has the best base - where three rungs means a base is finished
//  and the tokens go back to the ladder.
//

enum Upgrade: Hashable, CaseIterable {
    /// Walls that take more than one bomb to open.
    case walls

    /// A machine that pays faster and gilds more of what it pays.
    case arcade

    static let maxTier = 3

    var name: String {
        switch self {
        case .walls:  return "Walls"
        case .arcade: return "Arcade"
        }
    }
}
