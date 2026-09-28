//
//  Turret.swift
//  Loot Wars
//
//  A gun that stands in somebody's base and shoots whoever is not them.
//
//  Two tiles by two, like a mini machine, and placed the same way - carried home
//  out of a crate and stood up inside your walls. It is the one piece of furniture
//  that does something WHILE you are away, and the thing it does is the thing a
//  base has never been able to do for itself: make the inside of it dangerous.
//
//  IT DEFENDS THE ROOM, NOT THE APPROACH, and that falls out of the rules rather
//  than being written into them. A turret has to be able to see what it shoots,
//  and walls stop bullets - its own included - so standing inside a sealed base it
//  cannot touch anybody outside. What it does is punish the part of a raid that
//  takes time: cracking a chest, taking a machine apart, standing in the hole you
//  made. Walk past a base and nothing happens. Walk IN and it matters.
//
//  It can be broken, and that is not negotiable. Bullets and bombs take it apart
//  exactly as they take a machine apart, it mends when left alone, and breaking one
//  pays. A defence nobody could remove would make a sealed base simply not worth
//  raiding - which is the one failure the raid loop was rebuilt to prevent.
//

struct TurretID: Hashable {
    let raw: Int

    init(_ raw: Int) {
        self.raw = raw
    }
}

struct Turret {
    let id: TurretID

    /// Bottom-left tile of the footprint. It extends right and up, like a machine.
    let origin: GridPoint

    /// Whose base it defends. Always somebody's - there are no turrets on the map
    /// that nobody owns, because a gun that shoots everybody is a hazard rather
    /// than a defence, and the map already has gas for that.
    let owner: TeamID

    var health: Int = GameConfig.Turret.health

    /// Which way the barrel is pointing, in radians, and where it is trying to
    /// point. The barrel TURNS rather than snapping, which is most of what makes
    /// one read as a thing that has noticed you - see TurretSystem.track.
    var heading: Double = 0

    /// Who it is currently shooting at, if anybody. Kept so it does not flick
    /// between two intruders standing at similar distances every tick.
    var target: ActorID?

    /// Counts down to the next shot.
    var cooldown: Double = 0

    /// How long since anybody last put a shot into it, and the countdown to the
    /// next portion of health coming back. The machine's pair, for the machine's
    /// reason - see ArcadeSystem.mend.
    ///
    /// Starts absurdly high rather than at zero, so a turret that has never been
    /// touched is not, for its first few seconds, a turret that was just shot.
    var secondsSinceHit: Double = 999
    var mendTimer: Double = 0

    static let width = 2
    static let height = 2

    /// Every tile it stands on.
    var tiles: [GridPoint] {
        (0..<Turret.width).flatMap { dx in
            (0..<Turret.height).map { dy in
                GridPoint(col: origin.col + dx, row: origin.row + dy)
            }
        }
    }

    var centre: Vec2 {
        Vec2(x: Double(origin.col) + Double(Turret.width) / 2,
             y: Double(origin.row) + Double(Turret.height) / 2)
    }

    /// Solid, and exactly the size the renderer draws.
    var hitbox: Box {
        Box(centre: centre, size: Vec2(x: Double(Turret.width), y: Double(Turret.height)))
    }

    /// Where a shot leaves it, for a barrel pointing this way.
    ///
    /// OUTSIDE its own hitbox, and that is load-bearing rather than cosmetic. A
    /// turret absorbs its own team's bullets harmlessly, the way your own machine
    /// does - so a shot spawned inside the thing that fired it would be eaten on
    /// the first tick and nothing would ever leave the barrel.
    func muzzle(pointing direction: Vec2) -> Vec2 {
        centre + direction * GameConfig.Turret.muzzleReach
    }
}
