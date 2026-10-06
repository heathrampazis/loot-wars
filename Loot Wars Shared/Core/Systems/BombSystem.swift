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
                guard case .useItem(let slot) = command else { continue }
                throwBomb(by: id, from: slot, in: world)
                break   // one per tick, however many times it was asked
            }
        }
    }

    /// Whether this actor could throw whatever is in that slot right now.
    ///
    /// Asked by the bots before they commit to a raid and by the throw itself, so a
    /// bot can never line one up that the simulation would refuse.
    static func canThrow(_ actor: Actor, from slot: Int) -> Bool {
        guard actor.canUse(slot: slot) else { return false }
        return kind(of: actor.inventory.slots[slot]?.type) != nil
    }

    /// What an item turns into once it leaves your hand, or nil for anything that
    /// is not thrown at all.
    static func kind(of type: ItemType?) -> Bomb.Kind? {
        switch type {
        case .bomb:  return .blast
        case .stink: return .stink
        default:     return nil
        }
    }

    /// The first slot with a bomb in it, or nil.
    static func loadedSlot(of actor: Actor) -> Int? {
        actor.inventory.firstSlot(holding: .bomb)
    }

    private static func throwBomb(by id: ActorID, from slot: Int, in world: World) {
        guard var actor = world.actors[id], canThrow(actor, from: slot),
              let kind = kind(of: actor.inventory.slots[slot]?.type) else { return }

        // Thrown along the aim, which is wherever the actor was last walking or
        // shooting. Same rule for everybody: no separate targeting for bombs, and
        // no way to lob one somewhere you were not already pointed.
        let heading = actor.aim.normalized()
        guard heading.length > 0 else { return }

        _ = actor.inventory.consume(at: slot)
        world.actors[id] = actor

        world.spawnBomb(kind,
                        owner: id,
                        team: actor.team,
                        position: actor.position + heading * GameConfig.Bomb.launchOffset,
                        velocity: heading * GameConfig.Bomb.speed)
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

            // It hit something: it goes off against the face it struck, so the
            // blast is measured from the side it arrived on - see isShielded.
            if hitsSomething(bomb.position, in: world) {
                detonate(bomb, from: before, in: world)
                continue
            }

            // Out of throw. A bomb that ran out of arc still explodes rather than
            // vanishing.
            if bomb.distanceRemaining <= 0 {
                detonate(bomb, from: bomb.position, in: world)
                continue
            }

            stillFlying.append(bomb)
        }

        world.bombs = stillFlying
    }

    /// What stops a bomb in flight.
    ///
    /// Machines are in here, and were not: a bomb sailed straight through an arcade
    /// and went off somewhere behind it, which meant the one thing a machine is
    /// vulnerable to could not reliably be aimed at it. It is solid to a walking
    /// actor and solid to a shot; it is solid to a bomb now too, and since a bomb
    /// stopped by a machine goes off against its side, that is also what makes
    /// raiding one work.
    private static func hitsSomething(_ point: Vec2, in world: World) -> Bool {
        if world.map.isOccupied(GridPoint(containing: point)) { return true }
        if world.arcades.values.contains(where: { $0.hitbox.contains(point) }) { return true }

        // A turret stops a bomb and takes the blast - it is the thing you throw one
        // AT. Left out, a bomb lobbed at a turret would sail through it and go off
        // in the wall behind, and the aiming line would show it doing so.
        if world.turrets.values.contains(where: { $0.hitbox.contains(point) }) { return true }

        return world.trees.contains { $0.contains(point) }
    }

    // MARK: - Detonation

    /// - Parameter origin: where the blast spreads from, for deciding what is
    ///   behind cover. The last open point the bomb passed through, so a bomb
    ///   that struck a wall is on the near side of it rather than inside it.
    private static func detonate(_ bomb: Bomb, from origin: Vec2, in world: World) {
        // A stink bomb stops here. It takes nothing off the map, hurts nobody on
        // landing and kills nothing standing next to it - all of its effect is the
        // cloud it leaves behind, which is what makes it a way of taking GROUND
        // rather than a smaller way of taking health.
        guard case .blast = bomb.kind else {
            world.spawnGas(at: bomb.position, owner: bomb.owner, team: bomb.team)
            world.record(.gas(at: bomb.position))
            return
        }

        let radius = GameConfig.Bomb.blastRadius
        let reach = Int(radius.rounded(.up))
        let centre = GridPoint(containing: bomb.position)

        // What stood in the way BEFORE anything came down. Read first, because
        // the walls this blast destroys still took the blast - a wall soaks up the
        // bomb, and the turret or machine behind it is untouched. Blowing the wall
        // open is the bomb's job; getting at what is behind it is the next one.
        var cover: Set<GridPoint> = []
        for dCol in (-reach - 1)...(reach + 1) {
            for dRow in (-reach - 1)...(reach + 1) {
                let tile = GridPoint(col: centre.col + dCol, row: centre.row + dRow)
                if world.map.isOccupied(tile) || world.treeTiles.contains(tile) {
                    cover.insert(tile)
                }
            }
        }

        // Walls only. Terrain and trees survive - a bomb that could open the map
        // edge would make the whole ring of claims meaningless.
        for dCol in -reach...reach {
            for dRow in -reach...reach {
                let tile = GridPoint(col: centre.col + dCol, row: centre.row + dRow)
                guard let owner = world.map[tile].blockOwner else { continue }
                guard (tile.center - bomb.position).length <= radius else { continue }
                world.setTile(.floor, at: tile)

                // Only for somebody else's. Blowing up your own wall is a way of
                // opening a door, not an achievement.
                if owner != bomb.team {
                    world.award(GameConfig.Score.wallDestroyed, to: bomb.team)

                    // And the hole is now theirs to fix, which is worth something
                    // to them when they do - see World.recordBreach.
                    world.recordBreach(of: owner)
                }
            }
        }

        // Machines somebody put down. The map's own are scenery and survive - a
        // bomb that could clear those would strip the board of its economy.
        for machineID in world.arcades.keys.sorted(by: { $0.raw < $1.raw }) {
            guard let machine = world.arcades[machineID],
                  let owner = machine.owner,
                  owner != bomb.team,
                  machine.hitbox.expanded(by: radius).contains(bomb.position),
                  !isShielded(machine.hitbox.closestPoint(to: origin),
                              from: origin, by: cover) else { continue }

            ArcadeSystem.destroy(machineID, by: bomb.team, in: world)
        }

        // Chests, which take damage rather than bursting outright - see
        // GameConfig.Chest.bombDamage. Falls off from the centre exactly as it does
        // for a person, so a bomb lobbed through the hole in the wall from outside
        // softens a chest and does not take it.
        for id in world.chests.keys.sorted(by: { $0.raw < $1.raw }) {
            guard let chest = world.chests[id] else { continue }

            let distance = (chest.position - bomb.position).length
            guard distance <= radius,
                  !isShielded(chest.position, from: origin, by: cover) else { continue }

            let share = 1 - (distance / radius)
            let hurt = Int((Double(GameConfig.Chest.bombDamage) * share).rounded())
            ChestSystem.hit(id, for: max(1, hurt),
                            by: bomb.owner, of: bomb.team, in: world)
        }

        // Turrets, which take a blast the way a chest does - most of one, never all
        // of it. See GameConfig.Turret.bombDamage for why a bomb must not simply
        // clear one: it could then be done from outside the wall, and the defence
        // would never fire a shot.
        //
        // Measured to the nearest point of its body rather than its centre, which is
        // what a two-tile thing needs: a bomb going off against its side is a direct
        // hit, not a near miss a tile away.
        for id in world.turrets.keys.sorted(by: { $0.raw < $1.raw }) {
            guard let turret = world.turrets[id] else { continue }

            let nearest = turret.hitbox.closestPoint(to: bomb.position)
            let distance = (nearest - bomb.position).length
            guard distance <= radius,
                  !isShielded(turret.hitbox.closestPoint(to: origin),
                              from: origin, by: cover) else { continue }

            let share = 1 - (distance / radius)
            let hurt = Int((Double(GameConfig.Turret.bombDamage) * share).rounded())
            TurretSystem.hit(id, for: max(1, hurt),
                             by: bomb.owner, of: bomb.team, in: world)
        }

        for id in world.actors.keys.sorted(by: { $0.raw < $1.raw }) {
            guard let actor = world.actors[id], actor.isAlive else { continue }

            let distance = (actor.position - bomb.position).length
            guard distance <= radius,
                  !isShielded(actor.position, from: origin, by: cover) else { continue }

            // Falls off towards the edge, so being caught at the rim is a warning
            // rather than a death sentence.
            let share = 1 - (distance / radius)
            let hurt = Int((Double(GameConfig.Bomb.damage) * share).rounded())
            CombatSystem.damage(id, amount: max(1, hurt), from: bomb.owner, in: world)
        }

        world.record(.blast(at: bomb.position))
    }

    /// Whether something solid stands between the blast and this point.
    ///
    /// Walks the straight line in tenth-of-a-tile steps and stops just short of
    /// the target, so a thing standing flush against the inside of a wall is
    /// still behind it. Steps rather than an exact grid walk because a blast is a
    /// few tiles across at most - forty-odd checks against a set - and the answer
    /// only ever needs to be "is a wall in the way".
    private static func isShielded(_ target: Vec2, from origin: Vec2, by cover: Set<GridPoint>) -> Bool {
        let span = target - origin
        let steps = max(1, Int((span.length / 0.1).rounded(.up)))

        for index in 1..<steps {
            let point = origin + span * (Double(index) / Double(steps))
            if cover.contains(GridPoint(containing: point)) { return true }
        }
        return false
    }
}
