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

            // The perk multiplies the standard speed rather than replacing it, so
            // there is still exactly one number that says how fast anybody walks.
            let speed = GameConfig.Player.moveSpeed * actor.speedMultiplier
            let step = actor.moveInput.clampedToUnit() * (speed * dt)

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
            push(&actor, outOf: crate.hitbox, in: world)
        }
        for arcade in world.arcades.values {
            push(&actor, outOf: arcade.hitbox, in: world)
        }
        for chest in world.chests.values {
            push(&actor, outOf: chest.hitbox, in: world)
        }
    }

    /// Box against box: find how deeply the two overlap on each axis and push back
    /// out along the shallower one, which is the side the actor came in from.
    ///
    /// The push is CHECKED against the walls before it is applied, and that check is
    /// the fix for getting stuck on a chest. The figure is 1.72 tiles tall and a
    /// chest is 0.7, so a chest standing a tile from the wall of a small base leaves
    /// a gap the figure does not fit in - and the two resolvers then fought each
    /// other, one shoving out of the chest into the wall and the other shoving back
    /// out of the wall into the chest, sixty times a second. From the outside that
    /// is a player who has simply stopped moving.
    ///
    /// So each axis is tried in turn - the shallow one first, because that is the
    /// side you came in from - and the first that does not land in a wall wins. If
    /// NEITHER does, nothing is applied: the actor is genuinely wedged, and letting
    /// them stand in the chest for a moment and walk out under their own steam is
    /// far better than pinning them between two solids until the match ends.
    private static func push(_ actor: inout Actor, outOf solid: Box, in world: World) {
        let actorBox = actor.hitbox
        guard actorBox.intersects(solid) else { return }

        let overlapX = min(actorBox.upper.x, solid.upper.x) - max(actorBox.lower.x, solid.lower.x)
        let overlapY = min(actorBox.upper.y, solid.upper.y) - max(actorBox.lower.y, solid.lower.y)

        let sideways = Vec2(x: actor.position.x
                            + (actor.position.x < solid.centre.x ? -overlapX : overlapX),
                            y: actor.position.y)
        let upright = Vec2(x: actor.position.x,
                           y: actor.position.y
                           + (actor.position.y < solid.centre.y ? -overlapY : overlapY))

        for spot in (overlapX < overlapY ? [sideways, upright] : [upright, sideways])
        where !overlapsWall(at: spot, for: actor.team, in: world.map) {
            actor.position = spot
            return
        }
    }

    /// Whether an actor standing here would be inside something solid.
    ///
    /// The same test `resolve` uses, asked of a hypothetical position rather than
    /// of the actor's own - so the two can never disagree about what a wall is.
    private static func overlapsWall(at position: Vec2,
                                     for team: TeamID,
                                     in map: TileMap) -> Bool {
        let halfWidth = GameConfig.Player.halfWidth
        let halfDepth = GameConfig.Player.halfDepth

        let minCol = Int(floor(position.x - halfWidth))
        let maxCol = Int(floor(position.x + halfWidth))
        let minRow = Int(floor(position.y - halfDepth))
        let maxRow = Int(floor(position.y + halfDepth))

        for col in minCol...maxCol {
            for row in minRow...maxRow where
                map.blocksMovement(at: GridPoint(col: col, row: row), for: team) {
                return true
            }
        }

        return false
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
