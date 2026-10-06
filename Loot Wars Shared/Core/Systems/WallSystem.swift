//
//  WallSystem.swift
//  Loot Wars
//
//  Shooting your own walls down.
//
//  A player can take their own wall back two ways: hold a finger on it (see
//  BuildSystem.remove), or shoot it until it breaks. The second exists because
//  holding means walking up to it, and a player rearranging their base mid-fight,
//  or knocking a door through to get out, wants to do it from where they stand.
//
//  PLAYERS ONLY. A shot from a bot, or from a turret, never hurts its own team's
//  walls: bots have no reason to take their own base apart, and a bot defending
//  from inside its walls would otherwise shoot holes in them by accident every
//  time it fired at somebody outside.
//
//  Damage does not stick around. A wall left alone for a few seconds is whole
//  again, so the odd stray shot at your own wall in a fight costs nothing - only
//  meaning to knock it down knocks it down.
//

import Foundation

/// How much of a wall's shot-health has been taken, and how long ago.
struct WallDamage {
    var taken: Int
    var sinceHit: Double
}

enum WallSystem {

    /// Mends walls nobody has shot for a while.
    static func update(_ world: World, dt: Double) {
        guard !world.wallDamage.isEmpty else { return }

        for tile in world.wallDamage.keys.sorted(by: { ($0.row, $0.col) < ($1.row, $1.col) }) {
            guard var damage = world.wallDamage[tile] else { continue }
            damage.sinceHit += dt
            world.wallDamage[tile] = damage.sinceHit >= GameConfig.Build.wallMendDelay ? nil : damage
        }
    }

    /// A shot has hit the wall on this tile. Hurts it only when it is the
    /// shooter's own wall and the shooter is a player.
    static func shot(_ tile: GridPoint, by projectile: Projectile, in world: World) {
        guard world.map.contains(tile),
              let owner = world.map[tile].blockOwner,
              owner == projectile.team,
              !projectile.fromTurret,
              let shooter = world.actors[projectile.owner],
              shooter.ai == nil else { return }

        var damage = world.wallDamage[tile] ?? WallDamage(taken: 0, sinceHit: 0)
        damage.taken += projectile.damage
        damage.sinceHit = 0

        guard damage.taken < GameConfig.Build.wallShotHealth else {
            // Down. The same as prising it out by hand: the tile is floor again
            // and BlockRenderer crumbles it.
            world.wallDamage[tile] = nil
            world.setTile(.floor, at: tile)
            return
        }

        world.wallDamage[tile] = damage
        world.record(.wallHit(tile, at: tile.center))
    }
}
