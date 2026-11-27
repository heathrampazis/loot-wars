//
//  BaseUpgrade.swift
//  Loot Wars
//
//  What the shop's BASE tab sells (Nov 2026): better arcades, turrets and
//  walls for your whole base, a few levels each. Heath: "Players should be
//  able to upgrade their arcades to drop more tokens, turrets to be stronger,
//  walls to be more durable etc. It should apply to enemies too."
//
//  Bought for a TEAM, not carried: nothing goes in the bag, and the level
//  stays with the base however many times you are knocked out. Kept in
//  World.baseUpgrades. What each level does is in GameConfig.Upgrades.
//
//  ONE purchase now, raising all three together (Nov 2026), from a button
//  that shows while you stand in your own base - see BaseUpgradeNode. A
//  shop tab with a card per upgrade went unnoticed: Heath, "it should be an
//  upgrade base option, but it should appear on the screen at your base, so
//  you dont have to go into a seperate menu".
//

enum BaseUpgrade: Int, CaseIterable {
    /// More tokens out of every arcade you own - see Upgrades.arcadeRate.
    case arcades
    /// Your turrets hit harder, fire faster and take more - see Upgrades.turret*.
    case turrets
    /// Your walls take more bombing before they give - see Upgrades.wallHealth.
    case walls
}
