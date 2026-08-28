//
//  GameConfig.swift
//  Loot Wars
//
//  Every tunable number in the game lives here. If you find yourself typing a
//  number anywhere else in Core, it probably belongs in this file instead.
//

import Foundation

enum GameConfig {

    /// The simulation always advances in steps of this size, no matter what the
    /// framerate is doing. That keeps movement identical on every device and makes
    /// bugs reproducible.
    static let fixedTimeStep: Double = 1.0 / 60.0

    enum Map {
        static let width = 64
        static let height = 64
    }

    enum Player {
        /// Tiles travelled per second at full stick.
        static let moveSpeed: Double = 4.5
        /// Half the width of the player's square hitbox, in tiles.
        static let halfSize: Double = 0.4
    }
}
