//
//  WorldEvent.swift
//  Loot Wars
//
//  Things that HAPPENED, as opposed to things that are true.
//
//  The world is otherwise a description of the present - where everybody is, what
//  they are holding, how much of the wall is standing - and a renderer can work
//  almost entirely from that. It notices a health bar going down and flashes the
//  figure; it notices a chest that has stopped existing and breaks it open. Nothing
//  has to be announced, because the difference between two frames says it all.
//
//  This is for the handful of things that difference CANNOT say. A kill is the
//  clearest: the victim falling over is plainly visible in the state, but who did
//  it, and what it paid, exist only for the instant CombatSystem works them out. A
//  purchase is the same - buying a helmet you then wear changes the state, buying
//  one you never see does not. And a blast leaves a hole that is indistinguishable
//  from a hole somebody dug.
//
//  One list rather than one list per kind, because the alternative was already
//  happening: blasts had a pair of methods, purchases had another pair, and kills
//  would have been a third. They are drained in one place - the scene - and handed
//  to whoever draws them.
//
//  Note what is NOT in here. Damage, healing, walking, opening a crate: every one
//  of those is written on the actor a frame later, so the renderer can see it for
//  itself. Adding them would be paying for a message that is already in the post.
//

enum WorldEvent {
    /// A bomb went off here.
    case blast(at: Vec2)

    /// Somebody bought something.
    case purchase(ItemType, by: ActorID)

    /// Somebody was killed, and what it was worth to whoever did it.
    ///
    /// Carries the position because by the time this is read the victim has been
    /// moved back to their own claim to respawn, and the mark belongs where they
    /// fell. Carries the reward because it is priced by what the victim was
    /// wearing, which has been stripped by then too - the whole point of this
    /// event is that the answers do not survive the frame they were worked out in.
    case kill(victim: ActorID, by: ActorID?, at: Vec2, points: Int, tokens: Int)
}
