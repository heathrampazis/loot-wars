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
//  ONE THAT DOES EVERYTHING, AND THREE THAT EACH DO ONE THING.
//
//  There were four singles - regeneration, speed, strength, resistance - and they
//  were cut to one bottle that did all four, because four bottles meant telling
//  colours apart mid-fight having learned in advance which was which. That is a lot
//  of homework for a thing you find twice a match, and the usual outcome was
//  drinking whichever one you had and finding out afterwards.
//
//  The singles are back, minus resistance, and the shape is deliberately not what
//  it was. Before, the four were alternatives and you got whichever one the crate
//  felt like. Now there is a clear best item - the disco ball, which does all of it
//  - and three lesser ones that each do their own job BETTER than it does. So a
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
//  Resistance stays merged in, so thicker skin is the thing you can only get from
//  the disco ball. It keeps one power entirely to itself, which is worth more to it
//  than another few points on the three it shares.
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
        case .strength, .speed, .regeneration: return .legendary
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
        case .strength, .regeneration: return 1
        }
    }

    var damageBoost: Double {
        switch self {
        case .overdrive:  return GameConfig.Perks.damageBoost
        case .strength:   return GameConfig.Perks.soloDamageBoost
        case .speed, .regeneration: return 1
        }
    }

    /// Thicker skin, and the disco ball's alone.
    var damageTakenShare: Double {
        switch self {
        case .overdrive: return GameConfig.Perks.damageTaken
        case .strength, .speed, .regeneration: return 1
        }
    }

    /// Share of a health bar handed back per beat. Zero means this one does not
    /// heal, which is what stops PerkSystem needing to know which is which.
    var healPortion: Double {
        switch self {
        case .overdrive:    return GameConfig.Perks.healPortion
        case .regeneration: return GameConfig.Perks.soloHealPortion
        case .strength, .speed: return 0
        }
    }

    /// How often it turns up, relative to the others.
    ///
    /// The four shares add to four, which is what the crate tables were already
    /// handing to the single perk - so the same number of power-ups fall out of the
    /// map as before, and this only decides which. The disco ball is the scarce one
    /// at 0.7 against 1.1, so it is about a sixth of the power-ups you find.
    var lootShare: Double {
        switch self {
        case .overdrive: return 0.7
        case .strength, .speed, .regeneration: return 1.1
        }
    }
}
