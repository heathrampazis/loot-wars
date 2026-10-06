// The four kinds of ground a map is split into, and which one each tile belongs to.

enum Biome: CaseIterable {
    case plains
    case forest
    case snow
    case desert
}

struct BiomeMap {
    let width: Int
    let height: Int
    private var tiles: [Biome]

    init(width: Int, height: Int, fill: Biome = .plains) {
        self.width = width
        self.height = height
        self.tiles = Array(repeating: fill, count: width * height)
    }

    // Out-of-bounds reads clamp to the nearest edge tile, so callers never need to check.
    subscript(point: GridPoint) -> Biome {
        get {
            let col = min(max(point.col, 0), width - 1)
            let row = min(max(point.row, 0), height - 1)
            return tiles[row * width + col]
        }
        set {
            guard point.col >= 0, point.col < width, point.row >= 0, point.row < height else { return }
            tiles[point.row * width + point.col] = newValue
        }
    }

    func biome(at position: Vec2) -> Biome {
        self[GridPoint(containing: position)]
    }

    // Share 0-1 of the map's tiles in each biome.
    var shares: [Biome: Double] {
        var counts: [Biome: Int] = [:]
        for biome in tiles { counts[biome, default: 0] += 1 }
        let total = Double(max(1, tiles.count))
        return counts.mapValues { Double($0) / total }
    }
}
