//
//  SpikeSystem.swift
//  Loot Wars
//
//  Spike traps (Nov 2026): set into your own base's floor, invisible to
//  enemies until somebody steps on one, and then a big bite and a few seconds
//  where everybody can see it. See SpikeTrap and GameConfig.Spikes.
//

enum SpikeSystem {

    static func update(_ world: World, commands: [ActorID: [Command]], dt: Double) {
        place(world, commands: commands)
        guard !world.spikes.isEmpty else { return }

        // Tile order, so a seed replays the same.
        for tile in world.spikes.keys.sorted(by: { ($0.row, $0.col) < ($1.row, $1.col) }) {
            guard var trap = world.spikes[tile] else { continue }

            // Built over, or the base is gone: the trap goes with it.
            guard trap.tiles.allSatisfy({ world.map[$0] == .floor }),
                  world.claim(for: trap.owner) != nil else {
                world.spikes[tile] = nil
                continue
            }

            trap.revealed = max(0, trap.revealed - dt)
            trap.rearm = max(0, trap.rearm - dt)

            if trap.rearm <= 0, let victim = victim(on: tile, of: trap, in: world) {
                bite(victim, with: &trap, in: world)
            }

            world.spikes[tile] = trap
        }
    }

    // MARK: - Biting

    /// The first enemy standing on it, by their feet. Actors in id order.
    private static func victim(on tile: GridPoint, of trap: SpikeTrap, in world: World) -> ActorID? {
        world.actors.keys.sorted(by: { $0.raw < $1.raw }).first { id in
            guard let actor = world.actors[id], actor.isAlive,
                  actor.team != trap.owner,
                  actor.invulnerability <= 0 else { return false }
            return trap.covers(GridPoint(containing: actor.feet))
        }
    }

    private static func bite(_ id: ActorID, with trap: inout SpikeTrap, in world: World) {
        guard let actor = world.actors[id] else { return }
        let full = max(Double(GameConfig.Spikes.damage),
                       Double(actor.maxHealth) * GameConfig.Spikes.damageShare)
        // Credited to whoever owns the base, so a kill on your spikes is yours.
        CombatSystem.damage(id, amount: Int(full.rounded()),
                            from: world.actorID(of: trap.owner), in: world)
        trap.revealed = GameConfig.Spikes.revealTime
        trap.rearm = GameConfig.Spikes.rearmTime
        world.record(.spiked(at: trap.centre, by: trap.owner))
    }

    // MARK: - Setting them

    /// - Parameter tile: the bottom-left of the two by two.
    static func canPlace(at tile: GridPoint, by actor: Actor, in world: World) -> Bool {
        guard actor.inventory.firstSlot(holding: .spikes) != nil,
              world.spikeCount(ownedBy: actor.team) < GameConfig.Spikes.maxPerBase,
              let claim = world.claim(for: actor.team),
              claim.contains(GridPoint(containing: actor.feet)) else { return false }

        let footprint = SpikeTrap(tile: tile, owner: actor.team)
        for spot in footprint.tiles {
            guard claim.contains(spot),
                  spot != claim.centreTile,
                  world.map[spot] == .floor,
                  !world.structureOccupies(spot),
                  !world.treeTiles.contains(spot),
                  !world.spikes.values.contains(where: { $0.covers(spot) }) else { return false }
        }
        return true
    }

    @discardableResult
    static func place(at tile: GridPoint, by actor: Actor, in world: World) -> Bool {
        guard canPlace(at: tile, by: actor, in: world) else { return false }
        var owner = actor
        guard let slot = owner.inventory.firstSlot(holding: .spikes),
              owner.inventory.consume(at: slot) != nil else { return false }
        world.actors[actor.id] = owner
        world.spikes[tile] = SpikeTrap(tile: tile, owner: actor.team)
        return true
    }

    private static func place(_ world: World, commands: [ActorID: [Command]]) {
        for id in commands.keys.sorted(by: { $0.raw < $1.raw }) {
            for command in commands[id] ?? [] {
                guard case .placeSpikes(let tile) = command else { continue }
                guard let actor = world.actors[id], actor.isAlive else { break }
                place(at: tile, by: actor, in: world)
            }
        }
    }

    /// Blasts clear traps (Nov 2026): a bomb or popper going off takes out any
    /// trap within `radius` of it - so a careful raider can throw one ahead.
    static func clear(around centre: Vec2, radius: Double, in world: World) {
        for tile in world.spikes.keys.sorted(by: { ($0.row, $0.col) < ($1.row, $1.col) }) {
            guard let trap = world.spikes[tile],
                  trap.tiles.contains(where: { ($0.center - centre).length <= radius }) else { continue }
            world.spikes[tile] = nil
        }
    }
}
