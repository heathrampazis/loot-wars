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

    static func damage(_ id: ActorID, amount: Int, in world: World) {
        guard var actor = world.actors[id],
              actor.isAlive,
              actor.invulnerability <= 0 else { return }

        actor.health -= max(1, amount)
        actor.secondsSinceHit = 0

        if actor.health <= 0 {
            kill(&actor, in: world)
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

    private static func kill(_ actor: inout Actor, in world: World) {
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
        drop(.helmet(actor.helmet), chance: actor.helmet.dropChance, at: actor.position, in: world)
        actor.helmet = .none

        // A starter blaster never drops - everybody already has one, so scattering
        // them would only be a way of finding nothing.
        drop(.blaster(actor.blaster), chance: actor.blaster.dropChance, at: actor.position, in: world)
        actor.blaster = .starting
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
        for _ in 0..<GameConfig.Drops.scatterAttempts {
            let angle = Double.random(in: 0..<(2 * .pi), using: &world.rng)
            let distance = Double.random(in: (GameConfig.Drops.scatterRadius * 0.4)
                                            ...GameConfig.Drops.scatterRadius,
                                         using: &world.rng)

            let spot = position + Vec2.fromAngle(angle) * distance
            if world.isClearForDrop(spot) { return spot }
        }

        // Hemmed in on every side: better stacked than stuck in a wall.
        return position
    }
}
