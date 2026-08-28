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
}
