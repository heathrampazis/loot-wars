//
//  MenuBackdrop.swift
//  Loot Wars
//
//  The living map behind the title screen.
//
//  A real map from the real generator, with its bases BUILT - walls up, chests,
//  machines and turrets in them - and a person in each one, pottering about their
//  own base. All of it drawn by the match's own renderers, so a wall here is
//  joined up exactly like a wall in a match and a person bobs and breathes the
//  way they do in one.
//
//  It is a World, but nothing simulates it. Nothing is stepped, no brains run and
//  nothing fights: the people are puppets walked between spots inside their own
//  walls, and the renderers are synced from that. The point is to show what the
//  game is - bases, and the people who own them - not to play it behind the
//  buttons.
//

import SpriteKit

final class MenuBackdrop {

    /// Everything, moved as one by the menu's drift.
    let node = SKNode()

    private var world: World!

    private let tiles = TileMapRenderer()
    private let claims = ClaimRenderer()
    private let trees = TreeRenderer()
    private let blocks = BlockRenderer()
    private let arcades = ArcadeRenderer()
    private let turrets = TurretRenderer()
    private let lootboxes = LootboxRenderer()
    private let chests = ChestRenderer()
    private let actors = ActorRenderer()

    /// Where each person is walking to, and how long they stand once there.
    private struct Stroll {
        var target: Vec2
        var pause: Double
    }
    private var strolls: [ActorID: Stroll] = [:]
    private var rng = SystemRandomNumberGenerator()

    /// Slower than a match: they are at home, not in a hurry.
    private static let walkSpeed: Double = GameConfig.Player.moveSpeed * 0.45

    func build() {
        let generated = MapFactory.generate(seed: UInt64.random(in: 0..<UInt64.max))
        world = World(generated: generated)

        furnish(generated)
        dress()

        tiles.build(from: generated.map, biomes: generated.biomes)
        claims.build(claims: generated.claims)
        trees.build(patches: generated.trees, biomes: generated.biomes)
        arcades.build(mapHeight: world.map.height)
        turrets.build(mapHeight: world.map.height)
        blocks.build(from: world.map)

        node.removeAllChildren()
        for layer in [tiles.node, claims.node, actors.groundNode, trees.node,
                      blocks.node, arcades.node, turrets.node, lootboxes.node,
                      chests.node, actors.node] {
            node.addChild(layer)
        }

        // Once for everything that stands still; the people are synced each frame.
        lootboxes.sync(with: world)
        chests.sync(with: world)
        arcades.sync(with: world)
        turrets.sync(with: world)
        blocks.sync(with: world)
        actors.sync(with: world, dt: 0)
    }

    /// Bases as they look a couple of minutes in: walls up, a chest or two, and
    /// in most of them a machine and a turret.
    private func furnish(_ generated: GeneratedMap) {
        for team in generated.claims.keys.sorted(by: { $0.raw < $1.raw }) {
            guard let layout = generated.baseLayouts[team],
                  let claim = generated.claims[team] else { continue }

            for tile in layout.tiles {
                world.setTile(.block(owner: team), at: tile)
            }

            let middle = claim.centreTile.center

            for _ in 0..<Int.random(in: 1...2, using: &rng) {
                if let tile = world.nextChestTile(for: team, near: middle) {
                    world.spawnChest(at: tile, owner: team)
                }
            }

            let kind: ArcadeKind = Bool.random(using: &rng) ? .full : .mini
            if Double.random(in: 0..<1, using: &rng) < 0.7,
               let origin = world.nextArcadeOrigin(for: team, kind: kind, near: middle,
                                                   avoidingActors: false) {
                world.spawnArcade(at: origin, kind: kind, owner: team)
            }

            if Double.random(in: 0..<1, using: &rng) < 0.5,
               let origin = world.nextTurretOrigin(for: team, near: middle,
                                                   avoidingActors: false) {
                world.spawnTurret(at: origin, owner: team)
            }
        }
    }

    /// Everybody in something different, so the people read as eight people.
    private func dress() {
        let helmets: [HelmetTier] = [.none, .common, .epic, .legendary, .mythical, .cosmic]
        let blasters = BlasterTier.allCases

        for id in world.actors.keys {
            guard var actor = world.actors[id] else { continue }
            actor.ai = nil
            actor.helmet = helmets.randomElement(using: &rng) ?? .none
            actor.blaster = blasters.randomElement(using: &rng) ?? .one
            actor.health = actor.maxHealth
            world.actors[id] = actor
            strolls[id] = Stroll(target: actor.position,
                                 pause: Double.random(in: 0...2, using: &rng))
        }
    }

    /// Walks everybody a frame's worth, and redraws them.
    func update(dt: Double) {
        guard world != nil else { return }

        for id in world.actors.keys.sorted(by: { $0.raw < $1.raw }) {
            guard var actor = world.actors[id], var stroll = strolls[id] else { continue }

            let towards = stroll.target - actor.position
            let step = MenuBackdrop.walkSpeed * dt

            if towards.length <= step {
                actor.position = stroll.target
                actor.moveInput = .zero
                stroll.pause -= dt
                if stroll.pause <= 0 {
                    stroll.target = nextSpot(for: actor)
                    stroll.pause = Double.random(in: 1.2...3.5, using: &rng)
                }
            } else {
                let heading = towards.normalized()
                actor.position = actor.position + heading * step
                actor.moveInput = heading
                actor.aim = heading
                if abs(heading.x) > 0.01 { actor.facesLeft = heading.x < 0 }
            }

            world.actors[id] = actor
            strolls[id] = stroll
        }

        actors.sync(with: world, dt: dt)
    }

    /// A free spot inside their own walls, a few tiles from where they stand.
    ///
    /// Two tiles clear so the figure, which is nearly two tall, fits; and nothing
    /// built there. Falls back to standing still when nothing fits.
    private func nextSpot(for actor: Actor) -> Vec2 {
        let room = world.enclosure(of: actor.team).room
        let free = room.filter { tile in
            let above = GridPoint(col: tile.col, row: tile.row + 1)
            return room.contains(above)
                && !world.structureOccupies(tile) && !world.structureOccupies(above)
                && (tile.center - actor.position).length < 4.5
        }

        guard let tile = free.randomElement(using: &rng) else { return actor.position }
        return Vec2(x: tile.center.x, y: Double(tile.row) + 1.0)
    }
}
