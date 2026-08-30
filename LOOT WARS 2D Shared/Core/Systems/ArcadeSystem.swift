//
//  ArcadeSystem.swift
//  Loot Wars
//
//  Machines paying out tokens.
//
//  Two rules stop this from becoming a reason to stand still, which is the exact
//  opposite of what the game wants:
//
//  1. A machine will not let more than a few of its tokens pile up uncollected.
//     Camping one therefore caps out, and a circuit between machines beats it.
//  2. It needs a free tile around it to put a token on. Wall one in and it stops.
//

enum ArcadeSystem {

    static func update(_ world: World, dt: Double) {
        for index in world.arcades.indices {
            var arcade = world.arcades[index]

            // The timer runs down and then STAYS down. A machine that is blocked or
            // already full is ready the instant that stops being true, rather than
            // making you wait out another whole interval for something it was
            // holding all along.
            if arcade.emitTimer > 0 {
                arcade.emitTimer -= dt
                world.arcades[index] = arcade
                continue
            }

            guard world.uncollectedTokens(around: arcade) < GameConfig.Arcade.maxUncollected,
                  let spot = world.freeSpot(around: arcade) else {
                world.arcades[index] = arcade
                continue
            }

            world.spawnGroundItem(.token(GameConfig.Arcade.tokenValue), at: spot)
            arcade.emitTimer = GameConfig.Arcade.emitInterval
            world.arcades[index] = arcade
        }
    }
}
