//
//  BuildSystem.swift
//  Loot Wars
//
//  Placing blocks. Every rule about whether a block may go somewhere lives here and
//  nowhere else - the renderer draws whatever the map says, and input only ever asks.
//

enum BuildSystem {

    static func update(_ world: World, commands: [ActorID: [Command]]) {
        for (id, list) in commands {
            guard let actor = world.actors[id], actor.isAlive else { continue }
            for command in list {
                switch command {
                case .placeBlock(let point):
                    place(at: point, by: actor, in: world)
                case .removeBlock(let point):
                    remove(at: point, by: actor, in: world)
                // Listed rather than defaulted: a new Command should fail to
                // compile here until somebody has decided whether building cares
                // about it.
                case .move, .shoot, .openLootbox, .useItem,
                     .placeChest, .placeArcade, .storeItem, .takeItem,
                     .dropItem, .buyItem, .sellItem:
                    break
                }
            }
        }
    }

    /// Whether the ground itself is free to build on, ignoring who is asking.
    ///
    /// Split out from canPlace so a bot can plan a route to its next wall from the
    /// other side of the map, where the standing-inside rule below could not
    /// possibly be satisfied yet.
    static func isBuildableTile(_ point: GridPoint, for team: TeamID, in world: World) -> Bool {
        guard world.claim(for: team)?.contains(point) == true else { return false }
        guard !world.map.isOccupied(point) else { return false }
        guard !world.trees.contains(where: { $0.overlaps(point) }) else { return false }

        return !world.structureIntersects(Box(tile: point))
    }

    static func canPlace(at point: GridPoint, by actor: Actor, in world: World) -> Bool {
        // Not for a few seconds after being bombed - see World.canBuild. The one
        // rule in this file that is about somebody ELSE: a raider needs the hole to
        // still be there on the way out.
        guard world.canBuild(actor.team) else { return false }

        guard isBuildableTile(point, for: actor.team, in: world) else { return false }

        // You build your base from inside it. Measured from the feet, so it is
        // "standing on your own ground" rather than "leaning over it".
        guard world.claim(for: actor.team)?.contains(GridPoint(containing: actor.feet)) == true else {
            return false
        }

        // You may block yourself in - you can walk back out through your own wall.
        // Sealing an enemy inside one is not allowed.
        let wouldTrapAnEnemy = world.actors.values.contains {
            $0.team != actor.team && $0.overlaps(point)
        }
        return !wouldTrapAnEnemy
    }

    @discardableResult
    static func place(at point: GridPoint, by actor: Actor, in world: World) -> Bool {
        guard canPlace(at: point, by: actor, in: world) else { return false }
        world.setTile(.block(owner: actor.team), at: point)
        world.award(GameConfig.Score.wallPlaced, to: actor.team)

        // That may have been the tile that closed it - see World.recordSealIfNeeded.
        world.recordSealIfNeeded(for: actor.team)
        return true
    }

    // MARK: - Taking one back down

    /// Your own wall, and only from inside your own base.
    ///
    /// Deliberately the mirror of canPlace rather than a looser rule of its own. If
    /// you had to be standing in your claim to put a wall up, the same should be
    /// true of pulling it down - otherwise a base could be dismantled from outside
    /// it, which is what raiding is for.
    static func canRemove(at point: GridPoint, by actor: Actor, in world: World) -> Bool {
        guard world.map[point].blockOwner == actor.team else { return false }
        return world.claim(for: actor.team)?.contains(GridPoint(containing: actor.feet)) == true
    }

    @discardableResult
    static func remove(at point: GridPoint, by actor: Actor, in world: World) -> Bool {
        guard canRemove(at: point, by: actor, in: world) else { return false }

        // No refund, because blocks are not yet a resource - there is nothing to
        // give back. The day they cost something, this is where that goes.
        world.setTile(.floor, at: point)
        return true
    }
}
