//
//  ProjectileSystem.swift
//  Loot Wars
//
//  Moves shots, works out what they hit, and retires them when they run out of range.
//
//  A shot travels well under one tile per tick at the current speed, so a simple
//  point check is enough - nothing can tunnel through a wall. If projectile speed
//  ever climbs far higher, this is the function that needs sweeping collision.
//

enum ProjectileSystem {

    static func update(_ world: World, dt: Double) {
        guard !world.projectiles.isEmpty else { return }

        // Actors are checked in a fixed order. Dictionary order is not stable, and
        // with two actors overlapping, "whoever comes first" would decide who takes
        // the hit - which would make the same seed play out differently each run.
        let targets = world.actors.keys.sorted { $0.raw < $1.raw }

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

            // Somebody's machine takes the hit rather than merely absorbing it.
            //
            // Checked before the general solid test below, which would otherwise
            // eat the shot first and leave the machine untouched - the order here
            // IS the feature.
            if hitArcade(by: projectile, in: world) { continue }

            // Crates and machines are solid, so they stop a shot too - otherwise
            // bullets sail through something you demonstrably cannot walk through.
            if world.structureBlocks(projectile.position) { continue }

            if let hit = actorHit(by: projectile, in: world, order: targets) {
                CombatSystem.damage(hit, amount: projectile.damage,
                                    from: projectile.owner, in: world)
                continue
            }

            survivors.append(projectile)
        }

        world.projectiles = survivors
    }

    /// Damages an owned machine the shot landed on. Returns whether the shot was
    /// spent, which it is either way - an unowned machine still stops the bullet,
    /// it just does not care.
    ///
    /// Sorted, because this hands out damage and damage decides who dies.
    private static func hitArcade(by projectile: Projectile, in world: World) -> Bool {
        for id in world.arcades.keys.sorted(by: { $0.raw < $1.raw }) {
            guard var machine = world.arcades[id],
                  machine.hitbox.contains(projectile.position) else { continue }

            // Not the map's, and not your own - you cannot shoot your own furniture
            // apart, which would only ever be an accident.
            guard let owner = machine.owner, owner != projectile.team else { return true }

            machine.health -= projectile.damage

            guard machine.health <= 0 else {
                world.arcades[id] = machine
                world.record(.machineHit(id, at: machine.centre))
                return true
            }

            world.removeArcade(id)
            world.award(GameConfig.Score.arcadeDestroyed, to: projectile.team)
            world.awardTokens(GameConfig.Arcade.destroyedReward, to: projectile.owner)
            world.record(.blast(at: machine.centre))
            return true
        }

        return false
    }

    private static func actorHit(by projectile: Projectile,
                                 in world: World,
                                 order: [ActorID]) -> ActorID? {
        for id in order {
            guard let actor = world.actors[id] else { continue }

            // Not yourself, not your own team.
            guard actor.team != projectile.team else { continue }

            // The dead and the newly spawned are passed straight through rather
            // than absorbing the shot, so neither can be used as cover.
            guard actor.isAlive, actor.invulnerability <= 0 else { continue }

            guard actor.hitbox.contains(projectile.position) else { continue }
            return id
        }

        return nil
    }
}
