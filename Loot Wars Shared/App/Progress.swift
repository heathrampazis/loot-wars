//
//  Progress.swift
//  Loot Wars
//
//  Your level, what it has unlocked, and what a finished match adds to it.
//
//  The rules - the curve, the milestones, what a match is worth - are Core's
//  (see Roadmap). This is the half that remembers: it reads and writes the XP
//  total in Prefs, and answers "what is this player's next match allowed to
//  have".
//

import Foundation

enum Progress {

    /// What a finished match did to your progress, for the results screen to
    /// play out.
    struct Award {
        let xpBefore: Int
        let gained: Int
        /// What the match's XP was multiplied by, for the difficulty and for
        /// playing without assistance. 1 for none.
        let multiplier: Double
        /// Features that unlocked during this match's level-ups, in roadmap order.
        let unlocked: [Feature]

        var xpAfter: Int { xpBefore + gained }
        var levelBefore: Int { Roadmap.level(forXP: xpBefore).level }
        var levelAfter: Int { Roadmap.level(forXP: xpAfter).level }
    }

    static var level: Int { Roadmap.level(forXP: Prefs.totalXP).level }

    /// What your next match has in it. Everything in dev mode.
    static var matchUnlocks: Unlocks {
        Prefs.devMode ? .all : Roadmap.unlocks(atLevel: level)
    }

    /// How long your next match runs. The full length in dev mode.
    static var matchLength: Double {
        Prefs.devMode ? GameConfig.Match.duration : Roadmap.matchLength(atLevel: level)
    }

    /// Adds a finished match to your XP and says what changed.
    ///
    /// Harder difficulties pay more, and playing without Assisted controls pays
    /// a little more on top - Hardcore with no assists is about half as much
    /// again as Easy. See Difficulty.xpMultiplier.
    ///
    /// - Parameters:
    ///   - place: 0 for first.
    ///   - difficulty: what the match was played on.
    ///   - assisted: whether Assisted controls were on.
    static func award(score: Int, place: Int,
                      difficulty: Difficulty = .hard, assisted: Bool = false) -> Award {
        let before = Prefs.totalXP
        let multiplier = difficulty.xpMultiplier
            * (assisted ? 1 : Difficulty.unassistedXPBonus)
        let gained = Int((Double(Roadmap.matchXP(score: score, place: place)) * multiplier).rounded())

        let oldLevel = Roadmap.level(forXP: before).level
        let newLevel = Roadmap.level(forXP: before + gained).level
        let unlocked = Roadmap.milestones
            .filter { $0.level > oldLevel && $0.level <= newLevel }
            .map { $0.feature }

        Prefs.totalXP = before + gained
        return Award(xpBefore: before, gained: gained, multiplier: multiplier, unlocked: unlocked)
    }
}
