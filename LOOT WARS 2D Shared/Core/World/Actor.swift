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

    /// The last direction the actor actually moved in, and therefore where it
    /// shoots. Holds its value when the stick is released, so letting go does not
    /// leave you aiming at nothing.
    var facing: Vec2 = Vec2(x: 1, y: 0)

    /// Which way the figure is drawn. Held separately from `facing` because moving
    /// straight up or down should not turn the character to face the camera - it
    /// keeps whichever side it was last heading.
    var facesLeft: Bool = false

    /// Seconds until this actor may fire again.
    var shootCooldown: Double = 0

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
