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

    let claims: [TeamID: BaseClaim]

    /// Round obstacles. Not tiles - see TreePatch for why.
    let trees: [TreePatch]

    var actors: [ActorID: Actor] = [:]
    var projectiles: [Projectile] = []

    private var nextProjectileID = 0

    /// Which actor this device is driving. Today it is the only one; later it is
    /// simply one of eight. Nothing else in the code assumes it is special.
    let localPlayerID: ActorID

    init(generated: GeneratedMap, localTeam: TeamID) {
        self.map = generated.map
        self.claims = generated.claims
        self.trees = generated.trees

        let playerID = ActorID(0)
        self.localPlayerID = playerID

        // You start in the middle of your own claim.
        let spawn = generated.claims[localTeam]?.centreTile
            ?? GridPoint(col: generated.map.width / 2, row: generated.map.height / 2)

        self.actors[playerID] = Actor(id: playerID,
                                      team: localTeam,
                                      position: spawn.center)
    }

    var localPlayer: Actor? { actors[localPlayerID] }

    func claim(for team: TeamID) -> BaseClaim? { claims[team] }

    func spawnProjectile(owner: ActorID, team: TeamID, position: Vec2, velocity: Vec2) {
        let projectile = Projectile(id: ProjectileID(nextProjectileID),
                                    owner: owner,
                                    team: team,
                                    position: position,
                                    velocity: velocity,
                                    distanceRemaining: GameConfig.Blaster.range)
        nextProjectileID += 1
        projectiles.append(projectile)
    }

    func setTile(_ tile: TileType, at point: GridPoint) {
        guard map.contains(point), map[point] != tile else { return }
        map[point] = tile
        mapRevision += 1
    }

    /// Advances the whole game by exactly one fixed step.
    func step(commands: [ActorID: [Command]], dt: Double) {
        applyMovementInput(commands)
        BuildSystem.update(self, commands: commands)
        WeaponSystem.update(self, commands: commands, dt: dt)
        MovementSystem.update(self, dt: dt)
        ProjectileSystem.update(self, dt: dt)
        tick += 1
    }

    private func applyMovementInput(_ commands: [ActorID: [Command]]) {
        for (id, list) in commands {
            guard var actor = actors[id] else { continue }
            for command in list {
                switch command {
                case .move(let direction):
                    let input = direction.clampedToUnit()
                    actor.moveInput = input
                    // Remember where we were last heading - that is where we shoot.
                    if input.length > 0.01 {
                        actor.facing = input.normalized()
                    }
                    // Left/right is tracked on its own, so walking straight up does
                    // not reset which way the figure is turned.
                    if abs(input.x) > 0.01 {
                        actor.facesLeft = input.x < 0
                    }
                case .placeBlock, .shoot:
                    break   // other systems' business, not movement's
                }
            }
            actors[id] = actor
        }
    }
}
