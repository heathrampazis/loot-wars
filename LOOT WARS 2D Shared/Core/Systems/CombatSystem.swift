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
            world.actors[id] = actor
        }
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

        actor.health -= max(1, amount)
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
        // Nobody is paid for a team killing itself, and nobody is paid when there is
        // no killer to speak of.
        if let attacker, let killer = world.actors[attacker], killer.team != actor.team {
            world.awardTokens(GameConfig.Tokens.perKill, to: attacker)

            var points = GameConfig.Score.kill

            // Caught inside their own walls. Their ground and their advantage, so
            // taking it off them there is worth more - and it is the reason to
            // follow somebody home rather than let them go.
            if world.claim(for: actor.team)?.contains(GridPoint(containing: actor.feet)) == true {
                points += GameConfig.Score.killInTheirBase
            }

            world.award(points, to: killer.team)
        }

        actor.health = 0
        actor.respawnTimer = GameConfig.Player.respawnDelay

        // Stop dead rather than sliding on with whatever was last pressed.
        actor.moveInput = .zero

        // Gear is always LOST on death - what is random is only whether it lands
        // on the ground for somebody else.
        //
        // This is what makes a well-equipped actor worth hunting rather than just
        // worth avoiding: killing someone in a Legendary is how you get one. The
        // chance keeps it a gamble rather than a transaction, and it rises with
        // tier, so the good stuff is the stuff worth chasing.
        drop(.item(.helmet(actor.helmet)), chance: actor.helmet.dropChance,
             at: actor.position, in: world)
        actor.helmet = .none

        // A starter blaster never drops - everybody already has one, so scattering
        // them would only be a way of finding nothing.
        drop(.item(.blaster(actor.blaster)), chance: actor.blaster.dropChance,
             at: actor.position, in: world)

        actor.blaster = .starting

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
            case .bandage, .medkit, .bomb, .chest:
                break
            }
        }

        actor.inventory = Inventory()
    }

    private static func drop(_ pickup: Pickup, chance: Double, at position: Vec2, in world: World) {
        guard chance > 0, Double.random(in: 0..<1, using: &world.rng) < chance else { return }
        world.spawnGroundItem(pickup, at: scatteredSpot(near: position, in: world))
    }

    /// Flings a drop clear of where its owner fell.
    ///
    /// Without this a helmet and a blaster from the same kill land on precisely the
    /// same point and only the top one is visible - the second looks like it was
    /// never dropped at all.
    private static func scatteredSpot(near position: Vec2, in world: World) -> Vec2 {
        // Bounds hoisted out rather than written inline: a range operator wrapped
        // onto a new line parses as the PREFIX form (...x) instead of the infix
        // one, and the error it produces points nowhere near the cause.
        let nearest = GameConfig.Drops.scatterRadius * 0.4
        let furthest = GameConfig.Drops.scatterRadius

        for _ in 0..<GameConfig.Drops.scatterAttempts {
            let angle = Double.random(in: 0..<(2 * Double.pi), using: &world.rng)
            let distance = Double.random(in: nearest...furthest, using: &world.rng)

            let spot = position + Vec2.fromAngle(angle) * distance
            if world.isClearForDrop(spot) { return spot }
        }

        // Hemmed in on every side: better stacked than stuck in a wall.
        return position
    }
}
