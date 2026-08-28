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

        // A bot that died halfway across the map should not come back still
        // pointed the way it was going. Face it out of its own base and let it
        // choose again shortly.
        if var ai = actor.ai {
            let outward = (actor.position - Vec2(x: Double(world.map.width) / 2,
                                                 y: Double(world.map.height) / 2))
            let heading = outward.length > 0 ? outward.normalized() : Vec2(x: 1, y: 0)
            ai.heading = heading
            ai.desiredHeading = heading
            ai.decisionTimer = 0
            actor.ai = ai
        }
    }
}
