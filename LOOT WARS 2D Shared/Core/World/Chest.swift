//
//  Chest.swift
//  Loot Wars
//
//  Storage you place in your own base.
//
//  Note what it holds: an Inventory, the same type the player carries. A chest and
//  a pocket obey identical stacking rules, so four bandages stack in a chest exactly
//  as they do in a hotbar slot, and moving something between the two can never find
//  the two sides disagreeing about whether it fits. Reusing the type is not a
//  shortcut here - it is the reason no item can be lost in transit.
//

struct ChestID: Hashable {
    let raw: Int

    init(_ raw: Int) {
        self.raw = raw
    }
}

struct Chest {
    let id: ChestID
    let tile: GridPoint

    /// Whose base it stands in. Only the owner may open it - for now. Once raiding
    /// takes what is inside, this is the field that decides who is robbing whom.
    let owner: TeamID

    var contents = Inventory()

    /// How much punishment is left in it.
    ///
    /// A chest is broken open by shooting it - see GameConfig.Chest.health for what
    /// that replaced and why. Its own health rather than a share of the owner's or
    /// a timer on the raider, because the damage belongs to the BOX: two raiders on
    /// the same chest both count towards it, a raider who is driven off and comes
    /// back finds it as they left it, and a chest nobody followed up on mends.
    ///
    /// None of which a count on the raider could do. That one was zeroed the moment
    /// anybody hit you, so a chest half broken by somebody who then died was a
    /// chest that had never been touched.
    var health = GameConfig.Chest.health

    /// How long since anybody last put a shot into it, and the countdown to the
    /// next portion coming back. The same pair a machine has, for the same reason -
    /// see ArcadeSystem.mend.
    ///
    /// Starts absurdly high rather than at zero, so a chest that has never been
    /// touched is not, for its first few seconds, a chest that was just shot.
    var secondsSinceHit: Double = 999
    var mendTimer: Double = 0

    /// Whether this chest refills itself. True for a bot's, false for yours.
    ///
    /// A standing reason to come back. A chest raided once and empty forever is a
    /// one-off errand; one that fills again is a place on the map worth returning
    /// to, which is what makes raiding a habit rather than an event.
    var selfStocking = false

    /// Counts down to the next item appearing. Slow on purpose - see
    /// GameConfig.Chest.restockInterval.
    var restockTimer: Double = 0

    var position: Vec2 { tile.center }

    /// Solid, and exactly the size the renderer draws.
    var hitbox: Box {
        Box(centre: position, size: GameConfig.Chest.size)
    }
}
