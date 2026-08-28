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

    private(set) var lootboxes: [LootboxID: Lootbox] = [:]
    private(set) var groundItems: [GroundItemID: GroundItem] = [:]

    private var nextProjectileID = 0
    private var nextGroundItemID = 0

    /// Which actor this device is driving. Today it is the only one; later it is
    /// simply one of eight. Nothing else in the code assumes it is special.
    let localPlayerID: ActorID

    init(generated: GeneratedMap, localTeam: TeamID) {
        self.map = generated.map
        self.claims = generated.claims
        self.trees = generated.trees

        for box in generated.lootboxes {
            self.lootboxes[box.id] = box
        }

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

    // MARK: - Loot

    /// The closest lootbox within reach, or nil. Lives here so the Open button and
    /// the system that actually opens a box can never disagree about which one.
    func nearestLootbox(to position: Vec2, within range: Double) -> Lootbox? {
        var closest: Lootbox?
        var shortest = range

        for box in lootboxes.values {
            let distance = (box.position - position).length
            guard distance <= shortest else { continue }
            shortest = distance
            closest = box
        }

        return closest
    }

    func removeLootbox(_ id: LootboxID) {
        lootboxes[id] = nil
    }

    func spawnGroundItem(_ type: ItemType, at position: Vec2) {
        let id = GroundItemID(nextGroundItemID)
        nextGroundItemID += 1
        groundItems[id] = GroundItem(id: id, type: type, position: position)
    }

    func removeGroundItem(_ id: GroundItemID) {
        groundItems[id] = nil
    }

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
        // After movement, so picking things up uses where you actually ended up.
        LootSystem.update(self, commands: commands)
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
                case .placeBlock, .shoot, .openLootbox:
                    break   // other systems' business, not movement's
                }
            }
            actors[id] = actor
        }
    }
}
