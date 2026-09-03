//
//  MapFactory.swift
//  Loot Wars
//
//  Builds a map from a seed. Same seed in, same map out - always. That includes
//  which way each tree spins, so two runs of the same seed are identical.
//
//  An edge, eight base claims on a ring, scattered tree clumps and crates.
//  Terrain features beyond that arrive later.
//

import Foundation

/// Everything the generator produces.
///
/// Claims, trees, crates and even which team you play are all part of the map's
/// identity rather than things bolted on afterwards, so they all come out of the
/// same seeded pass. One number rebuilds an identical match.
struct GeneratedMap {
    let map: TileMap
    let claims: [TeamID: BaseClaim]
    let trees: [TreePatch]
    let lootboxes: [Lootbox]
    let arcades: [Arcade]
    /// The wall plan each team builds to, in the order it lays them.
    let baseLayouts: [TeamID: BaseLayout]
    /// Which team this device plays. Random per seed, so your colour and your
    /// corner of the map change every game.
    let localTeam: TeamID
    /// Kept so the world can start its own generator from the same number.
    let seed: UInt64
}

enum MapFactory {

    static func generate(seed: UInt64) -> GeneratedMap {
        var rng = SeededRandom(seed: seed)
        var map = TileMap(width: GameConfig.Map.width, height: GameConfig.Map.height)

        sealEdges(of: &map)
        let (claims, localTeam) = makeClaims(in: map, using: &rng)
        let trees = plantTrees(in: map, avoiding: claims, using: &rng)
        // Machines first: they are big and there are only a handful, so they get
        // the pick of the open ground. Crates then fit around them.
        let arcades = placeArcades(in: map, avoiding: claims, and: trees, using: &rng)
        let lootboxes = scatterLootboxes(in: map, avoiding: claims, and: trees,
                                         around: arcades, using: &rng)

        var baseLayouts: [TeamID: BaseLayout] = [:]
        for index in 0..<TeamID.count {
            let team = TeamID(index)
            guard let claim = claims[team] else { continue }
            baseLayouts[team] = BaseLayoutFactory.make(for: claim, using: &rng)
        }

        return GeneratedMap(map: map,
                            claims: claims,
                            trees: trees,
                            lootboxes: lootboxes,
                            arcades: arcades,
                            baseLayouts: baseLayouts,
                            localTeam: localTeam,
                            seed: seed)
    }

    /// Eight claims evenly spaced around a ring, then shuffled between the teams.
    ///
    /// The ring positions are fixed but WHO gets which one is not, so no team ever
    /// has a structural advantage and your base is somewhere new each game.
    private static func makeClaims(in map: TileMap,
                                   using rng: inout SeededRandom) -> ([TeamID: BaseClaim], TeamID) {
        let centre = GridPoint(col: map.width / 2, row: map.height / 2)
        let radius = GameConfig.Map.claimRingRadius

        var positions: [GridPoint] = (0..<TeamID.count).map { index in
            let angle = 2 * Double.pi * Double(index) / Double(TeamID.count)
            return GridPoint(col: centre.col + Int((cos(angle) * radius).rounded()),
                             row: centre.row + Int((sin(angle) * radius).rounded()))
        }

        positions.shuffle(using: &rng)

        var claims: [TeamID: BaseClaim] = [:]
        for index in 0..<TeamID.count {
            let team = TeamID(index)
            claims[team] = BaseClaim(team: team,
                                     centredOn: positions[index],
                                     size: GameConfig.Map.claimSize)
        }

        // Which colour you play is part of the match, so it comes from the seed too.
        let localTeam = TeamID(Int.random(in: 0..<TeamID.count, using: &rng))

        return (claims, localTeam)
    }

    private static func sealEdges(of map: inout TileMap) {
        for col in 0..<map.width {
            map[GridPoint(col: col, row: 0)] = .stone
            map[GridPoint(col: col, row: map.height - 1)] = .stone
        }
        for row in 0..<map.height {
            map[GridPoint(col: 0, row: row)] = .stone
            map[GridPoint(col: map.width - 1, row: row)] = .stone
        }
    }

    // MARK: - Trees

    private static func plantTrees(in map: TileMap,
                                   avoiding claims: [TeamID: BaseClaim],
                                   using rng: inout SeededRandom) -> [TreePatch] {
        var planted: [TreePatch] = []

        // Placement can fail, so try more often than we need and stop once we have
        // enough. A fixed attempt budget means generation always terminates.
        let attempts = GameConfig.Map.treePatchCount * 25

        for _ in 0..<attempts {
            guard planted.count < GameConfig.Map.treePatchCount else { break }

            let size = GameConfig.Map.treePatchSizes.randomElement(using: &rng) ?? 2
            let factor = GameConfig.Trees.collisionRadiusFactor[size] ?? 0.85

            // Draw every random value up front and in a fixed order, so the same
            // seed always produces the same forest.
            let col = Int.random(in: 1...(map.width - size - 1), using: &rng)
            let row = Int.random(in: 1...(map.height - size - 1), using: &rng)
            let speed = Double.random(in: GameConfig.Trees.minSpin...GameConfig.Trees.maxSpin,
                                      using: &rng)
            let clockwise = Bool.random(using: &rng)
            let startAngle = Double.random(in: 0..<(2 * .pi), using: &rng)

            let candidate = TreePatch(
                origin: GridPoint(col: col, row: row),
                size: size,
                radius: Double(size) / 2 * factor,
                spin: clockwise ? speed : -speed,
                initialRotation: startAngle
            )

            guard isClear(candidate, of: planted, and: claims) else { continue }
            planted.append(candidate)
        }

        return planted
    }

    /// A clump needs clear space around it: away from other clumps so they read as
    /// separate, and away from every claim so nobody is ever penned into their base.
    private static func isClear(_ candidate: TreePatch,
                                of planted: [TreePatch],
                                and claims: [TeamID: BaseClaim]) -> Bool {
        for other in planted {
            let delta = candidate.centre - other.centre
            let minimum = candidate.radius + other.radius + GameConfig.Trees.spacing
            if delta.length < minimum { return false }
        }

        for claim in claims.values {
            // The claim, grown by a tile of breathing room.
            let closest = candidate.closestPoint(
                inBox: Vec2(x: Double(claim.origin.col) - 1, y: Double(claim.origin.row) - 1),
                to: Vec2(x: Double(claim.origin.col + claim.size) + 1,
                         y: Double(claim.origin.row + claim.size) + 1)
            )
            if (closest - candidate.centre).length < candidate.radius { return false }
        }

        return true
    }
}

// MARK: - Arcades

extension MapFactory {

    /// A handful of machines on open ground.
    ///
    /// The footprint AND the ring around it both have to be clear. A machine needs
    /// somewhere to put a token or it pays out nothing, so one that spawns already
    /// hemmed in by trees would be dead scenery for the whole match.
    fileprivate static func placeArcades(in map: TileMap,
                                         avoiding claims: [TeamID: BaseClaim],
                                         and trees: [TreePatch],
                                         using rng: inout SeededRandom) -> [Arcade] {
        var placed: [Arcade] = []
        // Measured: at 40 tries each, one map in fourteen came up a machine short.
        // At 80 it is one in three hundred. Generation happens once, so the extra
        // rejections cost nothing anyone can perceive.
        let attempts = GameConfig.Arcade.count * 80

        for _ in 0..<attempts {
            guard placed.count < GameConfig.Arcade.count else { break }

            let col = Int.random(in: 2...(map.width - Arcade.width - 2), using: &rng)
            let row = Int.random(in: 2...(map.height - Arcade.height - 2), using: &rng)
            let stagger = Double.random(in: 0...GameConfig.Arcade.emitInterval, using: &rng)

            let candidate = Arcade(id: ArcadeID(placed.count),
                                   origin: GridPoint(col: col, row: row),
                                   owner: nil,
                                   emitTimer: stagger)

            guard isClear(candidate, in: map, of: placed, trees: trees, claims: claims) else {
                continue
            }
            placed.append(candidate)
        }

        return placed
    }

    private static func isClear(_ candidate: Arcade,
                                in map: TileMap,
                                of placed: [Arcade],
                                trees: [TreePatch],
                                claims: [TeamID: BaseClaim]) -> Bool {
        // Standing room, paying-out room, and room to WALK to what it pays out -
        // see Arcade.tiles(within:). A token on the ring with a tree behind it is
        // a token you can see and cannot reach, and that is most of what made the
        // machines on the map feel stingy.
        for tile in candidate.tiles(within: GameConfig.Arcade.clearance) {
            guard map.contains(tile), map[tile] == .floor else { return false }
            if trees.contains(where: { $0.overlaps(tile) }) { return false }
        }

        for other in placed {
            let gap = (candidate.centre - other.centre).length
            if gap < GameConfig.Arcade.spacing { return false }
        }

        // Well away from every base. Tokens should be worth leaving home for.
        for claim in claims.values {
            let home = Box(lower: Vec2(x: Double(claim.origin.col), y: Double(claim.origin.row)),
                           upper: Vec2(x: Double(claim.origin.col + claim.size),
                                       y: Double(claim.origin.row + claim.size)))
            if home.expanded(by: GameConfig.Arcade.claimClearance)
                .intersects(candidate.hitbox) { return false }
        }

        return true
    }
}

// MARK: - Lootboxes

extension MapFactory {

    fileprivate static func scatterLootboxes(in map: TileMap,
                                             avoiding claims: [TeamID: BaseClaim],
                                             and trees: [TreePatch],
                                             around arcades: [Arcade],
                                             using rng: inout SeededRandom) -> [Lootbox] {
        var placed: [Lootbox] = []
        let attempts = GameConfig.Loot.lootboxCount * 30

        for _ in 0..<attempts {
            guard placed.count < GameConfig.Loot.lootboxCount else { break }

            let tile = GridPoint(col: Int.random(in: 1...(map.width - 2), using: &rng),
                                 row: Int.random(in: 1...(map.height - 2), using: &rng))

            guard map[tile] == .floor else { continue }

            // Not inside anyone's base - the whole point is that you go out for loot.
            if claims.values.contains(where: { $0.contains(tile) }) { continue }

            // Not buried inside a tree clump, where you could never reach it.
            if trees.contains(where: { $0.overlaps(tile) }) { continue }

            // Not inside a machine, and not pressed against one either - a crate in
            // the ring is one less place a token can be paid out to.
            let boxed = Box(tile: tile)
            if arcades.contains(where: { $0.hitbox.expanded(by: 1).intersects(boxed) }) { continue }

            // Spread out, so one corner of the map is not the only place worth going.
            let centre = tile.center
            let tooClose = placed.contains {
                ($0.position - centre).length < GameConfig.Loot.lootboxSpacing
            }
            if tooClose { continue }

            placed.append(Lootbox(id: LootboxID(placed.count), tile: tile))
        }

        return placed
    }
}
