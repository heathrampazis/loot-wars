//
//  AssistSystem.swift
//  Loot Wars
//
//  Easy controls: the fiddly parts done for you, so a new player can spend their
//  attention on moving and shooting.
//
//  - A crate opens the moment you are in reach of it.
//  - A heal is used when your health drops low.
//  - A shot fired roughly at somebody is bent onto them (aim help).
//  - A power-up you are carrying switches on when a fight starts.
//
//  It works through the same commands a player sends - an open, a use, a shot -
//  so every rule about whether that is allowed is still checked in the one place
//  it lives. Apart from bending a shot it only ever adds; anything the player
//  does themselves still works.
//
//  Per actor rather than per match (see Actor.assisted), so in a match with real
//  people one player can have it on without it touching anyone else.
//

import Foundation

enum AssistSystem {

    static func contribute(to commands: inout [ActorID: [Command]], in world: World, dt: Double) {
        for id in world.actors.keys.sorted(by: { $0.raw < $1.raw }) {
            guard var actor = world.actors[id], actor.assisted, actor.ai == nil else { continue }

            actor.assistHealWait = max(0, actor.assistHealWait - dt)
            defer { world.actors[id] = actor }
            guard actor.isAlive else { continue }

            var added: [Command] = []

            // Aim help: each shot this tick is turned onto the best target near
            // where it was pointed. Noted, so a power-up can tell a fight has
            // started from the player's side too, not only from being hit.
            var lockedOn = false
            if let list = commands[id] {
                commands[id] = list.map { command in
                    guard case .shoot(let direction) = command,
                          let aimed = assistedAim(direction, for: actor, in: world) else {
                        return command
                    }
                    lockedOn = true
                    return .shoot(aimed)
                }
            }

            // Crates: in reach is enough. LootSystem picks the box and opens one
            // per tick, exactly as if the button had been pressed.
            if world.reachableLootbox(for: actor) != nil {
                added.append(.openLootbox)
            }

            // Heals: below the line, the best one in the bag - the smallest that
            // fills you up, or the biggest if none does. A short wait after each,
            // so two can not go in the same instant and the heal reads as a beat.
            let healthLeft = Double(actor.health) / Double(max(1, actor.maxHealth))
            if actor.assistHealWait <= 0,
               healthLeft < GameConfig.Assist.healBelow,
               let slot = ConsumableSystem.bestHeal(for: actor) {
                added.append(.useItem(slot: slot))
                actor.assistHealWait = GameConfig.Assist.healGap
            }

            // Power-ups: switched on when a fight starts - you were just hit, or
            // you are shooting at somebody - and only when none is running.
            let inFight = lockedOn || actor.secondsSinceHit < GameConfig.Assist.perkHitWithin
            if inFight, actor.perk == nil, let slot = bestPerk(for: actor) {
                added.append(.useItem(slot: slot))
            }

            if !added.isEmpty {
                commands[id, default: []].append(contentsOf: added)
            }
        }
    }

    // MARK: - Aim help

    /// The shot turned onto the enemy nearest to where it was aimed, if one is
    /// inside the aim help's cone, in range and in plain sight - or nil to leave
    /// the shot alone. Aimed where they will be, the way the bots aim.
    private static func assistedAim(_ direction: Vec2, for actor: Actor, in world: World) -> Vec2? {
        guard direction.length > 0.01 else { return nil }
        let aim = direction.normalized()
        let cone = GameConfig.Assist.aimCone

        var best: (point: Vec2, score: Double)?

        for id in world.actors.keys.sorted(by: { $0.raw < $1.raw }) {
            guard let enemy = world.actors[id], enemy.team != actor.team,
                  enemy.isAlive, enemy.invulnerability <= 0 else { continue }

            let towards = enemy.position - actor.position
            let distance = towards.length
            guard distance > 0.01, distance <= GameConfig.Blaster.range else { continue }

            let dot = max(-1, min(1, (aim.x * towards.x + aim.y * towards.y) / distance))
            let angle = acos(dot)
            guard angle <= cone else { continue }
            guard AIBrain.hasLineOfSight(from: actor.position, to: enemy.position, in: world) else {
                continue
            }

            // Mostly the angle, a little the distance: the one you are pointing
            // at, and of two in line, the nearer.
            let score = angle / cone + distance / GameConfig.Blaster.range * 0.35
            guard score < (best?.score ?? .greatestFiniteMagnitude) else { continue }

            let flightTime = distance / GameConfig.Blaster.projectileSpeed
            let drift = enemy.moveInput.clampedToUnit()
                * (GameConfig.Player.moveSpeed * enemy.speedMultiplier * flightTime)
            best = (enemy.position + drift, score)
        }

        guard let target = best?.point else { return nil }
        let turned = target - actor.position
        return turned.length > 0.01 ? turned.normalized() : nil
    }

    // MARK: - Power-ups

    /// The power-up worth switching on, or nil. Low on health, the ones that
    /// keep you alive come first; otherwise the ones that win the fight. Health
    /// back is never used near full health, where it would be wasted.
    private static func bestPerk(for actor: Actor) -> Int? {
        let healthLeft = Double(actor.health) / Double(max(1, actor.maxHealth))
        let order: [Perk] = healthLeft < GameConfig.Assist.healBelow
            ? [.overdrive, .regeneration, .resistance, .strength, .speed]
            : [.strength, .resistance, .overdrive, .speed, .regeneration]

        for perk in order {
            if perk == .regeneration, healthLeft >= GameConfig.Assist.regenBelow { continue }
            for (index, slot) in actor.inventory.slots.enumerated() {
                guard slot?.type.perk == perk,
                      ConsumableSystem.canUse(slot: index, actor: actor) else { continue }
                return index
            }
        }
        return nil
    }
}
