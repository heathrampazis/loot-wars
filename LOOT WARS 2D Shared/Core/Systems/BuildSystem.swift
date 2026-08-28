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
            guard let actor = world.actors[id] else { continue }
            for command in list {
                guard case .placeBlock(let point) = command else { continue }
                place(at: point, owner: actor.team, in: world)
            }
        }
    }

    static func canPlace(at point: GridPoint, owner: TeamID, in world: World) -> Bool {
        // Only on open ground: not on terrain, trees, or an existing block.
        guard !world.map.isOccupied(point) else { return false }

        // You may block yourself in - you can walk back out through your own wall.
        // Sealing an enemy inside one is not allowed.
        let wouldTrapAnEnemy = world.actors.values.contains {
            $0.team != owner && $0.overlaps(point)
        }
        return !wouldTrapAnEnemy
    }

    @discardableResult
    static func place(at point: GridPoint, owner: TeamID, in world: World) -> Bool {
        guard canPlace(at: point, owner: owner, in: world) else { return false }
        world.setTile(.block(owner: owner), at: point)
        return true
    }
}
