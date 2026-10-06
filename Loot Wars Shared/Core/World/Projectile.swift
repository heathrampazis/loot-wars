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

    /// Fixed when the trigger was pulled. A shot in flight is not re-priced if the
    /// shooter picks up a better blaster before it lands.
    let damage: Int

    /// Tiles left before it fizzles out. Counting distance rather than seconds means
    /// range stays the same if projectile speed is ever tuned.
    var distanceRemaining: Double

    /// Fired by a turret rather than by a person holding the blaster. Credited
    /// to the team's actor like any shot, but it never hurts its own team's walls
    /// - see WallSystem.
    var fromTurret: Bool = false
}
