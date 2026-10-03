//
//  Unlocks.swift
//  Loot Wars
//
//  Which of the game's extras are switched on for a match.
//
//  The basics are always in: walls and sealing a base, bombs and raiding, crates
//  and chests, bandages and medkits, and helmets and blasters up to Mythical.
//  Everything else arrives with levelling - see Roadmap - so a new player learns
//  the game a piece at a time instead of meeting it all in the first match.
//
//  A locked feature is not in the match AT ALL, for anybody: no crate rolls it,
//  no chest is stocked with it, the shop does not sell it and no bot is handed
//  it. One set per match, read off the World, so the match stays fair - and so
//  a future multiplayer lobby only has to agree on one set.
//

/// One thing that can be unlocked.
enum Feature: String, CaseIterable {
    case strength
    case miniArcade
    case speed
    case turrets
    case regeneration
    case stinkBombs
    case fullArcade
    case resistance
    case discoBall
    case cosmicHelmet
    case cosmicBlaster

    /// What it looks like - the item it lets into the game.
    var item: ItemType {
        switch self {
        case .strength:      return .perk(.strength)
        case .miniArcade:    return .arcade(.mini)
        case .speed:         return .perk(.speed)
        case .turrets:       return .turret
        case .regeneration:  return .perk(.regeneration)
        case .stinkBombs:    return .stink
        case .fullArcade:    return .arcade(.full)
        case .resistance:    return .perk(.resistance)
        case .discoBall:     return .perk(.overdrive)
        case .cosmicHelmet:  return .helmet(.cosmic)
        case .cosmicBlaster: return .blaster(.six)
        }
    }
}

struct Unlocks: Equatable {
    var features: Set<Feature>

    /// The newest unlocks, which crates hand out more often for a while - so
    /// something you have just unlocked actually turns up while it is new. See
    /// LootTable and Roadmap.unlocks(atLevel:).
    var featured: Set<Feature> = []

    /// Everything - dev mode, the menu's backdrop, the How to Play pictures, and
    /// any World nobody has said otherwise about. Nothing featured.
    static let all = Unlocks(features: Set(Feature.allCases))

    /// The basics and nothing else.
    static let none = Unlocks(features: [])

    /// The feature an item belongs to, if it is one of the unlockable ones.
    static func feature(of type: ItemType) -> Feature? {
        Feature.allCases.first { $0.item == type }
    }

    /// Whether this item is one of the newest unlocks.
    func isFeatured(_ type: ItemType) -> Bool {
        Unlocks.feature(of: type).map { featured.contains($0) } ?? false
    }

    /// How many of the four single power-ups this match has.
    var singlePerkCount: Int {
        [Feature.strength, .speed, .regeneration, .resistance].filter { has($0) }.count
    }

    func has(_ feature: Feature) -> Bool { features.contains(feature) }

    /// Whether this item may exist in a match.
    func allows(_ type: ItemType) -> Bool {
        switch type {
        case .perk(.strength):     return has(.strength)
        case .perk(.speed):        return has(.speed)
        case .perk(.regeneration): return has(.regeneration)
        case .perk(.resistance):   return has(.resistance)
        case .perk(.overdrive):    return has(.discoBall)
        case .arcade(.mini):       return has(.miniArcade)
        case .arcade(.full):       return has(.fullArcade)
        case .turret:              return has(.turrets)
        case .stink:               return has(.stinkBombs)
        case .helmet(.cosmic):     return has(.cosmicHelmet)
        case .blaster(.six):       return has(.cosmicBlaster)
        case .bandage, .medkit, .bomb, .chest, .helmet, .blaster:
            return true
        }
    }

    /// The item, or the nearest thing to it that is allowed: Cosmic gear steps
    /// down to Mythical. Nil when there is no stand-in.
    func clamp(_ type: ItemType) -> ItemType? {
        if allows(type) { return type }
        switch type {
        case .helmet(.cosmic): return .helmet(.mythical)
        case .blaster(.six):   return .blaster(.five)
        default:               return nil
        }
    }

    func clamp(_ pickup: Pickup) -> Pickup? {
        guard case .item(let type) = pickup else { return pickup }
        return clamp(type).map { .item($0) }
    }
}

/// The order things unlock in, one every five levels, and how much XP a level
/// takes.
///
/// Paced so the whole road takes a while - around forty matches - with the early
/// levels taking a match or so each, and each level costing a little more than
/// the last.
enum Roadmap {

    static let milestones: [(level: Int, feature: Feature)] = [
        (5, .strength),
        (10, .miniArcade),
        (15, .speed),
        (20, .stinkBombs),
        (25, .regeneration),
        (30, .fullArcade),
        (35, .resistance),
        (40, .turrets),
        (45, .discoBall),
        (50, .cosmicHelmet),
        (55, .cosmicBlaster)
    ]

    /// The level the roadmap ends at. Levelling carries on past it.
    static var finalLevel: Int { milestones.last?.level ?? 1 }

    /// XP to go from this level to the next.
    ///
    /// About a fifth quicker than it was (120 + 4 per level), all the way along:
    /// the first few levels still take a proper match each, but the whole road is
    /// around forty matches rather than the best part of fifty.
    static func xpToNext(from level: Int) -> Int {
        96 + 3 * max(1, level)
    }

    /// Where a running XP total puts you: the level, and how far into it.
    static func level(forXP xp: Int) -> (level: Int, into: Int, needed: Int) {
        var level = 1
        var left = max(0, xp)
        while left >= xpToNext(from: level) {
            left -= xpToNext(from: level)
            level += 1
        }
        return (level, left, xpToNext(from: level))
    }

    /// Everything unlocked by this level.
    ///
    /// The newest one is FEATURED for the ten levels after it unlocks - crates
    /// favour it - so it is something you actually get to use while it is new,
    /// not a card on the roadmap you meet once a week.
    static func unlocks(atLevel level: Int) -> Unlocks {
        let reached = milestones.filter { $0.level <= level }
        let fresh = reached.filter { level - $0.level < featuredLevels }
        return Unlocks(features: Set(reached.map { $0.feature }),
                       featured: Set(fresh.map { $0.feature }))
    }

    /// How many levels a new unlock stays featured for.
    static let featuredLevels = 10

    /// How long a match runs at this level, in seconds.
    ///
    /// Three minutes at every level now (Oct 2026) - it used to grow to five as
    /// the game filled up. Kept as a function of level so it can vary again.
    /// Everything that runs on the match's progress - loot bands, the late-game
    /// respawn kit, supply drops - stretches to fit.
    static func matchLength(atLevel level: Int) -> Double {
        GameConfig.Match.duration
    }

    /// What a finished match is worth.
    ///
    /// Finishing pays something whatever happened, so a bad match still moves the
    /// bar; placing pays more the higher you came; and score pays a share, capped
    /// so one runaway match cannot skip half the roadmap.
    static func matchXP(score: Int, place: Int) -> Int {
        let finish = 60
        let placing = [120, 90, 70, 55, 45, 35, 30, 25]
        let forPlace = placing[min(max(0, place), placing.count - 1)]
        let forScore = min(150, max(0, score) / 3)
        return finish + forPlace + forScore
    }
}
