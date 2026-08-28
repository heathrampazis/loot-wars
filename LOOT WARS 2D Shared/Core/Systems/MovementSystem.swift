//
//  MovementSystem.swift
//  Loot Wars
//

import Foundation

enum MovementSystem {

    static func update(_ world: World, dt: Double) {
        // Snapshot the keys: writing back into the dictionary while iterating its
        // live key view would copy the storage on every single write.
        for id in Array(world.actors.keys) {
            guard var actor = world.actors[id] else { continue }

            let step = actor.moveInput.clampedToUnit() * (GameConfig.Player.moveSpeed * dt)

            // One axis at a time. Moving both at once and then resolving makes
            // actors snag on the seam between two tiles.
            actor.position.x += step.x
            resolve(&actor, in: world.map, along: .horizontal, delta: step.x)

            actor.position.y += step.y
            resolve(&actor, in: world.map, along: .vertical, delta: step.y)

            world.actors[id] = actor
        }
    }

    private enum Axis {
        case horizontal
        case vertical
    }

    /// Pushes the actor back out of anything solid it just moved into.
    /// What counts as solid depends on the actor's team - your own walls do not.
    private static func resolve(_ actor: inout Actor, in map: TileMap, along axis: Axis, delta: Double) {
        guard delta != 0 else { return }

        let half = GameConfig.Player.halfSize
        // A hair of margin so the actor rests just outside the tile rather than
        // exactly on its edge, where floating point would flip-flop.
        let margin = 0.0001

        let minCol = Int(floor(actor.position.x - half))
        let maxCol = Int(floor(actor.position.x + half))
        let minRow = Int(floor(actor.position.y - half))
        let maxRow = Int(floor(actor.position.y + half))

        for col in minCol...maxCol {
            for row in minRow...maxRow {
                let point = GridPoint(col: col, row: row)
                guard map.blocksMovement(at: point, for: actor.team) else { continue }

                switch axis {
                case .horizontal:
                    actor.position.x = delta > 0
                        ? Double(col) - half - margin
                        : Double(col + 1) + half + margin
                case .vertical:
                    actor.position.y = delta > 0
                        ? Double(row) - half - margin
                        : Double(row + 1) + half + margin
                }
            }
        }
    }
}
