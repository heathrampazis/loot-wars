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

        /// How many tree clumps to try to place. Placement can fail when a spot is
        /// already taken, so treat this as a target rather than a guarantee.
        static let treePatchCount = 45

        /// Clumps are square, and either of these sizes.
        static let treePatchSizes = [2, 3]

        /// Width and height of a team's base claim, in tiles. Odd, so it has a
        /// true centre tile to spawn on.
        static let claimSize = 9

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
        /// Collision radius as a fraction of half a clump's width, per clump size.
        /// Chosen to sit between the star art's inner and outer radius.
        static let collisionRadiusFactor: [Int: Double] = [2: 0.82, 3: 0.89]

        /// Idle spin, radians per second. A full turn takes roughly 35 to 105 seconds.
        static let minSpin: Double = 0.06
        static let maxSpin: Double = 0.18

        /// Clear space kept between two clumps, in tiles.
        static let spacing: Double = 0.75
    }

    enum Blaster {
        /// Tiles per second.
        static let projectileSpeed: Double = 14
        /// Shots per second while the button is held.
        static let fireRate: Double = 3.0
        /// Tiles a shot travels before fizzling out.
        static let range: Double = 12
        /// How far in front of the actor a shot appears, so you never shoot yourself.
        static let muzzleOffset: Double = 0.5
        /// Half the width of a projectile, in tiles. Only used for drawing today;
        /// hit detection arrives with health at M5.
        static let projectileRadius: Double = 0.18
    }
}
