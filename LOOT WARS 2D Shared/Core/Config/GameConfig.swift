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

        /// Starting and maximum health. Nothing takes it away yet - damage lands
        /// with the rest of M5 - but the HUD reads the real value, so it will start
        /// moving the moment it does.
        static let maxHealth = 100
        // The hitbox is the whole standing figure: the sprite is drawn at exactly
        // these dimensions, so what you see is what you collide with.
        //
        // Keep the ratio between these two matching the artwork's own proportions
        // (currently 392 x 750, so 0.45 : 0.86) or the sprite will stretch.

        /// Half the figure's width, in tiles.
        static let halfWidth: Double = 0.45

        /// Half the figure's height, in tiles.
        static let halfDepth: Double = 0.86
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

    enum Loot {
        /// Lootboxes scattered across the map.
        static let lootboxCount = 30

        /// Minimum distance between two lootboxes, in tiles, so they do not cluster.
        static let lootboxSpacing: Double = 4

        /// The crate's footprint, in tiles. Matches the art's proportions
        /// (704 x 474), and LootboxRenderer draws the sprite at exactly this size.
        static let lootboxSize = Vec2(x: 0.95, y: 0.64)

        /// How far past your own hitbox you can reach to open a crate. Small,
        /// because a solid crate means you are already touching it.
        static let openReach: Double = 0.3
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

        /// Shots you can fire before running dry.
        static let magazineSize = 12

        /// Quiet time after your last shot before ammo starts coming back. This is
        /// what makes bursts better than holding the trigger down.
        static let rechargeDelay: Double = 1.0

        /// Seconds per bullet once recharging has started.
        static let rechargeInterval: Double = 0.6
    }
}
