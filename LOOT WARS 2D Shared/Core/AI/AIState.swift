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

    /// Counts down to the next look around for enemies.
    var threatScanTimer: Double = 0

    /// Counts down after spotting an enemy. Nobody reacts instantly, and a bot that
    /// does feels like a machine.
    var reactionTimer: Double = 0

    /// Which way round the bot is currently circling an enemy. Flipped now and
    /// then, so it does not orbit forever in one direction.
    var strafeDirection: Double = 1

    /// This bot's personal nerve. Scales its drinking thresholds, so no two bots
    /// panic at exactly the same moment.
    var caution: Double = 1

    /// Spaces out sips, so a hurt bot does not drink everything at once.
    var drinkTimer: Double = 0

    /// Counts down to the next urge to go home and add to the base.
    var buildUrgeTimer: Double = 0

    /// Walls left to lay on this trip home.
    var blocksLeftToLay: Int = 0

    /// Spaces out the individual walls within a trip.
    var placeTimer: Double = 0

    /// A small fixed error added to this bot's aim, re-rolled whenever it changes
    /// its mind. Perfect aim is what makes bots unbeatable and unfun.
    var aimNoise: Double = 0
}
