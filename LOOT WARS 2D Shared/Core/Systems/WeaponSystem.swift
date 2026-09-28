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

    /// Points the weapon, and nothing else.
    ///
    /// Split out of aimAndFire for a Command that aimed without firing - the aim
    /// stick was going to throw bombs, and it had to steer without the blaster
    /// going off. That did not survive contact (see GameScene.throwButton), and
    /// the Command went with it.
    ///
    /// This stayed, because the split is worth having on its own: aimAndFire now
    /// reads as the two things it does rather than as one block that happens to set
    /// facing halfway down, and the next caller that wants to point somebody
    /// without shooting has somewhere to go.
    private static func point(_ id: ActorID, towards direction: Vec2,
                              in world: World) -> Vec2? {
        guard var actor = world.actors[id], actor.isAlive else { return nil }

        let aim = direction.normalized()
        guard aim.length > 0 else { return nil }

        // Aiming happens whether or not a shot goes off. An actor waiting on its
        // cooldown still has the blaster pointed at what it means to hit, and an
        // actor lining up a bomb is doing the same thing with no trigger at all.
        actor.aim = aim
        if abs(aim.x) > 0.01 {
            actor.facesLeft = aim.x < 0
        }

        world.actors[id] = actor
        return aim
    }

    private static func aimAndFire(_ id: ActorID, towards direction: Vec2, in world: World) {
        guard let aim = point(id, towards: direction, in: world),
              var actor = world.actors[id] else { return }

        // The rate limit always applies - it is what makes a Blaster 6 different
        // from a Blaster 1. Running dry does not, unless GameConfig turns it back
        // on; see Blaster.usesAmmo for why it is off.
        guard actor.shootCooldown <= 0,
              !GameConfig.Blaster.usesAmmo || actor.ammo > 0 else {
            world.actors[id] = actor
            return
        }

        if GameConfig.Blaster.usesAmmo { actor.ammo -= 1 }
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
            // Priced when the shot is FIRED, not when it lands. A projectile
            // already in the air keeps the damage it left with, so a perk running
            // out mid-flight cannot weaken a bullet somebody has already dodged -
            // and one switched on mid-flight cannot strengthen it either.
            damage: max(1, Int((Double(actor.blaster.damage)
                                * actor.damageMultiplier).rounded()))
        )
    }
}
