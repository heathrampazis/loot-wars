//
//  Difficulty.swift
//  Loot Wars
//
//  How hard the seven bots play, picked in Settings.
//
//  HARD is the game exactly as it is tuned everywhere else - every number in
//  GameConfig.AI is the hard game, and choosing Hard changes nothing. EASY eases
//  the bots off from there: they aim worse, react slower, raid and hunt less
//  often, never gang up on whoever is winning, and get none of their quiet
//  help (power-up luck, faster bomb top-ups, toughened turrets).
//
//  Only the bots change. Your health, damage, loot, prices and the scoring are
//  the same on both, so a match on Easy is the same game against softer
//  opponents.
//

enum Difficulty: Int, CaseIterable {
    case easy = 0
    case hard = 1

    var title: String {
        switch self {
        case .easy: return "Easy"
        case .hard: return "Hard"
        }
    }

    /// How much wider a bot's aim wobble is. On Easy about 23% of aim-limited
    /// shots land, against 43% on Hard - see GameConfig.AI.aimSpread.
    var aimSpreadScale: Double { self == .easy ? 1.85 : 1 }

    /// How much slower a bot is to react to somebody it has just seen.
    var reactionScale: Double { self == .easy ? 2.2 : 1 }

    /// How much longer a bot waits between raids, and between hunts.
    var urgeScale: Double { self == .easy ? 2.4 : 1 }

    /// How much longer before a bot with no bomb is handed one.
    var bombSupplyScale: Double { self == .easy ? 3 : 1 }

    /// How much likelier a power-up is in a crate a bot opens - none on Easy.
    var botPerkBoost: Double { self == .easy ? 1 : GameConfig.AI.cratePerkBoost }

    /// How far into a match before a bot buys whatever gear it can afford.
    var buysAnythingAfter: Double { self == .easy ? 0.6 : GameConfig.AI.buysAnythingAfter }

    /// Whether the bots turn on a runaway leader: urges ticking faster, piling
    /// into fights and raids on them, and hunting them. Off on Easy, so being
    /// ahead is not punished.
    var pressesTheLeader: Bool { self == .hard }

    /// Whether bot bases get the toughened turret - see Turret.fortified.
    var fortifiesBotTurrets: Bool { self == .hard }
}
