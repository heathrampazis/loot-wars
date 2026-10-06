//
//  GasCloud.swift
//  Loot Wars
//
//  A patch of ground nobody wants to stand on.
//
//  The stink bomb's whole point, and the one thing in this game that takes GROUND
//  away rather than taking health, walls or loot. A bomb opens a base; a cloud
//  closes a doorway, a corridor, or the two tiles somebody was about to walk
//  through - and it does it for long enough to matter and not a second longer,
//  because a map with permanent no-go areas on it stops being a map.
//
//  It is not solid and it does not block a shot. Everything it does is done by
//  hurting whoever chooses to stand in it, which is what makes it a threat you can
//  ignore at a price rather than a wall you cannot pass.
//

struct GasCloudID: Hashable {
    let raw: Int

    init(_ raw: Int) {
        self.raw = raw
    }
}

struct GasCloud {
    let id: GasCloudID

    /// Where it was thrown. Clouds do not drift: a cloud that moved would be a
    /// thing you have to watch rather than a thing you have to route around, and
    /// routing around it is the decision this item exists to create.
    let centre: Vec2

    /// Who threw it, and for which team. Kept for the scoreboard - gas kills pay
    /// the person who left it there, in the minute or so it stands.
    let owner: ActorID
    let team: TeamID

    var timeRemaining: Double

    /// Counts down to the next dose. Damage arrives in portions rather than as a
    /// trickle for the same reason healing does: the screen reacts to every point
    /// of damage, and sixty reactions a second is not a fog, it is a fault.
    var doseTimer: Double = 0

    var radius: Double { GameConfig.Stink.radius }

    /// How thick it is right now, nought to one.
    ///
    /// Rises quickly as it spreads and falls away as it thins, so the picture and
    /// the danger agree: the renderer draws this, and the damage below is gated on
    /// the same number, which means gas you can barely see cannot still be taking
    /// half your health.
    var density: Double {
        let life = GameConfig.Stink.duration
        let spent = life - timeRemaining

        if spent < GameConfig.Stink.spread {
            return max(0, spent / GameConfig.Stink.spread)
        }

        let fade = GameConfig.Stink.fade
        guard timeRemaining < fade else { return 1 }
        return max(0, timeRemaining / fade)
    }

    func contains(_ point: Vec2) -> Bool {
        (point - centre).length <= radius
    }
}
