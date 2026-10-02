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

            // Where this tick started, which was a legal place to stand. Kept
            // so a tick that cannot be resolved can simply not happen.
            let start = actor.position

            // One axis at a time. Moving both at once and then resolving makes
            // actors snag on the seam between two tiles.
            actor.position.x += step.x
            resolve(&actor, in: world.map, along: .horizontal, delta: step.x)

            actor.position.y += step.y
            resolve(&actor, in: world.map, along: .vertical, delta: step.y)

            // Trees are circles, so they are resolved after the grid, by pushing
            // straight back out along the surface normal. That is what gives you
            // the smooth slide around a clump instead of catching on a corner.
            //
            // Twice, because clumps can sit side by side: pushing out of one can
            // land you in the edge of the next, and a single pass left that for
            // the next tick to fix with a jolt.
            var pinned = false
            for _ in 0..<2 where !pinned {
                pinned = !resolveTrees(&actor, in: world)
            }

            // Squeezed between a tree and a wall, with no way out of the tree
            // that is not into the wall: the step is not taken at all. Letting it
            // through left the actor sunk into the tree a little further each
            // tick, until some later push freed it all at once in a jump.
            if pinned { actor.position = start }

            resolveStructures(&actor, in: world)

            world.actors[id] = actor
        }
    }

    /// Pushes the actor out of every clump it overlaps. False if one of them
    /// could not be got out of without going into a wall.
    private static func resolveTrees(_ actor: inout Actor, in world: World) -> Bool {
        for tree in world.trees {
            // Nearest point on the actor's box to the centre of the clump.
            let closest = actor.hitbox.closestPoint(to: tree.centre)

            let normal = closest - tree.centre
            let distance = normal.length

            guard distance < tree.radius else { continue }

            let push: Vec2
            if distance > 0.0001 {
                push = normal * ((tree.radius - distance) / distance)
            } else {
                // The clump's centre is inside the actor's box, so there is no
                // surface normal to use. This used to push away from the centre
                // by a guess and leave the rest for later ticks, which is the
                // jump backwards: the box is separated properly instead, along
                // whichever axis gets it clear with the shorter move.
                push = separation(of: actor, from: tree)
            }

            guard nudge(&actor, by: push, out: tree, in: world.map) else { return false }
        }
        return true
    }

    /// The shortest axis-aligned move that takes the actor's whole box clear of a
    /// clump whose centre has ended up inside it.
    private static func separation(of actor: Actor, from tree: TreePatch) -> Vec2 {
        let away = actor.position - tree.centre
        let clearX = GameConfig.Player.halfWidth + tree.radius - abs(away.x)
        let clearY = GameConfig.Player.halfDepth + tree.radius - abs(away.y)

        if clearX < clearY {
            return Vec2(x: away.x < 0 ? -clearX : clearX, y: 0)
        }
        return Vec2(x: 0, y: away.y < 0 ? -clearY : clearY)
    }

    /// Moves the actor by a push, but never into a wall.
    ///
    /// A tree beside a wall used to push straight into it, and the wall's own
    /// resolve - which assumed anything solid you overlap is something you just
    /// walked into - then threw you out of its FAR side. At the edge of the map
    /// the far side is more stone, so each tick threw you another tile out, which
    /// is the flight off the map. So a push that would end in a wall is cut down:
    /// the whole push if that is clear, otherwise just the part along the wall -
    /// and only if it actually gets the actor out of the tree. Otherwise it
    /// reports that the actor is pinned, and the tick's step is undone.
    private static func nudge(_ actor: inout Actor,
                              by push: Vec2,
                              out tree: TreePatch,
                              in map: TileMap) -> Bool {
        let start = actor.position
        let options = [start + push,
                       Vec2(x: start.x + push.x, y: start.y),
                       Vec2(x: start.x, y: start.y + push.y)]

        for spot in options
        where !overlapsWall(at: spot, for: actor.team, in: map) && isClear(of: tree, at: spot) {
            actor.position = spot
            return true
        }
        return false
    }

    /// Whether an actor standing here is out of this clump, to within a hair.
    private static func isClear(of tree: TreePatch, at position: Vec2) -> Bool {
        let box = Box(centre: position,
                      size: Vec2(x: GameConfig.Player.halfWidth * 2,
                                 y: GameConfig.Player.halfDepth * 2))
        return (box.closestPoint(to: tree.centre) - tree.centre).length >= tree.radius - 0.001
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

        // Turrets, which are the fourth kind of box and the one this list would
        // have silently missed. World.structureBlocks already knew about them -
        // this function asks the structures one type at a time instead, which is
        // exactly the shape World's own note warns about: a new kind added to five
        // places, four of them right. Without this line every figure in the game
        // walked straight through a turret while the bullets bounced off it.
        for turret in world.turrets.values {
            push(&actor, outOf: turret.hitbox, in: world)
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
    ///
    /// Only tiles that were AHEAD of the actor before this step count. The old
    /// version took every solid tile it found overlapping and put the actor on
    /// the far side of it in the direction of travel - correct for a wall you
    /// walk into, and a teleport for one you were already touching from behind.
    /// Anything left overlapping from before is now simply walked out of.
    private static func resolve(_ actor: inout Actor, in map: TileMap, along axis: Axis, delta: Double) {
        guard delta != 0 else { return }

        // The footprint is wider than it is deep, so each axis has its own half
        // extent - one square value would be wrong on both counts.
        let halfWidth = GameConfig.Player.halfWidth
        let halfDepth = GameConfig.Player.halfDepth

        // A hair of margin so the actor rests just outside the tile rather than
        // exactly on its edge, where floating point would flip-flop.
        let margin = 0.0001

        // How far a face may sit behind the leading edge and still count as
        // ahead. Generous next to the margin above, so an actor resting against a
        // wall still stops at it.
        let tolerance = 0.001

        // Where the actor was on this axis before the step.
        let before = (axis == .horizontal ? actor.position.x : actor.position.y) - delta

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
                    if delta > 0 {
                        let face = Double(col)
                        guard face >= before + halfWidth - tolerance else { continue }
                        actor.position.x = min(actor.position.x, face - halfWidth - margin)
                    } else {
                        let face = Double(col + 1)
                        guard face <= before - halfWidth + tolerance else { continue }
                        actor.position.x = max(actor.position.x, face + halfWidth + margin)
                    }
                case .vertical:
                    if delta > 0 {
                        let face = Double(row)
                        guard face >= before + halfDepth - tolerance else { continue }
                        actor.position.y = min(actor.position.y, face - halfDepth - margin)
                    } else {
                        let face = Double(row + 1)
                        guard face <= before - halfDepth + tolerance else { continue }
                        actor.position.y = max(actor.position.y, face + halfDepth + margin)
                    }
                }
            }
        }
    }
}
