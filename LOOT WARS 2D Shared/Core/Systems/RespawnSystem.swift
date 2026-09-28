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
        actor.health = actor.maxHealth
        actor.ammo = GameConfig.Blaster.magazineSize
        actor.invulnerability = GameConfig.Player.spawnProtection

        actor.moveInput = .zero
        actor.shootCooldown = 0
        actor.rechargeTimer = 0
        actor.secondsSinceHit = 999

        // Back to the middle of your own claim - the one place on the map that is
        // always yours.
        if let claim = world.claim(for: actor.team) {
            actor.position = claim.centreTile.center
        }

        // Topped up to whatever the clock says a respawn is worth by now.
        //
        // Raised to the floor and never lowered to it, which is the whole
        // distinction: somebody who kept a Legendary through a death - they did
        // not, death strips it, but somebody who bought one back - is not pulled
        // down to a Rare by coming back to life. See GameConfig.Player.respawnFloor
        // for why the last ninety seconds needed this at all.
        if let kit = GameConfig.Player.respawnKit(at: world.matchProgress) {
            if actor.helmet < kit.helmet {
                actor.helmet = kit.helmet
                // Health is scaled by the helmet, and it was just set to the old
                // maximum. Re-topped here rather than moved above, because the
                // order is the bug: fill first and the new helmet's extra hearts
                // arrive empty.
                actor.health = actor.maxHealth
            }
            if actor.blaster < kit.blaster { actor.blaster = kit.blaster }
        }

        // And something to heal with - see GameConfig.Player.respawnHeals.
        for item in GameConfig.Player.respawnHealKit(at: world.matchProgress) {
            _ = actor.inventory.add(item)
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
