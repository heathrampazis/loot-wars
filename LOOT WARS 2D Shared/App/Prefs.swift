//
//  Prefs.swift
//  Loot Wars
//
//  The only thing this game remembers between launches.
//
//  Deliberately tiny, and deliberately the FIRST thing of its kind: until now
//  nothing in the project touched UserDefaults, which meant every match started
//  from absolute zero - including the tutorial, so a player on their tenth match
//  was still being taught how to build a wall.
//
//  What belongs here is what is true of the PLAYER rather than of a match. A match
//  is World's business and dies with it; how many matches somebody has played, and
//  which lessons they have already been taught, outlive it. Nothing here may ever
//  affect what happens inside a match - see the roadmap's meta rule - so this is a
//  memory of what you have seen, never of what you have earned.
//
//  Not in Core/. Core is the simulation and has no idea a device exists; a saved
//  preference is a fact about an installation.
//

import Foundation

enum Prefs {

    private static let store = UserDefaults.standard

    private enum Key {
        static let matchesStarted = "matchesStarted"
        static let taughtBuilding = "taughtBuilding"
        static let taughtSelling  = "taughtSelling"
    }

    /// How many matches this player has ever begun. Counted at the start rather
    /// than at the end, because the thing it gates is the tutorial, and somebody
    /// who quit halfway through their first match has still seen it.
    static var matchesStarted: Int {
        get { store.integer(forKey: Key.matchesStarted) }
        set { store.set(newValue, forKey: Key.matchesStarted) }
    }

    /// The first match, and only the first. Everything the tutorial says is
    /// something you either learned in five minutes or decided not to use, and a
    /// hint on your fourth match is not teaching, it is nagging.
    static var isFirstMatch: Bool { matchesStarted <= 1 }

    static var taughtBuilding: Bool {
        get { store.bool(forKey: Key.taughtBuilding) }
        set { store.set(newValue, forKey: Key.taughtBuilding) }
    }

    static var taughtSelling: Bool {
        get { store.bool(forKey: Key.taughtSelling) }
        set { store.set(newValue, forKey: Key.taughtSelling) }
    }

    /// For testing on a device, and for the day there is a settings screen with a
    /// "show me the tips again" line in it.
    static func forgetLessons() {
        taughtBuilding = false
        taughtSelling = false
    }
}
