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

    /// What each thing you can do is worth.
    ///
    /// Points are awarded where the thing HAPPENS - inside the system that does it -
    /// rather than by something watching afterwards and inferring. A wall is scored
    /// by BuildSystem as it goes down, a kill by CombatSystem as it lands. Nothing
    /// has to reconstruct what took place by comparing one tick's state to the last,
    /// which is the version that goes wrong the first time two things happen at once.
    ///
    /// The shape of the table IS the design. Raiding pays best because it costs a
    /// bomb, a breach and a walk into somebody's base under fire. Building pays
    /// least per action because you do it forty times, at home, in safety - it
    /// should add up to something without making patience a way to win.
    enum Score {
        static let kill = 50

        /// Added per tier the victim was carrying - helmet rung plus blaster rung
        /// above the starter, so nought to twelve.
        ///
        /// A kill used to be worth the same whether you took down somebody fresh off
        /// a respawn or somebody in a Cosmic with a Blaster 6, which are not remotely
        /// the same job. This makes the second worth 110 against the first's 50, and
        /// it is self-balancing in a way a flat number cannot be: the player running
        /// away with the match is also the one worth the most to stop.
        ///
        /// Five rather than the eight I first wrote. Eight took fighting from 30% of
        /// the board to 41%, which would have made the leaderboard mostly a kill
        /// count and squeezed raiding and base work for room. At five it sits at 37 -
        /// up, which is the point, without swallowing the other three.
        static let killPerTier = 5

        /// On top of the kill, for catching somebody inside their own walls. Their
        /// ground and their advantage - taking it off them there is worth more.
        static let killInTheirBase = 25

        static let lootboxOpened = 10

        /// A rare crate, which is worth choosing over an ordinary one when both are
        /// in sight - but not worth a match spent hunting them. The gear inside is
        /// the actual prize.
        static let rareLootboxOpened = 25

        /// Per wall. Small on purpose: forty of them is a base, not a strategy.
        static let wallPlaced = 2

        /// Blowing a hole in somebody else's. Their wall cost them two points to
        /// put up; taking it down costs you a bomb and puts you somewhere dangerous.
        static let wallDestroyed = 15

        static let chestPlaced = 15

        /// Per item lifted out of somebody else's chest. The best rate in the game,
        /// deliberately - it sits at the end of the longest chain of work there is.
        static let itemStolen = 20

        /// Zero, deliberately. A token is already its own reward - it buys the
        /// upgrade ladder - and paying score for it as well is the same act counted
        /// twice. At one point each, quadrupling token income made the economy the
        /// biggest slice of the board at 36% and pushed fighting into second, which
        /// would have turned the leaderboard into a measure of who did the most
        /// arcade laps. At zero the split sits at fighting 30, economy 30, raiding
        /// 24, base work 16 - which is the shape it had before the change.
        ///
        /// Left as a number rather than deleted, because it is a dial worth having.
        static let tokenCollected = 0

        /// Blowing up a machine. Between a wall at 15 and a chest emptied.
        static let arcadeDestroyed = 40
    }

    /// Where tokens come from, other than the arcades.
    ///
    /// Tokens do not survive a match - every actor starts on zero and there is no
    /// carry-over - so the whole upgrade ladder has to be climbable inside five
    /// minutes. It was not: arcades alone paid a balanced player about 21, which
    /// reaches the third rung of seven. These two sources and the faster machines
    /// take that to about 89, which reaches the sixth.
    enum Tokens {
        /// Paid to whoever got the kill. The largest single source, because a kill
        /// is the hardest thing on this list to arrange.
        static let perKill = 8

        /// And more for a better-equipped victim, on the same nought-to-twelve scale
        /// the score bounty uses. Somebody fully kitted pays 20 tokens against a
        /// fresh spawn's 8.
        ///
        /// One rather than two. At two, a match paid about 129 tokens, which reaches
        /// Cosmic from bare-headed and undoes the whole point of the ladder being
        /// something you cannot finish. At one it pays 109 and reaches Mythical -
        /// still a long climb, with the top rung left as something to be denied.
        static let perTierKilled = 1

        /// Every crate. Small, because you open a great many of them and it is the
        /// one source that needs no decision at all - at two a crate it out-earned
        /// both of the others put together.
        static let perLootbox = 1

        /// A rare one is worth going out of your way for, and this is part of why.
        static let perRareLootbox = 4
    }

    /// What tokens buy.
    ///
    /// Grouped into tabs, and the SHAPE is the point rather than the contents: a
    /// second tab is a row added here, not a change to the shop. Only tabs that
    /// have something in them are drawn, so today that is one.
    ///
    /// Prices are set against what a match actually earns, which I worked out
    /// before choosing them rather than after. A machine holds about 1.7 tokens at
    /// a time and a full circuit of the five is 36 seconds, so somebody doing
    /// nothing else makes 14 a minute - and a player splitting their attention
    /// makes perhaps 20 across a five-minute match. A bandage at 5 is roughly a
    /// minute of collecting; a medkit at 12 is a real decision. The old spec's 3
    /// was written for eight-minute matches and would buy nine of them, which makes
    /// the arcades a vending machine rather than a choice.
    enum Shop {
        struct Item {
            let type: ItemType
            let price: Int
        }

        /// What a tab is stocked with.
        ///
        /// Two kinds, because gear does not behave like a bandage. A shelf is the
        /// same for everybody; an upgrade depends on what you are already wearing,
        /// and listing all seven tiers would be seven cards where two will do and a
        /// shop full of things you cannot buy.
        enum Stock {
            case shelf([Item])
            case upgrades
        }

        struct Tab {
            let name: String
            let stock: Stock
        }

        /// The shelf, repriced against what the things actually DO rather than
        /// against each other.
        ///
        /// A bomb was six. A bomb opens a wall, and blowing up somebody's machine
        /// pays twenty-five - so six tokens bought a raid that returned nineteen,
        /// over and over, and the cheapest thing on the shelf was also the most
        /// decisive. At eleven the raid still profits, which it should, but the
        /// travel and the risk are now part of the price rather than a formality.
        ///
        /// A machine was eighteen. Modelled against how often its owner actually
        /// walks past it - it stops paying out at three uncollected, so a machine
        /// earns what you collect rather than what it makes - eighteen paid for
        /// itself even if you barely visited, and printed money if you hung around
        /// your own base. At twenty-four it wants both: bought in the first half
        /// AND worked. Bought late it is a luxury, which is the correct shape for
        /// the one purchase that pays you back.
        ///
        /// The gear ladder below is untouched. The complaint was that the shelf was
        /// cheap, not that the climb was - and the climb is where the best kit in
        /// the game comes from, so making it steeper would work against the very
        /// thing the late game is supposed to show off.
        /// GEAR first, because it is the tab you came for: the ladder is the only
        /// thing in here you cannot find lying on the map, and it is what the
        /// tokens are ultimately for.
        ///
        /// No bombs. A bomb was the odd one out on a shelf otherwise made of things
        /// you keep - and being both cheap and the way into somebody's base, it
        /// turned the shop into a raid vending machine. Bombs come out of crates
        /// and chests, where finding one is a reason to go and use it.
        static let tabs: [Tab] = [
            Tab(name: "GEAR", stock: .upgrades),
            Tab(name: "HEALING", stock: .shelf([
                Item(type: .bandage, price: 6),
                // Eleven, down from fifteen. At fifteen a medkit was worse than a
                // bandage on every axis a player actually feels: 0.067 of a health
                // bar per token against 0.083, and the same two bars per slot once
                // you counted the deeper bandage stack. It was the premium option
                // that lost to the cheap one, which is not a choice, it is a trap.
                // At eleven it pays 0.091 a token and three bars a slot.
                Item(type: .medkit,  price: 11)
            ])),
            Tab(name: "BUILDING", stock: .shelf([
                Item(type: .chest,  price: 14),
                Item(type: .arcade, price: 24)
            ]))
        ]

        /// The most cards any one tab shows, which is what the panel is sized for.
        ///
        /// Read off the catalogue rather than written down, so adding a third thing
        /// to a tab widens the shop instead of quietly hiding it.
        static var widestTab: Int {
            tabs.map { tab in
                switch tab.stock {
                case .shelf(let items): return items.count
                // A helmet rung and a blaster rung, and never more than that.
                case .upgrades: return 2
                }
            }.max() ?? 1
        }

        /// How long the quick-buy prompt stays up before getting out of the way.
        static let quickBuySeconds: Double = 6

        /// How hurt you have to be before the prompt offers a bandage instead of a
        /// rung of the ladder.
        ///
        /// Half a bar, not a scratch. The prompt exists to push the LADDER - that
        /// is the thing people forget to spend on, and the thing that decides
        /// fights - and offering a bandage the moment anybody grazes you would
        /// spend the prompt's whole budget of attention on the one purchase you
        /// were always going to remember to make while bleeding.
        static let quickHealBelow: Double = 0.5

        /// How long before an offer you ignored is put in front of you again.
        ///
        /// It comes BACK, and that is the point. An upgrade you cannot afford yet
        /// is announced once and forgotten; one you have been able to afford for
        /// half a minute is one you have not noticed, and noticing is the entire
        /// job of this prompt.
        static let quickBuyReappear: Double = 20

        /// How often the shop button nudges itself while you can afford something
        /// and have not been in. Long enough not to nag.
        static let nudgeInterval: Double = 14

        /// What things NOT on the shelf are notionally worth, for selling back.
        ///
        /// One entry, and it is the bomb: it came off the shelf because being able
        /// to buy the way into somebody's base turned the shop into a raid vending
        /// machine, but you can still end up carrying four with no wall in sight.
        /// Priced at what it used to cost.
        static let offShelf: [ItemType: Int] = [.bomb: 11]

        /// What the shop pays for something you sell back, as a share of its price.
        ///
        /// A fifth, down from a third, and the reason is that a third was an
        /// income. Selling is the only source of tokens the bots do not have, and
        /// it is the one that needs no travel, no risk and no decision - just a
        /// crate opened and a tab tapped. At a third, a match's worth of clearing
        /// out came to about a quarter of everything else earned put together, in
        /// a game whose difficulty complaint is that the player has it too easy.
        ///
        /// At a fifth a spare Rare pays 1, a spare Epic 2 and a Legendary 4, which
        /// is what this was always meant to be: not money, but the difference
        /// between litter and a small consolation. The margin also stops the shop
        /// being a laundry - at anything near full price you could buy a bomb,
        /// think better of it, sell it back, and every price in here would stop
        /// meaning anything.
        static let sellShare: Double = 0.20

        /// What it costs to step UP to each tier.
        ///
        /// EVERY rung is priced, not just the ones crates no longer carry. The
        /// first version only listed Epic upwards, which left anyone below Rare
        /// staring at an empty tab - correct, in that the floor is where they should
        /// be looking, and indistinguishable from a broken shop.
        ///
        /// So the low rungs are here and they are nearly free. A Common is three
        /// tokens because a Common is nearly worthless: the shop is topping you up,
        /// not selling you a shortcut past the crates. The shape is what matters -
        /// cheap at the bottom, steep at the top, so the shop's real value is
        /// exactly where the crates now stop.
        ///
        /// Priced against a match: a balanced player collects about 25 tokens in
        /// five minutes and somebody working the arcades about 42. Epic is half a
        /// match, Cosmic is a match and a half, and the whole climb from bare-headed
        /// is 190 - six or seven matches. Nobody tops out in one, which is the point.
        ///
        /// And every rung is lost on death, which is what stops a bought Cosmic from
        /// simply deciding the match. It is a lead to hold on to, not a purchase.
        static let helmetPrices: [HelmetTier: Int] = [
            .common: 3, .uncommon: 5, .rare: 8,
            .epic: 13, .legendary: 20, .mythical: 28, .cosmic: 38
        ]

        static let blasterPrices: [BlasterTier: Int] = [
            .two: 3, .three: 6,
            .four: 13, .five: 21, .six: 32
        ]
    }

    /// One-off awards for closing your own wall.
    ///
    /// The complaint this answers is the one that matters most: there was no reason
    /// to build. Two points a brick is not a reason - it is worth about a third of
    /// a kill for a whole base - so roaming and shooting people was simply the
    /// better game, and the base was a chore between fights.
    ///
    /// Sealing pays properly, once. Re-sealing after somebody has blown a hole in
    /// it pays a third of that, every time, which is the part that makes defending
    /// a base a thing you do rather than a thing you give up on - and it is capped
    /// by the fact that somebody has to breach you first for it to be available.
    enum Base {
        static let sealed = 60
        static let sealedTokens = 8
        static let resealed = 20
    }

    enum Match {
        /// How long a match runs, in seconds.
        static let duration: Double = 300

        /// How long into a match before bombs start turning up, in seconds.
        ///
        /// Nothing can be raided until somebody is carrying the way in, so holding
        /// bombs back holds raiding back - and that buys everyone the first two
        /// minutes to loot, build and shut their walls without a hole appearing in
        /// them. Bases finish around the minute mark, so this leaves a breather
        /// after the wall goes up rather than cutting it fine.
        ///
        /// It applies to every source at once - crates, a bot's chest, and the
        /// supply floor bots get. A grace period with one way round it is not one.
        static let bombGrace: Double = 120
    }

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

        /// Health coming back while you stand on your own ground: how big each
        /// portion is, how long between them, and how long after being shot it
        /// starts at all.
        ///
        /// PORTIONS rather than a trickle, and that is a rendering decision as much
        /// as a design one. A point of health every few frames is arithmetically
        /// identical to a portion every two seconds, but the screen reacts to a
        /// heal - a wash of green, a lift, motes coming off - and at sixty ticks a
        /// second the same actor is being re-announced constantly. Standing in your
        /// own base looked like being repeatedly zapped. Twelve deliberate pulses
        /// read as recovering; seven hundred tiny ones read as a fault.
        ///
        /// The pace is unchanged and still slow: eight per cent of your bar every
        /// two seconds is a full bar in twenty-five, so home is where you recover
        /// BETWEEN fights rather than a way to win one, and a bandage is still six
        /// times faster than walking back. The delay is what stops it ticking
        /// during a fight on your doorstep, where a defender who heals mid-firefight
        /// is a defender nobody can kill at home.
        static let recoveryPortion: Double = 0.08
        static let recoveryTick: Double = 2.0
        static let recoveryDelay: Double = 4

        /// Seconds spent dead before respawning at your own claim.
        static let respawnDelay: Double = 3.0

        /// The kit you come back in, by how far the match has run.
        ///
        /// Death strips everything, which is right, and for four minutes it stays
        /// right. It stops being right in the last ninety seconds: by then the map
        /// is full of Epics and Blaster 4s, and one death dropped you out of the
        /// match entirely - back to bare-headed with a starter blaster, against
        /// people three tiers up, with no time left to climb. The closing minutes
        /// were being decided by who had most recently died rather than by who was
        /// playing best, and the game's best gear was on show precisely when the
        /// people wearing it stopped being challenged.
        ///
        /// So a respawn is topped UP to a floor that rises with the clock. It never
        /// takes anything away - what you kept, you keep - and the floor stays well
        /// under what the shop and the chests are handing out by then, so it is a
        /// way back INTO the fight rather than a replacement for having won one.
        /// Everybody respawns to the same floor, bots included, which is what stops
        /// the last minute filling up with free kills.
        static let respawnFloor: [(progress: Double, helmet: HelmetTier, blaster: BlasterTier)] = [
            (0.50, .common,    .two),
            (0.70, .uncommon,  .three),
            // Epic rather than Rare at the top. The floor is what somebody who has
            // just died fights the last forty seconds in, and a Rare against a map
            // full of Epics and Legendaries is a spectator.
            (0.85, .epic,      .four)
        ]

        /// What a respawn is worth right now, or nil in the opening half when it is
        /// worth nothing at all.
        static func respawnKit(at progress: Double)
            -> (helmet: HelmetTier, blaster: BlasterTier)? {
            guard let band = respawnFloor.last(where: { progress >= $0.progress }) else {
                return nil
            }
            return (band.helmet, band.blaster)
        }

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
        /// The furthest a bot will ever start a fight from - before the screen has
        /// its say. See AIBrain.fightRanges: the real limit is usually what the
        /// camera can show, and this is only the ceiling on top of that.
        static let engageRange: Double = 12

        /// How much of the visible half-height a bot may fight across.
        ///
        /// Under one, so a bot is on screen BEFORE it starts shooting rather than
        /// exactly at the edge. This is the number that fixes being shot by things
        /// you cannot see: the ranges below used to be three independent constants
        /// with no relationship to the camera at all, and on a phone in landscape
        /// the camera shows under five tiles up or down while bots were engaging at
        /// twelve. Two and a half screens away, firing.
        static let visibleMargin: Double = 0.92

        /// How long a bot will keep at a fight it is getting nothing out of.
        ///
        /// Counted only while it has NO shot - so a real firefight never trips it,
        /// however long it runs. What it catches is the bot orbiting a base trying
        /// to reach somebody stood behind their own wall, which it can neither
        /// shoot through nor walk through, forever.
        static let fightPatience: Double = 4.0

        /// And it leaves that fight alone for this long afterwards, so it does not
        /// simply re-acquire the same unreachable target on the next tick. Being
        /// actually shot cancels it - giving up on somebody you cannot reach is
        /// sensible, ignoring somebody hitting you is not.
        static let fightCooldown: Double = 6.0

        // MARK: - Shopping

        /// Bots leave these tiers to the crates and save their tokens for what only
        /// the shop sells.
        ///
        /// Set at exactly where the loot table stops. Buying a Common for three
        /// tokens is three tokens not spent on an Epic, and a bot would have found
        /// that Common in a crate within the minute anyway - so below this line
        /// spending is worse than saving. Above it there is no other way up.
        static let buysHelmetsAbove: HelmetTier = .rare
        static let buysBlastersAbove: BlasterTier = .three

        /// Seconds before a bot with no bombs left is handed one.
        ///
        /// A deliberate cheat, and bots only. Bombs come from crates at one in
        /// seven, which is fine on average and useless in particular: a bot that
        /// draws badly for two minutes simply cannot raid, and raiding is most of
        /// what makes the bases worth anything. This is a floor under that, not a
        /// supply - it only ever tops an EMPTY pocket up to one.
        ///
        /// Sixty rather than the forty I first wrote. A bot opening crates draws
        /// about four bombs across a match; at forty seconds this could hand it
        /// twelve, which would have made the cheat the main source and the crates
        /// decoration. At sixty its ceiling is eight and its realistic contribution
        /// is a good deal less, because it only ever fires on an empty pocket.
        /// Down from 60. Raiding is the best thing in this game and the thing
        /// least likely to happen, and the reason is banal: a bot with no bomb
        /// cannot raid, and bots spend bombs on walls faster than crates hand them
        /// out. This is the supply line for the whole activity, so it is the dial
        /// that moves it - about a third more bombs across a match, which is about
        /// a third more raids.
        static let bombSupplyInterval: Double = 42

        /// Where a fight sits inside whatever range is available, as fractions of
        /// it. Fractions rather than tile counts so they can never again drift out
        /// of step with what is on screen.
        static let preferredFraction: Double = 0.72
        static let minimumFraction: Double = 0.48
        static let disengageFraction: Double = 1.35

        /// Inside this share of the engage range, a bot fights whoever is there and
        /// does not think about it. Arm's length: somebody this close is a problem
        /// whatever else was on your list.
        static let pressingFraction: Double = 0.45

        /// How much better equipped a bot has to be before it stops bothering with
        /// somebody, in tiers.
        ///
        /// Punching down pays almost nothing now that a kill is priced by what the
        /// victim was carrying - a Cosmic killing a fresh spawn earns 50 and 8
        /// tokens, where the same minute spent on a chest earns far more. So the
        /// bounty already says this is a poor use of a strong bot's time; this is
        /// the AI agreeing with it.
        static let punchDownSlack = 4

        /// How much gear makes somebody worth crossing open ground for, at the
        /// near edge of the band - and how much MORE is wanted at the far edge.
        ///
        /// The requirement grows with the distance, which is the part that matters.
        /// A flat threshold barely changed anything: by the middle of a match almost
        /// everybody is carrying enough to clear it, so seven bots still converged
        /// from the edge of vision. Sliding it from 3 up to 9 across the band means
        /// somebody a step away is worth fighting and the same person at maximum
        /// range is not - which is the actual complaint.
        ///
        /// Measured over 150,000 encounters with gear that climbs across a match:
        /// engagements fall from 100% to 79% overall, 62% early on when nobody has
        /// anything worth taking, and 95% late when everyone does. Late being high
        /// is correct - by then a fight IS the game.
        /// Lowered from 3 and 6 to 2 and 5, which is a smaller step than it looks.
        ///
        /// Modelled across 150,000 encounters, those two numbers move the share of
        /// sightings that become fights from 45% to 60%, and the sharper aim below
        /// takes the share of shots that land from 45% to 54%. Multiplied, the
        /// pressure a player is under goes from 0.20 to 0.33 - two thirds more -
        /// which is a large enough change in one pass that going further on either
        /// dial at the same time would have been guessing. 2 and 4 was the first
        /// draft and put it at 0.35; the difference is not worth the risk of
        /// overshooting into unfair, and the dial is right here if it is not enough.
        ///
        /// A bot still walks away from a naked spawn across the map. It just comes
        /// for anybody carrying anything.
        static let worthChasingGear = 2
        static let worthChasingAtRange = 5




        /// How often a bot looks around for enemies, in seconds. Threats cannot
        /// wait for the ordinary decision timer - up to three seconds to notice
        /// someone shooting at you is most of why fights never started - but line
        /// of sight is far too expensive to run every tick.
        static let threatScanInterval: Double = 0.1

        /// How far to the side a bot's shot may stray, in TILES, at whatever range
        /// it happens to be firing from.
        ///
        /// A distance, not an angle, and the difference matters the moment fights
        /// move closer. As an angle - which this was, at 0.12 radians - the miss
        /// shrinks with the range: the same wobble that threw a shot a whole tile
        /// wide at eight tiles throws it half that at four. Bringing fights into
        /// view would have quietly doubled every bot's accuracy, which is the exact
        /// opposite of what shortening them was for.
        ///
        /// Set at 1.0 because the player is 0.9 tiles across, so a bot's aim is
        /// uncertain by about one body width wherever it is standing - which is
        /// what 0.12 radians used to work out at, at the range fights used to
        /// happen at.
        /// Down from 1.0, and the arithmetic is worth stating because this is the
        /// single number that decides how hard the game is. The noise is uniform
        /// across the spread and the target is 0.9 tiles wide, so an aim-limited
        /// hit rate is 0.45 / spread: 45% at 1.0, and 54% at 0.83. A fifth more of
        /// their shots landing is what "too easy" was asking for, and it is a fifth
        /// rather than a half because doubling a bot's accuracy does not make a
        /// game harder, it makes it unfair - the player still has to be able to
        /// cross open ground.
        static let aimSpread: Double = 0.83

        /// Chance, at each change of mind, that a bot reverses the way it is
        /// circling. Never reversing reads as a machine on rails; reversing every
        /// tick reads as a machine having a fit.
        static let strafeFlipChance: Double = 0.35

        /// How long a bot takes to react to an enemy it has just noticed.
        /// Quicker off the mark, by about a fifth. Enough that walking round a
        /// corner into somebody is no longer a free first shot, not so quick that
        /// they stop feeling like people.
        static let reactionDelay: ClosedRange<Double> = 0.2...0.4

        /// Below this share of its health, a bot breaks off and runs for home -
        /// but only while an enemy is actually near. Once it is safe it gets back
        /// to work rather than cowering in its base for the rest of the match.
        static let retreatHealthFraction: Double = 0.35

        // Patching up. These read as one set of habits: finish the fight, catch
        // your breath, top up, and never spend a medkit on a scratch - unless you
        // are about to die, when none of that matters.

        /// Below this, a bot patches up immediately, mid-fight, under fire,
        /// whatever is to hand. Dying with a full inventory is the worst outcome
        /// there is.
        static let criticalHealthFraction: Double = 0.35

        /// When calm, a bot tops up once it has lost this much. Above it, the heal
        /// would mostly be thrown away.
        static let topUpHealthFraction: Double = 0.85

        /// How much of a break-off is "get away from them" versus "get home". Close
        /// up, distance is all that matters; with daylight between you, home does.
        static let breakOffDistance: Double = 8

        /// Having been shot this recently counts as still being in the fight.
        static let combatRecency: Double = 3.0

        /// And even once the shooting stops, a beat before patching up. Winding a
        /// bandage on the same frame the last bullet lands is a tell that nobody is
        /// home.
        static let settleDelay: Double = 1.5

        /// A bot will spend at most this many times the wound it is fixing. A
        /// medkit on a scratch technically works and is a terrible idea.
        static let maximumOverheal: Double = 2.0

        /// Unless it is at least this hurt, in which case topping up beats hoarding.
        static let overhealBelowFraction: Double = 0.5

        /// Seconds between treatments, so a hurt bot does not empty its whole
        /// inventory in a single tick.
        static let healInterval: Double = 1.2

        /// Each bot's thresholds are nudged by its own factor, so seven of them do
        /// not all reach for a bandage at the same instant.
        static let cautionRange: ClosedRange<Double> = 0.85...1.15

        /// How close to lined up a bot needs to be before lobbing a bomb, in
        /// radians. Generous - a bomb goes off on whatever it hits, so it does not
        /// need the precision a shot does.
        static let throwTolerance: Double = 0.45

        /// How close a bot has to be to somebody's claim before raiding it even
        /// occurs to it, in tiles.
        ///
        /// This is the VANDALISM range - opening a wall for its own sake, with no
        /// particular prize behind it. Eighteen rather than fourteen: still short
        /// enough that it reads as blowing open what you walk past, long enough
        /// that walking past happens.
        static let raidRange: Double = 18

        /// How often a bot gets the itch to go and rob somebody.
        ///
        /// The counterpart to Build.urgeInterval, and pitched against it. Building
        /// comes round every six to ten seconds and takes a trip home; raiding
        /// comes round every thirty-five to sixty and takes a trip across the map.
        /// Over a five-minute match that is five or six raid attempts per bot, or
        /// forty-odd on a map of eight - where before it was whatever happened to
        /// fall through the gaps between building, stashing and looting, which
        /// measured close to none.
        ///
        /// Spent on the ATTEMPT rather than on success, so a bot that cannot reach
        /// anybody does not re-ask every tick for the rest of the match.
        static let raidUrgeInterval: ClosedRange<Double> = 35...60

        /// How far a bot will travel for an enemy chest it could get at.
        ///
        /// Longer than raidRange, because this one is worth the walk: a chest with
        /// something in it is the only thing on the map that repays crossing it.
        static let robRange: Double = 40

        /// How much a target's standing pulls a bot towards them, 0 to 1.
        ///
        /// A bot picks the nearest enemy it can see. At 0.4 the team top of the
        /// leaderboard reads as 40% closer than it is, so a bot will walk past
        /// somebody nearer to go after the leader - without ever ignoring a threat
        /// standing next to it, because the pull scales distance rather than
        /// replacing it.
        ///
        /// How many chests a bot wants standing in its base.
        ///
        /// Bots buy these now, and the measurement is why. Left to the crates, a
        /// chest is one drop in eleven and has to survive a full bag, every death
        /// between finding it and the wall closing, and the wall closing at all -
        /// modelled over 200,000 matches that put a chest in a base 42% of the
        /// time and left 58% of bases with NOTHING in them to raid. A base worth
        /// breaking into is the entire reason bases exist, so it cannot be left to
        /// a one-in-eleven drop.
        ///
        /// Two, not more. A base is a place worth two visits; a base with five
        /// chests in it is a warehouse, and raiding stops being a raid.
        static let chestsWanted = 2

        /// How far into a match a bot will still spend on furniture rather than on
        /// gear. Past this everything goes on the ladder - see
        /// AIBrain.purchaseToMake for why an investment made this late is just
        /// tokens that never became anything.
        static let investsUntil: Double = 0.60

        /// What a raider thinks a base is worth, and what the walk costs.
        ///
        /// Raids used to be chosen by NEARNESS alone - the closest reachable chest
        /// won, whatever was in it - so a base with one bandage in it beat a base
        /// across the way holding four items and a machine. Nobody was ever robbed
        /// for being rich, which is the one reason a base should be robbed at all,
        /// and hoarding was therefore free.
        ///
        /// Now a target is worth what is in it, less what it costs to get there.
        /// The units are arbitrary and only the RATIO matters: at ten a point and a
        /// tile a point, an item is worth ten tiles of walking, so a four-item
        /// chest pulls a raider four times as far as a one-item chest. A machine
        /// counts for more than any single item because blowing one up pays
        /// twenty-five tokens on its own - it is the only thing in a base that is
        /// worth raiding even when the chests are bare.
        static let chestItemWorth = 10
        static let machineWorth = 25
        static let raidDistanceCost: Double = 1.0

        /// What a base has to be worth before a bot will cross the map to open it
        /// rather than get on with the match. Above a single item, so a lone
        /// bandage behind a wall is not a reason to go anywhere.
        static let raidWorthOpening = 15

        /// This is the counterweight to a runaway leader. Get far enough ahead and
        /// seven opponents start preferring you, which is also what makes their kill
        /// bounty worth having.
        static let leaderPull: Double = 0.4

        /// How far away a bot will notice a crate worth walking to, in tiles.
        static let lootSearchRange: Double = 26

        /// Carrying less healing than this - at most one bandage - a bot drops what
        /// it is doing and goes shopping.
        ///
        /// Raised from 50 when the bandaid went. The rule has always meant "one or
        /// none of the smallest supply", and at 50 with nothing below a bandage it
        /// would have meant "completely empty" instead - a bot setting off for
        /// supplies only once it had none left, which is exactly too late.
        ///
        /// Deliberately a near-empty bag rather than a comfortable one. Set at a
        /// comfortable level it beats building almost permanently, because with
        /// crates everywhere there is always one worth a detour, and bases never
        /// get built.
        /// Lowered from 60, which was two bandages or a medkit.
        ///
        /// This number does double duty - it is also the bar a bot has to clear
        /// before it will set out to rob somebody - and at 60 it was quietly the
        /// biggest brake on raiding: a bot with a single bandage was judged too
        /// poorly supplied to cross the map, which is most bots for most of a
        /// match. At 40 one bandage is enough to go with.
        ///
        /// Both uses move together on purpose. The bar being the SAME number is
        /// what keeps the two branches from wanting the bot in opposite directions:
        /// anything that fails the raid test wanted supplies anyway.
        static let emergencyHealingStock = 40

        /// How far a bot will detour for an item lying on the ground, in tiles.
        /// Shorter than the crate range - a dropped item is worth a few steps, not
        /// a march across the map.
        static let itemSearchRange: Double = 8

        /// How far a bot will go for a token lying on the ground.
        static let tokenSearchRange: Double = 16

        /// How far away a bot will notice an arcade machine worth walking to.
        ///
        /// This is what actually sends bots to arcades. Reacting to loose tokens
        /// was never going to: they live ten seconds, so at the moment a bot picks
        /// a goal there is usually nothing lying there to react to. A bot has to
        /// walk to the MACHINE and let the payouts happen while it is standing
        /// there. Kept under the crate range, so a crate still wins from far off.
        static let arcadeSearchRange: Double = 22

        /// Close enough to a machine to count as having swept it.
        static let arcadeReach: Double = 1.2

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
        /// patch itself up with. Same build time either way; this version spends
        /// the difference out on the map.
        static let urgeInterval: ClosedRange<Double> = 6...10

        /// Walls laid per trip.
        ///
        /// More walls per trip rather than more trips: the walk home is what a trip
        /// actually costs, so a bigger armful finishes the base faster without
        /// eating into the time a bot spends out on the map looting.
        static let blocksPerVisit: ClosedRange<Int> = 7...11

        /// Seconds between individual walls. Quick enough to read as somebody
        /// laying a run of them, slow enough that you can still see it happen.
        static let placeInterval: Double = 0.32

        /// How close a bot must be to the tile it is laying, in tiles.
        static let reach: Double = 2.2

        /// How far inside the claim the bot stands to lay an edge tile. Without
        /// this it would stand on the wall line itself, which for the bottom edge
        /// puts its feet outside the claim and the placement is refused.
        static let standIn: Double = 1.2

        /// Abandon a building trip that has taken this long - something is in the
        /// way and the bot has a match to be playing.
        static let patience: Double = 25

        /// How far behind the leading base a bot has to be before building stops
        /// waiting for its turn, as a share of the whole wall.
        ///
        /// Bots do not fall behind by building slowly - they fall behind by being
        /// interrupted, and the ones in the contested middle of the map get
        /// interrupted most. Left alone that compounds: the bot that is losing
        /// fights is also the one whose base never closes. A quarter of a wall is
        /// far enough to be bad luck rather than noise.
        static let catchUpGap: Double = 0.25

        /// Seconds between walls while there is a HOLE in a finished base.
        ///
        /// Repairing is not building, and it was running at building's pace: a
        /// raided base took the best part of a minute to close, during which its
        /// chests refuse to restock, so one bomb bought a quiet base for far longer
        /// than the raid itself lasted. Patching a hole you are standing in front
        /// of should look urgent, and the sooner it is shut the sooner there is
        /// something in it worth coming back for.
        static let repairInterval: Double = 0.18

        /// How long after being bombed before a team may lay walls again.
        ///
        /// A raid is a round trip - through the wall, into the chest, back out -
        /// and at repair speeds a hole could close while the raider was still
        /// reading the chest, which turns the best part of the game into being
        /// trapped in somebody's cellar. Twelve seconds is about two trips to a
        /// chest and back at walking pace.
        ///
        /// It is not free for the raider either: twelve seconds is also plenty of
        /// time for the owner to come home, and the owner is not prevented from
        /// defending - only from answering a raid with masonry.
        static let raidGrace: Double = 12

        /// Walls laid per trip while patching a breach.
        ///
        /// Sized against the damage, which is smaller than it feels: measured over
        /// the wall line, one bomb takes out three tiles and never more than three,
        /// so this covers a two-bomb hole in a single trip with something in hand.
        ///
        /// Deliberately not larger. An armful that runs out mid-repair costs a
        /// decision interval - one to three seconds of standing about before the
        /// bot re-commits - but an armful far bigger than the hole just keeps it at
        /// home laying wall nobody breached, and time at home is time not raiding.
        static let blocksWhenBreached: ClosedRange<Int> = 8...12

        /// Walls laid per trip by a bot that is behind.
        ///
        /// Roughly double the usual armful, and this is the half of catching up
        /// that does the work. Simulated, the bypass alone barely moved anything -
        /// because the urge timer was never what was holding a laggard back. Being
        /// interrupted was. A bot that is pulled away from home constantly gets few
        /// chances, so the fix is not more chances, it is making each one count.
        static let blocksWhenBehind: ClosedRange<Int> = 14...20
    }

    enum Bomb {
        /// How far a bomb can be lobbed, in tiles. It goes off where it lands even
        /// over open ground, so a throw into nothing is a wasted bomb rather than
        /// one that quietly disappears.
        static let throwRange: Double = 6

        /// How far in front of the thrower it appears, so nobody drops one on their
        /// own feet.
        static let launchOffset: Double = 0.5

        /// Tiles per second. Slower than a bullet on purpose - a bomb should look
        /// thrown, and the flight is the warning a defender gets.
        static let speed: Double = 9

        /// Everything within this of the blast loses its walls, in tiles.
        static let blastRadius: Double = 1.4

        /// Damage at the centre of the blast, falling to nothing at the edge.
        /// Terrain and trees are untouched - only walls come down.
        static let damage = 45

        /// How big the bomb is drawn, in tiles.
        static let spriteSize: Double = 0.55
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

        /// How many rungs death costs, per ladder, and it EASES as the clock runs
        /// down.
        ///
        /// Two helmet rungs and one blaster rung to start with, rather than
        /// everything - see CombatSystem.kill for why stripping the lot did not set
        /// a player back so much as take them out of the match.
        ///
        /// One helmet rung in the closing third, because that is where the
        /// complaint actually lives: late deaths are the ones there is no time to
        /// recover from, and a match whose last minute is fought by people who have
        /// been knocked back down the ladder is a match that gets less interesting
        /// exactly as it should be getting more so. Simulated across 30,000
        /// matches, the taper is worth about half a rung of gear in the closing
        /// minute to an engaged player and a full one to a strong player - and it
        /// WIDENS the gap between them, because it lets people keep what they
        /// earned rather than handing anybody anything.
        static func rungsLost(at progress: Double) -> (helmet: Int, blaster: Int) {
            progress >= 0.70 ? (helmet: 1, blaster: 1) : (helmet: 2, blaster: 1)
        }

        /// The odds that one item off a carried healing stack lands on the ground.
        ///
        /// ONE item, not the stack: enough that winning a hard fight tops you up a
        /// little, not enough that a body is a shop. You spend supplies winning a
        /// fight, and before this you always walked away poorer than you arrived,
        /// however well you shot.
        static let healingChance = 0.5

        /// How far a drop is flung from where its owner fell, in tiles. Enough that
        /// a helmet and a blaster from the same kill land side by side instead of
        /// stacked on top of each other.
        static let scatterRadius = 0.75

        /// Tries this many spots before settling for the exact spot of the death -
        /// a drop flung into a tree is a drop nobody can reach.
        static let scatterAttempts = 8

        /// How far in front of you an item you deliberately drop is thrown, in
        /// tiles, nearest first.
        ///
        /// The shortest of these still clears the player's own hitbox, which is
        /// 0.9 by 1.72. It has to: land one inside your own box and the pickup
        /// sweep hands it straight back on the next tick, and dropping an item
        /// would silently do nothing at all.
        static let throwDistances: [Double] = [1.25, 1.6, 2.0]
    }

    enum Loot {
        /// Lootboxes scattered across the map.
        /// How much likelier a bomb is inside a rare crate, on top of the bandage
        /// and chest rows having been removed from it entirely.
        ///
        /// A gentle nudge rather than the two and a half it started at, and the
        /// difference is arithmetic: with the filler rows gone, everything left is
        /// already far likelier than it was, and 2.5 on top made a rare crate 55%
        /// bombs - a jackpot that mostly pays out ammunition. At 1.15 it comes out
        /// around half gear, a third bombs and the rest medkits, which is a crate
        /// with nothing in it you would throw away and gear as the usual answer.
        static let rareBombBoost: Double = 1.15

        /// Share of crates on the map that are the good ones.
        ///
        /// One in fourteen. At one in six they were everywhere, and a thing you see
        /// constantly is not rare however it is drawn - the glow stopped meaning
        /// anything within a minute. At this share a map of thirty crates holds two
        /// or three, which is few enough that spotting one is a decision about where
        /// to go next. Rolled per crate rather than counted out, so no two maps hold
        /// the same number.
        static let rareShare: Double = 0.07

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

    enum Chest {
        /// What a bot's chest is holding the moment it goes down.
        ///
        /// A shortcut, and worth being honest about which one: bots do not hoard
        /// loot over a match and deposit it, they are simply credited with having
        /// done so. The alternative was a bot walking back to its own chest often
        /// enough to fill it, and it turned out never to do that.
        ///
        /// Sized against a crate, which is worth about 17.5% of a health bar. At
        /// two or three items averaging 42 points each this is a hundred-odd points
        /// of healing plus most of a bomb - six crates or so, for a bomb spent, a
        /// wall breached and a walk into somebody's base under fire. Raise
        /// stockCount before the weights if raids feel thin; it is the blunter dial.
        /// Three or four, up from two or three. A chest is the reason to cross the
        /// map and break a wall, and two items was a thin return on a bomb, a
        /// breach and a walk under fire.
        static let stockCount: ClosedRange<Int> = 3...4

        /// The wait after a raid, specifically.
        ///
        /// Shorter than the standing interval. A raided base should come back to
        /// life rather than be finished for the match - the first item is the one
        /// that makes it worth calling on again, and everything after it can take
        /// its time.
        static let restockAfterRaid: Double = 16

        /// Seconds between a raided bot chest putting one item back.
        ///
        /// Slow enough that emptying one still means something - a raider gets the
        /// lot and the next caller finds bare boards - and quick enough that the
        /// same base is worth a second visit later in a match. At this rate a
        /// stripped chest is back to a useful two items after about a minute.
        static let restockInterval: Double = 28

        /// The most a chest will refill itself to. Still under what a fresh one
        /// holds, so the first raid on a base is always the best one.
        static let restockCeiling = 3

        /// What a chest holds, and it MOVES with the match.
        ///
        /// One table meant a chest raided in the last minute paid out the same
        /// opening-minute Commons as one raided in the first, so raiding got less
        /// rewarding exactly as it got harder. Four bands now, and only the GEAR
        /// rows differ between them.
        ///
        /// Two rungs per band, and the LOW one moves up with the high one. That is
        /// the difference from the first attempt at this: leaving a Common in the
        /// late table meant a raid you had planned, bombed your way into and
        /// carried out under fire could still hand you a helmet worth nothing.
        /// Every rung on offer is now a rung worth the walk at the time it is
        /// offered.
        ///
        /// The top band reaches Mythical, which the crates never do and the earlier
        /// bands never do. Cosmic stays behind the token ladder - the very top rung
        /// should be climbed rather than found - but the second-best helmet in the
        /// game being the prize for a late raid is exactly the reward the closing
        /// minutes were missing.
        ///
        /// Healing is up: the medkit row nearly doubled and the bomb row gave way
        /// for it. A chest item is worth 35% of a health bar now against 32%, and
        /// with three or four items in a fresh chest rather than two or three, a
        /// raid is worth appreciably more than the bomb that opened it. Gear holds
        /// 34 of 138 in every band - a quarter, as before - so chests are worth
        /// breaking into exactly as often as they were, and worth more when you do.
        static let stockTables: [(from: Double, rows: [(item: ItemType, weight: Int)])] = [
            (0.00, [
                (.bandage, 58), (.medkit, 20), (.bomb, 26),
                (.helmet(.common), 11), (.helmet(.rare), 6),
                (.blaster(.two),   11), (.blaster(.three), 6)
            ]),
            (0.35, [
                (.bandage, 58), (.medkit, 20), (.bomb, 26),
                (.helmet(.rare), 11), (.helmet(.epic), 6),
                (.blaster(.three), 11), (.blaster(.four), 6)
            ]),
            (0.65, [
                (.bandage, 58), (.medkit, 20), (.bomb, 26),
                (.helmet(.epic), 11), (.helmet(.legendary), 6),
                (.blaster(.four), 11), (.blaster(.five), 6)
            ]),
            (0.85, [
                (.bandage, 58), (.medkit, 20), (.bomb, 26),
                (.helmet(.legendary), 11), (.helmet(.mythical), 6),
                (.blaster(.five), 11), (.blaster(.six), 6)
            ])
        ]

        /// The band the match is currently in.
        static func stockTable(at progress: Double) -> [(item: ItemType, weight: Int)] {
            stockTables.last { progress >= $0.from }?.rows ?? stockTables[0].rows
        }

        /// Footprint in tiles. The art is 1286 x 858 - a hair under 3:2 - and
        /// ChestRenderer draws it at exactly this size, so the chest you see is the
        /// chest you bump into.
        static let size = Vec2(x: 1.05, y: 0.70)

        /// How far past your own hitbox you can reach to open one. Small, because a
        /// chest is solid and you are already touching it when you are beside it.
        static let openReach: Double = 0.3
    }

    enum Arcade {
        /// Paid for blowing up somebody's machine.
        ///
        /// More than it cost them, which is deliberate: raiding one has to beat
        /// owning one or nobody would bother crossing the map for it. It is a lump
        /// sum rather than a slow drip - the opposite of what the machine does for
        /// its owner, and about a quarter of a match's income in one go.
        static let destroyedReward = 25

        /// Machines on the map. Deliberately few: an arcade you have to travel to
        /// is a place worth fighting over, one on every corner is furniture.
        static let count = 5

        /// Footprint in tiles. The art measures 496 x 808 opaque pixels - a ratio
        /// of 0.61 against the 0.67 of a 2 x 3 block, close enough to sit on the
        /// grid without stretching.
        static let footprintWidth = 2
        static let footprintHeight = 3

        /// How much clear ground a machine on the MAP needs around it, in tiles.
        ///
        /// Two, not one. One ring is where a token lands; two is what makes a
        /// landed token reachable - a token on the ring with a tree or the map edge
        /// behind it is one you can see and cannot walk to. Over 3,000 generated
        /// maps this costs nothing: every map still fits all five.
        ///
        /// Machines bought and placed in a base are exempt, and have to be: a base
        /// is nine tiles across and two rings of clearance inside a wall is not a
        /// thing that exists.
        static let clearance = 2

        /// Seconds between payouts.
        ///
        /// Down from 4. Together with the sealed-base multiplier below, a machine
        /// standing behind a finished wall now pays about one token every two
        /// seconds rather than one every four - which is what turns it from a
        /// twenty-four token ornament into the reason to own a base.
        static let emitInterval: Double = 3.2

        /// What a shut wall is worth, as a multiplier on the interval.
        ///
        /// Kept, but it is the smaller half of the answer - see sealedUncollected
        /// below, which is the half that actually pays. A faster interval only
        /// helps somebody who visits often enough to outpace it, which at two
        /// seconds a token means every eight seconds or so; anybody playing the
        /// match rather than guarding a cabinet is limited by the CAP instead.
        static let sealedInterval: Double = 0.62

        static let tokenValue = 1

        /// How many of its own tokens a machine will let pile up before it stops.
        ///
        /// This is the anti-camping valve, and it is the only reason standing at a
        /// machine does not beat moving between them. At three, a machine left
        /// alone is full in eighteen seconds and then pays nothing.
        static let maxUncollected = 4

        /// And how many it will let pile up behind a wall that is standing.
        ///
        /// THIS is why you build a base. A machine in the open stops at four,
        /// because standing at one is not supposed to beat moving between them.
        /// One behind your own shut wall banks eight, because nothing is going to
        /// walk off with them - so the wall turns the machine from a thing you have
        /// to babysit into a thing that earns while you are somewhere else.
        ///
        /// Modelled against a match: a machine bought at a minute pays 43 tokens to
        /// somebody who passes it every 45 seconds, against 16 before. It costs 24.
        /// That is the difference between an ornament and a reason.
        ///
        /// And it is exactly what a raider takes off you: breach the wall and the
        /// bank drops back to four until it is repaired, which is worth more to
        /// them than the twenty-five they get for blowing the machine up.
        static let sealedUncollected = 8

        /// How far out from the footprint a token still counts as this machine's,
        /// for the cap above. Just past the ring it drops them on.
        static let collectionRadius: Double = 1.5

        /// How long a token lies there.
        ///
        /// The same clock loot runs on, kept as its own number so the two can be
        /// tuned apart later. Note what this does to maxUncollected above: at one
        /// token every six seconds and ten seconds of life, a machine averages
        /// under two on the ground and never reaches the cap of three. The despawn
        /// IS the cap now - the pile is a thing you catch, not a thing you find.
        static let tokenLifetime: Double = 10

        /// And how long one lasts inside a base whose wall is standing.
        ///
        /// The bank above needs this to mean anything: eight tokens at two seconds
        /// apart take sixteen to accumulate, so on a ten-second clock the first has
        /// rotted before the fifth exists and the pile can never form. Forty-five
        /// seconds is long enough to come home to and short enough that leaving it
        /// all match still loses you the oldest of them.
        static let sealedTokenLifetime: Double = 45

        /// Minimum gap between two machines, in tiles.
        static let spacing: Double = 16

        /// How far a machine keeps from any claim. Tokens are supposed to be worth
        /// leaving home for.
        static let claimClearance: Double = 5
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

        /// Whether running dry is a thing that happens at all.
        ///
        /// Off. The bar was a second resource to watch in a game whose fights last
        /// four seconds, and what it actually did was punish the player for holding
        /// a trigger the bots were never going to hold - they fire in bursts by
        /// nature, so the mechanic taxed exactly one of the eight actors on the map.
        ///
        /// The machinery below stays, and stays wired: the magazine, the recharge
        /// delay and the drip are all still here and still correct. Only the check
        /// that stops a shot is skipped, and the bar is not drawn. Turning this back
        /// on is one word, which is the point of leaving it in.
        static let usesAmmo = false

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
