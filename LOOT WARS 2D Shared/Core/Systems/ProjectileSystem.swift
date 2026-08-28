//
//  ProjectileSystem.swift
//  Loot Wars
//
//  Moves shots, stops them at walls, and retires them when they run out of range.
//
//  A shot travels well under one tile per tick at the current speed, so a simple
//  point check is enough - nothing can tunnel through a wall. If projectile speed
//  ever climbs far higher, this is the function that needs sweeping collision.
//

enum ProjectileSystem {

    static func update(_ world: World, dt: Double) {
        guard !world.projectiles.isEmpty else { return }

        var survivors: [Projectile] = []
        survivors.reserveCapacity(world.projectiles.count)

        for var projectile in world.projectiles {
            let step = projectile.velocity * dt
            projectile.position = projectile.position + step
            projectile.distanceRemaining -= step.length

            if projectile.distanceRemaining <= 0 { continue }

            // Walls stop bullets - including your own. You can walk through your
            // base, but you cannot shoot through it.
            if world.map.isOccupied(GridPoint(containing: projectile.position)) { continue }

            if world.trees.contains(where: { $0.contains(projectile.position) }) { continue }

            survivors.append(projectile)
        }

        world.projectiles = survivors
    }
}
