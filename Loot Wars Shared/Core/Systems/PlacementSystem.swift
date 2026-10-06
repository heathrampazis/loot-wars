//
//  PlacementSystem.swift
//  Loot Wars
//
//  Where a thing you carry lands when you tap the map, and whether it may.
//
//  This exists because a machine is SIX tiles. One tile is forgiving - tap it and
//  what appears is the square you touched. Six is not: the footprint has to be put
//  somewhere relative to the finger, and it has to fit, and the odds of a blind tap
//  landing a legal 2 x 3 inside your own walls are about one in six. Measured over
//  200,000 bases, 17% of taps could take a machine, while 87% of bases had room for
//  one SOMEWHERE. Almost every refusal was a tap a few tiles off.
//
//  So the screen stops guessing and starts showing: it asks here for the footprint,
//  draws it under the finger, and asks here again whether it would take. Because the
//  preview and the placement are the same two questions asked of the same code, the
//  green outline cannot promise something the simulation then refuses.
//

enum PlacementSystem {

    /// How many tiles the thing covers. Nil for anything not placed on the map.
    struct Footprint {
        let width: Int
        let height: Int
    }

    static func footprint(of type: ItemType) -> Footprint? {
        switch type {
        case .arcade(let kind):
            return Footprint(width: kind.width, height: kind.height)
        case .turret:
            return Footprint(width: Turret.width, height: Turret.height)
        case .chest:
            return Footprint(width: 1, height: 1)
        default:
            return nil
        }
    }

    /// The corner a tap at this point means.
    ///
    /// Centred on the finger rather than growing up and to the right of it. The tap
    /// used to BE the corner, which is fine for a chest and wrong for a machine:
    /// five of its six tiles landed somewhere you had not touched, so it appeared
    /// offset from where you asked for it every single time.
    static func origin(of type: ItemType, tappedAt point: Vec2) -> GridPoint? {
        guard let size = footprint(of: type) else { return nil }

        // Half a footprint back, then floored onto the grid. For a single tile this
        // is exactly GridPoint(containing:), so chests are unchanged.
        let col = (point.x - Double(size.width) / 2 + 0.5).rounded(.down)
        let row = (point.y - Double(size.height) / 2 + 0.5).rounded(.down)
        return GridPoint(col: Int(col), row: Int(row))
    }

    /// Whether it would take, asked of the system that owns the rules.
    ///
    /// Deliberately a dispatch and nothing more. The moment this file starts
    /// deciding anything for itself, the preview and the placement can disagree,
    /// which is the one failure this whole file exists to prevent.
    static func canPlace(_ type: ItemType,
                         at origin: GridPoint,
                         by actor: Actor,
                         in world: World) -> Bool {
        switch type {
        case .arcade(let kind):
            return ArcadeSystem.canPlace(at: origin, kind: kind, by: actor, in: world)
        case .turret: return TurretSystem.canPlace(at: origin, by: actor, in: world)
        case .chest:  return ChestSystem.canPlace(at: origin, by: actor, in: world)
        default:      return false
        }
    }

    /// The intent to raise for it.
    /// Whether this team's base already holds as many of this as it may - see
    /// GameConfig.Base.maxChests. False for anything that is not base furniture.
    ///
    /// Asked by the hotbar, so a tap can say "base full" rather than opening a
    /// placement that can only ever show red, and by the bots, so none of them
    /// carries a third chest home to a base that will not take it.
    static func baseIsFull(for type: ItemType, team: TeamID, in world: World) -> Bool {
        guard let cap = limit(of: type) else { return false }
        switch type {
        case .arcade: return world.arcadeCount(ownedBy: team) >= cap
        case .turret: return world.turretCount(ownedBy: team) >= cap
        case .chest:  return world.chestCount(ownedBy: team) >= cap
        default:      return false
        }
    }

    /// How many of this a base may hold, or nil when it is not base furniture.
    static func limit(of type: ItemType) -> Int? {
        switch type {
        case .arcade: return GameConfig.Base.maxArcades
        case .turret: return GameConfig.Base.maxTurrets
        case .chest:  return GameConfig.Base.maxChests
        default:      return nil
        }
    }

    static func command(for type: ItemType, at origin: GridPoint) -> Command? {
        switch type {
        case .arcade(let kind): return .placeArcade(origin, kind)
        case .turret: return .placeTurret(origin)
        case .chest:  return .placeChest(origin)
        default:      return nil
        }
    }

    /// Somewhere it would actually go, nearest to this actor.
    ///
    /// Where the preview starts, so picking a machine out of the bag opens on a
    /// spot that works rather than on a red rectangle you then have to hunt a
    /// green one from.
    ///
    /// The nudge below is most of the value. The world's own search is the one the
    /// bots use and it does not know who is standing where, so the nearest legal
    /// footprint to somebody is very often the one they are standing IN: opened
    /// green only 24% of the time. Walking the ring outwards from it until the real
    /// rule agrees takes that to 87%, which is every base that has room at all.
    static func suggestion(for type: ItemType, by actor: Actor, in world: World) -> GridPoint? {
        let start: GridPoint?

        switch type {
        case .arcade(let kind):
            start = world.nextArcadeOrigin(for: actor.team, kind: kind, near: actor.position)
        case .turret:
            start = world.nextTurretOrigin(for: actor.team, near: actor.position)
        case .chest:  start = world.nextChestTile(for: actor.team, near: actor.position)
        default:      return nil
        }

        guard let candidate = start else { return nil }
        if canPlace(type, at: candidate, by: actor, in: world) { return candidate }

        // Rings outwards from it, nearest first. Bounded, and small: past a few
        // tiles it stops being a suggestion about where you are standing and
        // becomes a guess about the far side of the base.
        for radius in 1...suggestionReach {
            var ring: [GridPoint] = []

            for dCol in -radius...radius {
                for dRow in -radius...radius where max(abs(dCol), abs(dRow)) == radius {
                    ring.append(GridPoint(col: candidate.col + dCol,
                                          row: candidate.row + dRow))
                }
            }

            // Sorted, so the same situation always suggests the same tile.
            let sorted = ring.sorted { ($0.row, $0.col) < ($1.row, $1.col) }
            if let spot = sorted.first(where: { canPlace(type, at: $0, by: actor, in: world) }) {
                return spot
            }
        }

        // Nothing clear nearby. The original stands, in red, which is the honest
        // answer: there is a footprint here and something is in the way of it.
        return candidate
    }

    /// How far the suggestion will walk out looking for a clear spot.
    private static let suggestionReach = 4
}
