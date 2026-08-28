//
//  TreePatch.swift
//  Loot Wars
//
//  A clump of trees: grid-aligned, but collided with as a CIRCLE rather than as a
//  block of tiles.
//
//  Two reasons for the circle. The art is a star, so a square hitbox makes you catch
//  on corners that visibly contain nothing. And a circle is the one shape that does
//  not change as it rotates - which is what lets clumps spin without the collision
//  drifting away from what is drawn.
//

struct TreePatch {
    /// Bottom-left tile of the clump. Placement stays on the grid even though
    /// collision does not.
    let origin: GridPoint
    /// Width and height in tiles. Clumps are square.
    let size: Int
    /// Collision radius in tiles, sitting between the star's inner and outer radius:
    /// big enough not to walk through the shape, small enough not to catch on air.
    let radius: Double

    /// Radians per second. Signed - the sign is the direction of spin.
    let spin: Double
    /// Where in its turn the clump starts, so they are not all aligned.
    let initialRotation: Double

    var centre: Vec2 {
        Vec2(x: Double(origin.col) + Double(size) / 2,
             y: Double(origin.row) + Double(size) / 2)
    }

    func contains(_ point: Vec2) -> Bool {
        let delta = point - centre
        return delta.x * delta.x + delta.y * delta.y < radius * radius
    }

    /// Does the clump reach into this tile at all?
    func overlaps(_ tile: GridPoint) -> Bool {
        let closest = closestPoint(inBox: Vec2(x: Double(tile.col), y: Double(tile.row)),
                                   to: Vec2(x: Double(tile.col + 1), y: Double(tile.row + 1)))
        let delta = closest - centre
        return delta.x * delta.x + delta.y * delta.y < radius * radius
    }

    /// The point inside the given box that sits nearest the clump's centre.
    func closestPoint(inBox minimum: Vec2, to maximum: Vec2) -> Vec2 {
        Vec2(x: min(max(centre.x, minimum.x), maximum.x),
             y: min(max(centre.y, minimum.y), maximum.y))
    }
}
