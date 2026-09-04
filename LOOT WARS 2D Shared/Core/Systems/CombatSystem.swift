//
//  CombatSystem.swift
//  Loot Wars
//
//  What a hit does. Nothing else in the game is allowed to change health directly -
//  every source of damage, present and future, comes through here, so the rules
//  about spawn protection and dying exist exactly once.
//

enum CombatSystem {

    /// Ages the "how long since I was hurt" clock every actor carries.
    ///
    /// Lives here because CombatSystem is the only thing that ever resets it, and
    /// keeping the two together means they cannot drift apart.
    static func update(_ world: World, dt: Double) {
        for id in Array(world.actors.keys) {
            guard var actor = world.actors[id] else { continue }
            actor.secondsSinceHit += dt
            recover(&actor, in: world, dt: dt)
            world.actors[id] = actor
        }
    }

    /// Health coming back, slowly, to somebody standing on their own ground.
    ///
    /// The third reason to have a base, after the chest and the machine, and the
    /// one that costs nothing to understand: home is where you get better. It is
    /// deliberately slow - a full bar takes most of half a minute - so it is a
    /// reason to go home between fights rather than a way to win one, and a
    /// bandage is still much faster than walking.
    ///
    /// Two conditions, and both matter. Inside your OWN claim, so it cannot be
    /// used by whoever is standing in your base robbing you. And only after a lull,
    /// so it never ticks during a fight on your doorstep - a defender who heals
    /// mid-firefight is a defender nobody can ever kill at home.
    private static func recover(_ actor: inout Actor, in world: World, dt: Double) {
        let athome = actor.isAlive
            && actor.health < actor.maxHealth
            && actor.secondsSinceHit >= GameConfig.Player.recoveryDelay
            && world.claim(for: actor.team)?
                .contains(GridPoint(containing: actor.feet)) == true

        // Anything that disqualifies you puts the clock back to the top, so walking
        // out and back in does not bank a portion, and being shot at home does not
        // hand you one the instant the shooting stops.
        guard athome else {
            actor.recoveryTimer = GameConfig.Player.recoveryTick
            return
        }

        actor.recoveryTimer -= dt
        guard actor.recoveryTimer <= 0 else { return }
        actor.recoveryTimer = GameConfig.Player.recoveryTick

        // A whole portion at once - see GameConfig.Player.recoveryPortion for why
        // this is deliberately lumpy rather than smooth.
        let portion = max(1, Int((Double(actor.maxHealth)
                                  * GameConfig.Player.recoveryPortion).rounded()))
        actor.health = min(actor.maxHealth, actor.health + portion)
    }

    /// - Parameter attacker: WHO did it, for the scoreboard and the purse.
    ///
    /// The actor rather than the team, which it used to be. Score belongs to a team
    /// but tokens belong to a person - they are spent by somebody standing at a
    /// shop - so crediting a kill needs to name the individual. Both callers already
    /// carry their owner's id, so this cost nothing to tighten.
    static func damage(_ id: ActorID, amount: Int, from attacker: ActorID?, in world: World) {
        guard var actor = world.actors[id],
              actor.isAlive,
              actor.invulnerability <= 0 else { return }

        // Every source of damage in the game comes through here, which is what
        // makes resistance one line rather than four. A bullet, a blast and a
        // lungful of gas are all blunted by the same share, and a perk added later
        // that halves fire damage would be blunted by it too without anybody
        // remembering to say so.
        //
        // Never below one. A perk that made you immune to something would be a perk
        // that ends fights by making them unwinnable for the other person.
        let taken = max(1, Int((Double(max(1, amount))
                                * actor.damageTakenShare).rounded()))

        actor.health -= taken
        actor.secondsSinceHit = 0

        if actor.health <= 0 {
            kill(&actor, by: attacker, in: world)
        }

        world.actors[id] = actor
    }

    /// The counterpart to damage, and here for the same reason: health has exactly
    /// one door in and one door out, so nothing can quietly overheal or revive.
    static func heal(_ id: ActorID, amount: Int, in world: World) {
        guard var actor = world.actors[id], actor.isAlive, amount > 0 else { return }

        actor.health = min(actor.maxHealth, actor.health + amount)
        world.actors[id] = actor
    }

    private static func kill(_ actor: inout Actor, by attacker: ActorID?, in world: World) {
        // What it paid, kept so the screen can say so. Both are worked out below
        // from things that are about to be thrown away - the victim's gear is
        // stripped a few lines further down, and they are moved home to respawn -
        // which is exactly why a kill has to be announced rather than noticed.
        var earned = (points: 0, tokens: 0)

        // Nobody is paid for a team killing itself, and nobody is paid when there is
        // no killer to speak of.
        if let attacker, let killer = world.actors[attacker], killer.team != actor.team {
            // Priced by what they were carrying, and read BEFORE the gear is stripped
            // a few lines down. A fresh respawn and somebody in a Cosmic with a
            // Blaster 6 are not the same job, and used to pay the same.
            let worth = actor.gearWorth

            earned.tokens = GameConfig.Tokens.perKill
                + worth * GameConfig.Tokens.perTierKilled
            world.awardTokens(earned.tokens, to: attacker)

            var points = GameConfig.Score.kill + worth * GameConfig.Score.killPerTier

            // Caught inside their own walls. Their ground and their advantage, so
            // taking it off them there is worth more - and it is the reason to
            // follow somebody home rather than let them go.
            if world.claim(for: actor.team)?.contains(GridPoint(containing: actor.feet)) == true {
                points += GameConfig.Score.killInTheirBase
            }

            earned.points = points
            world.award(points, to: killer.team)
        }

        world.record(.kill(victim: actor.id, by: attacker, at: actor.position,
                           points: earned.points, tokens: earned.tokens))

        actor.health = 0
        actor.respawnTimer = GameConfig.Player.respawnDelay

        // Stop dead rather than sliding on with whatever was last pressed.
        actor.moveInput = .zero

        // Death costs you RUNGS, not everything you own.
        //
        // It used to strip the lot, which sounds like the harshest and therefore
        // fairest rule and is neither. The gear ladder takes most of a match to
        // climb, so a single death in the last minute did not set you back, it took
        // you out of the match: bare-headed with a starter blaster against people
        // three tiers up, and no time left to climb again. The closing minutes were
        // decided by who had most recently died.
        //
        // Two helmet rungs and one blaster rung. Enough to be a real loss - a
        // Legendary comes back an Epic, and being killed twice in a row genuinely
        // hurts - without ending anyone's match, and it stacks correctly with the
        // respawn floor, which catches whatever is left at the bottom.
        //
        // What DROPS is the rung you lost, at the odds that rung has always
        // carried. That is what keeps a well-equipped actor worth hunting rather
        // than merely worth avoiding: killing somebody in a Legendary is still how
        // you get one. The chance keeps it a gamble rather than a transaction, and
        // it rises with tier, so the good stuff is still the stuff worth chasing.
        // How much a death costs eases as the clock runs down - see
        // GameConfig.Drops.rungsLost.
        let cost = GameConfig.Drops.rungsLost(at: world.matchProgress)

        let hadHelmet = actor.helmet
        actor.helmet = HelmetTier(rawValue: max(0, hadHelmet.rawValue - cost.helmet)) ?? .none

        if hadHelmet != actor.helmet {
            drop(.item(.helmet(hadHelmet)), chance: hadHelmet.dropChance,
                 at: actor.position, in: world)
        }

        // A starter blaster never drops - everybody already has one, so scattering
        // them would only be a way of finding nothing. dropChance answers that.
        let hadBlaster = actor.blaster
        actor.blaster = BlasterTier(rawValue: max(BlasterTier.starting.rawValue,
                                                  hadBlaster.rawValue - cost.blaster))
            ?? .starting

        if hadBlaster != actor.blaster {
            drop(.item(.blaster(hadBlaster)), chance: hadBlaster.dropChance,
                 at: actor.position, in: world)
        }

        // The bag goes with the body.
        //
        // Everything carried is lost, and only SOME of it lands where somebody can
        // pick it up - spare gear rolls the same tier odds worn gear does, while
        // bandages, bombs and chests simply go. That asymmetry is deliberate rather
        // than unfinished: a kill should be worth walking over to, but eight actors
        // dying repeatedly and shedding their whole bags would carpet the map in
        // loot nobody had to work for.
        //
        // It is also what keeps a chest meaningful. If pockets survived death there
        // would be no reason to bank anything, and dying would stop costing
        // anything - you would stand up and put your spare straight back on. A
        // chest is the safe place; your pockets are not.
        //
        // Read before it is emptied, obviously.
        for stack in actor.inventory.slots.compactMap({ $0 }) {
            switch stack.type {
            case .helmet(let tier):
                drop(.item(.helmet(tier)), chance: tier.dropChance,
                     at: actor.position, in: world)
            case .blaster(let tier):
                drop(.item(.blaster(tier)), chance: tier.dropChance,
                     at: actor.position, in: world)
            // Supplies scatter, sometimes. Not the whole stack - one item off it,
            // at even odds - which is the difference between restocking off a body
            // and getting a consolation prize from one.
            //
            // This is the one thing worth having from a fight you won badly. You
            // spend bandages winning a fight; without this you walked away from it
            // poorer than you arrived however well you shot, which made winning a
            // fight something to avoid doing twice.
            case .bandage, .medkit:
                drop(.item(stack.type), chance: GameConfig.Drops.healingChance,
                     at: actor.position, in: world)

            // An unspent power-up drops on the same terms healing does, and for
            // the same reason: it is the thing worth walking over for. Killing
            // somebody who was saving one and taking it off them is a better story
            // than either of you gets from it evaporating - and it is a rung of
            // pressure on hoarding, which is the mistake a perk invites.
            //
            // One that is RUNNING is not in a slot at all. It stops with the
            // person, because it was never an object.
            case .perk:
                drop(.item(stack.type), chance: GameConfig.Drops.healingChance,
                     at: actor.position, in: world)

            // Bombs and gas, on slightly worse odds than healing. A raider killed
            // on your doorstep used to take their bomb with them into nothing,
            // which made winning that fight strangely empty - they had crossed a
            // map to break your wall open and the tool for it simply stopped
            // existing.
            case .bomb, .stink:
                drop(.item(stack.type), chance: GameConfig.Drops.suppliesChance,
                     at: actor.position, in: world)

            // And what they were carrying to put down. Rare, because a machine in a
            // bag is the most valuable object on the map - but never is worse than
            // rare: killing somebody carrying one and watching it evaporate is the
            // game deleting the best thing anybody has found all match.
            case .chest, .arcade:
                drop(.item(stack.type),
                     chance: GameConfig.Drops.carriedStructureChance,
                     at: actor.position, in: world)
            }
        }

        actor.inventory = Inventory()
    }

    private static func drop(_ pickup: Pickup, chance: Double, at position: Vec2, in world: World) {
        guard chance > 0, Double.random(in: 0..<1, using: &world.rng) < chance else { return }
        world.spawnGroundItem(pickup, at: world.scatteredSpot(near: position))
    }

}
