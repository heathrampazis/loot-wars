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
    /// Fire in this direction, independently of where the actor is walking.
    ///
    /// Aiming used to be a side effect of moving, which meant nobody could shoot
    /// while backing off, and every fight collapsed into two actors walking at each
    /// other. Rate limiting is still the simulation's job, so holding the stick
    /// over is perfectly safe.
    case shoot(Vec2)
    /// Open the nearest lootbox in reach. Carries no coordinate on purpose: asking
    /// for a specific box would mean the input code deciding which one is closest,
    /// and that is the simulation's call.
    case openLootbox
    /// Drink whatever is in this hotbar slot.
    case useItem(slot: Int)
    /// Lob a bomb at this tile. Whether one is thrown, and whether it reaches, is
    /// the simulation's call.
    case throwBomb(GridPoint)
}
