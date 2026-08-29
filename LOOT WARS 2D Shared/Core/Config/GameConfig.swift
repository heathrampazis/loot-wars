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

        /// How far the ring of base claims sits from the middle of the map.
        ///
        /// Sized so every claim keeps a few tiles of breathing room from the map
        /// edge, and so adjacent bases are about 17 tiles apart centre to centre.
        /// Nothing goes in the middle: the centre of the map should be contested
        /// ground, not somebody's living room.
        static let claimRingRadius: Double = 22

        /// Set this to replay one exact map. nil means a fresh map every launch -
        /// the seed used is printed to the console so you can pin it down here if
        /// something interesting (or broken) shows up.
        static let fixedSeed: UInt64? = nil
    }

    enum Player {
        /// Tiles travelled per second at full stick.
        static let moveSpeed: Double = 4.5

        /// Starting and maximum health.
        static let maxHealth = 100

        /// Seconds spent dead before respawning at your own claim.
        static let respawnDelay: Double = 3.0

        /// Seconds of immunity after respawning, so you cannot be spawn-camped.
        /// Shots pass straight through a protected actor rather than being absorbed,
        /// so it cannot be used as a shield either.
        static let spawnProtection: Double = 1.5
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

    enum AI {
        /// Master switch. Off gives you the quiet map back for testing anything else.
        static let enabled = true

        /// How many of the seven other actors get a brain. Drop it to 1 while
        /// watching a single bot's behaviour.
        static let botCount = 7

        /// How long a bot holds a direction before picking a new one. Randomised
        /// per decision, so seven bots never change their minds in unison.
        static let decisionInterval: ClosedRange<Double> = 1.2...3.0

        /// How fast a bot can turn, in radians per second. This is the single
        /// number that decides whether movement reads as steering or as snapping.
        /// Roughly a half-turn per second.
        static let turnRate: Double = 4.5

        /// How far a change of mind can swing the heading, in radians (about 60°).
        /// Large enough to be a real change, small enough not to look like a glitch.
        static let wanderTurn: Double = 1.1

        /// How far ahead to look for obstacles, in tiles. Several distances, so a
        /// bot starts easing away early rather than turning at the last moment.
        static let probeDistances: [Double] = [1.0, 2.0, 3.2]

        /// Angles to try when the way ahead is blocked, in radians, smallest first,
        /// so a bot takes the gentlest turn that works.
        static let avoidanceAngles: [Double] = [0.45, 0.9, 1.5, 2.1, 2.7, 3.14]

        /// How close to the map edge a bot has to get before it starts curving
        /// back inward, in tiles.
        static let edgeMargin: Double = 8

        /// How hard it curves inward when right up against the edge. 0 ignores the
        /// edge entirely, 1 turns straight for the middle. Anything near 1 looks
        /// like a bot fleeing the wall, so keep it gentle.
        static let edgeBias: Double = 0.65

        /// How far a bot will notice and go after an enemy, in tiles. Shorter than
        /// the blaster's range, so a fight starts with a bot closing in rather than
        /// sniping from off screen.
        static let engageRange: Double = 12

        /// The range a bot tries to fight at, in tiles. Inside this it plants its
        /// feet and shoots; outside it, it closes in.
        static let preferredRange: Double = 6

        /// It keeps chasing a target out to here even with no clear shot, so a tree
        /// passing between them does not end the fight.
        static let disengageRange: Double = 16

        /// How often a bot looks around for enemies, in seconds. Threats cannot
        /// wait for the ordinary decision timer - up to three seconds to notice
        /// someone shooting at you is most of why fights never started - but line
        /// of sight is far too expensive to run every tick.
        static let threatScanInterval: Double = 0.1

        /// How close to lined up a bot needs to be before it plants its feet and
        /// shoots, in radians.
        ///
        /// This MUST sit comfortably above aimError. If a bot's own aim wobbles
        /// further than it is willing to shoot from, it can never satisfy its own
        /// firing condition: it just keeps walking at whoever it is fighting, which
        /// is two bots circling each other and never resolving anything.
        static let fireTolerance: Double = 0.24

        /// Random wobble applied to a bot's aim, in radians (about 8°). This is
        /// what makes bots miss - it is applied to the heading, so a miss looks
        /// like slightly sloppy movement rather than a bullet bending.
        static let aimError: Double = 0.14

        /// Once planted, a bot holds its ground this much further out than it would
        /// first stop at, in tiles. Without the gap it flickers between standing
        /// and walking every time the range wobbles across the line.
        static let holdHysteresis: Double = 2

        /// How long a bot takes to react to an enemy it has just noticed.
        static let reactionDelay: ClosedRange<Double> = 0.25...0.5

        /// Below this share of its health, a bot breaks off and runs for home -
        /// but only while an enemy is actually near. Once it is safe it gets back
        /// to work rather than cowering in its base for the rest of the match.
        static let retreatHealthFraction: Double = 0.3

        // Drinking. These read as one set of habits: finish the fight, catch your
        // breath, top up, and never tip a big drink down a small wound - unless you
        // are about to die, when none of that matters.

        /// Below this, a bot drinks immediately, mid-fight, under fire, whatever is
        /// to hand. Dying with a full inventory is the worst outcome there is.
        static let criticalHealthFraction: Double = 0.35

        /// When calm, a bot tops up once it has lost this much. Above it, the heal
        /// would mostly be thrown away.
        static let topUpHealthFraction: Double = 0.85

        /// Having been shot this recently counts as still being in the fight.
        static let combatRecency: Double = 3.0

        /// And even once the shooting stops, a beat before drinking. Swigging on
        /// the same frame the last bullet lands is a tell that nobody is home.
        static let settleDelay: Double = 1.5

        /// A bot will pour at most this many times the wound it is fixing. A
        /// slushy into a scratch technically works and is a terrible idea.
        static let maximumOverdrink: Double = 2.0

        /// Unless it is at least this hurt, in which case topping up beats hoarding.
        static let overdrinkBelowFraction: Double = 0.5

        /// Seconds between sips, so a hurt bot does not empty its whole inventory
        /// in a single tick.
        static let drinkInterval: Double = 1.2

        /// Each bot's thresholds are nudged by its own factor, so seven of them do
        /// not all reach for a drink at the same instant.
        static let cautionRange: ClosedRange<Double> = 0.85...1.15

        /// How far away a bot will notice a crate worth walking to, in tiles.
        static let lootSearchRange: Double = 26

        /// How much healing a bot wants to be carrying, in health points. Below
        /// this it puts stocking up ahead of building - turning up to a fight with
        /// an empty bag is a worse problem than an unfinished wall.
        static let desiredHealingStock = 150

        /// How far a bot will detour for an item lying on the ground, in tiles.
        /// Shorter than the crate range - a dropped item is worth a few steps, not
        /// a march across the map.
        static let itemSearchRange: Double = 8

        /// Give up on a crate it has not reached in this long, in seconds. Without
        /// this, a bot cut off from a crate walks at it until the match ends.
        static let lootPatience: Double = 8

        /// And ignore crates entirely for this long afterwards, so it does not
        /// immediately turn back to the one it just abandoned.
        static let lootCooldown: Double = 4

        /// Draws each bot's current goal above its head. Useful while tuning
        /// behaviour, noise the rest of the time.
        static let showDebugLabels = false
    }

    enum Build {
        /// How long a bot goes without thinking about its base after a trip home.
        ///
        /// Long gaps, and more walls per trip. Short frequent trips finish a base
        /// just as fast but leave a bot commuting for most of the first two
        /// minutes - it barely loots, so it turns up to fights with nothing to
        /// drink. Same build time either way; this version spends the difference
        /// out on the map.
        static let urgeInterval: ClosedRange<Double> = 10...16

        /// Walls laid per trip. Still a handful at a time, so the base visibly
        /// grows over a match rather than appearing at once.
        static let blocksPerVisit: ClosedRange<Int> = 3...5

        /// Seconds between individual walls, so they go up one after another
        /// instead of all in the same instant.
        static let placeInterval: Double = 0.8

        /// How close a bot must be to the tile it is laying, in tiles.
        static let reach: Double = 2.2

        /// How far inside the claim the bot stands to lay an edge tile. Without
        /// this it would stand on the wall line itself, which for the bottom edge
        /// puts its feet outside the claim and the placement is refused.
        static let standIn: Double = 1.2

        /// Abandon a building trip that has taken this long - something is in the
        /// way and the bot has a match to be playing.
        static let patience: Double = 25
    }

    enum Loot {
        /// Lootboxes scattered across the map.
        static let lootboxCount = 42

        /// Minimum distance between two lootboxes, in tiles, so they do not cluster.
        static let lootboxSpacing: Double = 4

        /// The crate's footprint, in tiles. Matches the art's proportions
        /// (704 x 474), and LootboxRenderer draws the sprite at exactly this size.
        static let lootboxSize = Vec2(x: 0.95, y: 0.64)

        /// How far past your own hitbox you can reach to open a crate. Small,
        /// because a solid crate means you are already touching it.
        static let openReach: Double = 0.3

        /// Seconds before an opened crate comes back, in the same spot. Without
        /// this the map is stripped bare a minute into a match.
        static let respawnDelay: Double = 45
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

        /// Damage per hit. This is tier 1 from the design spec: nine hits to kill
        /// an unarmoured actor, about 2.7 seconds. When helmet and blaster tiers
        /// arrive, this number becomes a lookup on the actor's blaster.
        static let damage = 12

        /// Shots you can fire before running dry.
        static let magazineSize = 12

        /// Quiet time after your last shot before ammo starts coming back. This is
        /// what makes bursts better than holding the trigger down.
        static let rechargeDelay: Double = 1.0

        /// Seconds per bullet once recharging has started.
        static let rechargeInterval: Double = 0.6
    }
}
