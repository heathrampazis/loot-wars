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

    /// A stink bomb went off here, and there is now gas standing in it.
    ///
    /// Announced rather than noticed, unlike the cloud itself: the cloud IS state
    /// and the renderer draws it from the world every frame. What cannot be seen in
    /// the state is the moment it arrived, and a cloud that fades up out of nothing
    /// looks like fog rolling in where one that bursts looks like something landed.
    case gas(at: Vec2)

    /// A machine on the map has started paying out properly.
    ///
    /// Announced because the START is the interesting instant, and the state only
    /// says that a jackpot is happening: by the time anybody looks, the difference
    /// between "this began a moment ago" and "this has six seconds left" is gone,
    /// and only one of those is worth interrupting somebody for.
    case jackpot(at: Vec2)

    /// Somebody switched a power-up on.
    ///
    /// The RUNNING perk is state and the renderer reads it every frame - that is
    /// what the particles come off. This is only the moment it started, which state
    /// cannot show a second later, and which deserves something louder than the
    /// steady effect that follows it.
    case perkStarted(Perk, by: ActorID)

    /// A base paid out for still standing.
    ///
    /// Carries where, because the number belongs over the base that earned it
    /// rather than over the player - who is usually somewhere else entirely, which
    /// is the whole point of owning a base that earns without you.
    /// A base just closed for the first time, and what it was furnished with.
    ///
    /// State cannot show this. A finished wall is a fact the renderers can read any
    /// frame they like; the INSTANT it became finished is gone by the next one, and
    /// that instant is the only moment worth celebrating - it is the payoff for the
    /// thing this game has the hardest time getting anybody to do.
    case sealed(TeamID, chests: Int)

    /// A machine taking a bullet and surviving it.
    case machineHit(ArcadeID, at: Vec2)

    /// A chest broken open by somebody who did not own it.
    case chestCracked(at: Vec2, items: Int)

    case vault(points: Int, for: TeamID, at: Vec2)

    /// Somebody sold something, out of which slot, and what it paid.
    ///
    /// All three of those are gone by the next frame - the slot is empty, the item
    /// no longer exists, and the tokens have been added to a total that says
    /// nothing about where they came from. A screen that wants to show a sale
    /// being rewarded cannot work any of it out by looking, which is exactly the
    /// test for whether something belongs in here.
    case sold(slot: Int, tokens: Int, by: ActorID)

    /// Somebody bought something.
    case purchase(ItemType, by: ActorID)

    /// Somebody patched themselves up with a supply.
    ///
    /// The twin of perkStarted, and it clears the same bar for the same reason.
    /// Health going up IS state and the bar shows it - but health also goes up from
    /// standing at home, and from a helmet that came with capacity attached, and
    /// nothing a renderer can see a frame later tells those three apart. The one
    /// that involved spending a bandage is the one worth a noise.
    ///
    /// Recorded by ConsumableSystem rather than by CombatSystem.heal, which is
    /// shared with the slow recovery at home - putting it there would announce a
    /// bandage every two seconds to anybody stood in their own base.
    case healed(by: ActorID)

    /// Somebody picked something up off the ground, and whether it went straight on.
    ///
    /// This one is close to the line the note at the top of this file draws, so it
    /// is worth saying why it clears it. WHAT was picked up does not survive: a
    /// bandage joins a stack that was already there and a helmet is simply worn,
    /// and a frame later the bag looks the same as a bag somebody bought from.
    /// Neither does WORN - acquire is what makes "this beats what you have" stop
    /// being true, by putting it on your head.
    ///
    /// Worn is carried rather than worked out by the listener for exactly that
    /// reason. By the time anybody reads this, comparing the item against what the
    /// actor is wearing would compare it against ITSELF.
    case pickedUp(ItemType, by: ActorID, worn: Bool)

    /// Somebody was killed, and what it was worth to whoever did it.
    ///
    /// Carries the position because by the time this is read the victim has been
    /// moved back to their own claim to respawn, and the mark belongs where they
    /// fell. Carries the reward because it is priced by what the victim was
    /// wearing, which has been stripped by then too - the whole point of this
    /// event is that the answers do not survive the frame they were worked out in.
    case kill(victim: ActorID, by: ActorID?, at: Vec2, points: Int, tokens: Int)
}
