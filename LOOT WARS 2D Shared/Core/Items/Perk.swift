//
//  Perk.swift
//  Loot Wars
//
//  Something you switch ON rather than use up.
//
//  A bandage is spent the instant you press it; a perk is spent over the next
//  quarter of a minute, and while it runs it is a thing that is TRUE of you rather
//  than a thing you did. That distinction is why perks are their own kind rather
//  than another healing item with a long fuse: everything about them - one at a
//  time, a timer, particles coming off the person carrying it - belongs to the
//  state and not to the press.
//
//  ONE AT A TIME, and the rule was written when there was one perk and nothing to
//  conflict with. That is why adding three more cost almost nothing: the answer to
//  "what happens if you drink two" was already decided, in Actor.canUse, and every
//  screen and every bot reads it from there.
//
//  Four of them now, and they are deliberately four DIFFERENT verbs rather than
//  four sizes of the same one. Regeneration answers damage already taken, strength
//  answers a fight you are winning slowly, resistance answers one you are losing,
//  and speed answers a fight you would rather not have - or a base on the far side
//  of the map. Nothing here is strictly better than anything else here, which is
//  what makes finding one a decision about when rather than a decision about what.
//

enum Perk: Hashable, CaseIterable {
    /// Health back, steadily, for as long as it runs.
    case regeneration

    /// Faster on your feet.
    case speed

    /// Your shots hit harder.
    case strength

    /// Everything that hits you hurts less.
    case resistance

    /// How long it runs for.
    ///
    /// Regeneration lasts longest because it pays out in instalments - cut it short
    /// and it stops being the thing it is. The other three are on the moment they
    /// are spent in, and twelve seconds is about one fight.
    var duration: Double {
        switch self {
        case .regeneration: return GameConfig.Perks.regenerationDuration
        case .speed:        return GameConfig.Perks.speedDuration
        case .strength:     return GameConfig.Perks.strengthDuration
        case .resistance:   return GameConfig.Perks.resistanceDuration
        }
    }
}
