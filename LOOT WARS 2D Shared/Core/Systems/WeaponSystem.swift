//
//  WeaponSystem.swift
//  Loot Wars
//
//  Aiming and firing.
//
//  Aim is its own input, separate from movement. That separation is the whole
//  reason fights work: an actor can back away while still shooting at whoever is
//  chasing it, circle round somebody while keeping the blaster on them, or hold a
//  line and retreat under fire. When aiming was a side effect of walking, every
//  one of those was impossible, and the only way to keep a weapon pointed at
//  somebody was to walk into them.
//
//  Rate limiting and ammo both live here rather than in the input code, which is
//  why holding the stick over is safe, and why an AI asking to fire every tick
//  fires at exactly the same rate a player does, and runs dry just as fast.
//

enum WeaponSystem {

    static func update(_ world: World, commands: [ActorID: [Command]], dt: Double) {
        tickTimers(world, dt: dt)

        for (id, list) in commands {
            for command in list {
                guard case .shoot(let direction) = command else { continue }
                aimAndFire(id, towards: direction, in: world)
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

    private static func aimAndFire(_ id: ActorID, towards direction: Vec2, in world: World) {
        guard var actor = world.actors[id], actor.isAlive else { return }

        let aim = direction.normalized()
        guard aim.length > 0 else { return }

        // Aiming happens whether or not the shot goes off. An actor waiting on its
        // cooldown still has the blaster pointed at what it means to hit.
        actor.aim = aim
        if abs(aim.x) > 0.01 {
            actor.facesLeft = aim.x < 0
        }

        guard actor.shootCooldown <= 0, actor.ammo > 0 else {
            world.actors[id] = actor
            return
        }

        actor.ammo -= 1
        actor.shootCooldown = 1.0 / GameConfig.Blaster.fireRate
        // Firing pushes the refill back out to the full delay.
        actor.rechargeTimer = GameConfig.Blaster.rechargeDelay
        world.actors[id] = actor

        world.spawnProjectile(
            owner: id,
            team: actor.team,
            // Out of the end of the barrel you can actually see - the offset comes
            // from the blaster the actor is holding, and the renderer draws the gun
            // from the same numbers.
            position: actor.position + aim * actor.blaster.muzzleOffset,
            velocity: aim * GameConfig.Blaster.projectileSpeed,
            damage: actor.blaster.damage
        )
    }
}
