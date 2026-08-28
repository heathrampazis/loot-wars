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
}
