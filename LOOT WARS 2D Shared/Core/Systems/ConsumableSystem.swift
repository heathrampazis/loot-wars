//
//  ConsumableSystem.swift
//  Loot Wars
//
//  Patching yourself up.
//
//  The rule about not healing at full health lives here rather than in the UI,
//  which matters: the hotbar greys a slot out to SHOW you that, but a bot asking
//  for the same thing is refused by the same code. There is one answer to "can this
//  be used right now", and everything asks it.
//

enum ConsumableSystem {

    static func update(_ world: World, commands: [ActorID: [Command]]) {
        for (id, list) in commands {
            for command in list {
                guard case .useItem(let slot) = command else { continue }
                use(slot: slot, by: id, in: world)
            }
        }
    }

    /// Whether an actor could TREAT A WOUND with what is in that slot right now. A
    /// bomb in the same slot is somebody else's business - see BombSystem.
    static func canUse(slot: Int, actor: Actor) -> Bool {
        guard actor.canUse(slot: slot) else { return false }
        guard let type = actor.inventory.slots[slot]?.type else { return false }
        return type.isHealing || type.perk != nil
    }

    /// The heal worth reaching for right now, or nil if there is none.
    ///
    /// Smallest that covers the wound, and the biggest one otherwise: a graze
    /// should not cost a medkit, and when nothing in the bag is enough you want the
    /// most it can give.
    ///
    /// NOTHING CALLS THIS TODAY, and it is kept rather than deleted because the
    /// reason it was written is still a real reason - it is just not needed at the
    /// moment. It existed so the screen and a bot could not come to different
    /// conclusions about which heal to reach for: the screen used to pick one and
    /// arm it the instant you were shot, so that the corner button already showed a
    /// bandage. There is no corner button and a tap on a slot is the heal, so the
    /// player does their own choosing now. AIBrain.healToUse still makes the same
    /// decision on the bots' side and would be the caller if the two ever have to
    /// agree again.
    ///
    /// Slot order breaks a tie, so the same bag always offers the same slot rather
    /// than swapping between two identical bandages.
    static func bestHeal(for actor: Actor) -> Int? {
        let missing = actor.maxHealth - actor.health
        guard missing > 0 else { return nil }

        var smallestThatFills: (slot: Int, amount: Int)?
        var biggest: (slot: Int, amount: Int)?

        for (index, slot) in actor.inventory.slots.enumerated() {
            guard let stack = slot, stack.type.isHealing,
                  canUse(slot: index, actor: actor) else { continue }

            let amount = stack.type.healAmount(of: actor.maxHealth)

            if amount >= missing, amount < (smallestThatFills?.amount ?? .max) {
                smallestThatFills = (index, amount)
            }

            if amount > (biggest?.amount ?? 0) {
                biggest = (index, amount)
            }
        }

        return (smallestThatFills ?? biggest)?.slot
    }

    private static func use(slot: Int, by id: ActorID, in world: World) {
        guard var actor = world.actors[id], canUse(slot: slot, actor: actor) else { return }
        guard let supply = actor.inventory.consume(at: slot) else { return }

        // Switched on rather than swallowed. Actor.canUse has already refused this
        // if one is running, which is the single place "one at a time" is decided -
        // the hotbar greys the slot from the same answer, so what the screen shows
        // and what the simulation allows cannot disagree.
        if let perk = supply.perk {
            actor.perk = perk
            actor.perkRemaining = perk.duration
            actor.perkTick = 0
            world.actors[id] = actor
            world.record(.perkStarted(perk, by: id))
            return
        }

        world.actors[id] = actor
        CombatSystem.heal(id, amount: supply.healAmount(of: actor.maxHealth), in: world)
        world.record(.healed(by: id))
    }
}
