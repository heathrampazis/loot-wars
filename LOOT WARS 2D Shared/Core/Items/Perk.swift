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
//  ONE PERK, and it does all four things at once.
//
//  There were four - regeneration, speed, strength, resistance - and on paper they
//  were four different verbs for four different situations, which is a good shape
//  for an item. In the hand they were four bottles a player had to tell apart at a
//  glance, mid-fight, from a colour, having learned in advance which colour meant
//  which. That is a lot of homework for a thing you find twice a match, and the
//  usual outcome was drinking whichever one you had and finding out afterwards.
//
//  So the decision moved from WHICH to WHEN, which is the interesting half. One
//  bottle, everything on, shorter than any of the four were, and every number
//  underneath it pulled down so that all four together are worth about what one of
//  them used to be. You still cannot run two, you still have to choose the moment,
//  and now the moment is the entire skill.
//
//  Kept as an enum with one case on purpose. Everything downstream - the actor's
//  perk slot, the event, the bots, the trail of particles - is written against
//  "which perk is running", so a second one is still a case and a colour rather
//  than a system, if this ever wants to go back.
//

enum Perk: Hashable, CaseIterable {
    /// Everything at once: health back, faster feet, harder shots, thicker skin.
    case overdrive

    /// Which rung of the ladder it sits on.
    ///
    /// Mythical, which is purple - the same rung it has always drawn at, under the
    /// name the ladder now uses. It was .epic when there were six rungs and the
    /// gear ladders sat a rung below their own names; with the ladder cut to five
    /// and the names lined up, purple is called Mythical and this is one of the two
    /// rungs that still sparkles.
    ///
    /// The top but one, and it stays there for the same reason it went there: a
    /// thing that does four things at once belongs high, and gold is reserved for
    /// the one rung nobody can find.
    var rarity: Rarity { .mythical }

    /// How long it runs for.
    var duration: Double { GameConfig.Perks.duration }
}
