//
//  FlagSystem.swift
//  Loot Wars
//
//  Every base has a flag in its middle (Nov 2026). While it stands, its owner
//  respawns. An enemy standing by it for Flag.captureTime takes it, and from
//  then on the owner's next death is their last. See GameConfig.Flag.
//
//  Contested, it holds: while the owner is also standing by it, nobody's
//  capture moves. Left alone, a part-taken capture unwinds at Flag.decayRate.
//  Teams in id order and capturers in id order, so a seed replays the same.
//

enum FlagSystem {

    static func update(_ world: World, dt: Double) {
        guard !world.flags.isEmpty else { return }

        // Any base not sealed by now gets its flag anyway - see Flag.placeBy.
        if world.elapsed >= GameConfig.Flag.placeBy {
            for team in world.flags.keys.sorted(by: { $0.raw < $1.raw })
            where world.flags[team]?.placed == false && !world.isKnockedOut(team) {
                world.placeFlag(for: team)
            }
        }

        guard world.flagsCapturable else { return }
        let reach = GameConfig.Flag.captureRadius
        let full = GameConfig.Flag.captureTime

        for team in world.flags.keys.sorted(by: { $0.raw < $1.raw }) {
            guard var flag = world.flags[team], flag.placed, flag.standing,
                  let spot = world.flagPosition(of: team) else { continue }

            let near = world.actors.keys.sorted(by: { $0.raw < $1.raw })
                .compactMap { world.actors[$0] }
                .filter { $0.isAlive && ($0.position - spot).length <= reach }
            let takers = near.filter { $0.team != team }
            let defended = near.contains { $0.team == team }

            if let taker = takers.first {
                // Held while the owner stands there too.
                if !defended { flag.progress += dt }
                flag.capturer = taker.team
                if flag.progress >= full {
                    world.flags[team] = flag
                    world.captureFlag(of: team, by: taker.id)
                    continue
                }
            } else {
                flag.progress = max(0, flag.progress - dt * full * GameConfig.Flag.decayRate)
                if flag.progress <= 0 { flag.capturer = nil }
            }

            world.flags[team] = flag
        }
    }
}
