//
//  Actor.swift
//  Loot Wars
//
//  One type for the player and (later) every AI. The only difference between them
//  is who produces their Commands - a joystick, a brain, or a network packet.
//

struct Actor {
    let id: ActorID

    /// Centre of the actor's hitbox, in tile space.
    var position: Vec2

    /// The direction this actor is trying to move, length 0...1.
    /// Set from Commands at the start of every tick.
    var moveInput: Vec2 = .zero
}
