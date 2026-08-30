//
//  BombSystem.swift
//  Loot Wars
//
//  Throwing, flying and detonating.
//
//  A bomb is the only thing in the game that takes the map apart, so the rules
//  about what it can destroy live here and nowhere else: walls come down, terrain
//  and trees do not. Bases would stop being defensible if a bomb could open the map
//  edge, and the ring of claims would stop meaning anything.
//

enum BombSystem {

    static func update(_ world: World, commands: [ActorID: [Command]], dt: Double) {
        launch(world, commands: commands)
        fly(world, dt: dt)
    }

    // MARK: - Throwing

    private static func launch(_ world: World, commands: [ActorID: [Command]]) {
        for (id, list) in commands {
            for command in list {
                guard case .throwBomb(let tile) = command else { continue }
                throwBomb(by: id, at: tile, in: world)
                break   // one per tick, however many times it was asked
            }
        }
    }

    /// Whether this actor could lob one at that tile right now.
    ///
    /// Asked by the input code before it offers the action and by the throw itself,
    /// so a bot cannot line up a raid the simulation would refuse.
    static func canThrow(_ actor: Actor, at tile: GridPoint) -> Bool {
        guard actor.isAlive, actor.inventory.count(of: .bomb) > 0 else { return false }
        return (tile.center - actor.position).length <= GameConfig.Bomb.throwRange
    }

    private static func throwBomb(by id: ActorID, at tile: GridPoint, in world: World) {
        guard var actor = world.actors[id], canThrow(actor, at: tile) else { return }
        guard let slot = actor.inventory.firstSlot(holding: .bomb) else { return }
        _ = actor.inventory.consume(at: slot)
        world.actors[id] = actor

        let target = tile.center
        let heading = target - actor.position
        guard heading.length > 0.01 else { return }

        world.spawnBomb(owner: id,
                        team: actor.team,
                        position: actor.position,
                        velocity: heading.normalized() * GameConfig.Bomb.speed,
                        target: target)
    }

    // MARK: - Flight

    private static func fly(_ world: World, dt: Double) {
        guard !world.bombs.isEmpty else { return }

        var stillFlying: [Bomb] = []

        for var bomb in world.bombs {
            let before = bomb.position
            let step = bomb.velocity * dt
            bomb.position = bomb.position + step
            bomb.distanceRemaining -= step.length

            // Reached what it was aimed at - detonate even over open ground, so a
            // throw that misses still goes off rather than sailing away.
            let passedTarget = (bomb.target - before).length <= step.length

            if passedTarget || bomb.distanceRemaining <= 0 {
                detonate(bomb, in: world)
                continue
            }

            if hitsSomething(bomb.position, in: world) {
                detonate(bomb, in: world)
                continue
            }

            stillFlying.append(bomb)
        }

        world.bombs = stillFlying
    }

    private static func hitsSomething(_ point: Vec2, in world: World) -> Bool {
        if world.map.isOccupied(GridPoint(containing: point)) { return true }
        return world.trees.contains { $0.contains(point) }
    }

    // MARK: - Detonation

    private static func detonate(_ bomb: Bomb, in world: World) {
        let radius = GameConfig.Bomb.blastRadius
        let reach = Int(radius.rounded(.up))
        let centre = GridPoint(containing: bomb.position)

        // Walls only. Terrain and trees survive - a bomb that could open the map
        // edge would make the whole ring of claims meaningless.
        for dCol in -reach...reach {
            for dRow in -reach...reach {
                let tile = GridPoint(col: centre.col + dCol, row: centre.row + dRow)
                guard world.map[tile].blockOwner != nil else { continue }
                guard (tile.center - bomb.position).length <= radius else { continue }
                world.setTile(.floor, at: tile)
            }
        }

        for id in world.actors.keys.sorted(by: { $0.raw < $1.raw }) {
            guard let actor = world.actors[id], actor.isAlive else { continue }

            let distance = (actor.position - bomb.position).length
            guard distance <= radius else { continue }

            // Falls off towards the edge, so being caught at the rim is a warning
            // rather than a death sentence.
            let share = 1 - (distance / radius)
            let hurt = Int((Double(GameConfig.Bomb.damage) * share).rounded())
            CombatSystem.damage(id, amount: max(1, hurt), in: world)
        }

        world.recordBlast(at: bomb.position)
    }
}
