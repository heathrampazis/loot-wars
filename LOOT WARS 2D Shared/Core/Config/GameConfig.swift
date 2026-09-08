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


        /// Cracking somebody else's chest open. Paid once, for the whole act.
        ///
        /// Sized as roughly two items' worth of the old per-item rate plus the
        /// price of getting there. It is the end of the longest chain of work in
        /// the game - find a bomb, cross the map, breach a wall, survive the owner
        /// - and it should read as the biggest single thing you can do that is not
        /// a kill.
        static let chestRaided = 55

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

        // MARK: - Holding what you built

        /// How often a standing base pays.
        ///
        /// Building had one payment and it was a lump sum: two points a wall and
        /// sixty for closing it. That prices the ACT of building and nothing about
        /// keeping it, so the correct play was to throw a base up, never look at it
        /// again, and spend the rest of the match somewhere else - which is exactly
        /// what everybody did, including the bots.
        ///
        /// Paying by the tick prices the thing the game is actually about. A wall
        /// you are still standing behind at the whistle earned all match; one that
        /// was opened in the second minute stopped earning the moment it was
        /// opened, and started again when you fixed it. It also gives raiding a
        /// second motive: breaking somebody's seal does not just take what is in
        /// there, it turns their income off.
        ///
        /// Twelve seconds, which is slow enough to read as a drip rather than a
        /// counter spinning, and quick enough that the difference between holding
        /// and losing a base is visible inside one raid.
        static let holdInterval: Double = 12

        /// Paid for a wall with no hole in it.
        static let holdStanding = 3

        /// Paid for each item sitting in your chests, up to the cap.
        ///
        /// This is the answer to the other half of the question: why put anything
        /// in a chest at all? Storing used to be pure insurance - your pockets are
        /// lost when you die and a chest is not - and insurance is worth nothing
        /// when dying is cheap, so the honest answer was "do not bother, just find
        /// more". Now what is in the chest earns, every twelve seconds, for as long
        /// as you keep the wall shut round it. Banking is a scoring move.
        ///
        /// It is also what makes a raid worth the walk twice over. The items a
        /// raider carries out are not just supplies, they are the other team's
        /// income - and the same items go on earning for whoever took them home.
        static let holdPerStoredItem = 2

        /// The most items that can earn at once.
        ///
        /// Five. A base is a place worth two visits, not a warehouse - without a cap
        /// the best strategy is to never spend anything, which is the opposite of a
        /// game about spending supplies to win fights.
        static let holdItemCap = 5
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

        /// Tokens for cracking somebody's chest. Still more than a rare crate,
        /// because a rare crate does not shoot back.
        ///
        /// 3 rather than 7. The haul out of a chest is the ITEMS - two of them, and
        /// they are the reason to go - so this is a tip on top rather than a wage.
        static let perChestRaided = 3
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

        /// GEAR and HEALING, and nothing else - now as GROUPS rather than as tabs.
        ///
        /// The shop draws all of this on one page; what these two still decide is
        /// the order it appears in, and where a price is looked up from. They are
        /// kept because that grouping is real - a rung of the ladder and a bandage
        /// are different kinds of purchase - and because the day this shop sells
        /// six things, the page will want them grouped.
        ///
        /// Both ladders share the gear tab, side by side: two cards, one headed
        /// Helmet and one headed Blaster, each showing the next rung up. They belong
        /// together because they are the same decision asked twice - what to spend
        /// the next handful of tokens on - and splitting them across two tabs made
        /// you flick between headings to compare two prices.
        ///
        /// BUILDING is gone. It sold a chest, which crates hand out anyway, and a
        /// machine, which was the one purchase that paid for itself - and a shop
        /// that sells you your own income is a shop that decides the match at the
        /// counter. Machines come out of rare crates now: one or two exist in a
        /// whole match, whoever finds one has something worth defending, and
        /// everybody else has something worth raiding.
        ///
        /// No bombs either, for the older reason: being both cheap and the way into
        /// somebody's base, a bomb on a shelf turned the shop into a raid vending
        /// machine.
        /// HEALING first, which is what puts the bandage and the medkit on the LEFT
        /// of the shelf and the two gear rungs on the right.
        ///
        /// Order is the only layout decision the config still makes, and it is
        /// worth making here rather than in the panel: healing is what you open the
        /// shop for in a hurry, and the left of a row is where a thumb and an eye
        /// both start. The ladder is the considered purchase and can afford to be
        /// the second thing read.
        static let tabs: [Tab] = [
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
            Tab(name: "GEAR", stock: .upgrades)
        ]

        /// The most cards the shop can ever show at once, which is what the panel
        /// is sized for.
        ///
        /// Everything added together now rather than the widest tab, because the
        /// shop is one page: a fifth item makes the panel a row taller instead of
        /// quietly not being drawn. Read off the catalogue rather than written
        /// down, so nobody has to remember this exists.
        static var catalogueSize: Int {
            tabs.reduce(0) { total, tab in
                switch tab.stock {
                case .shelf(let items): return total + items.count
                // A helmet rung and a blaster rung, and never more than that.
                case .upgrades: return total + 2
                }
            }
        }

        /// How long the quick-buy prompt sits still after a purchase before it is
        /// allowed to offer something else.
        ///
        /// The prompt no longer times out - it stays up for as long as there is
        /// something you can afford - so this is not a lifespan any more, it is
        /// just long enough for the green confirmation to be seen. Without it,
        /// buying a bandage swaps the card to the next offer on the following
        /// frame and the celebration plays on an item you did not buy.
        static let quickBuySettle: Double = 0.9

        /// How hurt you have to be before the prompt offers healing instead of a
        /// rung of the ladder.
        ///
        /// The same seven tenths as Player.tapHealBelow, and they should never
        /// drift apart: that is the line where the hotbar starts ringing the heal
        /// in your bag green, and this is the line where the shop starts offering
        /// to sell you one. Two different numbers for "you are low" is the game
        /// disagreeing with itself about the only thing the player is thinking
        /// about at that moment.
        ///
        /// It was half a bar, chosen to protect the prompt's budget of attention
        /// back when the prompt appeared for six seconds at a time and had a budget
        /// to protect. It does not any more.
        static let quickHealBelow: Double = 0.7

        /// How often the shop button nudges itself while you can afford something
        /// and have not been in. Long enough not to nag - and it now holds off
        /// entirely while the quick-buy prompt is up, since the prompt is saying
        /// the same thing in more detail.
        static let nudgeInterval: Double = 14

        /// What things NOT on the shelf are notionally worth, for selling back.
        ///
        /// Everything that came off the shelf but can still end up in your bag: a
        /// bomb, a chest, a machine. Priced at what each used to cost.
        ///
        /// Without this they are unsellable, which sounds harmless and is not - a
        /// chest you cannot place because your wall is open, or a machine your base
        /// has no room for, would sit in one of four slots for the rest of the
        /// match with no way out but the grass.
        static let offShelf: [ItemType: Int] = [
            .bomb: 11,
            .chest: 14,
            .arcade: 24,

            // The power-up. Never on the shelf - the whole point of a perk is that
            // it is found - but the shop still makes an offer for one, because
            // nobody decides for the player which of their things are junk.
            //
            // Kept deliberately low against what it does. At a fifth back that is
            // about four tokens, roughly a bandage, and it should stay there: the
            // day selling a perk is worth more than drinking one, the strongest
            // item in the game turns into a coin, which is the opposite of finding
            // something.
            .perk(.overdrive): 22
        ]

        /// What the shop pays for something you sell back, as a share of its price.
        ///
        /// A fifth, down from a third, and the reason is that a third was an
        /// income. Selling is the only source of tokens the bots do not have, and
        /// it is the one that needs no travel, no risk and no decision - just a
        /// crate opened and a tab tapped. At a third, a match's worth of clearing
        /// out came to about a quarter of everything else earned put together, in
        /// a game whose difficulty complaint is that the player has it too easy.
        ///
        /// At a fifth a spare Epic pays 2, a Legendary 4, a Mythical 8 and a
        /// Cosmic 14, which is what this was always meant to be: not money, but the
        /// difference between litter and a small consolation. The margin also stops the shop
        /// being a laundry - at anything near full price you could buy a bomb,
        /// think better of it, sell it back, and every price in here would stop
        /// meaning anything.
        static let sellShare: Double = 0.20

        /// What it costs to step UP one rung. One ladder of prices, and BOTH gear
        /// ladders use it.
        ///
        /// They are the same ladder now. Five rungs of helmet, Common to Cosmic;
        /// five rungs of blaster, Blaster 2 to Blaster 6; the loot tables have
        /// always dealt them out in pairs and the rarity colours now say so out
        /// loud - a Blaster 3 and an Epic helmet are both green. Two cards sitting
        /// side by side on one page, wearing the same colour, at two prices was the
        /// shop contradicting the ladder it was selling from.
        ///
        /// The previous attempt kept the CUMULATIVE cost of reaching each surviving
        /// tier identical to what it was before two rungs were deleted, which was
        /// arithmetically neat and produced a shop that looked broken: an Epic at
        /// 26 and then a Legendary at 20, because Epic had swallowed two deleted
        /// rungs and Legendary had swallowed none. Nobody reads a cumulative total.
        /// What a player reads is the number on the card in front of them, and that
        /// number going DOWN as the gear gets better is the shop telling them the
        /// ladder is nonsense. Monotonic beats neat.
        ///
        /// EVERY rung is priced, not just the ones crates no longer carry. An
        /// earlier version only listed the top of the ladder, which left anyone
        /// near the bottom staring at an empty tab - correct, in that the floor is
        /// where they should be looking, and indistinguishable from a broken shop.
        /// So the first rung is here and it costs less than a bandage: the shop is
        /// topping you up, not selling you a shortcut past the crates. The shape is
        /// what matters - cheap at the bottom, steep at the top, about 1.7x a rung -
        /// so the shop's real value is exactly where the crates stop.
        ///
        /// Priced against a match, and repriced because the match changed. Every
        /// sealed base now has a machine in it, so a player who raids collects
        /// something like 136 tokens in five minutes and an ordinary one around 70
        /// - against the 25 and 42 these prices were first written for.
        ///
        /// At 5/9/16/26/40 that made both full ladders 1.4 busy matches, and topping
        /// one ladder 71% of a single match. "Nobody tops out in one" had stopped
        /// being true, and the top of the ladder is supposed to be the thing most
        /// matches nobody has.
        ///
        ///     rung          price   cumulative   of a busy match
        ///     Common/Bl2        6           6         4%
        ///     Epic/Bl3         12          18        13%
        ///     Legendary/Bl4    22          40        29%
        ///     Mythical/Bl5     40          80        59%
        ///     Cosmic/Bl6       70         150       110%
        ///
        /// So one ladder is 150 and both are 300 - a bit over two busy matches, or
        /// four ordinary ones. Reaching the top rung of ONE ladder costs more than a
        /// good match earns, which is the line that was missing: a Cosmic has to be
        /// something you save across matches rather than something a good afternoon
        /// buys twice.
        ///
        /// Equal rather than merely similar, and the bots are the reason it has to
        /// be exact. A bot buys whichever offer is cheaper, so a ladder that was
        /// dearer at every rung would never be bought at all - seven bots would
        /// climb one ladder to the top and ignore the other. Priced level, the tie
        /// goes to the helmet, which puts the bot a rung ahead on that ladder, which
        /// makes the blaster cheaper next time. They alternate, for free, because
        /// the numbers are equal rather than because anybody wrote a rule.
        ///
        /// And every rung is lost on death, which is what stops a bought Cosmic from
        /// simply deciding the match. It is a lead to hold on to, not a purchase.
        static let gearPrices: [Int] = [6, 12, 22, 40, 70]

        static let helmetPrices: [HelmetTier: Int] = [
            .common: gearPrices[0], .epic: gearPrices[1], .legendary: gearPrices[2],
            .mythical: gearPrices[3], .cosmic: gearPrices[4]
        ]

        static let blasterPrices: [BlasterTier: Int] = [
            .two: gearPrices[0], .three: gearPrices[1], .four: gearPrices[2],
            .five: gearPrices[3], .six: gearPrices[4]
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

        /// The least ground a wall has to enclose before it counts as a base.
        ///
        /// The only thing standing between free-form building and a nine-wall phone
        /// box. A three-by-three ring encloses one tile for eight blocks, which
        /// would be a third of the cost of a real base for all of the income, so
        /// there has to be a floor somewhere.
        ///
        /// Sixteen - a four-by-four room - because the generated plans enclose 25
        /// to 49 and the point of allowing any shape at all is that somebody can
        /// build SMALLER and stranger than the plan if they want to. Sixteen is
        /// meaningfully cheaper than the plan and still unmistakably a base. What
        /// stops small being strictly better is the chest count below: a room that
        /// size gets one chest where a seven-by-seven gets three, so building small
        /// buys you a quicker wall and less to put in it.
        static let minimumRoom = 16

        /// How many chests appear the moment a wall closes, by the size of the room
        /// it closed round.
        ///
        /// The plan is a random rectangle between five and seven tiles a side, so
        /// enclosed floor runs from 25 tiles to 49 - near enough double. One chest
        /// in a five-by-five is a furnished room; one chest in a seven-by-seven is
        /// somebody who has moved out. Paying by area means the big awkward base
        /// that took longer to wall in is also the one worth breaking into, which
        /// is the right way round: the reward for the work is that other people
        /// want what you built.
        ///
        ///     25-29 tiles   1 chest
        ///     30-44 tiles   2 chests
        ///     45+ tiles     3 chests
        static func chestsOnSeal(forRoomOf tiles: Int) -> Int {
            switch tiles {
            case ..<30: return 1
            case ..<45: return 2
            default:    return 3
            }
        }
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
        ///
        /// Ninety rather than a hundred and twenty. Two minutes was sized against
        /// bases that took most of that to close; they seal around the minute mark
        /// now that trips come round faster and carry more, so the last thirty
        /// seconds were not a breather, they were everybody standing about behind a
        /// finished wall with nothing to do. It is also most of why bombs FELT
        /// rare: for two of a five-minute match there were none, so the supply a
        /// player actually experienced was squeezed into the back three.
        static let bombGrace: Double = 90
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
        /// The band claims are scattered in, measured from the middle of the map.
        ///
        /// A band rather than a ring. Eight bases used to sit on one circle at fixed
        /// angles, shuffled between the teams - so every match had the identical
        /// octagon and the only thing that changed was which corner of it was
        /// yours. You learned the map once and knew it forever: where your
        /// neighbours were, how far the walk was, which way to run.
        ///
        /// Nineteen to twenty-seven keeps the two things that ring was protecting.
        /// Nobody gets the middle, which stays contested open ground with the
        /// densest loot on it; and nobody is exiled to a corner where no raider
        /// would ever bother walking. Between those two, everything moves.
        static let claimRadius: ClosedRange<Double> = 19...27

        /// How far round its own eighth of the map a claim may wander, as a share
        /// of that sector.
        ///
        /// Sectors rather than free placement, and this is what keeps the layout
        /// FAIR while making it different. Dart-throwing eight claims at a 64-tile
        /// map produces maps where three teams share a corner and one has the whole
        /// west side - which is a different match for each of them, and nobody
        /// chose to play an unfair one. One sector each means everybody has
        /// neighbours; the jitter inside it means you never know where.
        static let claimSectorJitter: Double = 0.32

        /// The least distance allowed between two claim centres, in tiles.
        ///
        /// Claims are nine wide, so fourteen leaves five tiles of ground between
        /// two walls - enough for a corridor, a crate and a fight in it. Relaxed a
        /// tile at a time if a map cannot be laid out at fourteen, which happens on
        /// about three maps in a hundred, and never goes below the floor.
        static let claimSpacing: Double = 14
        static let claimSpacingFloor: Double = 11

        /// How far a claim's centre must stay from the map's edge.
        static let claimMargin = 6

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
            // Cut right back, because death now takes everything and a generous
            // floor would hand most of it straight back. What is left is the
            // anti-spectator valve and nothing more: enough that somebody killed in
            // the last minute is not walking into gunfire bare-headed with no time
            // to do anything about it, and far short of a rebuild.
            //
            // The real floor is your own chest, which is the entire point. This one
            // exists for the player who has no base left to go back to - and it is
            // deliberately worse than what one trip home would give them.
            (0.60, .common, .two),
            (0.85, .epic,   .three)
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
        /// How hurt you have to be before a TAP on a healing slot spends it.
        ///
        /// Healing used to take two presses and a piece of knowledge: pick the slot,
        /// then find the button above the corner - and nothing on screen says that
        /// button belongs to the slot you picked. Under this threshold the tap does
        /// the thing, because there is exactly one reason anybody touches a bandage
        /// at forty per cent health.
        ///
        /// Not always, and the line is where the answer stops being obvious. Above
        /// seventy per cent you might be topping up before a fight, saving the
        /// medkit, or about to sell it - so the tap still picks it out and the
        /// button still spends it. Below, hesitating is the expensive thing.
        static let tapHealBelow: Double = 0.7

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
        /// tokens is three tokens not spent on a Legendary, and a bot would have
        /// found that Common in a crate within the minute anyway - so below this
        /// line spending is worse than saving. Above it there is no other way up.
        ///
        /// Epic now rather than Rare, and it is the same line in the new ladder's
        /// terms: the late crate band tops out at Legendary, so Legendary is the
        /// first rung worth a token.
        static let buysHelmetsAbove: HelmetTier = .epic
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
        /// The arithmetic is worth stating because this is the single number that
        /// decides how hard the game is. The noise is uniform across the spread and
        /// the target is 0.9 tiles wide, so an aim-limited hit rate is 0.45 /
        /// spread: 54% at 0.83, 45% at 1.0, 35% at 1.3.
        ///
        /// 1.3, up from 0.83. It went DOWN to 0.83 when the complaint was that the
        /// game was too easy, and that was the right move against the game as it
        /// was then - but a bot at 54% is a bot that wins nearly every exchange it
        /// starts, and everything since has quietly made losing one cost more:
        /// death takes all your gear now, not two rungs of it.
        ///
        /// Fixed the other way round, this is also the number to be most careful
        /// with. Doubling a bot's accuracy does not make a game harder, it makes it
        /// unfair - the player still has to be able to cross open ground - and the
        /// same is true in reverse, so this is a third off rather than a half.
        static let aimSpread: Double = 1.3

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

        /// How far ahead a bot looks for gas, and how hard it swerves when it sees
        /// some. Standing in a cloud overrides the heading entirely; seeing one
        /// coming only bends it, so a bot skirts a cloud rather than abandoning
        /// wherever it was going.
        static let gasLookAhead: Double = 3.5
        static let gasSwerve: Double = 0.6

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
        /// counts for more than any single item - it is the only thing in a base
        /// that is worth raiding even when the chests are bare.
        static let chestItemWorth = 10

        /// What a standing machine adds to a base's worth as a target.
        ///
        /// Two and a half items, and most of that is the DENIAL rather than the
        /// take. Wrecking one pays 40 points and 5 tokens, and the bank standing
        /// beside it is a handful more - but what it really does is remove the
        /// owner's best income until they rebuild, and that is worth crossing a map
        /// for whatever the chests hold.
        ///
        /// Unchanged when the wrecking reward was cut from 25 tokens to 5, because
        /// the reward was never the reason: this number is about how attractive a
        /// base LOOKS to a raider, and a base with a machine in it is exactly as
        /// worth visiting as it was.
        static let arcadeWorth: Double = 25

        /// What a base gains as a target for every second nobody has touched it,
        /// and the most it can gain.
        ///
        /// The anti-turtle clock, and it exists because of a specific hole: a
        /// player's chests are not stocked for them - a player's chest is theirs to
        /// fill - so a player who never stores anything owns a base with nothing in
        /// it, and the raid test could not see a reason to go. Bots stock their own
        /// chests and restock them, so bots raided each other all match and the
        /// player was never once broken into.
        ///
        /// Making empty chests attractive would have been the wrong fix - there is
        /// genuinely nothing in them. What IS true is that a base nobody has
        /// touched for two minutes belongs to somebody who has been building,
        /// banking and earning unopposed, and that is worth a bomb whatever is in
        /// the chest. Half a point a second, capped at 60: after two quiet minutes
        /// a base is worth six items more than it was, which will pull a raider
        /// across most of a map.
        ///
        /// It applies to everybody. Bot bases get raided constantly and keep
        /// resetting theirs, so in practice the pressure accumulates on whoever is
        /// being left alone - which is the player, and which is the point.
        static let raidPressurePerSecond: Double = 0.5
        static let raidPressureCap: Double = 60
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

        /// How far a bot will break off what it is doing for a piece of gear on the
        /// ground that beats what it is holding.
        ///
        /// Shorter than lootSearchRange, and that is the point: this is not "go
        /// looting", it is "do not walk past that". A bot deciding what to do next
        /// weighs gear against building, raiding and everything else, and by the
        /// time the question reaches the bottom of the list where collecting lives,
        /// it has usually already committed to an armful of walls - so a Blaster 5
        /// lying eight tiles away would sit there until it expired.
        ///
        /// Fourteen tiles is about three seconds of walking, against a drop that
        /// lies on the grass for ten. Far enough to catch anything a bot could
        /// plausibly have seen, short enough that nobody crosses a map for it and
        /// arrives to find it gone.
        static let upgradeSearchRange: Double = 14

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
        ///
        /// Shortened along with the bomb supply, and the two have to move together.
        /// Bombs are the key to a base, so making them commoner without making
        /// bases go up faster does not produce more raiding - it produces bases
        /// that are never finished, which is the same as no bases, which is nothing
        /// to raid. The gap is what balances the two: walls have to arrive faster
        /// than bombs take them away.
        /// Down to 3...5. Walls are FREE - there is no material, no cost, nothing
        /// a bot has to go and fetch first - so the only thing that was ever making
        /// a base take four minutes to go up was this timer, and a bot dawdling
        /// over a job that costs it nothing is a bot that looks like it forgot.
        static let urgeInterval: ClosedRange<Double> = 3...5

        /// Walls laid per trip.
        ///
        /// More walls per trip rather than more trips: the walk home is what a trip
        /// actually costs, so a bigger armful finishes the base faster without
        /// eating into the time a bot spends out on the map looting.
        /// 12...16, up from 8...12. The walk home is what a trip actually costs,
        /// so a bigger armful finishes the base sooner without adding a single
        /// extra commute - and with the urge timer shortened as well, the two
        /// together roughly halve the time a base spends unfinished.
        static let blocksPerVisit: ClosedRange<Int> = 12...16

        /// Seconds between individual walls. Quick enough to read as somebody
        /// laying a run of them, slow enough that you can still see it happen.
        /// 0.22, quicker but still one at a time. This is the number to be careful
        /// with: the run of blocks appearing is the only part of base-building
        /// anybody actually watches, and at much under a fifth of a second it stops
        /// reading as somebody laying them and starts reading as a wall being
        /// switched on.
        static let placeInterval: Double = 0.22

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
        /// Quicker again now that every base has something in it worth breaking
        /// into from the first minute: holes are commoner, so a hole has to be a
        /// wound rather than a condition.
        static let repairInterval: Double = 0.08

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
        ///
        /// Raised with the bomb supply. More bombs means more holes and bigger
        /// ones, and an armful sized for yesterday's hole is how a base ends up
        /// permanently half open - at which point nobody needs a bomb to get in and
        /// the whole exchange stops being a raid.
        /// Walls laid per trip on a base that has never been shut.
        ///
        /// The biggest armful there is, because the first wall is the only one
        /// where finishing it is worth more than anything else the bot could be
        /// doing - until it is up there is no chest, no machine, no income and
        /// nothing for anybody to raid, which is three quarters of the game
        /// waiting on a job that costs nothing to do.
        ///
        /// A plan is 24 to 32 tiles, so at this size a base is two trips.
        static let blocksWhenUnsealed: ClosedRange<Int> = 16...22

        static let blocksWhenBreached: ClosedRange<Int> = 16...20

        /// Walls laid per trip by a bot that is behind.
        ///
        /// Roughly double the usual armful, and this is the half of catching up
        /// that does the work. Simulated, the bypass alone barely moved anything -
        /// because the urge timer was never what was holding a laggard back. Being
        /// interrupted was. A bot that is pulled away from home constantly gets few
        /// chances, so the fix is not more chances, it is making each one count.
        static let blocksWhenBehind: ClosedRange<Int> = 18...24
    }

    /// The stink bomb, and what it leaves behind.
    ///
    /// Priced as a way of taking GROUND rather than as a second way of taking
    /// health. Stand in it for the full nine seconds and it costs about four fifths
    /// of a bar - whatever helmet you are wearing - which is enough that nobody
    /// walks through casually and still short of ending your match on its own. What it is really for is
    /// making two tiles unusable: a doorway, the gap you were about to break
    /// through, or the ground under somebody who has nowhere good to go.
    enum Stink {
        /// How far the cloud reaches, in tiles.
        ///
        /// 2.9, up from 2.2, which is six tiles across.
        ///
        /// The size was only half of why the first one felt small - it was drawn as
        /// a soft gradient, and a shape with no edge reads smaller than it is - but
        /// only half. At six tiles it covers a doorway and the ground either side,
        /// which is the least that "taking ground" can mean.
        ///
        /// Not larger, and the number that decides it is the BASE: a claim is nine
        /// tiles across, so this closes two thirds of the width of somebody's home.
        /// A cloud that swallowed a whole base would not be a way of taking ground,
        /// it would be a way of ending a match from outside the walls.
        static let radius: Double = 2.9

        /// Seconds it stands for, and how long it takes to billow out and to thin
        /// away at the end. A cloud that arrived and vanished instantly would be a
        /// trap rather than a hazard - you can see this one coming and you can see
        /// it going.
        static let duration: Double = 9
        static let spread: Double = 0.45
        static let fade: Double = 1.6

        /// How thick it has to be before it bites, on the same nought-to-one scale
        /// the renderer draws. Tying both to one number is what stops gas you can
        /// barely see from still taking your health.
        static let bitingDensity: Double = 0.35

        /// Damage per dose as a SHARE of the victim's health bar, and seconds
        /// between doses.
        ///
        /// A share rather than a flat six, and this is the whole reason nobody had
        /// any use for a stink bomb. Six a dose was written when a health bar was a
        /// health bar; the helmet ladder runs to 3.57 times a bare head, so the
        /// same cloud that took half a bar off somebody bare-headed took a seventh
        /// of one off a Cosmic. It got weaker exactly as the match got more
        /// dangerous, which meant that by the time you had a stink bomb and a
        /// target worth using it on, it did nothing to them.
        ///
        /// Seven per cent a dose, every 0.7 seconds. Over a full stay in a cloud
        /// that is about 80% of a bar - against ANY helmet - and around 15% for
        /// walking through one. So the shape it always wanted is finally the shape
        /// it has: crossing costs something you can shrug off, standing in it is a
        /// decision you regret in instalments, and being held in it is fatal.
        ///
        /// Deliberately still short of a kill on its own. The first pass at this
        /// was eight every half second, and the arithmetic caught it before anybody
        /// played it: a cloud that kills a full-health player outright is not a
        /// piece of ground to avoid, it is a death sentence with a radius. 80% is
        /// the number that makes a stink bomb decisive WITH one shot behind it and
        /// never on its own.
        static let doseShare: Double = 0.07
        static let doseInterval: Double = 0.7
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
        ///
        /// Up from 0.08 because the helmet ladder lost two rungs, and left alone
        /// that would have quietly dropped the best helmet in the game from an 80%
        /// chance of surviving its owner to 67% - the top of the ladder no longer
        /// reaching the cap simply because there were fewer steps up to it.
        ///
        /// The number is what makes both ladders top out AT the cap, and it can be
        /// one number for both because they are finally the same shape. A helmet
        /// spans five droppable rungs, Common through Cosmic; a blaster spans five
        /// droppable rungs, Blaster 2 through Blaster 6. Nobody starts holding a
        /// Common and everybody starts holding a Blaster 1, which is why the two
        /// ladders have different lengths on paper and the same length here. The
        /// old 0.08 hid that: it was sized for the helmet ladder and left the best
        /// blaster in the game surviving a death two thirds of the time while the
        /// best helmet managed four fifths, for no reason anybody had chosen.
        static let chancePerTier = 0.115

        static let maximumChance = 0.80


        /// The share of your unspent tokens that spills on the ground when you die.
        ///
        /// Half, and it SPILLS rather than evaporating. Tokens that simply vanished
        /// would be a punishment nobody sees land - a number in the corner quietly
        /// halving while you are watching the respawn clock - and a punishment you
        /// cannot see teaches nothing. A purse on the grass is legible from both
        /// ends: the person who killed you gets paid for it, and you get to watch
        /// somebody else pick your money up.
        ///
        /// Half rather than all of it. The full wipe is the version worth trying if
        /// this is not enough - it is this one number - but it has a failure mode
        /// worth naming first: with nothing left to lose, the correct play after
        /// every death is to spend down to zero the moment you have five tokens,
        /// and the ladder stops being something anybody saves for. Half keeps
        /// saving towards a Cosmic a real option and still makes carrying forty
        /// tokens into a fight a decision rather than an oversight.
        ///
        /// Points are deliberately NOT touched. Score is the win condition, and
        /// taking it away on death compounds in the wrong direction: whoever is
        /// losing dies most, so they would lose most score, and the match would be
        /// decided in its first two minutes. It also punishes fighting, in a game
        /// whose whole second half is meant to be fighting.
        static let tokenShare: Double = 0.5

        /// The odds that one item off a carried healing stack lands on the ground.
        ///
        /// ONE item, not the stack: enough that winning a hard fight tops you up a
        /// little, not enough that a body is a shop. You spend supplies winning a
        /// fight, and before this you always walked away poorer than you arrived,
        /// however well you shot.
        /// Seven in ten, up from a half.
        ///
        /// The half was arithmetic that read as stinginess. A bot's bag is rarely
        /// full - it spends its supplies staying alive - so with two occupied slots
        /// a coin flip each, a body handed you nothing about a quarter of the time
        /// and one thing most of the rest. The fight that earned it had taken ten
        /// seconds and most of a health bar. At seven in ten a kill nearly always
        /// pays something back, which is the feeling the rule was written for.
        static let healingChance = 0.7

        /// The odds that one bomb, or one stink bomb, comes off a body.
        ///
        /// Supplies rather than gear, so the same "one item, not the stack" rule
        /// applies. A bomb was the one thing a kill never yielded, which made
        /// killing a raider on your own doorstep oddly hollow: they had walked
        /// across the map to break your wall open, and the tool they were going to
        /// do it with evaporated with them.
        ///
        /// Slightly under healing, because a bomb is worth more than a bandage and
        /// this is the supply line for raiding: at a half you could keep yourself
        /// in bombs by winning fights, which would make the shop's bomb price - and
        /// the crate rows that ration them - decoration.
        static let suppliesChance = 0.55

        /// The odds that a chest or a machine somebody was carrying survives them.
        ///
        /// Lower again, and the lowest of the three on purpose: a machine in a bag
        /// is the most valuable object in the game and there are one or two on the
        /// whole map. Finding one on a body should be a story somebody tells, not a
        /// thing that happens on a Tuesday - but it has to be POSSIBLE, because
        /// killing somebody who is carrying one and watching it vanish is the game
        /// quietly deleting the best thing on the map.
        static let carriedStructureChance = 0.35

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

    enum Perks {
        /// How long a perk runs.
        ///
        /// Nine seconds, down from twelve and fifteen, and the cut is the price of
        /// putting all four powers in one bottle. A perk is now the strongest thing
        /// you can be holding, and the answer to "how do you keep that fair" is
        /// time rather than strength - a short window you have to spend well reads
        /// as a decision, where a long weak one reads as a status effect you
        /// happened to be wearing.
        ///
        /// Nine is about one fight at this game's ranges, which is the length the
        /// perk should be: long enough to decide the fight you drank it for, too
        /// short to still be running for the next one.
        static let duration: Double = 9

        /// Seconds between portions of health.
        ///
        /// Portions, not a trickle, for the third time in this project and the same
        /// reason as home recovery and gas damage: every point of healing makes the
        /// screen react, so sixty a second is not a warm glow, it is a strobe.
        ///
        /// A second flat now rather than 1.25. Over a nine-second perk that is nine
        /// beats instead of seven, and beats are what makes healing legible - the
        /// bar has to visibly step up often enough that you can tell it is the perk
        /// doing it and not luck.
        static let tickInterval: Double = 1

        /// Share of a full health bar handed back per beat.
        ///
        /// 5% nine times is about 45% of a bar across the perk, against the 78% the
        /// old regeneration paid over fifteen seconds. Barely more than one medkit,
        /// on purpose: this is no longer the whole item, it is one quarter of it,
        /// and it now arrives alongside thicker skin, which is the same defence
        /// bought twice. Stacked at the old rate the two together simply refused to
        /// let a fight resolve.
        static let healPortion: Double = 0.05

        /// How much faster you move.
        ///
        /// Down from a third again to about a fifth. Enough to be the reason you
        /// reach the wall first or break off a fight you are losing, and no longer
        /// enough to make everyone else look like they are standing still - which
        /// is what a third again looked like once it came free with the damage.
        static let speedBoost: Double = 1.22

        /// How much harder your shots hit.
        ///
        /// Down from two fifths to a quarter. At mid tiers that is still often a
        /// shot fewer to a kill, which is the whole point of it, but it no longer
        /// combines with the resistance below to win a duel outright against
        /// somebody playing better than you.
        static let damageBoost: Double = 1.25

        /// The share of incoming damage you still take.
        ///
        /// Everything, not only bullets - a bomb that goes off beside you, a lungful
        /// of gas. "Resistant to bullets" is what it is FOR, but a perk that let a
        /// blast through at full strength would be a perk with a footnote, and the
        /// only way anybody would ever learn the footnote is by dying to it.
        ///
        /// 0.72, up from 0.6. On its own, 0.6 was a duel-winner; arriving with the
        /// healing, the speed and the damage it was a different game for twelve
        /// seconds. The rule of thumb across all four of these numbers is that
        /// every one of them had to become something you NOTICE rather than
        /// something you win with, because you get all four.
        static let damageTaken: Double = 0.72
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

        /// How heavily a machine sits in a rare crate's table.
        ///
        /// Better than one rare crate in four now, with rare crates at one in eight
        /// - so a match turns up three or four machines between eight teams, where
        /// it used to turn up one.
        ///
        /// This has been raised twice and the reasoning changed the second time.
        /// Scarcity was originally the point: the most valuable thing anybody can
        /// own, one or two on the map, a story when you found one. What playing it
        /// showed is that a machine is not really a PRIZE, it is furniture - it is
        /// the thing that makes a base worth breaking into, and at one or two a
        /// match seven bases out of eight had nothing in them but a chest somebody
        /// had already emptied. Raiding needs somewhere to raid more than machines
        /// need to be rare.
        ///
        /// Four or five is still not one each. Whoever has one has something worth
        /// defending, everybody else has somewhere worth going, and that gap is the
        /// part that matters.
        /// 150, and it is no longer the only source - see the arcade rows in the
        /// ordinary mid and late bands. Between them a map turns up about four and
        /// a third machines for eight teams, against one and a half before, so most
        /// bases have one by the end and none of them start with one.
        ///
        /// Still worth being the rare crate's headline. Whoever opens one gets the
        /// machine early, which is the whole difference between owning the economy
        /// and catching up with it.
        static let rareArcadeWeight = 150

        /// Share of crates on the map that are the good ones.
        ///
        /// One in eight. At one in six they were everywhere, and a thing you see
        /// constantly is not rare however it is drawn - the glow stopped meaning
        /// anything within a minute. At one in fourteen, where this began, a whole
        /// match turned up under one machine between eight players and the economy
        /// those machines drive never started. One in eight is the closest this can
        /// sit to "everywhere" while a glowing crate is still worth changing
        /// direction for: a map of forty holds five.
        ///
        /// Rolled per crate rather than counted out, so no two maps hold the same
        /// number.
        static let rareShare: Double = 0.125

        /// How heavily ONE power-up sits in a crate's table, by how far the match
        /// has run.
        ///
        /// The BASE weight, doubled for the blue pair in LootTable - see
        /// Perk.rarity - so the arithmetic is worth writing down. Against band
        /// totals around three hundred, the six shares together come to roughly one
        /// crate in nineteen early and one in ten late. A particular blue perk is
        /// about one crate in forty, a particular purple one about one in eighty.
        ///
        /// That is the shape variety wants: a power-up is a normal part of a match
        /// rather than an event, you hold each of them often enough to learn what
        /// they do, and the two that decide a fight outright stay scarce.
        ///
        /// This is the dial for all four. Halve it and perks become a story you
        /// tell about a match; double it and they are part of the loadout.
        static func perkWeight(at progress: Double) -> Int {
            switch progress {
            case ..<0.35: return 3
            case ..<0.70: return 4
            default:      return 5
            }
        }

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
        ///
        /// Thirteen rather than ten, because ten was a clock on the WRONG thing.
        /// A kill usually arrives in the middle of a fight with somebody else, and
        /// the three seconds spent finishing that fight were coming out of the time
        /// left to collect - so the reward for winning a hard fight was routinely
        /// expiring while it was still being won.
        static let itemLifetime: Double = 13

        /// How long before that it starts flashing, so nobody watches a drop
        /// vanish without warning.
        static let itemWarningTime: Double = 4

        /// Seconds before an opened crate comes back, in the same spot. Without
        /// this the map is stripped bare a minute into a match.
        static let respawnDelay: Double = 45
    }

    enum Chest {
        /// How many items burst out of somebody else's chest when it is cracked.
        ///
        /// A raided chest is not opened, it is BROKEN - see ChestSystem.crack. So
        /// this is not "how much can you carry away", it is how much of what was in
        /// there survives being smashed. The rest is gone, for the same reason a
        /// lootbox does not leave a pile: a container that gave up everything would
        /// make one raid worth four crates and turn the rest of the map into
        /// scenery.
        ///
        /// Two, and the number is deliberately smaller than a fresh chest holds.
        /// The victim always loses more than the raider gains, which is what makes
        /// a raid an attack rather than a transfer - and is the reason defending
        /// one is worth doing.
        static let raidSpill = 2

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
        ///
        /// Eleven rather than sixteen, now that a stripped chest survives instead
        /// of being destroyed. The two changes are one decision: what makes raiding
        /// keep happening is bases being worth a second visit, and both the old
        /// rules pushed the other way - one removed the chest, the other made the
        /// wait long enough that nobody would have come back for what was in it.
        static let restockAfterRaid: Double = 8

        /// Seconds between a raided bot chest putting one item back.
        ///
        /// Slow enough that emptying one still means something - a raider gets the
        /// lot and the next caller finds bare boards - and quick enough that the
        /// same base is worth a second visit later in a match.
        ///
        /// Halved to 14, and the honest note is that this number was never the one
        /// doing the damage: the restock clock was being reset every frame while
        /// the wall was open, so a raided chest waited a full interval AFTER the
        /// repair no matter what this said. With that fixed, 28 would have been
        /// about right - but the raid loop wants to turn over faster than that, so
        /// it is 14 and the first tick after a raid puts back two items rather than
        /// one. A robbed base is worth calling on again about half a minute later
        /// instead of ninety seconds later, which is the difference between a map
        /// with places to break into and a map of empty rooms.
        static let restockInterval: Double = 14

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
                (.bandage, 58), (.medkit, 20), (.bomb, 26), (.stink, 10),
                (.helmet(.common), 11), (.helmet(.epic), 6),
                (.blaster(.two),   11), (.blaster(.three), 6)
            ]),
            (0.35, [
                (.bandage, 58), (.medkit, 20), (.bomb, 26), (.stink, 10),
                (.helmet(.common), 6), (.helmet(.epic), 11),
                (.blaster(.two),   11), (.blaster(.three), 6)
            ]),
            (0.65, [
                (.bandage, 58), (.medkit, 20), (.bomb, 26), (.stink, 10),
                (.helmet(.epic), 11), (.helmet(.legendary), 6),
                (.blaster(.three), 11), (.blaster(.four), 6)
            ]),
            (0.85, [
                (.bandage, 58), (.medkit, 20), (.bomb, 26), (.stink, 10),
                (.helmet(.legendary), 11), (.helmet(.mythical), 6),
                (.blaster(.four), 11), (.blaster(.five), 6)
            ])
        ]

        /// The band the match is currently in.
        static func stockTable(at progress: Double) -> [(item: ItemType, weight: Int)] {
            stockTables.last { progress >= $0.from }?.rows ?? stockTables[0].rows
        }

        /// Footprint in tiles, shaped to the artwork rather than the other way
        /// round: the picture is 462 x 399 of opaque pixels, so 1.158 wide to tall,
        /// and 0.95 x 0.82 is that shape. ChestRenderer sizes the sprite so the
        /// chest covers exactly this - the chest you see is the chest you bump into.
        ///
        /// It was 1.05 x 0.70, a hair under 3:2, because the art used to be. When
        /// the art was redrawn taller the box did not follow and every chest on the
        /// map was squashed by a third. Re-export the chest at a different shape and
        /// these two numbers are what needs to change; nothing else measures it.
        ///
        /// Slightly narrower than it was, deliberately. A chest is furniture in a
        /// room bots have to walk around, and they have form about getting wedged on
        /// their own - taller was unavoidable, wider was not.
        static let size = Vec2(x: 0.95, y: 0.82)

        /// How far past your own hitbox you can reach to open one. Small, because a
        /// chest is solid and you are already touching it when you are beside it.
        static let openReach: Double = 0.3
    }

    enum Arcade {
        /// Paid for blowing up somebody's machine.
        ///
        /// 5, down from 25.
        ///
        /// It was priced when a machine was a thing one or two players on the map
        /// had - "about a quarter of a match's income in one go" was the note, and
        /// that was true. Every sealed base is issued one now, so the same lump sum
        /// was payable eight times a match, and wrecking machines became 59% of what
        /// a raid was worth. A raid should pay for what you carry out of it.
        ///
        /// It is not zero, because breaking one still has to beat ignoring it. Five
        /// is a bandage - enough to be worth the seconds it costs, nowhere near
        /// enough to be the reason you came.
        static let destroyedReward = 5

        /// How much shooting a machine takes to break.
        ///
        /// 520, doubled, because at 260 a Blaster 6 finished one in 1.6 seconds and
        /// the whole "raiding is too easy" complaint lived in that number. The note
        /// under the old value claimed it was a deliberate act that gave the owner
        /// a window to come home and make you regret it. It was not. It was two
        /// seconds.
        ///
        ///     blaster        at 260      at 520
        ///     Blaster 1     6.6s        19.2s
        ///     Blaster 3     2.9s         8.3s
        ///     Blaster 6     1.6s         2.9s
        ///
        /// A defender twenty tiles out needs about seven seconds to get home, so
        /// this is the number that decides whether the trip is worth starting. Now
        /// it is: anybody below the top of the ladder has to commit real time,
        /// standing still, inside somebody's base, to break their machine - and a
        /// starter blaster should not be doing it at all, which nineteen seconds
        /// says clearly enough.
        ///
        /// It also restores the choice the old comment claimed and did not deliver:
        /// the seconds spent wrecking are seconds not spent on the chest, and both
        /// are on the clock the owner is walking home along.
        static let health = 520

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
        /// The LARGER half of the answer now, which is a reversal. It used to be
        /// the smaller one: a faster interval only helps somebody who visits often
        /// enough to outpace it, while the bank paid everybody who came home at all,
        /// so the pile was doing the work.
        ///
        /// That was the problem. A pile is collected whole on every visit, so income
        /// scaled with nothing but how often you walked home, and with a machine now
        /// standing in every sealed base that came to more tokens than anybody could
        /// spend. The bank is smaller and this is slower in absolute terms but a
        /// bigger share of the difference - a third faster than an open machine, at
        /// 2.4 seconds a token against 3.2 - so the reward for owning one goes to
        /// whoever is actually around to work it.
        static let sealedInterval: Double = 0.75

        static let tokenValue = 1

        /// A golden token, and how often one comes out instead of an ordinary one.
        ///
        /// Five, down from ten, and the number it is now equal to is the point: the
        /// first rung of the gear ladder costs five. One golden token is exactly one
        /// step up, which is a relationship a player can feel without being told,
        /// where ten was "most of a rung and change" and meant nothing in
        /// particular.
        ///
        /// Ten was also too much money. It made the expected value of a payout 1.72
        /// tokens against a face value of 1, so most of what the arcades paid came
        /// from the windfall rather than from the machine - and the windfall is
        /// rolled per token, so it favoured whoever stood at a cabinet longest. At
        /// five the expected value is 1.32, which narrows the gap between playing
        /// the match and guarding a machine by about a fifth. That gap is the thing
        /// this economy has always had to watch: an arcade is meant to reward
        /// holding ground, not sitting on it.
        ///
        /// The chance is unchanged at one payout in twelve or so, which is the
        /// third value it has had and the one between the other two. One in fifteen
        /// was a thing you heard about; one in ten was often enough that a golden
        /// token stopped being a find and became part of the rate. Halving the
        /// PRIZE rather than thinning the odds keeps it a thing you spot on the
        /// grass and change your route for, which is the whole reason it exists.
        static let goldenValue = 5
        static let goldenChance = 0.08

        /// A jackpot: how long one lasts, how often each map machine rolls for one,
        /// and the chance it takes.
        ///
        /// Only the map's machines, and that asymmetry is the design. The machine
        /// in your base pays you for staying home; a jackpot is the opposite offer -
        /// drop what you are doing, cross open ground, and stand in the middle of
        /// the map next to a thing that is loudly announcing itself. Two ways to
        /// earn that want opposite behaviour out of you is worth more than either
        /// of them being slightly better.
        ///
        /// Rolled every twenty seconds by each of five machines at one in eight.
        /// Nine jackpots across a match, one somewhere every thirty-three seconds,
        /// and a jackpot running somewhere about a quarter of the time.
        ///
        /// That last figure is the one to tune against, and it is not about
        /// fairness but about meaning: with five machines and an eight second
        /// jackpot, much past a quarter leaves one going at all times, and a thing
        /// that is always happening stops being an event and becomes the weather.
        /// At 29% it was starting to feel like the weather.
        static let jackpotDuration: Double = 8
        static let jackpotInterval: Double = 20
        static let jackpotChance = 0.12

        /// What a jackpot does to the two numbers that decide a machine's output.
        ///
        /// BOTH, and this is the lesson the sealed-base bank taught the hard way:
        /// the cap binds, not the rate. A machine that paid four times as fast but
        /// still stopped at four uncollected would produce exactly four tokens and
        /// a lot of waiting, which is not a jackpot, it is the same machine with
        /// impatience. Lifting the ceiling with the rate is what turns it into a
        /// pile worth sprinting for.
        static let jackpotRate = 0.22
        static let jackpotBank = 8

        /// How many of its own tokens a machine will let pile up before it stops.
        ///
        /// This is the anti-camping valve, and it is the only reason standing at a
        /// machine does not beat moving between them. At three, a machine left
        /// alone is full in eighteen seconds and then pays nothing.
        static let maxUncollected = 3

        /// And how many it will let pile up behind a wall that is standing.
        ///
        /// Part of why you build a base, and it used to be most of it. A machine in
        /// the open stops at three, because standing at one is not supposed to beat
        /// moving between them; one behind your own shut wall banks five, because
        /// nothing is going to walk off with them.
        ///
        /// 5, down from 8. Still more than a machine in the open holds, because a
        /// base is still meant to be the better place to own one - but the pile is
        /// no longer where most of that advantage lives. It moved to the two things
        /// that cannot be carried off in one visit: the rate, which is a third
        /// faster behind a shut wall, and the shelf life, where a token keeps for
        /// 45 seconds against 10 in the open.
        ///
        /// The pile was the problem. A bank of 8 refilling in 16 seconds is a
        /// machine that pays out its whole cap between visits however often you
        /// call, so income scaled with nothing but how often you walked home.
        static let sealedUncollected = 5

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
