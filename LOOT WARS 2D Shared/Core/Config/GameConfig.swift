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
        ///
        /// Slower than it looks like it should be, and deliberately. How hard
        /// somebody is to hit is really the ratio between how fast they move and
        /// how fast a shot travels - trimming this and raising projectileSpeed
        /// together is what turns a firefight from a guessing game into aiming.
        static let moveSpeed: Double = 3.8

        /// Health with no helmet on. Every tier scales up from here - see
        /// HelmetTier.maxHealth - so an actor's real maximum is actor.maxHealth,
        /// never this.
        static let baseHealth = 100

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

        /// The range a bot tries to fight at, in tiles. Outside it, it closes in.
        static let preferredRange: Double = 8

        /// And inside THIS, it gives ground. Without a floor on the range, nothing
        /// in a fight ever moves a bot backwards: every reason to move - closing,
        /// re-aiming, chasing - points at the enemy, so two bots grind together
        /// until they are standing on each other. A blaster that reaches twelve
        /// tiles should not be fought with at two.
        static let minimumRange: Double = 5

        /// It keeps chasing a target out to here even with no clear shot, so a tree
        /// passing between them does not end the fight.
        static let disengageRange: Double = 16

        /// How often a bot looks around for enemies, in seconds. Threats cannot
        /// wait for the ordinary decision timer - up to three seconds to notice
        /// someone shooting at you is most of why fights never started - but line
        /// of sight is far too expensive to run every tick.
        static let threatScanInterval: Double = 0.1

        /// Random wobble applied to a bot's aim, in radians (about 7°). This is
        /// the only reason bots miss, now that aiming is no longer tangled up with
        /// which way they happen to be walking.
        static let aimError: Double = 0.12

        /// Chance, at each change of mind, that a bot reverses the way it is
        /// circling. Never reversing reads as a machine on rails; reversing every
        /// tick reads as a machine having a fit.
        static let strafeFlipChance: Double = 0.35

        /// How long a bot takes to react to an enemy it has just noticed.
        static let reactionDelay: ClosedRange<Double> = 0.25...0.5

        /// Below this share of its health, a bot breaks off and runs for home -
        /// but only while an enemy is actually near. Once it is safe it gets back
        /// to work rather than cowering in its base for the rest of the match.
        static let retreatHealthFraction: Double = 0.35

        // Drinking. These read as one set of habits: finish the fight, catch your
        // breath, top up, and never tip a big drink down a small wound - unless you
        // are about to die, when none of that matters.

        /// Below this, a bot drinks immediately, mid-fight, under fire, whatever is
        /// to hand. Dying with a full inventory is the worst outcome there is.
        static let criticalHealthFraction: Double = 0.35

        /// When calm, a bot tops up once it has lost this much. Above it, the heal
        /// would mostly be thrown away.
        static let topUpHealthFraction: Double = 0.85

        /// How much of a break-off is "get away from them" versus "get home". Close
        /// up, distance is all that matters; with daylight between you, home does.
        static let breakOffDistance: Double = 8

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

        /// Carrying less healing than this - under two juices - a bot drops what it
        /// is doing and goes shopping.
        ///
        /// Deliberately a near-empty bag rather than a comfortable one. Set at a
        /// comfortable level it beats building almost permanently, because with
        /// crates everywhere there is always one worth a detour, and bases never
        /// get built.
        static let emergencyHealingStock = 50

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

        /// Walls laid per trip.
        ///
        /// More walls per trip rather than more trips: the walk home is what a trip
        /// actually costs, so a bigger armful finishes the base faster without
        /// eating into the time a bot spends out on the map looting.
        static let blocksPerVisit: ClosedRange<Int> = 4...7

        /// Seconds between individual walls. Quick enough to read as somebody
        /// laying a run of them, slow enough that you can still see it happen.
        static let placeInterval: Double = 0.5

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

    enum Drops {
        /// Chance the lowest droppable tier survives its owner's death.
        ///
        /// Not a certainty on purpose. A guaranteed drop makes every kill a
        /// transaction; a chance makes one a gamble, and makes finding a Cosmic on
        /// the ground feel like something happened rather than like arithmetic.
        static let baseChance = 0.35

        /// Added per tier above that, so the good stuff is likelier to survive -
        /// which is what makes hunting a well-equipped actor worth the risk.
        static let chancePerTier = 0.08

        static let maximumChance = 0.80

        /// How far a drop is flung from where its owner fell, in tiles. Enough that
        /// a helmet and a blaster from the same kill land side by side instead of
        /// stacked on top of each other.
        static let scatterRadius = 0.75

        /// Tries this many spots before settling for the exact spot of the death -
        /// a drop flung into a tree is a drop nobody can reach.
        static let scatterAttempts = 8
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

        /// How long a drop lies on the ground before it disappears.
        ///
        /// Short on purpose: it keeps the map from silting up with everything
        /// anybody ever dropped, and it puts a clock on a kill - the helmet you
        /// just knocked off somebody is only yours if you go and get it.
        static let itemLifetime: Double = 10

        /// How long before that it starts flashing, so nobody watches a drop
        /// vanish without warning.
        static let itemWarningTime: Double = 3

        /// Seconds before an opened crate comes back, in the same spot. Without
        /// this the map is stripped bare a minute into a match.
        static let respawnDelay: Double = 45
    }

    enum Blaster {
        /// Tiles per second.
        ///
        /// Against a target crossing your sights this matters more than damage
        /// does, because it decides how far ahead you have to aim - but push it too
        /// high and shots stop reading as shots and start reading as missiles
        /// teleporting out of the barrel.
        ///
        /// At the eight tiles bots fight at: 14 needs 2.17 tiles of lead, 15 needs
        /// 2.03, 18 needs 1.69. Since a target is only 0.9 tiles wide, every one of
        /// those still demands real leading, so the gameplay difference across that
        /// range is small and the visual difference is not.
        static let projectileSpeed: Double = 15
        /// Shots per second while the stick is held over.
        static let fireRate: Double = 4.5
        /// Tiles a shot travels before fizzling out.
        static let range: Double = 12
        /// How far in front of an actor's centre the weapon is gripped, in tiles.
        /// Shared by the simulation and the renderer, so the shot leaves the barrel
        /// you can see rather than a point near it - see BlasterTier.muzzleOffset.
        static let holdDistance: Double = 0.28

        /// How far up the figure the weapon is held, in tiles. Rendering only.
        ///
        /// Just below the eyes, which sit between 0.99 and 1.17 tiles up. The
        /// largest blaster art reaches about 0.37 tiles above the grip, so this is
        /// as high as it can be held without the barrel crossing the face - and the
        /// eyes are the whole expression on these characters.
        static let holdHeight: Double = 0.62

        /// How far the weapon may tilt off horizontal, in radians (45°).
        ///
        /// This is the number that decides whether rotation looks right or looks
        /// broken. A weapon free to swing the full circle has to mirror itself as
        /// it passes vertical, and that flip happens independently of the figure -
        /// which is the snap that reads as janky. Kept inside 45° of horizontal it
        /// never approaches vertical, so the only flip left is the character
        /// turning round, and the weapon turns with it.
        static let maxTilt: Double = 0.785

        /// How big the weapon is drawn, in tiles. The art is square with the gun
        /// filling more of it at higher tiers, so a Blaster6 looks like a Blaster6.
        static let spriteSize: Double = 1.0
        /// Half the width of a projectile, in tiles. Only used for drawing today;
        /// hit detection arrives with health at M5.
        static let projectileRadius: Double = 0.18

        /// Shots you can fire before running dry.
        ///
        /// Scaled up with the fire rate, so a magazine still lasts about four and a
        /// half seconds of holding the trigger - and each shot now takes a smaller
        /// bite out of the bar, so it drains at a pace you can read.
        static let magazineSize = 20

        /// Quiet time after your last shot before ammo starts coming back. This is
        /// what makes bursts better than holding the trigger down.
        static let rechargeDelay: Double = 1.0

        /// Seconds per bullet once recharging has started.
        static let rechargeInterval: Double = 0.35
    }
}
