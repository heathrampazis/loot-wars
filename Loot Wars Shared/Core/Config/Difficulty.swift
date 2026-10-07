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
//  Only the bots change. Your health, damage, loot, prices and the scoring are
//  the same on both, so a match on Easy is the same game against softer
//  opponents.
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
        case .easy:     return 1.0
        case .medium:   return 1.1
        case .hard:     return 1.2
        case .hardcore: return 1.3
        }
    }

    /// And a little more again for playing without Assisted controls.
    static let unassistedXPBonus: Double = 1.1

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
