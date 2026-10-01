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
        ///
        /// Except that it did not: 55 against a kill's 100, for a chain of work a
        /// kill does not require. 90 puts a raid where that sentence always said it
        /// was, just under a kill and well clear of everything else.
        static let chestRaided = 90

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

        /// The same for a mini, on the same ratio as everything else about it.
        ///
        /// Not the same number for both. A machine's destruction score is the one
        /// thing a raider gets for certain - the chest may be empty, the owner may
        /// come home - so paying the same for breaking the small one would quietly
        /// make the small one the better target, being cheaper to shoot apart.
        static let miniArcadeDestroyed = 24

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
        /// Paid to whoever got the kill, ON TOP of what the victim was carrying.
        ///
        /// That second half is new and is why this number is half what it was. A
        /// kill used to pay this bounty plus half the victim's purse; it now pays
        /// this plus ALL of it - see Drops.tokenShare - so the flat fee is stacked
        /// on a variable reward that roughly doubled underneath it without anybody
        /// touching the fee. Against a victim carrying fifteen, a kill was paying
        /// twenty-six.
        ///
        /// Four, plus a token a tier, so a bare kill on somebody with nothing still
        /// clears the cheapest rung in the shop at six. What it no longer does is
        /// pay for two rungs before the purse is even counted.
        ///
        /// REDUCED (token pass): 4 -> 3.
        static let perKill = 3

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
        /// REDUCED (token pass): 4 -> 3.
        static let perRareLootbox = 3

        /// Tokens for cracking somebody's chest. Still more than a rare crate,
        /// because a rare crate does not shoot back.
        ///
        /// 24, and the old note explaining why it was 3 is worth keeping as the
        /// mistake it was: "the haul out of a chest is the ITEMS, so this is a tip
        /// on top rather than a wage." True as far as it goes, and it left a raid
        /// paying less than a fifth of what a KILL pays - 14 - for a chain of work
        /// that starts with finding a bomb and ends with standing in somebody's
        /// base while they shoot at you.
        ///
        /// Tokens are the gear ladder, so this is not a tip: it is the other way a
        /// raid can pay off when the chest turns out to be full of bandages. At 24
        /// a raid is most of a helmet, which is what makes the trip worth planning
        /// rather than worth taking if you happen to be passing.
        ///
        /// REDUCED (token pass): 24 -> 15. Still the best-paying single act, but
        /// no longer most of a helmet in one go.
        static let perChestRaided = 15
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
            .arcade(.full): 24,
            .arcade(.mini): 14,
            // Priced with the mini machine, the thing it is found beside and worth
            // about the same to a base.
            .turret: 16,

            // The power-up. Never on the shelf - the whole point of a perk is that
            // it is found - but the shop still makes an offer for one, because
            // nobody decides for the player which of their things are junk.
            //
            // The ball's row is unreachable today: it is not obtainable, so it
            // cannot be in a bag to be sold out of one. Left in place with the rest
            // of what it owns - see Perk.isObtainable.
            //
            // Kept deliberately low against what it does. At a fifth back that is
            // about four tokens, roughly a bandage, and it should stay there: the
            // day selling a perk is worth more than drinking one, the strongest
            // item in the game turns into a coin, which is the opposite of finding
            // something.
            .perk(.overdrive): 22,

            // Fourteen for the singles. Not far under the disco ball, because the
            // floor here is set by the same worry: the day selling a perk beats
            // drinking one, the best items in the game turn into coins. At a fifth
            // back that is under three tokens, which is not a strategy.
            .perk(.strength): 14,
            .perk(.speed): 14,
            .perk(.regeneration): 14
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
        /// The most of each piece of furniture one base may hold.
        ///
        /// Caps rather than costs. Uncapped, a well-run base filled up with
        /// chests, machines and guns until it was a fortress printing money, and
        /// the player who got there first had nothing left to want. Two of each
        /// keeps a base a set of choices - which two spots, which machines - and
        /// keeps something worth raiding in every base rather than a vault.
        ///
        /// Minis and full cabinets both count towards the machines.
        static let maxChests = 2
        static let maxTurrets = 2
        static let maxArcades = 2

        /// How many berths - spots an actor could stand, see World+Footing - a
        /// respawn needs to be able to reach before it counts as somewhere you can
        /// move from. Six is a little room, not a corridor.
        static let spawnRoom = 6

        /// How far past the claim's edge a respawn will look for room when the
        /// base itself has none, in tiles.
        static let spawnSearchMargin = 4

        static let sealed = 60
        /// REDUCED (token pass): 8 -> 4.
        static let sealedTokens = 4
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
            default:    return 3   // held to Base.maxChests by World.furnish
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
        ///
        /// Thirty now, for the same reason taken further: ninety seconds was nearly
        /// a third of the match with no bombs anywhere, and then a flood once they
        /// arrived. Thirty seconds lets them start turning up early, and
        /// bombRampEnd keeps that start a trickle rather than a flood - nobody
        /// has a wall worth blowing open yet anyway.
        static let bombGrace: Double = 30

        /// When the bomb supply reaches full strength, in seconds.
        ///
        /// From bombGrace to here a crate's bomb row climbs from bombStartShare
        /// of its weight to all of it, so the supply grows in rather than
        /// switching on. The bots' free top-up waits for this too, which keeps
        /// their raiding starting where it always has.
        static let bombRampEnd: Double = 90

        /// How much of its weight the bomb row carries the moment bombs start.
        static let bombStartShare: Double = 0.35
    }

    enum Map {
        /// Fifty-six a side, down from sixty-four.
        ///
        /// Not a balance change by itself - it is a TRAVEL change, and everything
        /// it does follows from that. Area drops by a quarter, crossing the map
        /// falls from about seventeen seconds to fifteen, the walk to a neighbour's
        /// wall gets a seventh shorter, and the slice of the map a phone can show
        /// at once goes from seven per cent to nine. Nobody is as far away as they
        /// were, which means more of the match happens where somebody can see it.
        ///
        /// Everything measured per unit of ground is scaled with it rather than
        /// left to get denser by accident - treePatchCount and lootboxCount below,
        /// and claimRadius and claimSpacing further down, which had to move or the
        /// eight claims would simply have clamped themselves against the edge. The
        /// map machines are the one exception and are left at four: they are
        /// contested landmarks rather than scenery, and a quarter fewer jackpots is
        /// an economy change wearing a map change's clothes.
        static let width = 56
        static let height = 56

        /// How many tree clumps to try to place. Placement can fail when a spot is
        /// already taken, so treat this as a target rather than a guarantee.
        /// Thirty-five, down from forty-five with the map, so cover stays exactly
        /// as thick per tile of ground as it was.
        static let treePatchCount = 35

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
        /// Eighteen to twenty-three, scaled with the map. This HAD to move: the
        /// band is measured from the middle, so on a 56-tile map the old outer
        /// radius of twenty-seven put a claim eight tiles past what claimMargin
        /// allows, and all eight would have clamped flat against the edges - one
        /// fixed octagon again, which is the exact thing the band replaced.
        ///
        /// Simulated over three thousand maps, this layout is better behaved than
        /// the one it replaces: 3.6% of maps need the spacing relaxed against
        /// 4.9% before, none ever reach the floor, and the outermost claim
        /// overshoots the clamp by one tile rather than two.
        static let claimRadius: ClosedRange<Double> = 18...23

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
        /// Twelve now, with the map, leaving three tiles of ground between two
        /// walls rather than five. Still a corridor, and a tighter one: adjacent
        /// bases sit about twelve tiles apart centre to centre against fourteen,
        /// so the walk to somebody else's wall is a seventh shorter for everybody
        /// including whoever is coming for yours.
        static let claimSpacing: Double = 12
        static let claimSpacingFloor: Double = 10

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
        ///
        /// Ten, up from three, and it is the largest single change to what a death
        /// costs that this file contains. Three seconds was barely a pause - you
        /// lost your gear and your purse and were back in the match before the
        /// fight you lost had finished - so the only real price of dying was the
        /// stuff, and stuff is replaceable. Ten is a twelfth of a five-minute
        /// match spent watching it happen without you, and it applies to all eight
        /// teams alike.
        ///
        /// TWO THINGS QUIETLY DIED WITH IT, and they are worth writing down rather
        /// than discovering later. A purse lies there for Arcade.tokenLifetime
        /// (10s) and dropped gear for Loot.itemLifetime (13s); at a three-second
        /// respawn you had seven seconds and ten seconds respectively to get back
        /// to your own body, which across a map this size was a race you usually
        /// lost but could sometimes win. At ten you cannot win it: the purse
        /// expires on the same beat you stand up, and you respawn at your claim
        /// centre with three seconds to reach gear that may be forty tiles away.
        ///
        /// So both are now a straight transfer to whoever killed you, or to nobody
        /// if they do not bother. That may well be the right shape for a death to
        /// have - it makes a kill unambiguously worth taking - but it is a
        /// consequence of this number and not a decision anybody made. The dial
        /// that turns it back into a race is Arcade.tokenLifetime, not this one.
        static let respawnDelay: Double = 10.0

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
        /// takes anything away - what you kept, you keep. It used to stay well under
        /// what the shop and the chests hand out; it now climbs to the top half of
        /// the ladder by the end, for the reason given below.
        /// Everybody respawns to the same floor, bots included, which is what stops
        /// the last minute filling up with free kills.
        static let respawnFloor: [(progress: Double, helmet: HelmetTier, blaster: BlasterTier)] = [
            // Raised a long way, on purpose, and it is the main lever on a match
            // a strong player was winning at a walk. Death takes everything, and
            // the bots die far more often than a good player does - so under the
            // old floor (Epic and a Blaster 3, and only in the last forty-five
            // seconds) the seven of them spent the back half of every match
            // walking out of their bases in starter kit, while the player who had
            // stayed alive was in Mythical. The fights that decided the match were
            // not fights.
            //
            // It is still the same floor for everybody, player included, and it
            // still never takes anything away. What changes is that by the closing
            // minutes nobody is under-geared: everyone is in the top half of the
            // ladder, and gear stops being the reason a fight is won.
            (0.30, .common,    .two),
            (0.50, .epic,      .three),
            (0.70, .legendary, .four),
            (0.85, .mythical,  .five)
        ]

        /// Healing handed back on a respawn, by how far the match has run.
        ///
        /// The gear floor's partner. A respawn late in the match used to come
        /// back with empty pockets, so even a well-geared bot lost the first
        /// exchange it walked into and had nothing to recover with. Topped up, not
        /// added to: a respawn starts with empty pockets anyway, so this is simply
        /// what is in them. Same for everybody.
        static let respawnHeals: [(progress: Double, items: [ItemType])] = [
            (0.45, [.bandage, .bandage]),
            (0.70, [.bandage, .bandage, .medkit, .medkit])
        ]

        static func respawnHealKit(at progress: Double) -> [ItemType] {
            respawnHeals.last(where: { progress >= $0.progress })?.items ?? []
        }

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

    // How the map is split into plains, forest, snow and desert regions.
    enum Biomes {
        // Regions per map; every biome gets at least one, the rest come from extraRegionPool.
        static let regionCount = 6
        static let extraRegionPool: [Biome] = [.plains, .plains, .forest, .snow, .desert]

        // Tiles kept between region centres, and between a centre and the map edge.
        static let siteSpacing: Double = 16
        static let siteMargin = 4

        // Size in tiles of the wobble grid, and how far in tiles it bends region edges.
        static let warpCell = 7
        static let warpStrength: Double = 4.5

        // Radius in tiles of the round clearing round each base that takes the base's biome.
        static let baseClearing: Double = 8

        // Trees per area relative to plains; forests are dense, deserts sparse.
        static let treeDensity: [Biome: Double] = [.plains: 1.0, .forest: 3.0,
                                                   .snow: 1.0, .desert: 0.45]

        // Clear tiles kept between two clumps, where it differs from Trees.spacing.
        // Forest gaps are wider than a person is tall, so its many trees are always walkable.
        static let treeGap: [Biome: Double] = [.forest: 2.1, .desert: 1.0]
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

        /// How much of the figure's own half-width the probe reaches out to on each
        /// side of the direction it is checking.
        ///
        /// Nine tenths rather than all of it. Probing the exact silhouette makes a
        /// bot refuse gaps it would fit through by a hair and stand outside its own
        /// doorway; a shade under leaves it willing to try a tight one, and the
        /// wedge check will get it out again if the try was wrong.
        static let probeWidthShare: Double = 0.9

        /// How far ahead the width is checked for, in tiles.
        ///
        /// Only the near probe. Beyond about a tile and a half the question stops
        /// being "do I fit" and becomes "which way should I go", and demanding a
        /// whole body's clearance three tiles out has a bot rejecting directions
        /// that would have been perfectly clear by the time it arrived - which is a
        /// bot turning on the spot in its own base, the very thing this is here to
        /// stop. A wedge happens where the bot already is.
        static let probeWidthRange: Double = 1.5

        /// How long a stretch of going nowhere counts as being stuck, and how far a
        /// bot has to cover in it to prove otherwise.
        ///
        /// Three quarters of a second and a third of a tile. Both deliberately
        /// generous: a bot pressed against a wall at a shallow angle really does
        /// crawl, and calling that stuck would have bots abandoning perfectly good
        /// errands every time they brushed past something. A genuinely wedged one
        /// covers no ground at all, so there is a wide gap between the two and the
        /// threshold can sit in the middle of it.
        static let stuckWindow: Double = 0.75
        static let stuckDistance: Double = 0.33

        /// How long it backs out for once it has decided it is stuck.
        ///
        /// A second. The turn alone eats half of it - four fifths of a half-turn at
        /// the turn rate above - so anything much shorter and the bot is still
        /// swinging round when it goes back to walking at whatever wedged it.
        static let shoveDuration: Double = 1.0

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

        /// Bots leave these tiers to the crates while waiting is still a plan.
        ///
        /// Set at exactly where the loot table stops. Buying a Common for six
        /// tokens is six tokens not spent on a Legendary, and a bot would have
        /// found that Common in a crate within the minute anyway - so below this
        /// line spending is worse than saving. Above it there is no other way up.
        ///
        /// Epic now rather than Rare, and it is the same line in the new ladder's
        /// terms: the late crate band tops out at Legendary, so Legendary is the
        /// first rung worth a token.
        ///
        /// WHAT THIS COULD NOT SAY, and what made it a bug rather than a policy:
        /// the shop offers exactly the rung ABOVE what you are wearing, so the tier
        /// tested against this line is never the one the bot HAS - it is the one it
        /// wants next. A bot wearing nothing is offered Common and asked whether
        /// Common clears Epic. It does not. Wearing Common it is offered Epic and
        /// asked whether Epic clears Epic. It does not either. The same holds one
        /// rung at a time all the way up, so the bar did not read "save for a
        /// Legendary", it read "buy nothing, ever, until a crate has already
        /// carried you past Epic on its own".
        ///
        /// Seven bots therefore spent every match banking tokens they could not
        /// spend, and finished in whatever gear the crates happened to hand them.
        /// That is most of what "the other players are not competitive" was.
        ///
        /// The line itself is kept, because the reasoning behind it is sound. What
        /// it was missing is an expiry - see buysAnythingAfter.
        static let buysHelmetsAbove: HelmetTier = .epic
        static let buysBlastersAbove: BlasterTier = .three

        /// When waiting for a crate stops being a plan.
        ///
        /// Past this, a bot buys the rung in front of it whatever it is. The whole
        /// argument for saving was "a crate will hand you one of those within the
        /// minute", and there are only so many minutes: a bot a third of the way
        /// into a match still wearing nothing is not being patient, it is being
        /// farmed.
        ///
        /// A third rather than halfway, because gear compounds - the tokens buy
        /// fights and the fights buy tokens - and a ladder started at a hundred
        /// seconds has the rest of the match to pay itself back. Started at a
        /// hundred and fifty it mostly does not.
        static let buysAnythingAfter: Double = 0.33

        /// How little healing a bot has to be carrying before it buys some.
        ///
        /// Bots could not buy a bandage at all: upgradeToBuy reads the gear tab and
        /// nothing anywhere read the other one. So a bot that ran dry had exactly
        /// one answer - walk to a crate and hope - while carrying forty tokens past
        /// a shop selling bandages at six.
        ///
        /// Deliberately the same number the raiding gates use rather than a new
        /// one, so the two cannot drift apart: emergencyHealingStock is the line
        /// below which a bot stops raiding and goes looking for supplies, and this
        /// is that same bot buying them instead of walking.
        static let buysHealingBelow = emergencyHealingStock

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
        ///
        /// Down again, from 42, and not simply because raiding should be commoner.
        /// Taking a chest now costs two seconds stood still on it and starts over
        /// if anybody lands a shot, so an attempt converts far less often than it
        /// used to. More attempts is the counterweight to that rather than a buff
        /// on top of it: about the same number of chests changing hands, arrived at
        /// by trying more often and succeeding less.
        ///
        /// Down again to 26, with the raid urge below. Bases now have turrets that
        /// hit back, so fewer raids land; the supply line has to keep up.
        static let bombSupplyInterval: Double = 26

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

        /// How a bot deals with gas, and the reason a stink bomb used to be worth
        /// nothing at all.
        ///
        /// The item was buffed twice on its damage and stayed useless both times,
        /// because damage was never the problem: NOBODY WAS EVER IN THE CLOUD.
        /// avoidGas ran above the goal list, every frame, for every bot, against
        /// every cloud on the map, with a 3.5 tile look-ahead in front of a 2.9
        /// tile cloud - so a bot began turning before it could possibly have
        /// touched one - and when it was somehow caught inside anyway it took a
        /// weight of 1.0, which threw the heading away and replaced it with the
        /// exactly optimal vector out. Perfect information, zero reaction time,
        /// perfect escape. A cloud landing squarely on a bot's feet was answered on
        /// the very next tick.
        ///
        /// So the numbers below are all about being late and imperfect, which is
        /// the same fix `reactionDelay` above makes for spotting a person - and for
        /// the same reason, written there: nobody reacts instantly, and a bot that
        /// does feels like a machine.

        /// How far ahead a bot looks, in tiles. Barely past its own feet now, so
        /// bots clip the edges of clouds instead of giving them a wide berth.
        static let gasLookAhead: Double = 1.6

        /// Seconds of standing in it before a bot starts getting out.
        ///
        /// This is the buff. Scaled by the bot's own caution, so the nervy ones
        /// notice sooner - and at 0.5 a cloud thrown onto somebody gets two doses
        /// into them before they have begun to move, which is the difference
        /// between an item that does something and an item that is a warning sign.
        static let gasReaction: Double = 0.5

        /// How hard it swerves: a nudge for one seen ahead, most of the heading for
        /// one it is standing in.
        ///
        /// Not 1.0 any more. A bot leaving a cloud now takes a slightly wrong line
        /// out and spends an extra fraction of a second in it, because the escape
        /// is blended with whatever it was doing rather than replacing it.
        static let gasSwerve: Double = 0.5
        static let gasFlee: Double = 0.85

        /// What is left of all that when the bot is running for its life.
        ///
        /// Gas used to outrank fleeing, which quietly removed the best thing a
        /// stink bomb can do: cut off the way out. A bot being shot at would
        /// calmly reroute around a cloud laid across its escape. At 0.3 it would
        /// rather choke than be shot, which is the correct answer and makes
        /// throwing one at a fleeing enemy worth doing.
        static let gasPanic: Double = 0.3

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
        ///
        /// Down to 26...45 alongside the bomb supply, and the pair is what moves
        /// this: an urge with no bomb behind it is a bot standing at a wall it
        /// cannot open, so shortening one without the other buys nothing. Together
        /// they take a bot's ceiling from about six attempts a match to about eight
        /// and a half. A ceiling rather than a count - most never find a target in
        /// range, and of those that do, a good many now end with somebody putting a
        /// shot into the raider two seconds from the chest.
        ///
        /// 20...36 now, and faster still while somebody is running away with the
        /// match - see leaderRush. The complaint was that the player was never
        /// raided at all, and a clock this slow meant most bots got four or five
        /// goes a match, most of which went on each other.
        static let raidUrgeInterval: ClosedRange<Double> = 20...36

        /// How far a bot will travel for an enemy chest it could get at.
        ///
        /// Longer than raidRange, because this one is worth the walk: a chest with
        /// something in it is the only thing on the map that repays crossing it.
        static let robRange: Double = 40

        /// How long a bot keeps coming back to a base it has started on.
        ///
        /// Generous, because what it is paying for is already spent: by the time
        /// this is running the bot has crossed the map and usually put a bomb
        /// through a wall, and the whole complaint it answers is bots abandoning
        /// raids they had already done the expensive part of. Half a minute is
        /// long enough to survive a fight and still finish, short enough that a bot
        /// which genuinely cannot get in gives up rather than orbiting a base for
        /// the rest of the match.
        ///
        /// It does not tick down during a fight - see AIBrain.think - so a raid
        /// interrupted by a long scrap is not quietly timed out by it.
        static let raidHold: Double = 30

        /// How far outside a base a bot will still consider itself mid-raid.
        ///
        /// Well past the walls, because being driven back is the normal way a raid
        /// is interrupted: a bot that only counted as raiding while standing inside
        /// would lose the thread exactly when it most needs to keep it.
        static let raidReturnRange: Double = 22

        // What a standing machine adds to a base's worth as a target; arcades are the main
        // reason to raid, since wrecking one pays points and cuts the owner's income.
        static let machineWorth = 40

        // Extra worth on a base a person owns, so bots raid the player for points even when
        // there is nothing in their chests.
        static let playerBaseWorth: Double = 20

        /// And what a mini adds. Counted per machine rather than once for the base
        /// now that a base can hold several - see World.lootValue, where a room
        /// with three machines in it correctly prices above one with a single
        /// cabinet.
        static let miniMachineWorth = 24

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
        static let raidDistanceCost: Double = 1.0

        /// What a base has to be worth before a bot will cross the map to open it
        /// rather than get on with the match. Above a single item, so a lone
        /// bandage behind a wall is not a reason to go anywhere.
        static let raidWorthOpening = 15

        /// What one bomb through a standing wall is worth going for.
        ///
        /// On the same scale as everything else in raidWorth, where a unit is a
        /// tile of walking: forty means a sealed base is worth about ten seconds of
        /// travel on its own, before anything that happens to be inside it.
        ///
        /// Under a stocked bot base's 55, deliberately. A rich base should still
        /// beat a bare one - that is the whole reason a base is priced rather than
        /// just measured - but the bare one should not price at ZERO, which is what
        /// it did, and which is why the one base on the map whose chests nobody
        /// fills for it went a whole match without being visited.
        ///
        /// The real payoff is 45 to 75 score, three to five tiles at
        /// Score.wallDestroyed. Forty rather than sixty because a raider does not
        /// always get the bomb where it meant to.
        static let breachWorth: Double = 40

        // MARK: - Hunting

        /// How far clear of the field somebody has to be before bots come looking
        /// for them personally.
        ///
        /// On World.lead's scale, where 1 is a runaway. Lower than leaderChaseAt
        /// (0.35) would have every bot abandoning its match to chase a narrow lead;
        /// much higher and the pressure arrives too late to matter, because by then
        /// the leader has already won and is simply being told about it.
        ///
        /// This is the answer to "the player can roam all game without much
        /// threat". Nothing in the brain ever went and FOUND anybody: fights were
        /// acquired by line of sight inside twelve tiles and dropped again at
        /// sixteen, so a player who kept moving was never followed by anything. A
        /// good player therefore chose every fight they were in, which is most of
        /// what dominating a match consists of.
        ///
        /// 0.38 now, from 0.45: the hunting starts a little earlier in a runaway,
        /// while it is still a contest rather than a formality.
        static let huntsLeaderAt: Double = 0.38

        /// How long between one bot's hunts.
        ///
        /// Deliberately long and deliberately staggered. Seven bots hunting at once
        /// is a mob; on twenty-five to fifty seconds apiece, one or two of the seven
        /// are out looking at any moment and the rest are playing the match. That is
        /// the difference between the leader being under pressure and the leader
        /// being griefed.
        static let huntUrgeInterval: ClosedRange<Double> = 25...50

        /// How long a bot will keep looking before giving up and going back to its
        /// own match.
        ///
        /// A hunt that has found nobody is a bot walking away from its base for
        /// nothing, and thirty seconds of that is a tenth of a match spent on an
        /// errand with no payoff. It gives up, takes a fresh urge, and gets on.
        static let huntPatience: Double = 30

        /// How far off a bot can pick a hunt's trail up from.
        ///
        /// The mark only refreshes on a clear view inside this, so a hunt tracks
        /// where somebody WAS rather than where they are. Wider than the twelve a
        /// fight is acquired at, because noticing somebody across a clearing and
        /// being close enough to shoot at them are different things.
        static let huntSight: Double = 16

        /// How close counts as having reached the mark.
        ///
        /// Standing here with nobody in sight is what makes a trail go cold: the
        /// mark is dropped and the hunt falls back on the quarry's base. Small,
        /// because "where they were" is a spot and not an area.
        static let huntArrival: Double = 1.5



        /// This is the counterweight to a runaway leader. Get far enough ahead and
        /// seven opponents start preferring you, which is also what makes their kill
        /// bounty worth having.
        static let leaderPull: Double = 0.4

        /// How big a lead over the field counts as running away with it.
        ///
        /// The scale behind World.lead, which is what points the bots at whoever is
        /// running away with the match.
        ///
        /// Modelled against what a match actually pays. A bot that seals its base,
        /// lays a couple of dozen walls, opens a dozen crates and gets a kill or two
        /// finishes around 420; seven of them land in a 350 to 500 spread. A player
        /// doing the same finishes level with them. A player who has learned the
        /// raid loop - bomb the wall, crack the chest, wreck the machine, bank it,
        /// repeat - finishes near 1,200, because one raid pays 55 plus 40 plus the
        /// items and takes under a minute.
        ///
        /// Down from 700 to 560, which moves WHEN rather than whether. At seven
        /// hundred an expert read 0.54 half way through and nothing pointed at them
        /// before that; the first half of a match had no answer to anybody, and the
        /// first half is where a runaway is built. At 560 the same player crosses
        /// huntsLeaderAt around the end of the first third, which is early enough
        /// to be a contest and late enough not to be a punishment for a good
        /// opening.
        ///
        /// What must not change is the bottom of the ramp. An ordinary player
        /// reads 0.01 and a decent one about 0.50; seven bots with nobody running
        /// away read about 0.14 among themselves, which is below every threshold
        /// that hangs off this. Somebody learning the game still never meets any of
        /// it. That is the requirement, and the reason this is a measure of what
        /// you are doing to the other seven teams rather than a difficulty setting.
        static let leadScale: Double = 560

        /// The scale behind World.behind, which is what a losing bot sharpens up
        /// against - aim, reaction and how soon it starts spending.
        ///
        /// Its own number, because behind and lead are not the same measurement.
        /// lead compares a team against the AVERAGE of the other seven; this
        /// compares it against the BEST of them, and a maximum saturates far more
        /// easily than a mean. One constant serving both meant the thresholds on
        /// the two sides were not comparable quantities, which is the sort of thing
        /// that looks tidy and quietly makes every number above it a guess.
        ///
        /// Held at 700 - the value both sides shared - so this change moves the
        /// leader-pointing half only. The losing half already fires when it should:
        /// against one runaway on three times the field, all seven bots correctly
        /// read as fully behind and all seven sharpen up.
        static let deficitScale: Double = 700

        /// What a full leader's base is worth on top of what is in it.
        ///
        /// Forty-five, read against the other terms in chestWorthRobbing: a stocked
        /// chest is 30 to 40, a machine 25, an unraided base builds up to 60, and a
        /// tile of walking costs 1. So a runaway leader's base outweighs an equally
        /// stocked one forty-five tiles further off - most of the width of the map,
        /// which makes them the target - while a bot standing next to a rich base
        /// still opens the one in front of it rather than trekking across the world.
        ///
        /// Raised to 100. At 45 a runaway's base was one option among several and
        /// usually lost to a nearer bot base, so the player doubling everybody's
        /// score was never once broken into. At 100 a full runaway is THE target:
        /// worth more than any stocked bot base, and - past leaderChaseAt - worth
        /// crossing the whole map for (see AIBrain.chestWorthRobbing).
        static let leaderWorth: Double = 100

        /// How much faster the raid and hunt urges come round while somebody else
        /// is running away with the match, at a full runaway lead.
        ///
        /// The adaptive half of the difficulty, and deliberately a change in what
        /// bots DO rather than in how strong they are: nobody gets more damage or
        /// health for being behind. At 1.5 a bot facing a full runaway gets the
        /// itch two and a half times as often, and since the leader's base and the
        /// leader are now what that itch points at, the pressure lands on them.
        /// An ordinary match reads well under leaderChaseAt and never feels it.
        static let leaderRush: Double = 1.5

        // MARK: - Dodging

        /// A raider being shot at weaves rather than walking a straight line.
        ///
        /// Before this a raider under fire walked dead straight at the chest, which
        /// is the easiest thing in the game to hit - anybody leading their shot, or
        /// any turret, landed nearly all of them. Now the heading swings either
        /// side of the line on a short beat, which throws a leading aim off
        /// without costing much ground.
        ///
        /// Swing in radians either side, period in seconds for one full weave.
        /// Kept inside what a bot can turn (turnRate) so the swing is not damped
        /// into a wobble.
        static let dodgeSwing: Double = 0.85
        static let dodgePeriod: Double = 1.2

        /// What counts as being under threat: hit this recently, or an enemy this
        /// close, or a turret with this bot in its sights.
        static let dodgeMemory: Double = 1.5
        static let dodgeRange: Double = 9

        /// The lead at which somebody is worth chasing wherever they are.
        ///
        /// Was a cliff: level with the best score at all, which made the leader
        /// worth crossing the map for and the team one point behind them worth
        /// ignoring - a coin toss on a scoreboard that moves in fifties. At 0.35 it
        /// is a judgement instead, and one nobody in an ordinary match ever trips.
        static let leaderChaseAt: Double = 0.35

        /// How much of its aim wobble a bot being left behind gets back.
        ///
        /// A third, and no more. Tightening aim is the crudest difficulty dial
        /// there is and the least pleasant to play against - a bot that cannot miss
        /// is not a better opponent, it is a wall - so this is deliberately the
        /// smallest of the three levers. Most of the answer to a dominant player is
        /// meant to be seven bots turning up at their base, not seven bots shooting
        /// straighter.
        static let pressureAim: Double = 0.35

        /// How much quicker a bot that is losing looks up.
        ///
        /// Moves the reaction draw towards the bottom of its range without ever
        /// reaching it: the floor stays, because a bot that reacts instantly reads
        /// as a machine however far behind it is.
        static let pressureReaction: Double = 0.6

        /// How far behind a bot has to be before it stops saving for the best gear.
        ///
        /// Below this it holds out for a rung the shop is the only way to reach.
        /// Past it the bar drops by one, which is the difference between saving for
        /// an upgrade and having a gun now - the right call for somebody losing.
        static let pressureBuysAt: Double = 0.45

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
        /// How much blaster damage a player's own wall takes before it breaks
        /// when they shoot it - see WallSystem. Sixty: five shots from a starter
        /// blaster, two from the best, so it is quick when you mean it.
        static let wallShotHealth = 60

        /// Seconds without a shot before a damaged wall is whole again, so stray
        /// shots in a fight never add up to a hole you did not mean to make. The
        /// health bar goes with it. Two, down from four: the bar was hanging about
        /// after you had stopped shooting.
        static let wallMendDelay: Double = 2

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
        /// 3.5, up from 2.9 and 2.2 before that - seven tiles across.
        ///
        /// The ceiling on this is the BASE: a claim is nine tiles across, so seven
        /// closes about three quarters of the width of somebody's home and still
        /// leaves a corner of it to stand in. A cloud that swallowed a whole base
        /// would not be a way of taking ground, it would be a way of ending a match
        /// from outside the walls, and that is still the line this does not cross.
        ///
        /// Seven tiles is also what makes CROSSING one cost something. At a walk of
        /// 3.8 tiles a second the far side is 1.8 seconds away, which is two doses
        /// and change - where six tiles was 1.5 seconds and could be shrugged off.
        static let radius: Double = 3.5

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
        /// Eleven per cent a dose, every 0.7 seconds, up from seven.
        ///
        /// Seven was set against a full eight-second stay, which came to 80% of a
        /// bar and read as about right on paper. What it actually meant in a match
        /// was 15% for the only exposure that ever happened - a crossing - because
        /// the bots never stood in one. That is an item nobody has a use for.
        ///
        /// So it is priced against the SHORT stay instead, which is the real one.
        /// Crossing seven tiles is two or three doses, 22% to 33%. Being caught by
        /// one thrown at your feet, with the half second of reaction the bots now
        /// have, is about the same. Being pinned in one during a fight is four or
        /// five doses and better than half a bar.
        ///
        /// A full stay is now past a kill, and the note that used to be here argued
        /// against exactly that - "a death sentence with a radius". The difference
        /// is what it takes to get there: eight unbroken seconds inside a cloud you
        /// can see the edge of, which is not a thing that happens to somebody who
        /// is paying attention. What the old note was really defending was that
        /// walking in and turning straight back out should be survivable, and at
        /// one dose for the round trip it comfortably is.
        ///
        /// Still a share of the bar rather than a flat number, for the reason
        /// above: the helmet ladder runs to 3.57 times a bare head, and a flat dose
        /// is what made this stop working on the people worth throwing one at.
        static let doseShare: Double = 0.11
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
        /// All of it, and it SPILLS rather than evaporating. Tokens that simply
        /// vanished would be a punishment nobody sees land - a number in the corner
        /// quietly emptying while you are watching the respawn clock - and a
        /// punishment you cannot see teaches nothing. A purse on the grass is
        /// legible from both ends: the person who killed you gets paid for it, and
        /// you get to watch somebody else pick your money up.
        ///
        /// It was a half, and the note here said the full wipe was the version
        /// worth trying if that was not enough. It was not enough. It also brings
        /// tokens into line with everything else death takes: your gear goes
        /// completely, your bag goes completely, and a purse that survived at
        /// fifty per cent was the one thing dying was gentle about.
        ///
        /// The failure mode named when this was a half is now live and worth
        /// watching for: with nothing left to lose, the correct play after every
        /// death is to spend down to zero the moment you can afford anything, and
        /// the cheapest rung is six tokens. If saving towards a Cosmic stops
        /// happening at all, this is the number that did it.
        ///
        /// What used to soften it was that the money is not gone, it is on the
        /// floor where you died - so a death was a race for your own purse that you
        /// could occasionally win. That is no longer true, and the number that
        /// changed was not in this enum. A purse lives Arcade.tokenLifetime (10s)
        /// and respawning now costs Player.respawnDelay (10s), so the purse expires
        /// on the same beat you stand up. It is a transfer to whoever killed you,
        /// or to nobody.
        ///
        /// Whether that is right is a live question. It makes a kill unambiguously
        /// worth taking, which is good; it also means the one thing that made
        /// dying survivable is gone, and losing a fight now costs the gear, the
        /// purse and a twelfth of the match. If deaths start to feel like being
        /// removed from the game rather than set back in it, Arcade.tokenLifetime
        /// is the dial - not this one, and not the respawn.
        ///
        /// Points are deliberately NOT touched. Score is the win condition, and
        /// taking it away on death compounds in the wrong direction: whoever is
        /// losing dies most, so they would lose most score, and the match would be
        /// decided in its first two minutes. It also punishes fighting, in a game
        /// whose whole second half is meant to be fighting.
        ///
        /// REDUCED (token pass): 1.0 -> 0.5. Killing a bot used to hand over its
        /// whole purse, which is where a good player's income snowballed. Half
        /// spills; the other half stays with the victim.
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
        /// Seven, down from nine, and still the same for all four. Nine was written
        /// as "about one fight at this game's ranges", and that was true of a fight
        /// you walk into knowing it is coming - most of them are shorter, and the
        /// back half of a nine-second perk was routinely spent walking around
        /// powered up with nobody to use it on. Seven is the fight and not the walk
        /// away from it.
        ///
        /// It matters more now there are four of them and they turn up half again
        /// as often: the moment should stay a moment.
        static let duration: Double = 7

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
        /// 5% seven times is about 35% of a bar across the perk, against the 78%
        /// the old regeneration paid over fifteen seconds. Barely more than one medkit,
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

        // MARK: - The three that each do one thing
        //
        // Every one of these is ABOVE the disco ball's version of the same power,
        // which reads backwards for the weaker item and is the point. A single that
        // is worse at its one job than the item which also does three others is
        // strictly dominated - no situation makes finding it good news - and an
        // item nobody is pleased to find is exactly what the old four-perk version
        // was. Less overall, better in its lane.
        //
        // Modestly above, though. Far enough that the right tool is worth reaching
        // for, near enough that the disco ball is still the one you hope for.

        /// A fifth again becomes a third again. Speed on its own has to be worth
        /// drinking for the chase or the escape alone, with no shots or health
        /// behind it - and at 1.22 it was not, it was a bonus attached to a better
        /// item rather than a reason to pick a bottle up.
        static let soloSpeedBoost: Double = 1.32

        /// A quarter again becomes a third again, which over seven seconds is about
        /// one extra hit landed in a close fight. That is the whole item.
        static let soloDamageBoost: Double = 1.35

        /// 7% a beat rather than 5%, so about 49% of a bar across the perk against
        /// the disco ball's 35%. Short of the 78% the old regeneration paid, and
        /// deliberately: this no longer arrives alongside thicker skin, but it is
        /// still a bar and a half of healing on a map where a medkit is the
        /// expensive thing in the shop.
        static let soloHealPortion: Double = 0.07

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

    enum SupplyDrop {
        /// When the first one lands, as a share of the match. Past half way, so
        /// it lands on a map where everybody has gear worth fighting with and a
        /// base worth leaving for a minute.
        static let firstAt: Double = 0.55

        /// Seconds between drops after the first, and how many a match gets.
        /// Three over the back 45%: one every forty-five seconds or so, so there
        /// is nearly always one to go and fight over in the closing minutes.
        static let interval: Double = 45
        static let maxDrops = 3

        /// Seconds a drop is locked after it lands. Long enough for everybody who
        /// saw it come down to get there - which is the point: the countdown is
        /// what turns a crate into a fight.
        static let unlockTime: Double = 20

        /// Where they may land: within this share of the map's half-width of the
        /// middle, which is the contested ground, and at least this many tiles
        /// clear of every base, so nobody gets one delivered to their doorstep.
        static let spread: Double = 0.62
        static let baseClearance: Double = 5
        /// And not on top of an earlier drop still waiting to be opened.
        static let dropSpacing: Double = 12

        /// What opening one pays, on top of the gear. More than a rare crate by a
        /// distance - you usually have to win a fight to get your hands on it.
        static let score = 50
        /// REDUCED (token pass): 8 -> 5 - the gear is the prize.
        static let tokens = 5

        /// What is inside: ONE item, always a Mythical or Cosmic helmet or
        /// blaster. Cosmic is the rarer half.
        static let loot: [(pickup: Pickup, weight: Int)] = [
            (.item(.helmet(.mythical)), 35),
            (.item(.helmet(.cosmic)),   15),
            (.item(.blaster(.five)),    35),
            (.item(.blaster(.six)),     15)
        ]

        /// How far a bot will go to contest a LOCKED drop, in tiles. An open one
        /// pulls bots from anywhere - see AIBrain.supplyWorthContesting.
        static let botInterest: Double = 40

        /// Inside this, a bot simply runs in and takes an open drop - it will not
        /// stop to fight, even under fire. The hot-commodity rule.
        static let botGrabRange: Double = 12
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

        /// The most bombs that may be lying on the ground at once.
        ///
        /// Late in a match every bot is carrying one and dying often, so death
        /// drops alone used to carpet the map. At the cap, crates roll without the
        /// bomb row and bodies drop none; once one is picked up or expires, they
        /// come back.
        static let maxLooseBombs = 2

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
        ///
        /// Trimmed to 120 alongside the mini, with bases now capped at two machines:
        /// a machine should be something you are pleased to find, not something
        /// every crate run turns up.
        static let rareArcadeWeight = 120

        /// And how heavily a MINI sits in an ordinary one.
        ///
        /// Against band totals of 338 down to 315 once the perks are in, twenty-six
        /// is about one crate in thirteen - and a shade likelier late than early,
        /// because the bands shrink while this does not.
        ///
        /// Over the twenty-odd crates somebody opens that is roughly one and a half
        /// a match. Deliberately a number you can count on rather than a number you
        /// hope for: the cabinet is the prize and stays behind a rare crate, and
        /// this is the thing that makes a base an economy instead of a lottery
        /// ticket. A base with no machine in it has nothing to defend and nothing
        /// worth breaking into, and that used to be seven bases out of eight.
        ///
        /// Down to 20 - about one crate in sixteen, a little over one a match.
        static let miniArcadeWeight = 20

        /// A turret, out of any crate, a little rarer than a mini machine.
        ///
        /// Rarer because it is worth more to a base than a mini - it keeps the other
        /// things in it safe - and because the bots are handed one on seal three
        /// times in four already. At 20 against the mini's 26 it is about one crate
        /// in seventeen, a little over one a match: enough that most players will
        /// find one, few enough that a second is a decision about whether to double
        /// up or carry it for later.
        ///
        /// Now a Mythical (purple) find, and weighted like one: 9, about one crate
        /// in thirty-five - roughly one every other match for somebody opening
        /// crates steadily. Bots still get theirs on seal, so this is what makes a
        /// turret in YOUR base something you earned.
        static let turretWeight = 9

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
        ///
        /// SUPERSEDED by startingRareShare, rareChance and maxRareCrates. Kept for
        /// reference.
        static let rareShare: Double = 0.125

        /// Share of crates that start the match rare: about one in fourteen, two or
        /// three on a map of forty. Enough that there is something purple to go for in the
        /// opening, few enough that it is still a find.
        static let startingRareShare: Double = 0.07

        /// The chance a crate comes back RARE when it respawns, by how far the
        /// match has run.
        ///
        /// Rare crates are an event now rather than a feature of the map: none in
        /// the opening, a trickle from the middle on, a few more towards the end
        /// when the gear inside matters most. Rolled per respawn with the world's
        /// generator, so a seed replays.
        static func rareChance(at progress: Double) -> Double {
            guard progress >= rareFrom else { return 0 }
            let along = min(1, (progress - rareFrom) / (1 - rareFrom))
            return rareChanceEarly + (rareChanceLate - rareChanceEarly) * along
        }
        ///
        /// Loosened after the first pass - none until 30%, 3% rising to 10%, at
        /// most three - which left whole matches with barely one in sight. Now:
        /// from 15%, 10% rising to 22%, at most four; about three in the
        /// opening map.
        static let rareFrom: Double = 0.15
        static let rareChanceEarly: Double = 0.10
        static let rareChanceLate: Double = 0.22

        /// The most rare crates standing on the map at once, so a lucky run of
        /// respawns cannot carpet the map with them.
        static let maxRareCrates = 4

        /// How heavily ONE of the three plain power-ups sits in a crate's table,
        /// by how far the match has run.
        ///
        /// Written as the weight itself rather than a base to be multiplied. It used
        /// to be one number that both this and the disco ball were scaled off, which
        /// worked while they wanted the same curve and stopped working the moment
        /// they did not: the singles needed to climb and the disco ball needed to
        /// hold still, and a shared base cannot do both without a fudge factor that
        /// falls as the base rises. Two curves, two functions, each number the thing
        /// it actually is.
        ///
        /// 7 / 9 / 12, down a fifth from the 9 / 12 / 15 these were first set to.
        /// That first pass was solved against fourteen crates a match, which is what
        /// an ordinary player opens; somebody who knows the map opens twenty to
        /// twenty-five, and at the old weights that put two and a half to nearly
        /// three singles in their hands - often enough that having one stopped being
        /// a thing that happened and started being a state you were usually in.
        ///
        /// The figures now. The three together are 6.2% of an early crate and 12.5%
        /// of a late one, which is 1.2 a match for an ordinary player and 1.8 to 2.2
        /// for somebody opening everything they walk past. So you reliably meet one,
        /// often two, occasionally three - rare enough to be a find, common enough
        /// to have an opinion about which of the three you would rather have, which
        /// is the entire reason there are three.
        ///
        /// Still well above where this started. The original 5 / 6 / 7 came out at
        /// 0.96 a match, the wrong side of one, and most matches had none at all - a
        /// power-up you meet less than once is a mechanic nobody plans around.
        ///
        /// The climb across the match is the part that has not moved: twice as
        /// likely late as early, against a little over half again before any of
        /// this. Seven seconds of faster feet is worth more in a late fight than an
        /// early one, and late is when the match is being decided and a crate needs
        /// to be able to change something.
        static func singlePerkWeight(at progress: Double) -> Int {
            switch progress {
            case ..<0.35: return 7
            case ..<0.70: return 9
            default:      return 12
            }
        }

        /// The same, for the disco ball.
        ///
        /// PARKED. The ball is not obtainable at the moment - see Perk.obtainable -
        /// so nothing reads this. Kept because it is the answer to "how often would
        /// it turn up", which is the first question asked the day it comes back.
        ///
        /// Deliberately flat where the singles climb, and these numbers are chosen
        /// to hold its ABSOLUTE rate still - about 0.19 a match, exactly what it was
        /// before the singles moved - rather than to hold some ratio against them.
        /// The table grows underneath it as the singles get heavier, so standing
        /// still here is a weight rise of its own.
        ///
        /// It is the one power-up that ends a fight by itself, and "rarer than it
        /// was" was never the ask. Everything the change handed out went to the
        /// three that each do one thing.
        static func overdriveWeight(at progress: Double) -> Int {
            switch progress {
            case ..<0.35: return 4
            case ..<0.70: return 4
            default:      return 5
            }
        }

        /// Thirty-four, down from forty-two with the map. Density is held flat on
        /// purpose, so shrinking the map is a change to how FAR things are and
        /// not to how much there is - a fifth fewer crates on a fifth less
        /// ground. What does change is that eight people are now competing over
        /// thirty-four of them instead of forty-two, which is the contest the
        /// smaller map was for.
        static let lootboxCount = 34

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
        /// Three, up from two, and what comes out is now the BEST three rather
        /// than the first three - see ChestSystem.crack.
        ///
        /// Those two changes together are most of "a raid should be worth making".
        /// A chest is 3 or 4 items and a quarter of the table is gear, so two items
        /// off the front meant a raid handed you two bandages more often than not.
        /// Taking the best of what is in there is also just what a person does: you
        /// do not scoop the nearest thing out of a box you have broken open under
        /// fire, you take the helmet.
        ///
        /// Still short of what a fresh chest holds, so the victim loses more than
        /// the raider gains - which is what makes a raid an attack rather than a
        /// transfer, and is the reason defending one is worth doing.
        static let raidSpill = 3

        /// How much punishment a chest takes before it bursts.
        ///
        /// A chest is SHOT open now. It used to be a two second count that began on
        /// a tap and reset if anybody hit you, and the count was there for a good
        /// reason - before it, a raid was "walk in, tap, walk out" and the owner
        /// sprinting home always arrived too late to matter. It bought a defence
        /// window and it worked.
        ///
        /// What it cost was the raid itself. The player tapped once and then stood
        /// still for two seconds doing nothing, in the middle of the most active
        /// thing in the game, with a progress bar over their head - and one bullet
        /// sent it back to nothing, so in any contested raid the bar was pure
        /// frustration and never finished. Health buys the same window and spends
        /// it on something to DO. It is also the language the board already speaks:
        /// arcades are shot apart, and a chest that works the same way needs no
        /// explaining.
        ///
        /// 170, which is 3.1 seconds of a starting blaster, 1.8 of a Blaster 3 and
        /// 1.1 of a Blaster 5. Wider than the flat two seconds it replaces, and
        /// deliberately: the gear you raided for should make the next raid quicker.
        /// The bottom of that range is still long enough for somebody who heard the
        /// bomb to cross their own base and start shooting.
        ///
        /// The interrupt is gone and is not missed. Being shot at already stops you
        /// breaking a chest, because you cannot hold an aim on a box and dodge at
        /// the same time - the mechanism is now the fight rather than a rule about
        /// one.
        static let health = 170

        /// A chest left alone mends, exactly as a machine does.
        ///
        /// Without it, every chest on the map would be chipped down over five
        /// minutes by stray fire and the map would end up made of ruins nobody
        /// chose to break. The delay is the part that matters: mending only ever
        /// undoes damage nobody followed up on, so breaking a chest stays something
        /// you commit to rather than an errand you run in instalments.
        ///
        /// Quicker to come back than a machine, because there is so much less of
        /// it: four seconds of quiet and then a seventh of the box a second, so an
        /// abandoned chest is whole again about eleven seconds after the shooting
        /// stops.
        static let mendDelay: Double = 4
        static let mendPortion: Double = 0.14
        static let mendTick: Double = 1.0

        /// What a bomb takes off one at the centre of the blast, falling away to
        /// nothing at the rim exactly as it does for a person.
        ///
        /// Damage rather than destruction, which is what a bomb does to an actor
        /// and not what it does to a machine. A bomb that burst a chest outright
        /// would hand the whole raid back to the raider: lob one through the hole
        /// you just made from outside the wall, and the defence window this is all
        /// built around never opens at all. 120 of 170 means a bomb is most of a
        /// chest and never all of it - you still have to go in.
        static let bombDamage = 120

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
        /// GEAR IS UP and bandages are down, which is the other half of a raid
        /// being worth making. Gear held 34 of 138 - a quarter - and bandages held
        /// 42% on their own, so the commonest outcome of bombing a wall, walking
        /// into somebody's base and breaking their chest under fire was a couple of
        /// bandages. That is a crate, and a crate costs nothing.
        ///
        /// 46 of 142 now (bombs trimmed from 26 to 22 so they stay a find), a
        /// third, against 42 for bandages. With three
        /// or four items in a fresh chest and the best three of them coming out,
        /// 73% of chests hand over a piece of gear, against 43% before - modelled
        /// over 200,000 chests rather than guessed at. The rest still pay in
        /// healing and bombs, which is what lets you keep raiding.
        static let stockTables: [(from: Double, rows: [(item: ItemType, weight: Int)])] = [
            (0.00, [
                (.bandage, 42), (.medkit, 20), (.bomb, 22), (.stink, 12),
                (.helmet(.common), 15), (.helmet(.epic), 8),
                (.blaster(.two),   15), (.blaster(.three), 8)
            ]),
            (0.35, [
                (.bandage, 42), (.medkit, 20), (.bomb, 22), (.stink, 12),
                (.helmet(.common), 8), (.helmet(.epic), 15),
                (.blaster(.two),   15), (.blaster(.three), 8)
            ]),
            (0.65, [
                (.bandage, 42), (.medkit, 20), (.bomb, 22), (.stink, 12),
                (.helmet(.epic), 15), (.helmet(.legendary), 8),
                (.blaster(.three), 15), (.blaster(.four), 8)
            ]),
            (0.85, [
                (.bandage, 42), (.medkit, 20), (.bomb, 22), (.stink, 12),
                (.helmet(.legendary), 15), (.helmet(.mythical), 8),
                (.blaster(.four), 15), (.blaster(.five), 8)
            ])
        ]

        /// The band the match is currently in.
        static func stockTable(at progress: Double) -> [(item: ItemType, weight: Int)] {
            stockTables.last { progress >= $0.from }?.rows ?? stockTables[0].rows
        }

        /// What you BUMP INTO, which is no longer the same as what you see.
        ///
        /// The drawn chest follows the artwork's shape; this does not, and the
        /// difference is deliberate. A figure is 1.72 tiles tall, so the gap between
        /// a chest and the wall behind it is the tightest space in the game - see
        /// MovementSystem.push, which exists because actors wedge in it. Shaping
        /// this box to a redrawn, taller chest took the height from 0.70 to 0.82 and
        /// closed every one of those gaps by another eighth of a tile, which put the
        /// bots straight back to standing in their own furniture.
        ///
        /// So the height is the number the wedging was solved against and the art
        /// does not get a vote in it. ChestRenderer draws the picture at its true
        /// shape, standing on the bottom of this box, and the lid overhangs by about
        /// a tenth of a tile - which is what a chest lid does.
        ///
        /// The width came down from 1.05 and can stay down: narrower only ever
        /// widens the gap it has to be walked past in.
        static let size = Vec2(x: 0.95, y: 0.70)

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

        static let miniDestroyedReward = 3

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
        /// Down from 520, and the reason is the mending below rather than the
        /// number itself. At 520 a Blaster 3 needed five and a half seconds of
        /// standing still in somebody's base to break one machine, which nobody
        /// ever has; the machines were not tough, they were simply never the thing
        /// a raid had time for. At 340 it is three and a half - long enough to be a
        /// commitment, short enough to fit inside a raid you are already making.
        ///
        /// Easy to break and easy to keep, rather than hard to break and gone
        /// forever once it is: see mendPortion.
        static let health = 340

        /// A mini has noticeably less in it, and that is its main weakness rather
        /// than a rounding of its payout. Three hundred and twenty against five
        /// hundred and twenty is eleven seconds of Blaster 3 against seventeen: a
        /// raider passing through can take a mini apart on their way to something
        /// else, where a full cabinet is a decision to stand still and commit.
        static let miniHealth = 200

        /// Machines on the map. Deliberately few: an arcade you have to travel to
        /// is a place worth fighting over, one on every corner is furniture.
        ///
        /// Four rather than five. A small cut on purpose - map machines are only
        /// about six per cent of what a player earns in a match, so this is worth
        /// roughly a rung of the ladder over five minutes. It is here for the
        /// crowding rather than the economy: five on a map whose bases already sit
        /// on a ring of radius eighteen meant there was usually one within a few
        /// seconds of wherever you were standing, and a machine you stumble over is
        /// not a place worth fighting over.
        static let count = 4

        /// Footprint in tiles. The art measures 496 x 808 opaque pixels - a ratio
        /// of 0.61 against the 0.67 of a 2 x 3 block, close enough to sit on the
        /// grid without stretching.
        static let footprintWidth = 2
        static let footprintHeight = 3

        /// A mini is two by two. The WIDTH is shared - both machines are two tiles
        /// across, which is what lets one stand anywhere the other would and makes
        /// "swap a full one for a mini" a real choice about depth rather than a
        /// different placement puzzle.
        static let miniFootprintHeight = 2

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
        /// REDUCED (token pass): 3.2 -> 3.9. Machines were the biggest single
        /// source of tokens and let a player buy the ladder far too early.
        static let emitInterval: Double = 3.9

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
        /// REDUCED (token pass): 0.75 -> 1.0. A sealed base no longer makes its
        /// machines faster, only safer - camping your own machine was about 40% of
        /// a player's income.
        static let sealedInterval: Double = 1.0

        /// How much slower a mini pays, as a multiplier on the interval.
        ///
        /// Sixty per cent more, so behind a standing wall a mini pays every 3.84
        /// seconds against a cabinet's 2.4. Together with the smaller bank that
        /// puts a mini at about two thirds of a full machine - and two of them,
        /// which cost eight tiles of base against six, comfortably ahead of one.
        /// That is the trade the two sizes are for.
        static let miniRate: Double = 1.6

        /// Health coming back into a machine nobody is shooting: how long after the
        /// last shot it starts, how big each portion is, and how long between them.
        ///
        /// Five seconds, then a tenth of its own maximum every second - so a machine
        /// left alone is whole again about fifteen seconds after the shooting stops,
        /// and a mini a touch sooner in absolute terms because a tenth of it is less.
        ///
        /// The delay is the part that matters. Without it, mending fights the
        /// raider in real time and taking a machine down becomes a damage race; with
        /// it, mending only ever undoes damage nobody followed up on. That is the
        /// behaviour this is for - a machine you put two shots into and walked away
        /// from is a machine you have not dented, so breaking one has to be a thing
        /// you commit to rather than an errand you run in instalments over a match.
        ///
        /// Portions on a tick rather than a smooth trickle, exactly as a person
        /// recovers at home - see GameConfig.Player.recoveryPortion for that
        /// argument, which is about the screen as much as the arithmetic. A bar
        /// that climbs in ten visible steps reads as repairing; one that creeps up
        /// a pixel a frame reads as a rendering fault.
        static let mendDelay: Double = 5
        static let mendPortion: Double = 0.10
        static let mendTick: Double = 1.0

        /// How often a bot's free machine on seal is the small one.
        ///
        /// Two thirds. The free machine exists so that every base is worth visiting
        /// at all, and the cabinet is the thing that should be worth going out of
        /// your way for - handing all seven bots the good one for nothing would
        /// make finding one yourself mean nothing.
        static let botMiniShare: Double = 0.65

        /// How much every extra machine in the same base slows all of them down.
        ///
        /// THE REASON THE CAP COULD GO. A base used to hold exactly one machine,
        /// and that single rule was carrying the whole economy: the safest income
        /// on the map, uncapped, in a room you can fit six machines into, works out
        /// at about 860 tokens a match - nearly three full gear ladders, against a
        /// raiding player's entire income of around 136. Simply removing the cap
        /// would have ended the shop.
        ///
        /// So machines crowd instead. Each one in a base is slowed by 30% of itself
        /// per other machine standing there, as though the room only has so many
        /// people in it to play them. One machine is 165 tokens a match, two full
        /// and two mini is 278, and six is 343 - so building your base out is
        /// clearly worth doing and tops out at about twice one machine rather than
        /// nine times.
        ///
        /// A cost you weigh rather than a wall you hit, which is the difference
        /// between this and putting the cap back at three. It also prices itself
        /// into the raiding side for free: a base with four machines in it is worth
        /// far more to break into than a base with one, and now actually reads that
        /// way to the bots.
        static let crowding: Double = 0.30

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
        /// REDUCED (token pass): 8% -> 5%.
        static let goldenChance = 0.05

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

        static let miniUncollected = 2

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

        /// A mini holds three. The other half of "about two thirds": the interval
        /// decides what it pays while you stand there, and the bank decides what it
        /// is worth coming home to.
        static let miniSealedUncollected = 3

        /// How far out from the footprint a token still counts as this machine's,
        /// for the cap above. Just past the ring it drops them on.
        ///
        /// Only used by machines standing in the OPEN now, and by a base somebody
        /// has broken into. A sealed base counts its whole floor instead - see
        /// ArcadeSystem.basePile.
        static let collectionRadius: Double = 1.5

        /// The most loose tokens a base will let lie on its floor before every
        /// machine in it stops.
        ///
        /// Six. "A few to collect, and then it waits for you" is the whole feel this
        /// is for, and six is about two handfuls - enough that a cabinet's bank of
        /// five still means something on its own, small enough that walking in
        /// reads as clearing a pile rather than wading through one.
        ///
        /// It is a CEILING on the machines' own banks added together, not a
        /// replacement for them: a base with a single mini still stops at three, so
        /// what coming home is worth still scales with what you have built. It only
        /// bites once a base holds more than about one cabinet's worth, which is
        /// exactly the case that was producing twenty tokens of litter.
        ///
        /// This does not cap income, and that distinction matters. Stand in your own
        /// base and the tokens are picked up as they land, so the pile never gets
        /// near this and the rate is whatever crowding allows. It caps what
        /// accumulates while you are somewhere ELSE - which is the thing that should
        /// have a limit on it.
        /// REDUCED (token pass): 6 -> 4, so leaving a base to bank is worth less.
        static let basePileCeiling = 4

        /// How far off a tile's centre a token is nudged when it has to share.
        ///
        /// Tokens prefer an empty tile and only double up when every clear spot
        /// round the machine is taken - see World.freeSpot. When they do, this stops
        /// the second one being drawn exactly on top of the first, which made three
        /// tokens look like one and a working machine look like a stopped one.
        ///
        /// In tiles, so a quarter of one either way: visibly two things, still
        /// obviously on the same square, and nowhere near far enough to land
        /// somewhere you cannot reach.
        static let tokenNudge: Double = 0.22

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

    enum Turret {
        /// How far it can see and shoot, in tiles.
        ///
        /// Level with a blaster's twelve. It was eight, two thirds of a blaster, on
        /// the theory that out-ranging it was the skill - and in practice that was
        /// the whole counter: stand at ten tiles, shoot it to bits, never take a
        /// hit. A turret you can dismantle from outside its reach is scenery.
        ///
        /// Walls still block it both ways, so it guards the room and the doorway
        /// rather than the open ground around a base. And it will not open up on
        /// the player from off the edge of their screen - see TurretSystem.canEngage
        /// - which is the same courtesy the bots extend.
        static let range: Double = 12

        /// Damage per shot and shots a second.
        ///
        /// A Blaster 2's bullet at under half a player's rate - 16 at 2.2 a second,
        /// 35 a second against the 54 of the weakest blaster anybody carries. Enough
        /// to take a bare-headed raider in about three seconds of standing still,
        /// which is the point: the raid step that takes time is the step it
        /// punishes. Nowhere near enough to win a straight duel with somebody who
        /// turns round and shoots back, which is the other point.
        ///
        /// Raised to 20 at 2.4 a second - 48 a second, up from 35 - alongside the
        /// turret learning to lead its shots. The two together are what turned it
        /// from something raiders walked past into something they have to deal
        /// with: the damage was never the real problem, the misses were.
        static let damage = 20
        static let fireRate: Double = 2.4

        /// How much of a moving target's travel it aims ahead for, as a share of
        /// a perfect lead.
        ///
        /// It used to aim at where you ARE, and a shot takes most of a second to
        /// cross its range, so anybody simply walking was never hit. Not the whole
        /// lead: at ninety per cent a steady walk still gets clipped, while
        /// changing direction - actually dodging - beats it, which is the skill it
        /// should be asking for.
        static let leadShare: Double = 0.9

        /// How fast the barrel swings, in radians a second, and how close to on
        /// target it has to be before it fires.
        ///
        /// It TRACKS rather than snapping, and the turn rate is a real mechanic as
        /// well as the look: somebody running across its front can get most of the
        /// way before it has come round, while somebody standing still at a chest
        /// is under fire within half a second. The tolerance is loose because a
        /// bullet is not a laser, and a turret that waited to be perfect would
        /// hardly ever shoot.
        static let turnRate: Double = 5.0
        static let fireTolerance: Double = 0.18

        /// How fast an idle barrel sweeps, in radians a second. Slow - one full turn
        /// every twelve seconds or so - so it reads as watching rather than spinning.
        static let idleSweep: Double = 0.5

        /// How finely the line of sight is checked, in tiles. A quarter: finer than
        /// the thinnest thing that stops a bullet, which is a wall tile.
        static let sightStep: Double = 0.25

        /// How far past its centre a shot starts - see Turret.muzzle. Clear of its
        /// own two-tile body with a little to spare.
        static let muzzleReach: Double = 1.25

        /// How much punishment it takes.
        ///
        /// 300: a little over three seconds of a Blaster 3 standing still, while it
        /// shoots back at 35 a second. Raised from 220, which went down before it
        /// had really made its point - a turret should be something a raider has
        /// to commit to, not something they clip on the way past. A fair duel
        /// against somebody with good gear, a losing one for somebody fresh off a
        /// respawn. Still under a machine's 340 because it fights back and a
        /// machine does not.
        ///
        /// Up again to 360, with the bomb pulled back below, so that clearing one
        /// takes a bomb AND a proper exchange of fire rather than either alone.
        static let health = 360

        /// Taken off it by a bomb at the centre of the blast, falling off to nothing
        /// at the rim.
        ///
        /// Most of one and never all of it, for the reason the chest's number gives:
        /// a bomb that burst it outright would let a raider clear it through the
        /// hole from outside, and the defence would never get to fire a shot.
        ///
        /// 150 of its 360 now. A bomb softens it; it does not do the job.
        static let bombDamage = 150

        /// Turrets in BOT bases, which are deliberately stronger than the player's.
        ///
        /// A difficulty lever, and the one place the game quietly favours the bots
        /// (Heath's call): raiding a bot base should be the hard part of a match,
        /// and a player's own turret does not need to be anything like as good for
        /// the player to be well defended - the bots are not as good at dealing
        /// with one as a person is.
        ///
        /// 25 at 2.7 a second is 67 a second against a normal turret's 48, on 460
        /// health against 360. A bomb (150) is now about a third of one.
        static let botDamage = 25
        static let botFireRate: Double = 2.7
        static let botHealth = 460

        /// A turret left alone mends, as a machine does. See Arcade.mendDelay.
        static let mendDelay: Double = 5
        static let mendPortion: Double = 0.12
        static let mendTick: Double = 1.0

        /// What breaking one pays whoever did it.
        ///
        /// Between a mini machine and a cabinet: it is worth more to its owner than
        /// a small machine, since it is the thing keeping everything else in the
        /// base safe, and less than a cabinet, which is the base's whole income.
        /// REDUCED (token pass): 8 -> 5.
        static let destroyedReward = 5
        static let destroyedScore = 60

        /// How often a bot's base is handed one on seal.
        ///
        /// Nine in ten, up from three in four: an unguarded bot base was the easy
        /// meal that let a good player run away with a match. The odd one without
        /// is still worth keeping - part of what makes raiding interesting is the
        /// base that turns out to have nothing guarding it.
        static let botShare: Double = 0.9
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
