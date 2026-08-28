//
//  Actor.swift
//  Loot Wars
//
//  One type for the player and (later) every AI. The only difference between them
//  is who produces their Commands - a joystick, a brain, or a network packet.
//

struct Actor {
    let id: ActorID
    let team: TeamID

    /// Centre of the actor's hitbox, in tile space.
    var position: Vec2

    /// The direction this actor is trying to move, length 0...1.
    /// Set from Commands at the start of every tick.
    var moveInput: Vec2 = .zero

    /// Does this actor's hitbox overlap the given tile at all?
    /// Lives here so collision, building and rendering all agree on the answer.
    func overlaps(_ point: GridPoint) -> Bool {
        let half = GameConfig.Player.halfSize
        return position.x + half > Double(point.col)
            && position.x - half < Double(point.col + 1)
            && position.y + half > Double(point.row)
            && position.y - half < Double(point.row + 1)
    }
}
