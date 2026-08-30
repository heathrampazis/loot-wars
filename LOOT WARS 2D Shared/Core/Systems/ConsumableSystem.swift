//
//  ConsumableSystem.swift
//  Loot Wars
//
//  Drinking.
//
//  The rule about not drinking at full health lives here rather than in the UI,
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

    /// Whether an actor could DRINK what is in that slot right now. A bomb in the
    /// same slot is somebody else's business - see BombSystem.
    static func canUse(slot: Int, actor: Actor) -> Bool {
        guard actor.canUse(slot: slot),
              actor.inventory.slots[slot]?.type.isDrink == true else { return false }
        return true
    }

    private static func use(slot: Int, by id: ActorID, in world: World) {
        guard var actor = world.actors[id], canUse(slot: slot, actor: actor) else { return }
        guard let drink = actor.inventory.consume(at: slot) else { return }

        world.actors[id] = actor
        CombatSystem.heal(id, amount: drink.healAmount(of: actor.maxHealth), in: world)
    }
}
