//
//  Perk.swift
//  Loot Wars
//
//  Something you switch ON rather than use up.
//
//  A bandage is spent the instant you press it; a perk is spent over the next few
//  seconds, and while it runs it is a thing that is TRUE of you rather than a thing
//  you did. That distinction is why perks are their own kind rather than another
//  healing item with a long fuse: everything about them - one at a time, a timer,
//  particles coming off the person carrying it - belongs to the state and not to
//  the press.
//
//  ONE THAT DOES EVERYTHING, AND FOUR THAT EACH DO ONE THING.
//
//  There were four singles - regeneration, speed, strength, resistance - and they
//  were cut to one bottle that did all four, because four bottles meant telling
//  colours apart mid-fight having learned in advance which was which. That is a lot
//  of homework for a thing you find twice a match, and the usual outcome was
//  drinking whichever one you had and finding out afterwards.
//
//  The singles are back, all four of them, and the shape is deliberately not what
//  it was. Before, the four were alternatives and you got whichever one the crate
//  felt like. Now there is a clear best item - the disco ball, which does all of it
//  - and four lesser ones that each do their own job BETTER than it does. So a
//  single is never a disappointing disco ball; it is the right tool if the thing
//  you need is that one thing, and the wrong one if you do not know yet.
//
//  That is why each single's number is above the disco ball's rather than below it,
//  which sounds backwards for something meant to be the weaker item and is not. A
//  single that is worse at its ONE job than the item that also does three others is
//  strictly dominated - there is no situation in which finding it is good news, and
//  an item nobody is pleased to find is the failure the four-perk version had. Less
//  overall, better in its lane, is what makes it a choice.
//
//  Resistance came back as a single of its own, so the disco ball no longer keeps
//  any power to itself - what it has instead is all of them at once.
//
//  Everything downstream was already written against "which perk is running" rather
//  than "is a perk running", so this arrived as a set of switches to fill in rather
//  than a system to build. The one place that was NOT - Actor's three boosts, which
//  asked whether any perk was running at all - is the bug this would have shipped
//  with: every single would have granted all four powers.
//

enum Perk: Hashable, CaseIterable {
    /// Everything at once: health back, faster feet, harder shots, thicker skin.
    case overdrive
    /// Harder shots, and only that.
    case strength
    /// Faster feet, and only that.
    case speed
    /// Health back, and only that.
    case regeneration
    /// Thicker skin, and only that.
    case resistance

    /// The ones that can actually be FOUND, and the only list anything handing a
    /// power-up out should ever read.
    ///
    /// Not allCases, and the difference is the point of it existing. A perk that is
    /// switched off is switched off in ONE place, and the name of this collection
    /// is what steers the next thing that wants to offer one - a shop tab, a chest
    /// row, a reward for something - into asking the right question. Filtering
    /// allCases at each of those call sites would mean every new one starts out
    /// handing the ball back.
    ///
    /// Deterministic: allCases is declaration order and filter preserves it.
    static let obtainable: [Perk] = allCases.filter { $0.isObtainable }

    /// Whether this one is in the game at the moment. All of them are: the disco
    /// ball was switched off here for a while and is back.
    ///
    /// A flag rather than a weight of zero. Zero is a number in a table that
    /// somebody has to notice and interpret, and a weighted pick given a zero row
    /// is a thing to reason about rather than a thing that plainly cannot happen.
    /// This says what is meant.
    var isObtainable: Bool {
        switch self {
        case .overdrive, .strength, .speed, .regeneration, .resistance: return true
        }
    }

    /// Which rung of the ladder it sits on.
    ///
    /// The disco ball is Mythical and the singles are Legendary, one rung down. It
    /// is the cheapest way to say "this is the lesser one" - the rung is already
    /// the language the whole game uses for how good a thing is, it decides the
    /// colour of the pool under it on the grass, and it means a player reads the
    /// difference before they have learned what any of the three do.
    var rarity: Rarity {
        switch self {
        case .overdrive: return .mythical
        case .strength, .speed, .regeneration, .resistance: return .legendary
        }
    }

    /// How long it runs for. The same for all of them: the difference between these
    /// items is what they do, not how long you have to do it, and two dials moving
    /// at once is how you end up unable to say why one feels better.
    var duration: Double { GameConfig.Perks.duration }

    // MARK: - What it actually does

    var speedBoost: Double {
        switch self {
        case .overdrive:  return GameConfig.Perks.speedBoost
        case .speed:      return GameConfig.Perks.soloSpeedBoost
        case .strength, .regeneration, .resistance: return 1
        }
    }

    var damageBoost: Double {
        switch self {
        case .overdrive:  return GameConfig.Perks.damageBoost
        case .strength:   return GameConfig.Perks.soloDamageBoost
        case .speed, .regeneration, .resistance: return 1
        }
    }

    /// Thicker skin: the share of every hit that still lands.
    var damageTakenShare: Double {
        switch self {
        case .overdrive:  return GameConfig.Perks.damageTaken
        case .resistance: return GameConfig.Perks.soloDamageTaken
        case .strength, .speed, .regeneration: return 1
        }
    }

    /// Share of a health bar handed back per beat. Zero means this one does not
    /// heal, which is what stops PerkSystem needing to know which is which.
    var healPortion: Double {
        switch self {
        case .overdrive:    return GameConfig.Perks.healPortion
        case .regeneration: return GameConfig.Perks.soloHealPortion
        case .strength, .speed, .resistance: return 0
        }
    }

    /// How heavily it sits in a crate's table, by how far the match has run.
    ///
    /// This was a SHARE - 0.7 or 1.1, multiplied against one weight the crate tables
    /// handed both kinds - and it is a weight now because the two kinds stopped
    /// wanting the same curve. The singles were made commoner and made to climb
    /// harder as a match runs; the disco ball was meant to stay exactly where it
    /// was. Expressed as shares of a shared base that is rising, "stay where it was"
    /// becomes a share that falls by a different amount in every band, and nobody
    /// reading 0.44 / 0.33 / 0.33 would ever guess it meant "unchanged".
    ///
    /// So each kind names its own curve in GameConfig and this picks one. The
    /// relationship between them is still perfectly readable - the four singles
    /// together are about seven times the disco ball late - it is just no longer
    /// encoded in a number you have to divide to understand.
    func lootWeight(at progress: Double) -> Int {
        switch self {
        case .overdrive:
            return GameConfig.Loot.overdriveWeight(at: progress)
        case .strength, .speed, .regeneration, .resistance:
            return GameConfig.Loot.singlePerkWeight(at: progress)
        }
    }
}
