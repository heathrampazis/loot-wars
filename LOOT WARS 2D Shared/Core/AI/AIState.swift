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

    /// Where the bot is currently heading, in tile space.
    var destination: Vec2

    /// Counts down to the next decision. Bots keep executing in between, which is
    /// what makes them look deliberate instead of twitchy.
    var decisionTimer: Double

    /// Where the bot was when it last decided, so it can tell whether it is
    /// actually getting anywhere.
    var positionAtLastDecision: Vec2
}
