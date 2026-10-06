//
//  VaultSystem.swift
//  Loot Wars
//
//  What a base pays you for being a base.
//
//  Every other score in this game is for an ACT: opening a crate, laying a wall,
//  taking somebody down. Building was priced the same way - two points a brick and
//  sixty for the last one - and the result was that a base was worth exactly as
//  much as the minute you spent making it, after which the correct play was to walk
//  away and never think about it again. Nothing paid for keeping it, so nobody kept
//  it, and a game about breaking into places had eight players who did not care
//  about their own.
//
//  So a standing base pays on a clock, and what is inside it pays more. Both halves
//  matter and they answer different questions. The wall answers "why build" - it
//  earns while it is shut and stops the moment somebody opens it, which is also
//  what turns a raid into something more than shopping: you are switching off their
//  income. The chest answers "why store anything" - banking used to be pure
//  insurance against dying, and insurance is worth nothing when dying is cheap, so
//  everybody carried their loot until they lost it. Now the vault earns.
//
//  It cannot be farmed. The per-item share is capped, so hoarding stops paying
//  quickly and a base stays a place worth two visits rather than a warehouse.
//

enum VaultSystem {

    static func update(_ world: World, dt: Double) {
        guard !world.isOver else { return }

        world.holdTimer -= dt
        guard world.holdTimer <= 0 else { return }
        world.holdTimer = GameConfig.Score.holdInterval

        for team in TeamID.all {
            // A hole anywhere in the wall stops all of it. baseIsBreached is also
            // true for a base that was never finished, which is the same answer for
            // a different reason and the right one either way: this pays for a wall
            // that is SHUT, and an unbuilt base is not shut.
            guard !world.baseIsBreached(team) else { continue }

            let banked = min(world.storedItemCount(ownedBy: team),
                             GameConfig.Score.holdItemCap)

            let points = GameConfig.Score.holdStanding
                + banked * GameConfig.Score.holdPerStoredItem

            world.award(points, to: team)

            // Announced rather than noticed, because a score arriving on a clock is
            // the one thing a renderer cannot work out by looking: nothing about
            // the world changed except a number in a table nobody is reading.
            guard let claim = world.claim(for: team) else { continue }

            world.record(.vault(points: points, for: team,
                                at: Vec2(x: Double(claim.centreTile.col) + 0.5,
                                         y: Double(claim.centreTile.row) + 0.5)))
        }
    }
}
