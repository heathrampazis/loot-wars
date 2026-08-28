//
//  Projectile.swift
//  Loot Wars
//

struct ProjectileID: Hashable {
    let raw: Int

    init(_ raw: Int) {
        self.raw = raw
    }
}

struct Projectile {
    let id: ProjectileID
    /// Who fired it. Kept so a bullet can never hit its own team later.
    let owner: ActorID
    let team: TeamID

    var position: Vec2
    let velocity: Vec2

    /// Tiles left before it fizzles out. Counting distance rather than seconds means
    /// range stays the same if projectile speed is ever tuned.
    var distanceRemaining: Double
}
