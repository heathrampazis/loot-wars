//
//  SupplyDropSystem.swift
//  Loot Wars
//
//  Golden crates that land in the last part of a match.
//
//  The point of one is the FIGHT, not the loot. It comes down in the open middle
//  of the map, everybody can see which way it is, and it stays shut for a
//  countdown - so the people who want it arrive at about the same time and have
//  to settle it. Whoever is left standing when it opens gets one piece of the best
//  gear in the game.
//
//  Everything about opening one goes through the ordinary crate path: a supply
//  drop IS a Lootbox, with a lock on it (see Lootbox.supply). World.reachableLootbox
//  refuses a locked one, so the Open button, the reach rim and the bots cannot
//  offer to open it early; LootSystem pays it out; World.removeLootbox does not
//  bring it back.
//

import Foundation

enum SupplyDropSystem {

    static func update(_ world: World, dt: Double) {
        world.tickSupplyLocks(dt: dt)

        guard world.supplyDropsSent < GameConfig.SupplyDrop.maxDrops else { return }

        let first = GameConfig.SupplyDrop.firstAt * GameConfig.Match.duration
        let due = first + Double(world.supplyDropsSent) * GameConfig.SupplyDrop.interval
        guard world.elapsed >= due else { return }

        // No spot free right now - somebody is standing on every candidate, which
        // on this map means never - so try again next tick rather than skipping
        // the drop.
        guard let tile = landingSpot(in: world) else { return }
        world.spawnSupplyDrop(at: tile)
    }

    /// The one item inside. See GameConfig.SupplyDrop.loot.
    static func roll(using rng: inout SeededRandom) -> Pickup {
        let table = GameConfig.SupplyDrop.loot
        let total = table.reduce(0) { $0 + $1.weight }
        var pick = Int.random(in: 0..<total, using: &rng)

        for row in table {
            if pick < row.weight { return row.pickup }
            pick -= row.weight
        }
        return table[0].pickup
    }

    /// Somewhere in the contested middle, in the open, clear of every base and of
    /// any drop still waiting to be opened.
    ///
    /// "In the open" means the tile and all eight around it are walkable, so a
    /// drop never lands wedged against a tree where only one side can reach it.
    /// Candidates are gathered in row order and one is drawn with the world's own
    /// generator, so a seed always drops them in the same places.
    static func landingSpot(in world: World) -> GridPoint? {
        let map = world.map
        let middle = Vec2(x: Double(map.width) / 2, y: Double(map.height) / 2)
        let reach = GameConfig.SupplyDrop.spread * Double(min(map.width, map.height)) / 2
        let waiting = world.supplyDrops.map(\.position)

        var candidates: [GridPoint] = []

        for row in 0..<map.height {
            for col in 0..<map.width {
                let tile = GridPoint(col: col, row: row)
                guard (tile.center - middle).length <= reach else { continue }
                guard isOpen(around: tile, in: world) else { continue }
                guard clearOfBases(tile, in: world) else { continue }
                guard !world.awaitsCrate(near: tile) else { continue }
                guard !waiting.contains(where: {
                    ($0 - tile.center).length < GameConfig.SupplyDrop.dropSpacing
                }) else { continue }

                let box = Box(centre: tile.center, size: GameConfig.Loot.lootboxSize)
                guard !world.actors.values.contains(where: {
                    $0.isAlive && $0.hitbox.intersects(box)
                }) else { continue }

                candidates.append(tile)
            }
        }

        guard !candidates.isEmpty else { return nil }
        return candidates[Int.random(in: 0..<candidates.count, using: &world.rng)]
    }

    private static func isOpen(around tile: GridPoint, in world: World) -> Bool {
        for dc in -1...1 {
            for dr in -1...1 {
                let spot = GridPoint(col: tile.col + dc, row: tile.row + dr)
                guard world.map.contains(spot),
                      world.map[spot] == .floor,
                      !world.treeTiles.contains(spot),
                      !world.structureOccupies(spot) else { return false }
            }
        }
        return true
    }

    private static func clearOfBases(_ tile: GridPoint, in world: World) -> Bool {
        let clearance = GameConfig.SupplyDrop.baseClearance
        for claim in world.claims.values {
            // Distance from the tile to the claim's square, zero if inside it.
            let lowX = Double(claim.origin.col), highX = lowX + Double(claim.size)
            let lowY = Double(claim.origin.row), highY = lowY + Double(claim.size)
            let point = tile.center
            let dx = max(lowX - point.x, 0, point.x - highX)
            let dy = max(lowY - point.y, 0, point.y - highY)
            if (dx * dx + dy * dy).squareRoot() < clearance { return false }
        }
        return true
    }
}
