//
//  CombatSystem.swift
//  Loot Wars
//
//  What a hit does. Nothing else in the game is allowed to change health directly -
//  every source of damage, present and future, comes through here, so the rules
//  about spawn protection and dying exist exactly once.
//

enum CombatSystem {

    static func damage(_ id: ActorID, amount: Int, in world: World) {
        guard var actor = world.actors[id],
              actor.isAlive,
              actor.invulnerability <= 0 else { return }

        actor.health -= max(1, amount)

        if actor.health <= 0 {
            kill(&actor)
        }

        world.actors[id] = actor
    }

    private static func kill(_ actor: inout Actor) {
        actor.health = 0
        actor.respawnTimer = GameConfig.Player.respawnDelay

        // Stop dead rather than sliding on with whatever was last pressed.
        actor.moveInput = .zero

        // Upgrades are deliberately kept: the design calls for aggressive play in a
        // short match, and losing your gear on death punishes exactly that.
    }
}
