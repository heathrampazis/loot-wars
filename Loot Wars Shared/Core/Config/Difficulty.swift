//
//  Difficulty.swift
//  Loot Wars
//
//  How hard the seven bots play, picked in Settings.
//
//  Four settings, in order: Easy, Medium, Hard, Hardcore.
//
//  HARD is the game exactly as it is tuned everywhere else - every number in
//  GameConfig.AI is the hard game, and choosing Hard changes nothing. EASY eases
//  the bots right off: they aim worse, react slower, raid and hunt less often,
//  never turn on whoever is winning, and get none of their quiet help
//  (power-up luck, faster bomb top-ups, toughened turrets). MEDIUM sits between
//  the two. HARDCORE goes past Hard: sharper aim, quicker reactions, more
//  raiding, more help, and bigger gangs on the leader.
//
//  It also sets how much the game helps YOU (Oct 2026) - what used to be the
//  separate Assisted controls switch. Easy aims for you, heals you at half
//  health and switches power-ups on in a fight. Medium does the same, lighter.
//  Hard only steps in to stop a death with a heal you are carrying. Hardcore
//  leaves you on your own. One choice, so Hard and Hardcore really are hard -
//  nobody plays Hardcore with the aim done for them.
//
//  Your health, damage, loot, prices and the scoring are the same on all four.
//

enum Difficulty: Int, CaseIterable {
    // Declared easiest first, which is the order Settings cycles through. The
    // raw values are what Prefs saves: Easy and Hard kept the numbers they
    // shipped with, so a saved choice still means the same thing.
    case easy = 0
    case medium = 2
    case hard = 1
    case hardcore = 3

    var title: String {
        switch self {
        case .easy:     return "Easy"
        case .medium:   return "Medium"
        case .hard:     return "Hard"
        case .hardcore: return "Hardcore"
        }
    }

    /// The next setting along, wrapping round - what a tap in Settings picks.
    var next: Difficulty {
        let all = Difficulty.allCases
        let index = all.firstIndex(of: self) ?? 0
        return all[(index + 1) % all.count]
    }

    /// How much wider a bot's aim wobble is. Roughly the share of aim-limited
    /// shots that land: Easy 23%, Medium 31%, Hard 43%, Hardcore 53% - see
    /// GameConfig.AI.aimSpread.
    /// XP for a match is multiplied by this - see Progress.award. Harder pays
    /// better: not enough to make Easy a chore, enough to see on the results.
    var xpMultiplier: Double {
        switch self {
        // Wider apart than before (Oct 2026): the help you get is part of the
        // setting now, and there is no separate bonus for turning it off.
        case .easy:     return 1.0
        case .medium:   return 1.15
        case .hard:     return 1.3
        case .hardcore: return 1.45
        }
    }


    // MARK: - Help for the player - see AssistSystem

    /// How far off a shot can be and still be bent onto somebody, in radians,
    /// or nil for no aim help.
    var assistAimCone: Double? {
        switch self {
        case .easy:     return 0.44   // about 25 degrees either side
        case .medium:   return 0.26   // about 15
        case .hard, .hardcore: return nil
        }
    }

    /// Below this share of health a heal you are carrying is used for you, or
    /// nil for never. On Hard it is a last-ditch save, not a habit.
    var assistHealBelow: Double? {
        switch self {
        case .easy:     return 0.5
        case .medium:   return 0.35
        case .hard:     return 0.25
        case .hardcore: return nil
        }
    }

    /// Whether a power-up you are carrying switches on for you in a fight.
    var assistPerks: Bool { self == .easy || self == .medium }

    // MARK: - Match length

    /// How long a match runs, in seconds.
    ///
    /// Longer the harder it gets (Oct 2026). With no help and sharper bots,
    /// everything takes longer on Hard and Hardcore - a fight, a base, a raid -
    /// and two and a half minutes left no time to do anything but survive. The
    /// phases (opening, final 30) are fixed lengths and everything that runs on
    /// match progress stretches to fit, so a longer match is more of the middle.
    var matchLength: Double {
        switch self {
        case .easy, .medium: return GameConfig.Match.duration   // 2:30
        case .hard, .hardcore: return 180                        // 3:00
        }
    }

    var aimSpreadScale: Double {
        switch self {
        case .easy:     return 1.85
        case .medium:   return 1.4
        case .hard:     return 1
        case .hardcore: return 0.85
        }
    }

    /// How much slower (or quicker) a bot is to react to somebody it has just
    /// seen.
    var reactionScale: Double {
        switch self {
        case .easy:     return 2.2
        case .medium:   return 1.5
        case .hard:     return 1
        case .hardcore: return 0.75
        }
    }

    /// How much longer (or shorter) a bot waits between raids, and between hunts.
    var urgeScale: Double {
        switch self {
        case .easy:     return 2.4
        case .medium:   return 1.6
        case .hard:     return 1
        case .hardcore: return 0.75
        }
    }

    /// How much longer (or shorter) before a bot with no bomb is handed one.
    var bombSupplyScale: Double {
        switch self {
        case .easy:     return 3
        case .medium:   return 1.8
        case .hard:     return 1
        case .hardcore: return 0.7
        }
    }

    /// How much likelier a power-up is in a crate a bot opens.
    var botPerkBoost: Double {
        switch self {
        case .easy:     return 1
        case .medium:   return 1.75
        case .hard:     return GameConfig.AI.cratePerkBoost
        case .hardcore: return 3.5
        }
    }

    /// How far into a match before a bot buys whatever gear it can afford.
    var buysAnythingAfter: Double {
        switch self {
        case .easy:     return 0.6
        case .medium:   return 0.35
        case .hard:     return GameConfig.AI.buysAnythingAfter
        case .hardcore: return 0.05
        }
    }

    /// Whether the bots turn on a runaway leader: urges ticking faster, the
    /// leader's base priced up, hunting them. Off on Easy, so being ahead is not
    /// punished.
    var pressesTheLeader: Bool { self != .easy }

    /// Whether bots gang up on the leader - piling into fights and raids on
    /// them - and how many at once. None on Easy or Medium.
    var gangSize: Int {
        switch self {
        case .easy, .medium: return 0
        case .hard:          return GameConfig.AI.gangSize
        case .hardcore:      return GameConfig.AI.gangSize + 1
        }
    }

    /// Whether bot bases get the toughened turret - see Turret.fortified.
    var fortifiesBotTurrets: Bool { self == .hard || self == .hardcore }
}
