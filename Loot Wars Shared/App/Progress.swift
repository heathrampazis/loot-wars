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

    /// How long your next match runs.
    ///
    /// Set by the difficulty now - longer on Hard and Hardcore, see
    /// Difficulty.matchLength. Roadmap.matchLength is kept as the per-level
    /// hook, and is the same at every level.
    static var matchLength: Double {
        Prefs.difficulty.matchLength
    }

    /// Adds a finished match to your XP and says what changed.
    ///
    /// Harder difficulties pay more - Hardcore is about half as much again as
    /// Easy. The help you get is part of the difficulty now, so there is no
    /// separate bonus for playing without it. See Difficulty.xpMultiplier.
    ///
    /// - Parameters:
    ///   - place: 0 for first.
    ///   - difficulty: what the match was played on.
    static func award(score: Int, place: Int,
                      difficulty: Difficulty = .hard) -> Award {
        let before = Prefs.totalXP
        let multiplier = difficulty.xpMultiplier
        // Nothing is earned past the top level. Capped here so the total stops
        // at it and the results screen has nothing to fill.
        let earned = Int((Double(Roadmap.matchXP(score: score, place: place)) * multiplier).rounded())
        let gained = max(0, min(earned, Roadmap.maxXP - before))

        let oldLevel = Roadmap.level(forXP: before).level
        let newLevel = Roadmap.level(forXP: before + gained).level
        let unlocked = Roadmap.milestones
            .filter { $0.level > oldLevel && $0.level <= newLevel }
            .map { $0.feature }

        Prefs.totalXP = max(before, before + gained)
        return Award(xpBefore: before, gained: gained, multiplier: multiplier, unlocked: unlocked)
    }
}
