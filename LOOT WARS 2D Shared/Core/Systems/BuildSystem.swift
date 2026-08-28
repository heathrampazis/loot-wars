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
                place(at: point, owner: actor.team, in: world)
            }
        }
    }

    static func canPlace(at point: GridPoint, owner: TeamID, in world: World) -> Bool {
        // You may only build on your own claim.
        guard world.claim(for: owner)?.contains(point) == true else { return false }

        // Only on open ground: not on terrain or an existing block.
        guard !world.map.isOccupied(point) else { return false }

        // Trees are not tiles, so they need asking about separately. Today they can
        // never land on a claim anyway, but that is a generation rule, not a
        // guarantee worth relying on here.
        guard !world.trees.contains(where: { $0.overlaps(point) }) else { return false }

        // Same for crates. They cannot land on a claim today, but that is a
        // generation rule, not a guarantee worth relying on from here.
        let tileBox = Box(tile: point)
        guard !world.lootboxes.values.contains(where: { $0.hitbox.intersects(tileBox) }) else {
            return false
        }

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
