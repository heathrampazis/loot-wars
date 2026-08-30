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

        // The helmet falls where you did, and you come back bare-headed.
        //
        // This is what makes a well-equipped actor worth hunting rather than just
        // worth avoiding: killing someone in a Legendary is how you get one. It
        // also keeps an early lead from compounding across a whole match.
        if actor.helmet > .none {
            world.spawnGroundItem(.helmet(actor.helmet), at: actor.position)
            actor.helmet = .none
        }

        // Only upgrades are worth dropping. Everyone respawns holding a starter
        // blaster, so scattering those would just litter the map.
        if actor.blaster > .starting {
            world.spawnGroundItem(.blaster(actor.blaster), at: actor.position)
            actor.blaster = .starting
        }
    }
}
