//
//  WeaponSystem.swift
//  Loot Wars
//
//  Decides WHEN a shot happens, and whether there is anything left to fire.
//  Where the shot goes afterwards is ProjectileSystem's job.
//
//  Rate limiting and ammo both live here rather than in the input code, which is why
//  holding the fire button down is safe, and why an AI hammering .shoot every tick
//  will fire at exactly the same rate a player does, and run dry just as fast.
//

enum WeaponSystem {

    static func update(_ world: World, commands: [ActorID: [Command]], dt: Double) {
        tickTimers(world, dt: dt)

        for (id, list) in commands {
            for command in list {
                guard case .shoot = command else { continue }
                fire(id, in: world)
                break   // one trigger pull per tick, however many times it was asked
            }
        }
    }

    private static func tickTimers(_ world: World, dt: Double) {
        for id in Array(world.actors.keys) {
            guard var actor = world.actors[id] else { continue }

            if actor.shootCooldown > 0 {
                actor.shootCooldown = max(0, actor.shootCooldown - dt)
            }

            recharge(&actor, dt: dt)

            world.actors[id] = actor
        }
    }

    /// Ammo comes back on its own, but only once you stop shooting: the timer is
    /// pushed back to the full delay on every shot, then drips a bullet at a time.
    private static func recharge(_ actor: inout Actor, dt: Double) {
        guard actor.ammo < GameConfig.Blaster.magazineSize else { return }

        actor.rechargeTimer -= dt

        while actor.rechargeTimer <= 0 && actor.ammo < GameConfig.Blaster.magazineSize {
            actor.ammo += 1
            actor.rechargeTimer += GameConfig.Blaster.rechargeInterval
        }
    }

    private static func fire(_ id: ActorID, in world: World) {
        guard var actor = world.actors[id],
              actor.isAlive,
              actor.shootCooldown <= 0,
              actor.ammo > 0 else { return }

        let direction = actor.facing.normalized()
        guard direction.length > 0 else { return }

        actor.ammo -= 1
        actor.shootCooldown = 1.0 / GameConfig.Blaster.fireRate
        // Firing pushes the refill back out to the full delay.
        actor.rechargeTimer = GameConfig.Blaster.rechargeDelay
        world.actors[id] = actor

        world.spawnProjectile(
            owner: id,
            team: actor.team,
            position: actor.position + direction * GameConfig.Blaster.muzzleOffset,
            velocity: direction * GameConfig.Blaster.projectileSpeed
        )
    }
}
