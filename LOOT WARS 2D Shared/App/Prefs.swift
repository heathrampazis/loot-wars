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
        static let lessonsVersion = "lessonsVersion"
    }

    /// Bumped whenever a lesson CHANGES, which wipes every "you have seen this"
    /// flag on the device.
    ///
    /// This exists because of a real bug and is worth keeping for the next one. The
    /// build lesson was gated on being your first ever match, the match counter had
    /// been running for several builds by the time the lesson itself was finished,
    /// and the result was a tutorial that could never appear on the only device it
    /// had to appear on. A flag saying "already seen" is a claim about a version of
    /// a lesson, not about the player, and the version has to be part of it.
    private static let lessons = 2

    /// How many matches this player has ever begun.
    ///
    /// It gates nothing. It used to gate the tutorial and that was a mistake worth
    /// leaving a note about: a match count cannot tell whether anybody learned
    /// anything, and it had already been running for several builds by the time the
    /// lesson it switched off was finished. It stays because "matches played" is
    /// the first line of the stats screen the roadmap wants next.
    static var matchesStarted: Int {
        get { store.integer(forKey: Key.matchesStarted) }
        set { store.set(newValue, forKey: Key.matchesStarted) }
    }

    /// Whether each lesson has been LEARNED, which is not the same as shown.
    ///
    /// Counting matches was the first attempt at this and it was wrong twice over.
    /// It could not tell the difference between somebody who had built a wall and
    /// somebody who had spent their first match being shot at in a field - and it
    /// switched the tutorial off after one match either way. A lesson ends when the
    /// player does the thing: three walls laid, one item sold. Until then it is
    /// offered again next match, because it has not worked yet.
    ///
    /// Every read runs the version check first, so a lesson that has been rewritten
    /// is offered again to everybody.
    static var taughtBuilding: Bool {
        get { migrateIfNeeded(); return store.bool(forKey: Key.taughtBuilding) }
        set { store.set(newValue, forKey: Key.taughtBuilding) }
    }

    static var taughtSelling: Bool {
        get { migrateIfNeeded(); return store.bool(forKey: Key.taughtSelling) }
        set { store.set(newValue, forKey: Key.taughtSelling) }
    }

    private static func migrateIfNeeded() {
        guard store.integer(forKey: Key.lessonsVersion) != lessons else { return }
        store.set(lessons, forKey: Key.lessonsVersion)
        store.set(false, forKey: Key.taughtBuilding)
        store.set(false, forKey: Key.taughtSelling)
    }

    /// For testing on a device, and for the day there is a settings screen with a
    /// "show me the tips again" line in it.
    static func forgetLessons() {
        taughtBuilding = false
        taughtSelling = false
    }
}
