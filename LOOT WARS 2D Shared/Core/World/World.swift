//
//  World.swift
//  Loot Wars
//
//  THE game state. If it is not in here, it is not game state.
//  Note there is no SpriteKit anywhere in Core - that is deliberate and worth
//  protecting. It is what would let this same code run on a host or a server.
//

import Foundation

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

    let baseLayouts: [TeamID: BaseLayout]

    var actors: [ActorID: Actor] = [:]
    var projectiles: [Projectile] = []

    private(set) var lootboxes: [LootboxID: Lootbox] = [:]
    private(set) var groundItems: [GroundItemID: GroundItem] = [:]

    /// An opened crate, waiting to come back in the same spot.
    private struct PendingLootbox {
        let tile: GridPoint
        var timer: Double
    }

    private var pendingLootboxes: [PendingLootbox] = []

    private var nextProjectileID = 0
    private var nextGroundItemID = 0
    private var nextLootboxID = 0

    /// The one source of randomness during play. Nothing in Core may call
    /// Int.random - everything goes through here, so a seed reproduces a match
    /// exactly, bots included.
    var rng: SeededRandom

    /// Which actor this device is driving. Today it is the only one; later it is
    /// simply one of eight. Nothing else in the code assumes it is special.
    let localPlayerID: ActorID

    init(generated: GeneratedMap) {
        self.map = generated.map
        self.claims = generated.claims
        self.trees = generated.trees
        self.baseLayouts = generated.baseLayouts

        // Offset from the map's seed, so play does not replay the same number
        // sequence that built the terrain.
        var rng = SeededRandom(seed: generated.seed &+ 0x9E37)

        var crates: [LootboxID: Lootbox] = [:]
        for box in generated.lootboxes {
            crates[box.id] = box
        }
        self.lootboxes = crates
        self.nextLootboxID = generated.lootboxes.count

        // One actor per team, standing in the middle of its own claim.
        //
        // The local player is simply one of the eight. Nothing else about it is
        // special, and nothing downstream may assume otherwise - that is what makes
        // an AI or a remote player a drop-in replacement for the joystick.
        var spawned: [ActorID: Actor] = [:]
        var local = ActorID(0)
        var brainsGiven = 0

        for index in 0..<TeamID.count {
            let team = TeamID(index)
            guard let claim = generated.claims[team] else { continue }

            let id = ActorID(index)
            let spawn = claim.centreTile.center
            var actor = Actor(id: id, team: team, position: spawn)

            if team == generated.localTeam {
                local = id
            } else if brainsGiven < GameConfig.AI.botCount {
                brainsGiven += 1
                let heading = Vec2.fromAngle(Double.random(in: 0..<(2 * .pi), using: &rng))
                actor.ai = AIState(
                    heading: heading,
                    desiredHeading: heading,
                    // Staggered, so all seven do not change their minds in unison.
                    decisionTimer: Double.random(in: GameConfig.AI.decisionInterval,
                                                 using: &rng),
                    turnPreference: Bool.random(using: &rng) ? 1 : -1
                )
            }

            spawned[id] = actor
        }

        self.actors = spawned
        self.localPlayerID = local
        self.rng = rng
    }

    var localPlayer: Actor? { actors[localPlayerID] }

    func claim(for team: TeamID) -> BaseClaim? { claims[team] }

    /// The next wall this team should lay, or nil once the base is finished.
    ///
    /// Walks the plan in order and takes the first tile that is still free, so a
    /// spot temporarily blocked by a crate is skipped rather than stalling the
    /// whole build.
    func nextBuildTile(for team: TeamID) -> GridPoint? {
        baseLayouts[team]?.tiles.first {
            BuildSystem.isBuildableTile($0, for: team, in: self)
        }
    }

    // MARK: - Loot

    /// The nearest lootbox this actor can reach, or nil.
    ///
    /// Reach is the actor's own hitbox grown slightly, tested against the crate's
    /// hitbox - not a distance between two points. Since crates are solid you are
    /// already touching one when you are next to it, so the margin only has to cover
    /// the hair of clearance collision leaves behind.
    ///
    /// Lives here so the Open button and the system that actually opens a crate can
    /// never disagree about which one, or about whether you are close enough.
    func reachableLootbox(for actor: Actor) -> Lootbox? {
        let reach = actor.hitbox.expanded(by: GameConfig.Loot.openReach)

        var closest: Lootbox?
        var shortest = Double.greatestFiniteMagnitude

        for box in lootboxes.values {
            guard reach.intersects(box.hitbox) else { continue }

            let distance = (box.position - actor.position).length
            guard distance < shortest else { continue }
            shortest = distance
            closest = box
        }

        return closest
    }

    func removeLootbox(_ id: LootboxID) {
        guard let crate = lootboxes[id] else { return }
        lootboxes[id] = nil

        // Crates come back. Without that, seven bots strip the map bare within a
        // minute and there is nothing left to play around.
        pendingLootboxes.append(PendingLootbox(tile: crate.tile,
                                               timer: GameConfig.Loot.respawnDelay))
    }

    func tickLootboxRespawns(dt: Double) {
        guard !pendingLootboxes.isEmpty else { return }

        var stillWaiting: [PendingLootbox] = []

        for var pending in pendingLootboxes {
            pending.timer -= dt

            if pending.timer > 0 {
                stillWaiting.append(pending)
                continue
            }

            // Crates are solid, so one appearing under somebody would shove them
            // out of the way. Wait for them to move on instead.
            let crate = Lootbox(id: LootboxID(nextLootboxID), tile: pending.tile)
            if actors.values.contains(where: { $0.isAlive && $0.hitbox.intersects(crate.hitbox) }) {
                pending.timer = 1
                stillWaiting.append(pending)
                continue
            }

            nextLootboxID += 1
            lootboxes[crate.id] = crate
        }

        pendingLootboxes = stillWaiting
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
        // Whatever is driving actors from outside comes in; the brains fill in the
        // rest. From here down, nothing can tell which is which.
        var everyone = commands
        AISystem.contribute(to: &everyone, in: self, dt: dt)

        applyMovementInput(everyone)
        BuildSystem.update(self, commands: everyone)
        WeaponSystem.update(self, commands: everyone, dt: dt)
        ConsumableSystem.update(self, commands: everyone)
        MovementSystem.update(self, dt: dt)
        ProjectileSystem.update(self, dt: dt)
        // After movement, so picking things up uses where you actually ended up.
        LootSystem.update(self, commands: everyone, dt: dt)
        RespawnSystem.update(self, dt: dt)
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
                case .placeBlock, .shoot, .openLootbox, .useItem:
                    break   // other systems' business, not movement's
                }
            }
            actors[id] = actor
        }
    }
}
