//
//  EquipSystem.swift
//  Loot Wars
//
//  Putting on gear you were carrying.
//
//  Sits alongside ConsumableSystem and BombSystem, all three watching the same
//  useItem command and each answering for its own kind of item. They cannot collide:
//  a drink is healing, a bomb is a bomb, and gear is neither.
//
//  The rule that matters is that this only ever goes UP. It is written once, in
//  Actor.canUse, and asked here and by the hotbar that greys the slot out - so a
//  spare you cannot use yet looks unusable, and lights up by itself the moment you
//  respawn bare-headed.
//

enum EquipSystem {

    static func update(_ world: World, commands: [ActorID: [Command]]) {
        for (id, list) in commands {
            for command in list {
                guard case .useItem(let slot) = command else { continue }
                equip(slot: slot, by: id, in: world)
            }
        }
    }

    /// Whether this slot holds gear this actor could put on right now.
    static func canEquip(slot: Int, actor: Actor) -> Bool {
        actor.inventory.stack(at: slot)?.type.isGear == true && actor.canUse(slot: slot)
    }

    private static func equip(slot: Int, by id: ActorID, in world: World) {
        guard var actor = world.actors[id],
              canEquip(slot: slot, actor: actor),
              let type = actor.inventory.stack(at: slot)?.type else { return }

        switch type {
        case .helmet(let tier):
            // The extra capacity arrives as actual health, exactly as it does when
            // one is picked up off the ground - so a spare pulled out of a chest
            // after respawning is a real recovery and not just a longer empty bar.
            let gained = tier.maxHealth - actor.maxHealth
            actor.helmet = tier
            actor.health = min(actor.maxHealth, actor.health + gained)

        case .blaster(let tier):
            actor.blaster = tier

        case .bandage, .medkit, .bomb, .chest:
            return   // somebody else's business; canEquip already refused these
        }

        _ = actor.inventory.consume(at: slot)
        world.actors[id] = actor
    }
}
