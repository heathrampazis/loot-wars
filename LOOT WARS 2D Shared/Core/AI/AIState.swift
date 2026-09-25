//
//  AIState.swift
//  Loot Wars
//
//  A bot's memory.
//
//  This lives on the Actor - which is to say, inside World - and NOT inside the
//  brain. That is deliberate and worth protecting: the moment a bot's memory sits
//  outside the world, the world stops being the full state of the game, replays
//  from a seed stop matching, and a networked host and client can disagree about
//  what a bot is doing. Brains stay stateless; all their memory is here.
//

struct AIState {
    var goal: AIGoal = .wander

    /// The direction the bot is actually travelling, as a unit vector.
    ///
    /// This is turned TOWARDS desiredHeading at a limited rate rather than being set
    /// to it. That one indirection is the whole difference between a bot that steers
    /// and a bot that snaps.
    var heading: Vec2

    /// Where the bot currently wants to go.
    var desiredHeading: Vec2

    /// Counts down to the next change of mind. The bot keeps walking throughout -
    /// it never stops to think.
    var decisionTimer: Double

    /// Which way this bot prefers to turn when something is in the way. Fixed per
    /// bot, so one in a corner commits to a direction instead of dithering between
    /// left and right.
    var turnPreference: Double

    /// How long the current goal has been running. Used to give up on a crate the
    /// bot cannot actually get to.
    var goalAge: Double = 0

    /// While this is running the bot ignores crates, so giving up on one does not
    /// immediately turn it straight back around.
    var lootCooldown: Double = 0

    /// How long the current fight has gone without a shot being available. See
    /// GameConfig.AI.fightPatience - this is what notices a bot orbiting a wall it
    /// cannot get past.
    var fightStale: Double = 0

    /// While this is running the bot will not START a fight. Being hit cancels it.
    var fightCooldown: Double = 0

    /// Counts down to being handed a bomb, if it has none.
    var bombSupplyTimer: Double = 0

    /// Counts down to the next look around for enemies.
    var threatScanTimer: Double = 0

    /// Counts down after spotting an enemy. Nobody reacts instantly, and a bot that
    /// does feels like a machine.
    var reactionTimer: Double = 0

    /// How long this bot has been standing in gas, or walking at some.
    ///
    /// Counts UP, unlike every other timer here, because what it gates is a
    /// reaction rather than a repeat: a bot does nothing about a cloud until this
    /// passes GameConfig.AI.gasReaction. Zeroed the moment it is clear of one, so
    /// stepping out and back in costs it the reaction again - which is what
    /// stumbling at the edge of a cloud looks like from outside.
    ///
    /// This one field is most of why a stink bomb is worth carrying. Without it the
    /// bots answered a cloud landing on their feet in a single tick.
    var gasNoticed: Double = 0

    /// Which way round the bot is currently circling an enemy. Flipped now and
    /// then, so it does not orbit forever in one direction.
    var strafeDirection: Double = 1

    /// This bot's personal nerve. Scales its patch-up thresholds, so no two bots
    /// panic at exactly the same moment.
    var caution: Double = 1

    /// Spaces out treatments, so a hurt bot does not burn its whole bag at once.
    var healTimer: Double = 0

    /// Counts down to the next urge to go home and add to the base.
    var buildUrgeTimer: Double = 0

    /// Counts down to wanting to go and rob somebody.
    ///
    /// The mirror of the build urge, and it exists for the same reason that one
    /// does. Raiding kept coming out rare no matter how attractive the targets were
    /// made, and the reason was never appetite - it was the queue. Robbing sat
    /// below building, and building renews itself: a trip home takes an armful of
    /// walls, the armful is a commitment, finishing it sets a fresh urge timer, and
    /// somewhere in there the bot looted a crate and started again. A thing that is
    /// always fourth in line never happens.
    ///
    /// So raiding gets a clock of its own. When it comes round, robbing jumps the
    /// queue - above building and stashing, still below fighting for your life and
    /// below patching a hole in your own wall, because those are emergencies and
    /// this is an errand.
    /// It is a PRIORITY clock, not a rate limit, and the difference has caught
    /// two people out. chooseGoal asks chestWorthRobbing twice: once up here
    /// behind this timer, and again much further down with no gate on it at all.
    /// So when the timer is cold a bot still robs - it simply does it after
    /// building, re-arming and stashing rather than instead of them. Nothing
    /// anywhere caps how OFTEN a bot raids. What caps that is the bomb supply,
    /// because chestWorthRobbing wants a bomb in the bag or a hole already in the
    /// wall, and robRange, because it will not cross the whole map for one.
    ///
    var raidUrgeTimer: Double = 0

    /// Counts down to going after whoever is winning, in person.
    ///
    /// Separate from the raid urge because they answer different questions - that
    /// one is about a BASE and this one is about a PERSON - and because they must
    /// not fire together. Seven bots all deciding at once that the leader is the
    /// problem is not pressure, it is a mob, and a mob is both unfair and dull.
    /// Staggered per bot on its own clock, one or two of the seven are usually out
    /// looking for the leader at any moment and the rest are getting on with the
    /// match.
    var huntUrgeTimer: Double = 0

    /// Where the quarry was last actually SEEN.
    ///
    /// A hunt walks at this and not at the quarry's live position, which is the
    /// difference between a bot that is hunting you and a bot that knows where you
    /// are. Refreshed only on a clear view inside huntSight; when there has never
    /// been one, the hunt falls back on the quarry's own base, which is the one
    /// place somebody is guaranteed to turn up eventually.
    ///
    /// So breaking line of sight works, and works the way it looks like it should:
    /// the bot keeps coming to where you were, arrives, finds nothing, and has to
    /// pick the trail up again.
    var huntMark: Vec2?

    /// Walls left to lay on this trip home.
    var blocksLeftToLay: Int = 0

    /// Whether this bot has ever seen its base finished.
    ///
    /// The world cannot tell an unfinished wall from a bombed one - both are just
    /// "something left to build". This is the difference, and it is why it has to
    /// be remembered rather than looked up: once the base HAS been whole, a gap in
    /// it means somebody put it there, and that deserves dropping everything for in
    /// a way that the ordinary slow business of building does not.
    var baseWasComplete = false


    /// Spaces out the individual walls within a trip.
    var placeTimer: Double = 0

    /// Stops a bot re-committing to standing something down after it has just
    /// failed to.
    ///
    /// Its own timer rather than a reuse, and the reason is the bug it exists to
    /// prevent. The stash errand used to back off by resetting buildUrgeTimer,
    /// which worked exactly as long as the errand was gated on buildUrgeTimer -
    /// and then that gate was removed to stop finished bases standing empty, and
    /// nobody noticed that the escape hatch had been unplugged from the door. A
    /// timer that is only ever read by the branch that sets it cannot come apart
    /// that way.
    var stashCooldown: Double = 0

    /// Where the bot was last tick, and how far it has got since the window opened.
    ///
    /// The pair is the whole of "am I stuck": a bot's only command is .move at full
    /// speed, so one that has covered almost no ground is one something is holding.
    /// Distance over a window rather than speed on a tick, because a bot squeezing
    /// past a chest genuinely does crawl for a moment and is not stuck at all.
    var lastPosition: Vec2?
    var stuckFor: Double = 0
    var stuckDistance: Double = 0

    /// While this runs the bot is backing out of somewhere and its goal is ignored.
    var shoveFor: Double = 0
    var shoveHeading: Vec2 = Vec2(x: 1, y: 0)

    /// A small fixed error added to this bot's aim, re-rolled whenever it changes
    /// its mind. Perfect aim is what makes bots unbeatable and unfun.
    var aimNoise: Double = 0
}
