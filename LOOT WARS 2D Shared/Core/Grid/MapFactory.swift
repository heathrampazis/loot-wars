//
//  MapFactory.swift
//  Loot Wars
//
//  Builds a map from a seed. Same seed in, same map out - always.
//
//  Still deliberately simple: an edge, one base claim, and scattered trees. Eight
//  claims on a ring, terrain features and loot spawns arrive at M3.
//

/// Everything the generator produces. Claims are part of the map's identity, not
/// something bolted on afterwards, so they come out of the same seeded pass.
struct GeneratedMap {
    let map: TileMap
    let claims: [TeamID: BaseClaim]
    let treePatches: [TreePatch]
}

enum MapFactory {

    static func generate(seed: UInt64) -> GeneratedMap {
        var rng = SeededRandom(seed: seed)
        var map = TileMap(width: GameConfig.Map.width, height: GameConfig.Map.height)

        sealEdges(of: &map)
        let claims = makeClaims(in: map)
        let treePatches = plantTrees(in: &map, avoiding: claims, using: &rng)

        return GeneratedMap(map: map, claims: claims, treePatches: treePatches)
    }

    /// One claim in the middle for now. M3 spreads eight of them around a ring.
    private static func makeClaims(in map: TileMap) -> [TeamID: BaseClaim] {
        let claim = BaseClaim(team: TeamID(0),
                              centredOn: GridPoint(col: map.width / 2, row: map.height / 2),
                              size: GameConfig.Map.claimSize)
        return [claim.team: claim]
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

    private static func plantTrees(in map: inout TileMap,
                                   avoiding claims: [TeamID: BaseClaim],
                                   using rng: inout SeededRandom) -> [TreePatch] {
        var patches: [TreePatch] = []

        // Placement can fail, so try more often than we need and stop once we have
        // enough. A fixed attempt budget means generation always terminates.
        let attempts = GameConfig.Map.treePatchCount * 25

        for _ in 0..<attempts {
            guard patches.count < GameConfig.Map.treePatchCount else { break }

            let size = GameConfig.Map.treePatchSizes.randomElement(using: &rng) ?? 2
            let patch = TreePatch(
                origin: GridPoint(col: Int.random(in: 1...(map.width - size - 1), using: &rng),
                                  row: Int.random(in: 1...(map.height - size - 1), using: &rng)),
                size: size
            )

            guard isClear(patch, in: map, avoiding: claims) else { continue }

            for tile in patch.tiles {
                map[tile] = .tree
            }
            patches.append(patch)
        }

        return patches
    }

    /// A clump needs its own tiles free AND a one tile gap all the way round.
    ///
    /// The gap does two jobs: clumps stay visually separate instead of fusing into
    /// accidental walls, and because the check runs one tile outside the patch, it
    /// also keeps trees from crowding right up against a claim or the map edge.
    private static func isClear(_ patch: TreePatch,
                                in map: TileMap,
                                avoiding claims: [TeamID: BaseClaim]) -> Bool {
        for col in (patch.origin.col - 1)...(patch.origin.col + patch.size) {
            for row in (patch.origin.row - 1)...(patch.origin.row + patch.size) {
                let point = GridPoint(col: col, row: row)

                guard map[point] == .floor else { return false }
                if claims.values.contains(where: { $0.contains(point) }) { return false }
            }
        }
        return true
    }
}
