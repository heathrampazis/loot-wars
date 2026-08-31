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
                guard case .placeBlock(let point) = command else { continue }
                place(at: point, by: actor, in: world)
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
        return true
    }
}
