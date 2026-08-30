//
//  Bomb.swift
//  Loot Wars
//
//  A thrown charge, in flight.
//
//  Separate from Projectile on purpose: a bullet is a point that hurts whoever it
//  touches, a bomb is a thing that lands somewhere and takes a piece of the map
//  with it. Sharing a type would mean every check on either one carrying an
//  "except when it is the other kind" clause.
//

struct BombID: Hashable {
    let raw: Int

    init(_ raw: Int) {
        self.raw = raw
    }
}

struct Bomb {
    let id: BombID
    /// Who threw it. Kept so a raider is not caught in its own blast.
    let owner: ActorID
    let team: TeamID

    var position: Vec2
    let velocity: Vec2

    /// Where it was aimed. It detonates on arrival even over open ground, so a
    /// throw that misses still goes off rather than sailing away.
    let target: Vec2

    /// Tiles left before it falls short.
    var distanceRemaining: Double
}
