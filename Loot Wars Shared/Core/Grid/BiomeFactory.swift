// Splits a map into a handful of wobbly biome regions, the same way every time for a seed.

enum BiomeFactory {
    static func generate(width: Int, height: Int, seed: UInt64,
                         around claims: [TeamID: BaseClaim]) -> BiomeMap {
        // Its own generator, so adding biomes never shifts the rest of the map's random draws.
        var rng = SeededRandom(seed: seed ^ 0xB10E_5EED_CAFE_F00D)
        let sites = placeSites(width: width, height: height, using: &rng)
        let warp = WarpField(width: width, height: height, using: &rng)

        func region(col: Int, row: Int) -> Biome {
            let bend = warp.offset(col: col, row: row)
            let point = Vec2(x: Double(col) + 0.5 + bend.x, y: Double(row) + 0.5 + bend.y)
            return nearest(of: sites, to: point)
        }

        // Each base claims a round clearing in the biome at its centre, so no border runs through it.
        let bases = claims.values.sorted { $0.team.raw < $1.team.raw }.map { claim in
            (centre: claim.centreTile.center,
             biome: region(col: claim.centreTile.col, row: claim.centreTile.row))
        }

        var biomes = BiomeMap(width: width, height: height)
        for row in 0..<height {
            for col in 0..<width {
                let spot = Vec2(x: Double(col) + 0.5, y: Double(row) + 0.5)
                var clearing: Biome?
                var closest = GameConfig.Biomes.baseClearing
                for base in bases {
                    let distance = (base.centre - spot).length
                    if distance < closest {
                        closest = distance
                        clearing = base.biome
                    }
                }
                biomes[GridPoint(col: col, row: row)] = clearing ?? region(col: col, row: row)
            }
        }

        var result = smoothed(biomes)
        settle(&result, under: claims)
        return result
    }

    // MARK: - Bases

    // A safety net after smoothing: each base's own square is painted its centre's biome.
    private static func settle(_ biomes: inout BiomeMap, under claims: [TeamID: BaseClaim]) {
        let reach = GameConfig.Map.claimSize / 2
        for claim in claims.values.sorted(by: { $0.team.raw < $1.team.raw }) {
            let centre = claim.centreTile
            let biome = biomes[centre]
            for dr in -reach...reach {
                for dc in -reach...reach {
                    biomes[GridPoint(col: centre.col + dc, row: centre.row + dr)] = biome
                }
            }
        }
    }

    // MARK: - Regions

    private struct Site {
        let position: Vec2
        let biome: Biome
    }

    // Every biome appears at least once; the extra regions lean towards plains.
    private static func placeSites(width: Int, height: Int,
                                   using rng: inout SeededRandom) -> [Site] {
        var kinds = Biome.allCases
        let extras = max(0, GameConfig.Biomes.regionCount - kinds.count)
        for _ in 0..<extras {
            kinds.append(GameConfig.Biomes.extraRegionPool.randomElement(using: &rng) ?? .plains)
        }
        kinds.shuffle(using: &rng)

        let margin = Double(GameConfig.Biomes.siteMargin)
        var spacing = GameConfig.Biomes.siteSpacing
        var sites: [Site] = []

        for biome in kinds {
            var placed: Vec2?
            // Relaxes the spacing a tile at a time so generation always finishes.
            while placed == nil {
                for _ in 0..<60 {
                    let spot = Vec2(x: Double.random(in: margin...(Double(width) - margin), using: &rng),
                                    y: Double.random(in: margin...(Double(height) - margin), using: &rng))
                    if sites.allSatisfy({ ($0.position - spot).length >= spacing }) {
                        placed = spot
                        break
                    }
                }
                if placed == nil { spacing = max(1, spacing - 1) }
            }
            sites.append(Site(position: placed ?? Vec2(x: 0, y: 0), biome: biome))
        }
        return sites
    }

    // Ties go to the earlier site, so the answer never depends on anything but the seed.
    private static func nearest(of sites: [Site], to point: Vec2) -> Biome {
        var best = sites.first?.biome ?? .plains
        var shortest = Double.greatestFiniteMagnitude
        for site in sites {
            let distance = (site.position - point).length
            if distance < shortest {
                shortest = distance
                best = site.biome
            }
        }
        return best
    }

    // One majority pass, so borders lose their single-tile specks.
    private static func smoothed(_ source: BiomeMap) -> BiomeMap {
        var result = source
        for row in 0..<source.height {
            for col in 0..<source.width {
                var counts: [Biome: Int] = [:]
                for dr in -1...1 {
                    for dc in -1...1 {
                        counts[source[GridPoint(col: col + dc, row: row + dr)], default: 0] += 1
                    }
                }
                for biome in Biome.allCases where (counts[biome] ?? 0) >= 5 {
                    result[GridPoint(col: col, row: row)] = biome
                }
            }
        }
        return result
    }

    // MARK: - Wobble

    // A coarse grid of random nudges, blended smoothly, that bends the straight region edges.
    private struct WarpField {
        let cell: Int
        let columns: Int
        let nudges: [Vec2]

        init(width: Int, height: Int, using rng: inout SeededRandom) {
            cell = max(1, GameConfig.Biomes.warpCell)
            columns = width / cell + 2
            let rows = height / cell + 2
            var made: [Vec2] = []
            for _ in 0..<(columns * rows) {
                made.append(Vec2(x: Double.random(in: -1...1, using: &rng),
                                 y: Double.random(in: -1...1, using: &rng)))
            }
            nudges = made
        }

        func offset(col: Int, row: Int) -> Vec2 {
            let fx = Double(col) / Double(cell)
            let fy = Double(row) / Double(cell)
            let ix = Int(fx)
            let iy = Int(fy)
            let tx = ease(fx - Double(ix))
            let ty = ease(fy - Double(iy))

            let top = nudge(ix, iy) * (1 - tx) + nudge(ix + 1, iy) * tx
            let bottom = nudge(ix, iy + 1) * (1 - tx) + nudge(ix + 1, iy + 1) * tx
            return (top * (1 - ty) + bottom * ty) * GameConfig.Biomes.warpStrength
        }

        private func nudge(_ x: Int, _ y: Int) -> Vec2 {
            nudges[min(y * columns + x, nudges.count - 1)]
        }

        // Smoothstep, so the bends have no visible kinks at cell edges.
        private func ease(_ t: Double) -> Double {
            t * t * (3 - 2 * t)
        }
    }
}
