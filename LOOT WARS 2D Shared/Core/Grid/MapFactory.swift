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
    // Which biome each tile is in; only the look and the tree density depend on it.
    let biomes: BiomeMap
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
        // After the bases, so region borders can bend round them.
        let biomes = BiomeFactory.generate(width: map.width, height: map.height,
                                           seed: seed, around: claims)
        let trees = plantTrees(in: map, biomes: biomes, avoiding: claims, using: &rng)
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
                            biomes: biomes,
                            lootboxes: lootboxes,
                            arcades: arcades,
                            baseLayouts: baseLayouts,
                            localTeam: localTeam,
                            seed: seed)
    }

    /// Eight claims, one to a sector, scattered inside a band around the middle.
    ///
    /// Every match used to be the same octagon. Eight fixed points on a circle,
    /// shuffled between the teams - so the only thing that changed was which corner
    /// was yours, and after a few games you knew where every base on every map was
    /// before you left home.
    ///
    /// Now each team gets an eighth of the map and lands somewhere inside it: any
    /// angle within its own sector, any radius within a band. That split is what
    /// keeps the change from costing anything. Throwing eight claims at the map at
    /// random produces maps where three teams share a corner and one owns the whole
    /// west side, which is a different match for each of them and nobody agreed to
    /// play the unfair one; a sector each means everybody has neighbours, and the
    /// jitter inside it means nobody knows where.
    ///
    /// WHO gets which sector is still shuffled, so a colour is never a position.
    private static func makeClaims(in map: TileMap,
                                   using rng: inout SeededRandom) -> ([TeamID: BaseClaim], TeamID) {
        let centre = Vec2(x: Double(map.width) / 2, y: Double(map.height) / 2)
        let sector = 2 * Double.pi / Double(TeamID.count)

        // Relaxed a tile at a time when a sector cannot find room, which the
        // measurement says happens on about three maps in a hundred. A layout that
        // is slightly tight beats a generator that can hang, and the floor stops it
        // relaxing into claims that overlap.
        var spacing = GameConfig.Map.claimSpacing
        var positions: [GridPoint] = []

        for index in 0..<TeamID.count {
            var placed: GridPoint?

            while placed == nil {
                for _ in 0..<MapFactory.claimAttempts {
                    let jitter = GameConfig.Map.claimSectorJitter
                    let offset = Double.random(in: (0.5 - jitter)...(0.5 + jitter), using: &rng)
                    let angle = (Double(index) + offset) * sector

                    let radius = Double.random(in: GameConfig.Map.claimRadius, using: &rng)
                    let spot = centre + Vec2.fromAngle(angle) * radius
                    let tile = MapFactory.clamped(spot, in: map)

                    let clear = positions.allSatisfy {
                        (Vec2(x: Double($0.col), y: Double($0.row))
                            - Vec2(x: Double(tile.col), y: Double(tile.row))).length >= spacing
                    }

                    if clear {
                        placed = tile
                        break
                    }
                }

                if placed == nil {
                    spacing -= 1

                    // Out of room even at the floor: take the middle of the sector
                    // and move on. A map that is tight in one corner is a worse map;
                    // a generator that never returns is not a map at all.
                    if spacing < GameConfig.Map.claimSpacingFloor {
                        let angle = (Double(index) + 0.5) * sector
                        let radius = GameConfig.Map.claimRadius.upperBound
                        placed = MapFactory.clamped(centre + Vec2.fromAngle(angle) * radius,
                                                    in: map)
                    }
                }
            }

            positions.append(placed ?? GridPoint(col: map.width / 2, row: map.height / 2))
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

    /// How many spots a sector tries before the spacing is relaxed.
    private static let claimAttempts = 40

    /// Keeps a claim's centre far enough from the edge that its whole nine tiles,
    /// and the wall its owner will build round them, are on the map.
    private static func clamped(_ spot: Vec2, in map: TileMap) -> GridPoint {
        let margin = GameConfig.Map.claimMargin

        return GridPoint(col: min(max(Int(spot.x.rounded()), margin), map.width - 1 - margin),
                         row: min(max(Int(spot.y.rounded()), margin), map.height - 1 - margin))
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
                                   biomes: BiomeMap,
                                   avoiding claims: [TeamID: BaseClaim],
                                   using rng: inout SeededRandom) -> [TreePatch] {
        var planted: [TreePatch] = []

        // treePatchCount is for an all-plains map; scale it by how dense this map's biomes are.
        let density = GameConfig.Biomes.treeDensity
        let densest = density.values.max() ?? 1
        let shares = biomes.shares
        // Summed in case order, so floating point never makes two devices disagree.
        let average = Biome.allCases.reduce(0.0) { $0 + (shares[$1] ?? 0) * (density[$1] ?? 1) }
        let target = Int((Double(GameConfig.Map.treePatchCount) * average).rounded())

        // Placement can fail, so try more often than we need and stop once we have
        // enough. A fixed attempt budget means generation always terminates.
        let attempts = target * 40

        for _ in 0..<attempts {
            guard planted.count < target else { break }

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
            // Kept in proportion to the local biome's density; drawn every time so the order stays fixed.
            let keep = Double.random(in: 0..<1, using: &rng)

            let candidate = TreePatch(
                origin: GridPoint(col: col, row: row),
                size: size,
                radius: Double(size) / 2 * factor,
                spin: clockwise ? speed : -speed,
                initialRotation: startAngle
            )

            let local = density[biomes.biome(at: candidate.centre)] ?? 1
            guard keep < local / densest else { continue }

            guard isClear(candidate, of: planted, and: claims, biomes: biomes, in: map) else { continue }
            planted.append(candidate)
        }

        return planted
    }

    private static func treeGap(in biome: Biome) -> Double {
        GameConfig.Biomes.treeGap[biome] ?? GameConfig.Trees.spacing
    }

    /// A clump needs clear space around it: away from other clumps so they read as
    /// separate, and away from every claim so nobody is ever penned into their base.
    ///
    /// And every gap it leaves has to be one a player FITS through. A player is
    /// under a tile wide but nearly two tall, so a gap is measured against the
    /// player's size across it: two clumps side by side need a player's width
    /// between them to walk up through, two stacked need a player's height to
    /// walk across. The same goes for the gap beside a base and along the stone
    /// edge of the map, so no clump ever closes off a corner.
    private static func isClear(_ candidate: TreePatch,
                                of planted: [TreePatch],
                                and claims: [TeamID: BaseClaim],
                                biomes: BiomeMap,
                                in map: TileMap) -> Bool {
        let width = GameConfig.Player.halfWidth * 2 + GameConfig.Trees.passageMargin
        let height = GameConfig.Player.halfDepth * 2 + GameConfig.Trees.passageMargin

        let ownGap = treeGap(in: biomes.biome(at: candidate.centre))
        for other in planted {
            let delta = candidate.centre - other.centre
            let distance = delta.length
            guard distance > 0.0001 else { return false }

            // How much of a player lies along the line between the two: their
            // width if the clumps are side by side, their height if stacked.
            let across = abs(delta.x) / distance * width + abs(delta.y) / distance * height

            // The wider of the two biomes' gaps, so a forest edge stays walkable
            // from both sides - and never less than a player.
            let gap = max(ownGap, treeGap(in: biomes.biome(at: other.centre)), across)
            if distance < candidate.radius + other.radius + gap { return false }
        }

        for claim in claims.values {
            // The claim, grown by a player's width at the sides and a player's
            // height above and below, so there is always a way round a base.
            let closest = candidate.closestPoint(
                inBox: Vec2(x: Double(claim.origin.col) - width,
                            y: Double(claim.origin.row) - height),
                to: Vec2(x: Double(claim.origin.col + claim.size) + width,
                         y: Double(claim.origin.row + claim.size) + height)
            )
            if (closest - candidate.centre).length < candidate.radius { return false }
        }

        // Off the stone border by enough to walk between the two.
        let centre = candidate.centre
        let radius = candidate.radius
        guard centre.x - radius >= 1 + width,
              centre.x + radius <= Double(map.width - 1) - width,
              centre.y - radius >= 1 + height,
              centre.y + radius <= Double(map.height - 1) - height else { return false }

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

            // The map's own are always cabinets. A mini is something you find in
            // a crate and stand up behind your own wall - the point of the four out
            // here is that they are the best machines on the board and the risky
            // way to earn, and a small one in the open would be neither.
            let size = ArcadeKind.full

            let col = Int.random(in: 2...(map.width - size.width - 2), using: &rng)
            let row = Int.random(in: 2...(map.height - size.height - 2), using: &rng)
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

            // A few start rare; most rare ones turn up later, as crates respawn -
            // see GameConfig.Loot.rareChance. Drawn from the world's own
            // generator, so a seed still replays exactly.
            let rare = Double.random(in: 0..<1, using: &rng) < GameConfig.Loot.startingRareShare
            placed.append(Lootbox(id: LootboxID(placed.count), tile: tile, rare: rare))
        }

        return placed
    }
}
