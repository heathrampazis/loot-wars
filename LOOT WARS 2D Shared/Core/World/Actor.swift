//
//  Actor.swift
//  Loot Wars
//
//  One type for the player and (later) every AI. The only difference between them
//  is who produces their Commands - a joystick, a brain, or a network packet.
//

struct Actor {
    let id: ActorID
    let team: TeamID

    /// Centre of the actor's hitbox, in tile space.
    var position: Vec2

    /// The direction this actor is trying to move, length 0...1.
    /// Set from Commands at the start of every tick.
    var moveInput: Vec2 = .zero

    /// Where the blaster points. Set from aiming, not from walking, and it holds
    /// its value when the stick is released so letting go does not leave the actor
    /// aiming at nothing.
    var aim: Vec2 = Vec2(x: 1, y: 0)

    /// Which way the figure is drawn. Aiming wins over walking - somebody backing
    /// away while shooting is looking at what they are shooting at - and vertical
    /// input leaves it alone, so walking straight up does not turn the character.
    var facesLeft: Bool = false

    /// What the actor is wearing. Everyone starts with nothing.
    var helmet: HelmetTier = .none

    /// What the actor is shooting with. Everyone starts with the basic one.
    var blaster: BlasterTier = .starting

    /// Full health for THIS actor, which depends on its helmet.
    var maxHealth: Int { helmet.maxHealth }

    var health: Int = GameConfig.Player.baseHealth

    /// nil while alive; counts down to respawn while dead.
    var respawnTimer: Double?

    /// How long since anything last hurt this actor. Starts high, so a fresh
    /// spawn does not count as having just been in a fight.
    var secondsSinceHit: Double = 999

    /// Seconds of spawn protection left.
    var invulnerability: Double = 0

    var isAlive: Bool { respawnTimer == nil }

    var ammo: Int = GameConfig.Blaster.magazineSize

    /// Counts down to the next portion of health handed back at home - see
    /// CombatSystem.recover. Reset whenever you stop qualifying, so the first
    /// portion always arrives a full interval after you get there.
    var recoveryTimer: Double = GameConfig.Player.recoveryTick

    /// The power-up currently running, and how long is left of it.
    ///
    /// One, never a list. See Perk for why the rule is written before there is a
    /// second perk to break it - and note that this is state on the ACTOR rather
    /// than an item in a slot: once it is switched on there is nothing to drop,
    /// nothing to steal, and dying ends it.
    var perk: Perk?
    var perkRemaining: Double = 0

    /// Counts down to the next thing a running perk does.
    var perkTick: Double = 0

    /// How fast this actor moves, as a share of the standard speed.
    ///
    /// Three of the perk's four powers work like this - a number READ at the point
    /// of use rather than a system that reaches in and edits something. Nothing has
    /// to be put back when the perk ends, nothing can be applied twice by a system
    /// that ran the same frame, and a perk that stops existing takes its effect
    /// with it in the same instant. Only the healing needs a beat, and PerkSystem
    /// runs that.
    ///
    /// All three ask the PERK rather than asking whether one is running, which is
    /// the difference between three power-ups and three copies of the same one:
    /// "is a perk running" was correct for exactly as long as there was one perk,
    /// and would have quietly granted every power to every bottle. See Perk, which
    /// answers for itself and does it in one switch per power.
    ///
    /// They asked it directly for a while, and only a while: with one power-up in
    /// the game "is a perk running" and "does this perk do that" are the same
    /// question, and they stopped being the same question the moment there were
    /// four again.
    var speedMultiplier: Double {
        perk?.speedBoost ?? 1
    }

    /// How hard this actor's shots hit, as a share of the blaster's own damage.
    var damageMultiplier: Double {
        perk?.damageBoost ?? 1
    }

    /// The share of incoming damage this actor actually takes.
    var damageTakenShare: Double {
        perk?.damageTakenShare ?? 1
    }

    var inventory = Inventory()

    /// Currency. Worth nothing yet - the shop is what will give it meaning - but
    /// collected, dropped and counted from now so the economy has a history by the
    /// time there is something to spend it on.
    var tokens: Int = 0

    /// A bot's memory. nil for anything driven from outside - the local player
    /// today, a remote player later.
    var ai: AIState?

    /// Seconds until this actor may fire again.
    var shootCooldown: Double = 0

    /// Counts down to the next bullet coming back. Reset to the recharge delay on
    /// every shot, so firing keeps pushing the refill away.
    var rechargeTimer: Double = 0

    /// This actor's collision box, in tile space.
    ///
    /// EVERYTHING that asks about the actor's shape goes through here - walls, trees,
    /// lootboxes, item pickups, building. One shape, one answer, so no two systems
    /// can develop their own idea of where the player is.
    var hitbox: Box {
        Box(centre: position,
            size: Vec2(x: GameConfig.Player.halfWidth * 2,
                       y: GameConfig.Player.halfDepth * 2))
    }

    /// The bottom edge of the hitbox, which is where the sprite is anchored.
    var feet: Vec2 {
        Vec2(x: position.x, y: position.y - GameConfig.Player.halfDepth)
    }

    /// Whether the item in this hotbar slot can be used right now.
    ///
    /// The one answer, asked by the systems that act on it and by the tap on the
    /// hotbar that raises it - so what the player is allowed to do and what the
    /// simulation allows can never disagree.
    ///
    /// It said "the hotbar that greys it out" for a long time, then nothing greyed
    /// out and a separate refusesTap answered the bar instead. Both of those are
    /// gone; a tap on a slot spends what is in it, and this decides whether it may.
    func canUse(slot index: Int) -> Bool {
        guard isAlive,
              inventory.slots.indices.contains(index),
              let stack = inventory.slots[index] else { return false }

        switch stack.type {
        case .bomb, .stink:
            return true
        // A perk is switched on rather than aimed, so the button will do - but
        // only while one is not already running. Everything else about "one at a
        // time" follows from this single answer: the hotbar greys the slot, the
        // button goes faint, and ConsumableSystem refuses the command.
        case .perk:
            return perk == nil

        case .chest, .arcade, .turret:
            // Always tappable. Whether either can go down HERE depends on the tile
            // you then pick, which is the placing system's call - the hotbar cannot
            // answer it and should not pretend to.
            return true
        case .bandage, .medkit:
            // Using one on full health would throw it away for nothing.
            return health < maxHealth

        // The no-downgrade rule, and the only place it is written. The hotbar greys
        // the slot out from this same answer, so a spare you cannot use yet LOOKS
        // unusable - and lights up by itself the moment you respawn bare-headed.
        case .helmet(let tier):
            return tier > helmet
        case .blaster(let tier):
            return tier > blaster
        }
    }

    // refusesTap USED TO LIVE HERE, and it is worth saying what it was for and why
    // it is gone rather than leaving a hole.
    //
    // It was canUse with healing excused: a bandage at full health fails canUse,
    // and refusing a TAP on one would have been wrong while a tap only picked the
    // slot out. Picking a bandage out before a fight is a reasonable thing to want,
    // and the warning belonged on the button that would actually spend it.
    //
    // A tap spends it now - see GameScene.tapHotbar - so there is no gap left
    // between what the screen allows and what the simulation allows, and canUse is
    // the one answer again. Which is where it started: the note on canUse below
    // still says it is "the one answer, asked by the systems that act on it and by
    // the hotbar", and that is true once more.

    /// How well equipped this actor is, from 0 to 12.
    ///
    /// Helmet rung plus blaster rungs above the starter. Used to price a kill: what
    /// somebody was carrying is the closest thing there is to how hard they were to
    /// take down, and it is already sitting on the actor rather than needing to be
    /// tracked.
    var gearWorth: Int {
        helmet.rawValue + (blaster.rawValue - BlasterTier.starting.rawValue)
    }

    /// Whether this item could be taken at all, from wherever it is coming from.
    ///
    /// An upgrade is always takeable, room or no room, because it goes ONTO the
    /// actor rather than into a slot. Everything else - gear at or below what is
    /// already worn included - needs somewhere to sit. A spare is worth carrying;
    /// it is not worth a full bag.
    func canAcquire(_ type: ItemType) -> Bool {
        if case .helmet(let tier) = type, tier > helmet { return true }
        if case .blaster(let tier) = type, tier > blaster { return true }
        return inventory.canAccept(type)
    }

    /// Whether this is worth bending down for.
    ///
    /// Stricter than canAcquire, and only for things lying on the ground: a helmet
    /// or a blaster is taken only if it BEATS what you are wearing. Anything at or
    /// below your own rung is left where it is.
    ///
    /// The bag is four slots. Before this, walking across a map after a firefight
    /// filled it with gear a rung or two under what was already on your head -
    /// none of it usable, all of it in the way of the medkit you actually wanted,
    /// and the only cure was throwing things away one at a time. The theory was
    /// that a spare is insurance against dying and dropping a rung; in practice
    /// nobody banks a spare, they just carry rubbish.
    ///
    /// Chests are deliberately NOT held to this rule. Taking something out of a
    /// chest is a decision somebody made on purpose, and a raider standing in an
    /// enemy base looking at a Rare helmet they cannot use may still want it for
    /// the tokens - see ChestSystem, which asks canAcquire.
    /// Whether walking over this is worth stopping for.
    ///
    /// An upgrade always is. A SPARE now is too, and that is a reversal: gear worse
    /// than what you had on used to be left on the grass, because picking it up was
    /// clutter with nothing to spend it on - the bag filled with helmets nobody had
    /// a use for.
    ///
    /// There is a use for them now. Dying takes everything, so a spare in a chest
    /// is the difference between coming back and starting again, and a rule that
    /// refuses to let you carry one home is a rule against the whole point of
    /// owning a base.
    ///
    /// Gear has no special case at all now, which is the third setting for this and
    /// the first one that never refuses something a player is standing over.
    ///
    /// It used to skip the bottom rung - a Common helmet, a Blaster 2 - on the
    /// argument that they are what the crates hand out in the first minute, so
    /// banking one banks nothing. True of a crate, and wrong everywhere else: a
    /// chest cracked in somebody's base spills three items, and if one of them was a
    /// Common you stood on it and nothing happened. The reward for the longest
    /// errand in the game silently declined to exist.
    ///
    /// So gear obeys the same rule as everything else: you take it if you can hold
    /// it. Upgrades never need a slot, because they go ON you rather than in the
    /// bag - see canAcquire - so the only thing that ever turns gear down now is a
    /// genuinely full bag, which the hotbar hint already explains.
    func wantsFromGround(_ type: ItemType) -> Bool {
        canAcquire(type)
    }

    /// Takes an item: worn if it beats what is on, bagged if it does not.
    ///
    /// The one place this rule lives. Walking over a helmet, pulling one out of a
    /// chest and robbing one off somebody else's shelf are the same act from the
    /// actor's point of view, and each used to answer it separately - which is
    /// three chances for them to disagree about what an upgrade is.
    ///
    /// Returns false when there was nowhere for it to go, and the caller is
    /// expected to leave it where it was rather than quietly destroying it.
    mutating func acquire(_ type: ItemType) -> Bool {
        switch type {
        case .helmet(let tier) where tier > helmet:
            // The extra capacity arrives as actual health, so a helmet found
            // mid-fight is a real reprieve and not just a longer empty bar.
            let gained = tier.maxHealth - maxHealth
            helmet = tier
            health = min(maxHealth, health + gained)
            return true

        case .blaster(let tier) where tier > blaster:
            blaster = tier
            return true

        default:
            return inventory.add(type)
        }
    }

    /// Whether this actor has any use for something lying on the ground.
    ///
    /// One answer, asked by both the pickup code and the bots deciding whether a
    /// drop is worth walking to - so a bot can never set off for something it
    /// would then decline to pick up.
    func wants(_ pickup: Pickup) -> Bool {
        switch pickup {
        case .item(let type):
            return wantsFromGround(type)
        case .token:
            // Always. Currency never fills up and never becomes the wrong kind.
            return true
        }
    }

    /// Does this actor's hitbox overlap the given tile at all?
    func overlaps(_ point: GridPoint) -> Bool {
        hitbox.intersects(Box(tile: point))
    }
}
