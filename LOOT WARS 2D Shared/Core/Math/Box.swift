//
//  Box.swift
//  Loot Wars
//
//  An axis-aligned box in tile space.
//
//  Named lower/upper rather than min/max on purpose: properties called min and max
//  would shadow the global functions of the same name inside this type's own methods.
//

struct Box {
    var lower: Vec2
    var upper: Vec2

    init(lower: Vec2, upper: Vec2) {
        self.lower = lower
        self.upper = upper
    }

    /// A box of the given size, centred on a point.
    init(centre: Vec2, size: Vec2) {
        self.lower = Vec2(x: centre.x - size.x / 2, y: centre.y - size.y / 2)
        self.upper = Vec2(x: centre.x + size.x / 2, y: centre.y + size.y / 2)
    }

    /// The box covering exactly one grid tile.
    init(tile: GridPoint) {
        self.lower = Vec2(x: Double(tile.col), y: Double(tile.row))
        self.upper = Vec2(x: Double(tile.col + 1), y: Double(tile.row + 1))
    }

    var centre: Vec2 {
        Vec2(x: (lower.x + upper.x) / 2, y: (lower.y + upper.y) / 2)
    }

    func contains(_ point: Vec2) -> Bool {
        point.x >= lower.x && point.x <= upper.x
            && point.y >= lower.y && point.y <= upper.y
    }

    func intersects(_ other: Box) -> Bool {
        upper.x > other.lower.x && lower.x < other.upper.x
            && upper.y > other.lower.y && lower.y < other.upper.y
    }

    /// Grown by the same amount on every side. Used for reach checks, where you want
    /// "close enough to touch" rather than "actually overlapping".
    func expanded(by amount: Double) -> Box {
        Box(lower: Vec2(x: lower.x - amount, y: lower.y - amount),
            upper: Vec2(x: upper.x + amount, y: upper.y + amount))
    }

    /// The point inside this box nearest to the given one.
    func closestPoint(to point: Vec2) -> Vec2 {
        Vec2(x: Swift.min(Swift.max(point.x, lower.x), upper.x),
             y: Swift.min(Swift.max(point.y, lower.y), upper.y))
    }
}
