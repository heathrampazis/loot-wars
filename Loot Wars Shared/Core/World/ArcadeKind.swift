//
//  ArcadeKind.swift
//  Loot Wars
//
//  Two sizes of machine.
//
//  There was one, and it was the most valuable thing anybody could own: two tiles
//  by three, found only in a rare crate, one to a base, and the safest income on
//  the map once it was standing behind a wall. All of that was true and most of it
//  was the problem. A thing that good, that rare, and that limited meant a base
//  either had THE machine or had nothing, and which one you got was decided by
//  whichever crate you happened to open in the first two minutes.
//
//  The mini is the ordinary version of that. Two by two, out of any crate rather
//  than the good ones, worth about two thirds as much, and dying noticeably faster
//  when somebody puts a blaster on it. It is not a lesser prize - it is the thing
//  that makes a base an ECONOMY rather than a lottery ticket, because you can
//  reliably expect to find one and you can stand more than one up.
//
//  WHY THE NUMBERS ARE HERE AND NOT ON THE ARCADE. Every one of these is a fact
//  about the KIND, and the alternative is what the perks had before they were
//  rewritten: a set of `if isMini` scattered through four systems, each of which
//  has to remember to ask. Perk.swift settled this argument once already - see the
//  per-perk computed properties there - and this is the same shape of answer. A
//  third size would be a case and a column, not an audit.
//
//  The one thing deliberately NOT here is the artwork. Core does not name assets;
//  ItemArt and ArcadeRenderer map a kind to a texture, which is where every other
//  "what does this look like" answer in the game lives.
//

enum ArcadeKind: Hashable, CaseIterable {

    /// The cabinet. Two by three, and still the best thing in a base.
    case full

    /// Two by two, and about two thirds of one.
    case mini

    // MARK: - How much room it takes

    var width: Int { GameConfig.Arcade.footprintWidth }

    var height: Int {
        switch self {
        case .full: return GameConfig.Arcade.footprintHeight
        case .mini: return GameConfig.Arcade.miniFootprintHeight
        }
    }

    // MARK: - How much punishment it takes

    var health: Int {
        switch self {
        case .full: return GameConfig.Arcade.health
        case .mini: return GameConfig.Arcade.miniHealth
        }
    }

    // MARK: - What it pays

    /// Multiplier on the emit interval, so a mini is SLOWER.
    ///
    /// Expressed against the full machine rather than as its own number of seconds,
    /// because the interesting quantity is the ratio and a pair of absolute
    /// intervals is two things to keep in step.
    var rate: Double {
        switch self {
        case .full: return 1
        case .mini: return GameConfig.Arcade.miniRate
        }
    }

    /// How many payouts pile up before it stops, behind a wall that is standing.
    var sealedBank: Int {
        switch self {
        case .full: return GameConfig.Arcade.sealedUncollected
        case .mini: return GameConfig.Arcade.miniSealedUncollected
        }
    }

    /// The same, standing in the open or with the wall breached.
    var openBank: Int {
        switch self {
        case .full: return GameConfig.Arcade.maxUncollected
        case .mini: return GameConfig.Arcade.miniUncollected
        }
    }

    // MARK: - What it is worth to somebody else

    /// What a raider gets for shooting it apart.
    var destroyedReward: Int {
        switch self {
        case .full: return GameConfig.Arcade.destroyedReward
        case .mini: return GameConfig.Arcade.miniDestroyedReward
        }
    }

    /// And the points for it.
    var destroyedScore: Int {
        switch self {
        case .full: return GameConfig.Score.arcadeDestroyed
        case .mini: return GameConfig.Score.miniArcadeDestroyed
        }
    }

    /// What it adds to the price on its owner's base - see World.lootValue.
    var raidWorth: Int {
        switch self {
        case .full: return GameConfig.AI.machineWorth
        case .mini: return GameConfig.AI.miniMachineWorth
        }
    }

    // MARK: - How it reads

    /// Which rung of the ladder it sits on, which decides the colour of the pool
    /// under it on the grass and how loudly the crate announces it.
    ///
    /// A rung apart, which is the cheapest way to say "this is the lesser one" -
    /// the rung is already the language the whole game uses for how good a thing
    /// is, and a player reads the difference before they have learned either.
    var rarity: Rarity {
        switch self {
        case .full: return .mythical
        case .mini: return .legendary
        }
    }
}
