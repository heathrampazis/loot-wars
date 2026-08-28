//
//  BuildSystem.swift
//  Loot Wars
//
//  Placing blocks. Every rule about whether a block may go somewhere lives here and
//  nowhere else - the renderer draws whatever the map says, and input only ever asks.
//

enum BuildSystem {

    static func update(_ world: World, commands: [ActorID: [Command]]) {
        for (_, list) in commands {
            for command in list {
                guard case .placeBlock(let point) = command else { continue }
                place(at: point, in: world)
            }
        }
    }

    static func canPlace(at point: GridPoint, in world: World) -> Bool {
        // Only on open ground: not on terrain, trees, or an existing block.
        guard world.map[point] == .floor else { return false }

        // Never seal someone inside a wall.
        let wouldTrapSomeone = world.actors.values.contains { overlaps($0, point) }
        return !wouldTrapSomeone
    }

    @discardableResult
    static func place(at point: GridPoint, in world: World) -> Bool {
        guard canPlace(at: point, in: world) else { return false }
        world.setTile(.block, at: point)
        return true
    }

    /// Does an actor's hitbox overlap this tile at all?
    private static func overlaps(_ actor: Actor, _ point: GridPoint) -> Bool {
        let half = GameConfig.Player.halfSize
        let left = Double(point.col)
        let right = Double(point.col + 1)
        let bottom = Double(point.row)
        let top = Double(point.row + 1)

        return actor.position.x + half > left
            && actor.position.x - half < right
            && actor.position.y + half > bottom
            && actor.position.y - half < top
    }
}
