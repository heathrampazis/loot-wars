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
            guard var actor = world.actors[id], actor.isAlive else { continue }

            let step = actor.moveInput.clampedToUnit() * (GameConfig.Player.moveSpeed * dt)

            // One axis at a time. Moving both at once and then resolving makes
            // actors snag on the seam between two tiles.
            actor.position.x += step.x
            resolve(&actor, in: world.map, along: .horizontal, delta: step.x)

            actor.position.y += step.y
            resolve(&actor, in: world.map, along: .vertical, delta: step.y)

            // Trees are circles, so they are resolved after the grid, by pushing
            // straight back out along the surface normal. That is what gives you
            // the smooth slide around a clump instead of catching on a corner.
            resolveTrees(&actor, in: world.trees)
            resolveStructures(&actor, in: world)

            world.actors[id] = actor
        }
    }

    private static func resolveTrees(_ actor: inout Actor, in trees: [TreePatch]) {
        for tree in trees {
            // Nearest point on the actor's box to the centre of the clump.
            let closest = actor.hitbox.closestPoint(to: tree.centre)

            var normal = closest - tree.centre
            var distance = normal.length

            guard distance < tree.radius else { continue }

            if distance < 0.0001 {
                // The clump's centre is inside the actor's box, so there is no
                // surface normal to use. Push away from the centre instead; it
                // untangles over the next tick or two.
                normal = actor.position - tree.centre
                distance = normal.length
                if distance < 0.0001 {
                    normal = Vec2(x: 0, y: 1)
                    distance = 0.0001
                }
            }

            let push = (tree.radius - distance) / distance
            actor.position = actor.position + normal * push
        }
    }

    /// Crates and arcade machines are both boxes, and both push out of the way the
    /// same. A machine is simply a bigger one - which is the whole reason this is
    /// one function taking a Box rather than two that happen to agree.
    private static func resolveStructures(_ actor: inout Actor, in world: World) {
        for crate in world.lootboxes.values {
            push(&actor, outOf: crate.hitbox)
        }
        for arcade in world.arcades {
            push(&actor, outOf: arcade.hitbox)
        }
    }

    /// Box against box: find how deeply the two overlap on each axis and push back
    /// out along the shallower one, which is the side the actor came in from.
    private static func push(_ actor: inout Actor, outOf solid: Box) {
        let actorBox = actor.hitbox
        guard actorBox.intersects(solid) else { return }

        let overlapX = min(actorBox.upper.x, solid.upper.x) - max(actorBox.lower.x, solid.lower.x)
        let overlapY = min(actorBox.upper.y, solid.upper.y) - max(actorBox.lower.y, solid.lower.y)

        if overlapX < overlapY {
            actor.position.x += actor.position.x < solid.centre.x ? -overlapX : overlapX
        } else {
            actor.position.y += actor.position.y < solid.centre.y ? -overlapY : overlapY
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

        // The footprint is wider than it is deep, so each axis has its own half
        // extent - one square value would be wrong on both counts.
        let halfWidth = GameConfig.Player.halfWidth
        let halfDepth = GameConfig.Player.halfDepth

        // A hair of margin so the actor rests just outside the tile rather than
        // exactly on its edge, where floating point would flip-flop.
        let margin = 0.0001

        let minCol = Int(floor(actor.position.x - halfWidth))
        let maxCol = Int(floor(actor.position.x + halfWidth))
        let minRow = Int(floor(actor.position.y - halfDepth))
        let maxRow = Int(floor(actor.position.y + halfDepth))

        for col in minCol...maxCol {
            for row in minRow...maxRow {
                let point = GridPoint(col: col, row: row)
                guard map.blocksMovement(at: point, for: actor.team) else { continue }

                switch axis {
                case .horizontal:
                    actor.position.x = delta > 0
                        ? Double(col) - halfWidth - margin
                        : Double(col + 1) + halfWidth + margin
                case .vertical:
                    actor.position.y = delta > 0
                        ? Double(row) - halfDepth - margin
                        : Double(row + 1) + halfDepth + margin
                }
            }
        }
    }
}
