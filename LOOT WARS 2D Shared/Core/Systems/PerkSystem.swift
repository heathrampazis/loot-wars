//
//  PerkSystem.swift
//  Loot Wars
//
//  Power-ups, while they run.
//
//  Deliberately its own system rather than a few lines inside CombatSystem, and the
//  reason is the ones that are not written yet. There will be more perks - speed,
//  damage, something that makes walls cheaper - and every one of them is the same
//  shape: a timer on the actor, something that happens on a beat while it lasts,
//  and an end. A file that already has that shape is where the second one goes; a
//  clause bolted into combat is where the second one gets bolted on beside it.
//
//  Health arrives in PORTIONS here too, for the third time in this project and the
//  same reason each time: the screen reacts to every point of healing, and sixty
//  reactions a second is not a glow, it is a fault.
//

enum PerkSystem {

    static func update(_ world: World, dt: Double) {
        for id in world.actors.keys.sorted(by: { $0.raw < $1.raw }) {
            guard var actor = world.actors[id], actor.perk != nil else { continue }

            // Dying ends it. A perk is a thing that is true of you, and you have
            // stopped being true.
            guard actor.isAlive else {
                clear(&actor)
                world.actors[id] = actor
                continue
            }

            actor.perkRemaining -= dt

            guard actor.perkRemaining > 0 else {
                clear(&actor)
                world.actors[id] = actor
                continue
            }

            actor.perkTick -= dt

            if actor.perkTick <= 0 {
                actor.perkTick = GameConfig.Perks.tickInterval
                world.actors[id] = actor
                apply(actor.perk, to: id, in: world)
                continue
            }

            world.actors[id] = actor
        }
    }

    private static func clear(_ actor: inout Actor) {
        actor.perk = nil
        actor.perkRemaining = 0
        actor.perkTick = 0
    }

    /// What one beat of a running perk does.
    ///
    /// Only the healing, because only the healing is a thing that HAPPENS. The
    /// speed, the damage and the resistance are numbers read where they matter - by
    /// MovementSystem, by WeaponSystem, by CombatSystem - so they need no beat and
    /// nothing put back at the end. The switch stays a switch rather than an `if`,
    /// so a second perk added later arrives as a compiler error here rather than as
    /// a power-up that silently does nothing.
    private static func apply(_ perk: Perk?, to id: ActorID, in world: World) {
        guard let perk, let actor = world.actors[id] else { return }

        switch perk {
        case .overdrive:
            let portion = Double(actor.maxHealth) * GameConfig.Perks.healPortion
            CombatSystem.heal(id, amount: max(1, Int(portion.rounded())), in: world)
        }
    }
}
