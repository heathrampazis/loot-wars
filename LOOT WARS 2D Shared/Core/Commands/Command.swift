//
//  Command.swift
//  Loot Wars
//
//  Intents, not actions. Nothing outside the simulation is allowed to reach in and
//  change the world - input produces Commands, and only World.step applies them.
//
//  This is the single most important rule in the codebase. Keep it and multiplayer
//  stays a later addition; break it and it becomes a rewrite.
//

enum Command {
    case move(Vec2)
    case placeBlock(GridPoint)
    /// Fire in whatever direction the actor is facing. Rate limiting is the
    /// simulation's job, so holding the button down is perfectly safe.
    case shoot
}
