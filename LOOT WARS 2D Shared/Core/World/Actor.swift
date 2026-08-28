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

    var health: Int = GameConfig.Player.maxHealth

    /// nil while alive; counts down to respawn while dead.
    var respawnTimer: Double?

    /// Seconds of spawn protection left.
    var invulnerability: Double = 0

    var isAlive: Bool { respawnTimer == nil }

    var ammo: Int = GameConfig.Blaster.magazineSize

    var inventory = Inventory()

    /// Seconds until this actor may fire again.
    var shootCooldown: Double = 0

    /// Counts down to the next bullet coming back. Reset to the recharge delay on
    /// every shot, so firing keeps pushing the refill away.
    var rechargeTimer: Double = 0

    /// This actor's collision box, in tile space.
    ///
    /// EVERYTHING that asks about the actor's shape goes through here - walls, trees,
    /// lootboxes, item pickups, building. One shape, one answer, so no two systems
    /// can develop their own idea of where the player is.
    var hitbox: Box {
        Box(centre: position,
            size: Vec2(x: GameConfig.Player.halfWidth * 2,
                       y: GameConfig.Player.halfDepth * 2))
    }

    /// The bottom edge of the hitbox, which is where the sprite is anchored.
    var feet: Vec2 {
        Vec2(x: position.x, y: position.y - GameConfig.Player.halfDepth)
    }

    /// Does this actor's hitbox overlap the given tile at all?
    func overlaps(_ point: GridPoint) -> Bool {
        hitbox.intersects(Box(tile: point))
    }
}
