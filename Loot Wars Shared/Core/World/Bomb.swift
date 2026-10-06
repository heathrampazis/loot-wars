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
    /// What happens when it stops.
    ///
    /// One type with a kind rather than two types, because everything BEFORE the
    /// landing is identical - thrown along the aim, same speed, same arc, stopped
    /// by the same walls - and only the last instant differs. Two structs would
    /// have meant two copies of the flight code drifting apart, and the flight is
    /// the part with the interesting bugs in it.
    enum Kind {
        /// Takes a piece of the map with it.
        case blast
        /// Leaves a cloud of gas standing where it landed.
        case stink
    }

    let id: BombID
    let kind: Kind
    /// Who threw it. Kept so a raider is not caught in its own blast.
    let owner: ActorID
    let team: TeamID

    var position: Vec2
    let velocity: Vec2

    /// Tiles left before it runs out of throw and goes off where it lands.
    var distanceRemaining: Double
}
