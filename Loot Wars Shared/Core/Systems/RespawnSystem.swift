//
//  RespawnSystem.swift
//  Loot Wars
//
//  Counts the dead back in, and runs down spawn protection.
//

enum RespawnSystem {

    static func update(_ world: World, dt: Double) {
        for id in Array(world.actors.keys) {
            guard var actor = world.actors[id] else { continue }

            if actor.invulnerability > 0 {
                actor.invulnerability = max(0, actor.invulnerability - dt)
            }

            if let timer = actor.respawnTimer {
                let remaining = timer - dt
                if remaining <= 0 {
                    respawn(&actor, in: world)
                } else {
                    actor.respawnTimer = remaining
                }
            }

            world.actors[id] = actor
        }
    }

    /// Takes the best helmet and the best blaster out of this actor's own chests,
    /// if they beat what it is wearing, and puts them on.
    ///
    /// Chests in id order, so two chests holding the same tier always give up
    /// the same one and a seed replays the same.
    private static func rearm(_ actor: inout Actor, in world: World) {
        var bestHelmet: (chest: ChestID, slot: Int, tier: HelmetTier)?
        var bestBlaster: (chest: ChestID, slot: Int, tier: BlasterTier)?

        let mine = world.chests.keys.sorted(by: { $0.raw < $1.raw })
            .compactMap { world.chests[$0] }
            .filter { $0.owner == actor.team }

        for chest in mine {
            for (index, slot) in chest.contents.slots.enumerated() {
                guard let stack = slot else { continue }
                switch stack.type {
                case .helmet(let tier) where tier > actor.helmet
                        && tier > (bestHelmet?.tier ?? HelmetTier.none):
                    bestHelmet = (chest.id, index, tier)
                case .blaster(let tier) where tier > actor.blaster
                        && tier > (bestBlaster?.tier ?? BlasterTier.starting):
                    bestBlaster = (chest.id, index, tier)
                default:
                    break
                }
            }
        }

        if let pick = bestHelmet {
            _ = world.chests[pick.chest]?.contents.consume(at: pick.slot)
            actor.helmet = pick.tier
            // Health is scaled by the helmet - fill it after, not before.
            actor.health = actor.maxHealth
        }
        if let pick = bestBlaster {
            _ = world.chests[pick.chest]?.contents.consume(at: pick.slot)
            actor.blaster = pick.tier
        }

        if bestHelmet != nil || bestBlaster != nil {
            world.record(.rearmed(actor.id, helmet: bestHelmet?.tier, blaster: bestBlaster?.tier))
        }
    }

    private static func respawn(_ actor: inout Actor, in world: World) {
        actor.respawnTimer = nil
        actor.health = actor.maxHealth
        actor.ammo = GameConfig.Blaster.magazineSize
        actor.invulnerability = GameConfig.Player.spawnProtection

        actor.moveInput = .zero
        actor.shootCooldown = 0
        actor.rechargeTimer = 0
        actor.secondsSinceHit = 999

        // Back to the middle of your own claim - the one place on the map that is
        // always yours.
        // The middle of your claim, unless your base has been furnished or walled
        // so that the middle is somewhere you could not move from - see
        // World.spawnPoint.
        actor.position = world.spawnPoint(for: actor.team)

        // Everybody comes back with nothing (Nov 2026): no free gear, no free
        // heals, bots included. It used to be bots only that got the late-match
        // floor, which with two lives made your second life hopeless against
        // them. Now the only thing that survives a death is what is in your
        // chest - see rearm below. Switch back with Player.respawnsWithKit.
        if GameConfig.Player.respawnsWithKit,
           let kit = GameConfig.Player.respawnKit(at: world.matchProgress) {
            if actor.helmet < kit.helmet {
                actor.helmet = kit.helmet
                // Health is scaled by the helmet, and it was just set to the old
                // maximum. Re-topped here rather than moved above, because the
                // order is the bug: fill first and the new helmet's extra hearts
                // arrive empty.
                actor.health = actor.maxHealth
            }
            if actor.blaster < kit.blaster { actor.blaster = kit.blaster }
        }

        if GameConfig.Player.respawnsWithKit {
            for item in GameConfig.Player.respawnHealKit(at: world.matchProgress) {
                _ = actor.inventory.add(item)
            }
        }

        // Everybody puts on the best helmet and blaster waiting in their own
        // chests. This is what a chest is FOR: gear banked at home is the
        // difference between walking back out ready and walking back out bare.
        // Bots too now, the same rule and the same instant, rather than walking
        // home for it (AIBrain.reArmWanted still does that for gear that turns up
        // in a chest later). Whatever a bot's chest happens to hold when it dies
        // is what it comes back in - the luck of the draw.
        rearm(&actor, in: world)

        // A bot that died halfway across the map should not come back still
        // pointed the way it was going. Face it out of its own base and let it
        // choose again shortly.
        if var ai = actor.ai {
            let outward = (actor.position - Vec2(x: Double(world.map.width) / 2,
                                                 y: Double(world.map.height) / 2))
            let heading = outward.length > 0 ? outward.normalized() : Vec2(x: 1, y: 0)
            ai.heading = heading
            ai.desiredHeading = heading
            ai.decisionTimer = 0
            actor.ai = ai
        }
    }
}
