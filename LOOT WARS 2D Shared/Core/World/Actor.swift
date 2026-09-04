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
    /// The three perks that are not regeneration all work like this - a number
    /// read at the point of use rather than a system that reaches in and edits
    /// something. Nothing has to be put back when the perk ends, nothing can be
    /// applied twice by a system that ran the same frame, and a perk that stops
    /// existing takes its effect with it in the same instant.
    var speedMultiplier: Double {
        perk == .speed ? GameConfig.Perks.speedBoost : 1
    }

    /// How hard this actor's shots hit, as a share of the blaster's own damage.
    var damageMultiplier: Double {
        perk == .strength ? GameConfig.Perks.strengthMultiplier : 1
    }

    /// The share of incoming damage this actor actually takes.
    var damageTakenShare: Double {
        perk == .resistance ? GameConfig.Perks.resistanceShare : 1
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
    /// The one answer, asked by the systems that act on it and by the hotbar that
    /// greys it out - so what the player sees and what the simulation allows can
    /// never disagree.
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

        case .chest, .arcade:
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

    /// Whether the HOTBAR should draw this slot as unavailable.
    ///
    /// Deliberately not the same question as canUse, and the difference is what a
    /// grey slot is for. Greying says "you have this and you cannot use it", which
    /// is worth saying about a spare helmet that is worse than the one you have on
    /// - that stays true until you die, and it explains itself. It is not worth
    /// saying about a bandage at full health: full health is the state you spend
    /// most of the match in, so the useful half of your bag sat grey almost all the
    /// time and the grey stopped meaning anything at all.
    ///
    /// The button still asks canUse, so a bandage on a full health bar is faint on
    /// the one control that would spend it - which is where the warning belongs,
    /// because that is the moment you would waste it.
    func showsAsUnusable(slot index: Int) -> Bool {
        guard inventory.slots.indices.contains(index),
              let stack = inventory.slots[index] else { return false }

        if stack.type.isHealing { return false }
        return !canUse(slot: index)
    }

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
            return canAcquire(type)
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
