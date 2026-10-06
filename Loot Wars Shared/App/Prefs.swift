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
        static let matchesFinished = "matchesFinished"
        static let bestScore = "bestScore"
        static let taughtSelling  = "taughtSelling"
        static let taughtHolding  = "taughtHolding"
        static let lessonsVersion = "lessonsVersion"
        static let soundOn = "soundOn"
        static let tipsOn = "tipsOn"
        static let leftHanded = "leftHanded"
        static let easyControls = "easyControls"
        static let totalXP = "totalXP"
        static let devMode = "devMode"
        static let difficulty = "difficulty"
        static let playerName = "playerName"
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
    /// Two, down from three. The build lesson was retired - not learned, retired:
    /// it became a standing reminder that a base has no walls in it, which is a
    /// fact about the match rather than about the player, so there is nothing left
    /// for a device to remember about it. Lowering the count is what wipes the old
    /// flag off every device that already has one.
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
    /// player does the thing: one item sold. Until then it is offered again next
    /// match, because it has not worked yet.
    ///
    /// Every read runs the version check first, so a lesson that has been rewritten
    /// is offered again to everybody.
    static var taughtSelling: Bool {
        get { migrateIfNeeded(); return store.bool(forKey: Key.taughtSelling) }
        set { store.set(newValue, forKey: Key.taughtSelling) }
    }

    /// The one lesson that teaches itself by happening: the first time your own
    /// base pays out, the game says what the number was for.
    static var taughtHolding: Bool {
        get { migrateIfNeeded(); return store.bool(forKey: Key.taughtHolding) }
        set { store.set(newValue, forKey: Key.taughtHolding) }
    }

    private static func migrateIfNeeded() {
        guard store.integer(forKey: Key.lessonsVersion) != lessons else { return }
        store.set(lessons, forKey: Key.lessonsVersion)
        store.set(false, forKey: Key.taughtSelling)
        store.set(false, forKey: Key.taughtHolding)
    }

    /// Matches played to the whistle, and the best you have ever scored.
    ///
    /// The first two things the menu has to say. A title screen with nothing on it
    /// but a play button is a door; a title screen that knows your best score is
    /// the start of a reason to press it again - and these are the two rows the
    /// stats screen in the roadmap begins with.
    static var matchesFinished: Int {
        get { store.integer(forKey: Key.matchesFinished) }
        set { store.set(newValue, forKey: Key.matchesFinished) }
    }

    static var bestScore: Int {
        get { store.integer(forKey: Key.bestScore) }
        set { store.set(newValue, forKey: Key.bestScore) }
    }

    /// Records the end of a match. Everything here is a high-water mark or a count,
    /// so finishing badly can never take anything away from you.
    static func finishedMatch(scoring score: Int) {
        matchesFinished += 1
        bestScore = max(bestScore, score)
    }

    // MARK: - Settings

    /// Sound on or off - every sound goes through SoundPlayer, which asks this.
    /// On until somebody turns it off, so a missing value means on.
    static var soundOn: Bool {
        get { store.object(forKey: Key.soundOn) as? Bool ?? true }
        set { store.set(newValue, forKey: Key.soundOn) }
    }

    /// Mirror the controls: move stick on the right, aim stick on the left. Read
    /// by GameScene when it lays the controls out at the start of a match.
    static var leftHanded: Bool {
        get { store.bool(forKey: Key.leftHanded) }
        set { store.set(newValue, forKey: Key.leftHanded) }
    }

    /// Easy controls: crates open as you reach them, heals are used for you when
    /// your health drops low, shots bend onto nearby enemies and power-ups switch
    /// on when a fight starts. Off until switched on. Read by GameScene at
    /// the start of a match - see AssistSystem.
    static var easyControls: Bool {
        get { store.bool(forKey: Key.easyControls) }
        set { store.set(newValue, forKey: Key.easyControls) }
    }

    /// The name over your head and on the leaderboard, typed on the title screen. Always
    /// cleaned - see PlayerNames.clean - and "You" until one is chosen.
    static var playerName: String {
        get { PlayerNames.clean(store.string(forKey: Key.playerName) ?? "") }
        set { store.set(PlayerNames.clean(newValue), forKey: Key.playerName) }
    }

    /// How hard the bots play - see Difficulty. Hard, the game as tuned, until
    /// somebody picks Easy in Settings.
    static var difficulty: Difficulty {
        get {
            guard store.object(forKey: Key.difficulty) != nil else { return .hard }
            return Difficulty(rawValue: store.integer(forKey: Key.difficulty)) ?? .hard
        }
        set { store.set(newValue.rawValue, forKey: Key.difficulty) }
    }

    /// Tips on or off - the hints that teach building, raiding, selling and
    /// what your base earns. On until switched off. Switching them back on
    /// forgets which ones you have learned, so they all come round again.
    static var tipsOn: Bool {
        get { store.object(forKey: Key.tipsOn) as? Bool ?? true }
        set {
            store.set(newValue, forKey: Key.tipsOn)
            if newValue { forgetLessons() }
        }
    }

    // MARK: - Progression

    /// Every point of XP ever earned. The level is worked out from this - see
    /// Roadmap.level(forXP:) - so changing the curve never strands anybody.
    static var totalXP: Int {
        get { store.integer(forKey: Key.totalXP) }
        set { store.set(max(0, newValue), forKey: Key.totalXP) }
    }

    /// Every feature unlocked in matches, whatever your level - for testing the
    /// whole game together. Your real level and XP are untouched.
    ///
    /// No longer switchable in the app: the Settings row was removed for
    /// release. To test with it, set `devModeForced` to true below and build.
    /// The saved value is ignored, so a phone that had it switched on during
    /// testing goes back to normal play.
    static var devMode: Bool {
        get { devModeForced }
        set { store.set(newValue, forKey: Key.devMode) }
    }

    /// Flip to true to play every match with everything unlocked. Must be false
    /// in anything shipped.
    static let devModeForced = false

    static func forgetLessons() {
        taughtSelling = false
        taughtHolding = false
    }
}
