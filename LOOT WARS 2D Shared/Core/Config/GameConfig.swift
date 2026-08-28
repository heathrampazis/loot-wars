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

        /// Fraction of open tiles that grow a tree.
        static let treeDensity: Double = 0.05

        /// Tiles either side of the spawn kept clear, so you never start hemmed in.
        static let spawnClearRadius = 4

        /// Set this to replay one exact map. nil means a fresh map every launch -
        /// the seed used is printed to the console so you can pin it down here if
        /// something interesting (or broken) shows up.
        static let fixedSeed: UInt64? = nil
    }

    enum Player {
        /// Tiles travelled per second at full stick.
        static let moveSpeed: Double = 4.5
        /// Half the width of the player's square hitbox, in tiles.
        static let halfSize: Double = 0.4
    }

    enum Trees {
        /// A tree blocks exactly one tile, but is drawn slightly larger so it
        /// overlaps the tile above and the map does not read as flat.
        static let visualWidth: Double = 1.15
        static let visualHeight: Double = 1.35
    }
}
