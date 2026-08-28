//
//  RespawnSystem.swift
//  Loot Wars
//
//  Counts the dead back in, and runs down spawn protection.
//

enum RespawnSystem {

    static func update(_ world: World, dt: Double) {
        for id in Array(world.actors.keys) {
            guard var actor = world.actors[id] else { continue }

            if actor.invulnerability > 0 {
                actor.invulnerability = max(0, actor.invulnerability - dt)
            }

            if let timer = actor.respawnTimer {
                let remaining = timer - dt
                if remaining <= 0 {
                    respawn(&actor, in: world)
                } else {
                    actor.respawnTimer = remaining
                }
            }

            world.actors[id] = actor
        }
    }

    private static func respawn(_ actor: inout Actor, in world: World) {
        actor.respawnTimer = nil
        actor.health = GameConfig.Player.maxHealth
        actor.ammo = GameConfig.Blaster.magazineSize
        actor.invulnerability = GameConfig.Player.spawnProtection

        actor.moveInput = .zero
        actor.shootCooldown = 0
        actor.rechargeTimer = 0

        // Back to the middle of your own claim - the one place on the map that is
        // always yours.
        if let claim = world.claim(for: actor.team) {
            actor.position = claim.centreTile.center
        }

        // A bot that died halfway across the map should not set off for its old
        // destination the moment it comes back. Make it think again immediately.
        if var ai = actor.ai {
            ai.destination = actor.position
            ai.positionAtLastDecision = actor.position
            ai.decisionTimer = 0
            actor.ai = ai
        }
    }
}
