//
//  World.swift
//  Loot Wars
//
//  THE game state. If it is not in here, it is not game state.
//  Note there is no SpriteKit anywhere in Core - that is deliberate and worth
//  protecting. It is what would let this same code run on a host or a server.
//

final class World {

    private(set) var tick: Int = 0

    /// Read freely, but change only through setTile, so the renderer always knows
    /// when the map has moved on.
    private(set) var map: TileMap

    /// Bumped every time a tile changes. The renderer compares this against what it
    /// last drew, which is far cheaper than diffing four thousand tiles a frame.
    private(set) var mapRevision: Int = 0

    var actors: [ActorID: Actor] = [:]

    /// Which actor this device is driving. Today it is the only one; later it is
    /// simply one of eight. Nothing else in the code assumes it is special.
    let localPlayerID: ActorID

    init(map: TileMap, playerSpawn: Vec2) {
        self.map = map
        let playerID = ActorID(0)
        self.localPlayerID = playerID
        self.actors[playerID] = Actor(id: playerID, position: playerSpawn)
    }

    var localPlayer: Actor? { actors[localPlayerID] }

    func setTile(_ tile: TileType, at point: GridPoint) {
        guard map.contains(point), map[point] != tile else { return }
        map[point] = tile
        mapRevision += 1
    }

    /// Advances the whole game by exactly one fixed step.
    func step(commands: [ActorID: [Command]], dt: Double) {
        applyMovementInput(commands)
        BuildSystem.update(self, commands: commands)
        MovementSystem.update(self, dt: dt)
        tick += 1
    }

    private func applyMovementInput(_ commands: [ActorID: [Command]]) {
        for (id, list) in commands {
            guard var actor = actors[id] else { continue }
            for command in list {
                switch command {
                case .move(let direction):
                    actor.moveInput = direction.clampedToUnit()
                case .placeBlock:
                    break   // BuildSystem's business, not movement's
                }
            }
            actors[id] = actor
        }
    }
}
