//
//  WeaponSystem.swift
//  Loot Wars
//
//  Decides WHEN a shot happens. Where it goes afterwards is ProjectileSystem's job.
//
//  Rate limiting lives here rather than in the input code, which is why holding the
//  fire button down is safe, and why an AI hammering .shoot every tick will fire at
//  exactly the same rate a player does.
//

enum WeaponSystem {

    static func update(_ world: World, commands: [ActorID: [Command]], dt: Double) {
        coolDown(world, dt: dt)

        for (id, list) in commands {
            for command in list {
                guard case .shoot = command else { continue }
                fire(id, in: world)
                break   // one trigger pull per tick, however many times it was asked
            }
        }
    }

    private static func coolDown(_ world: World, dt: Double) {
        for id in Array(world.actors.keys) {
            guard var actor = world.actors[id], actor.shootCooldown > 0 else { continue }
            actor.shootCooldown = max(0, actor.shootCooldown - dt)
            world.actors[id] = actor
        }
    }

    private static func fire(_ id: ActorID, in world: World) {
        guard var actor = world.actors[id], actor.shootCooldown <= 0 else { return }

        let direction = actor.facing.normalized()
        guard direction.length > 0 else { return }

        actor.shootCooldown = 1.0 / GameConfig.Blaster.fireRate
        world.actors[id] = actor

        world.spawnProjectile(
            owner: id,
            team: actor.team,
            position: actor.position + direction * GameConfig.Blaster.muzzleOffset,
            velocity: direction * GameConfig.Blaster.projectileSpeed
        )
    }
}
