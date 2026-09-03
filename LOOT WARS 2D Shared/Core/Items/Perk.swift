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
//  ONE AT A TIME, and the rule exists before the second perk does. There is exactly
//  one today, so nothing can conflict with anything; writing the rule now means the
//  answer to "what happens if you drink two" is decided while it costs nothing,
//  rather than being discovered later by whoever adds the third.
//

enum Perk: Hashable, CaseIterable {
    /// Health back, steadily, for as long as it runs.
    case regeneration

    var duration: Double {
        switch self {
        case .regeneration: return GameConfig.Perks.regenerationDuration
        }
    }
}
