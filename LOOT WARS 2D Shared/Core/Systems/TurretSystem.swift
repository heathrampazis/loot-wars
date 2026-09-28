//
//  TurretSystem.swift
//  Loot Wars
//
//  Guns in bases: standing them up, pointing them, firing them, and breaking them.
//
//  A turret is not an actor and does not think. It has one rule - shoot the
//  nearest enemy it can see - and everything that makes it feel like more than
//  that comes from two constraints on the rule rather than from cleverness:
//
//  It has to SEE. Walls stop bullets, its own included, so a turret inside a sealed
//  base cannot touch anybody outside it. It guards the room, not the approach -
//  see Turret for why that is the right shape for a defence in this game.
//
//  It has to TURN. The barrel swings at a fixed rate and only fires once it is
//  close to on target, so somebody running across its front mostly gets past,
//  while somebody standing still at a chest is under fire within half a second.
//  The raid step that takes time is the step it punishes.
//

// For cos and sin. Vec2 already imports it for atan2, and Core is allowed Foundation
// - it is SpriteKit and UIKit that Core must never see.
import Foundation

enum TurretSystem {

    static func update(_ world: World, commands: [ActorID: [Command]], dt: Double) {
        place(world, commands: commands)
        mend(world, dt: dt)
        aimAndFire(world, dt: dt)
    }

    // MARK: - Standing one up

    /// Whether a carried turret would go down with its footprint here.
    ///
    /// The machine's rules, point for point - see ArcadeSystem.canPlace, which
    /// carries the reasoning for each of them. The one that bears repeating is the
    /// ground: it is the room you actually walled in, not the rectangle the plan
    /// drew, so a spot the preview offers inside your own base is one you can use.
    static func canPlace(at origin: GridPoint, by actor: Actor, in world: World) -> Bool {
        guard actor.inventory.firstSlot(holding: .turret) != nil else { return false }

        guard let claim = world.claim(for: actor.team),
              claim.contains(GridPoint(containing: actor.feet)) else { return false }

        let ground = world.baseGround(of: actor.team)
        let turret = Turret(id: TurretID(-1), origin: origin, owner: actor.team)

        for tile in turret.tiles {
            guard ground.contains(tile),
                  tile != claim.centreTile,
                  world.map[tile] == .floor,
                  !world.structureOccupies(tile),
                  !world.treeTiles.contains(tile) else { return false }
        }

        // Solid, and four tiles of it: not on top of anybody, the placer included.
        return !world.actors.values.contains {
            $0.isAlive && $0.hitbox.intersects(turret.hitbox)
        }
    }

    @discardableResult
    static func place(at origin: GridPoint, by actor: Actor, in world: World) -> Bool {
        guard canPlace(at: origin, by: actor, in: world) else { return false }

        var owner = actor
        guard let slot = owner.inventory.firstSlot(holding: .turret),
              owner.inventory.consume(at: slot) != nil else { return false }

        world.actors[actor.id] = owner
        world.spawnTurret(at: origin, owner: actor.team)
        return true
    }

    private static func place(_ world: World, commands: [ActorID: [Command]]) {
        for id in commands.keys.sorted(by: { $0.raw < $1.raw }) {
            for command in commands[id] ?? [] {
                guard case .placeTurret(let origin) = command else { continue }
                guard let actor = world.actors[id], actor.isAlive else { break }
                place(at: origin, by: actor, in: world)
            }
        }
    }

    // MARK: - Shooting

    /// Every turret, one tick: pick a target, swing towards it, fire if lined up.
    ///
    /// Sorted, because this hands out damage and damage decides who dies.
    private static func aimAndFire(_ world: World, dt: Double) {
        for id in world.turrets.keys.sorted(by: { $0.raw < $1.raw }) {
            guard var turret = world.turrets[id] else { continue }

            turret.cooldown = max(0, turret.cooldown - dt)

            // Keep the one it has if it can still have it. Re-picking the nearest
            // every tick would flick the barrel between two raiders at similar
            // distances and it would never finish turning towards either.
            if let current = turret.target,
               !canEngage(current, from: turret, in: world) {
                turret.target = nil
            }
            if turret.target == nil {
                turret.target = nearestTarget(for: turret, in: world)
            }

            guard let targetID = turret.target,
                  let target = world.actors[targetID] else {
                // Nothing to shoot: a slow sweep. It is the difference between a
                // gun that looks switched off and one that looks like it is
                // watching, and it costs one line.
                turret.heading = wrapped(turret.heading + GameConfig.Turret.idleSweep * dt)
                world.turrets[id] = turret
                continue
            }

            let wanted = (aimPoint(at: target, from: turret) - turret.centre).angle
            let error = shortestAngle(from: turret.heading, to: wanted)
            let step = GameConfig.Turret.turnRate * dt

            turret.heading = abs(error) <= step
                ? wanted
                : wrapped(turret.heading + (error > 0 ? step : -step))

            // Fired along the BARREL, not straight at the target. That is what
            // makes the turn rate a real mechanic rather than a look: a shot goes
            // where the gun is pointing, so a barrel still coming round misses
            // somebody who has kept moving.
            let remaining = abs(shortestAngle(from: turret.heading, to: wanted))

            if turret.cooldown <= 0,
               remaining <= GameConfig.Turret.fireTolerance,
               let shooter = world.actorID(of: turret.owner) {
                let direction = Vec2(x: cos(turret.heading), y: sin(turret.heading))

                world.spawnProjectile(owner: shooter,
                                      team: turret.owner,
                                      position: turret.muzzle(pointing: direction),
                                      velocity: direction * GameConfig.Blaster.projectileSpeed,
                                      damage: GameConfig.Turret.damage)

                turret.cooldown = 1.0 / GameConfig.Turret.fireRate
            }

            world.turrets[id] = turret
        }
    }

    /// The nearest enemy this turret could shoot right now, or nil.
    ///
    /// Sorted by id before distance, so two intruders at exactly the same range are
    /// broken by a fact about them rather than by dictionary order.
    private static func nearestTarget(for turret: Turret, in world: World) -> ActorID? {
        var best: ActorID?
        var shortest = Double.greatestFiniteMagnitude

        for id in world.actors.keys.sorted(by: { $0.raw < $1.raw }) {
            guard canEngage(id, from: turret, in: world),
                  let actor = world.actors[id] else { continue }

            let distance = (actor.position - turret.centre).length
            guard distance < shortest else { continue }
            shortest = distance
            best = id
        }

        return best
    }

    /// Whether this turret may shoot at this actor at all.
    ///
    /// Not its own side, not the dead, not somebody still spawn-protected, not out
    /// of range, and not behind anything. The last is the one that shapes the whole
    /// defence - see the note at the top of this file.
    /// Where to point to hit somebody who is moving: where they will be when the
    /// shot arrives, near enough.
    ///
    /// The same sum the bots aim with - see AIBrain.shotToTake - with the lead cut
    /// to GameConfig.Turret.leadShare, so walking in a straight line gets you shot
    /// and changing direction does not.
    private static func aimPoint(at target: Actor, from turret: Turret) -> Vec2 {
        let away = (target.position - turret.centre).length
        let flight = max(0, away - GameConfig.Turret.muzzleReach)
            / GameConfig.Blaster.projectileSpeed
        let speed = GameConfig.Player.moveSpeed * target.speedMultiplier
        let drift = target.moveInput.clampedToUnit()
            * (speed * flight * GameConfig.Turret.leadShare)
        return target.position + drift
    }

    private static func canEngage(_ id: ActorID, from turret: Turret, in world: World) -> Bool {
        guard let actor = world.actors[id],
              actor.isAlive,
              actor.team != turret.owner,
              actor.invulnerability <= 0 else { return false }

        let towards = actor.position - turret.centre
        let distance = towards.length
        guard distance > 0.01, distance <= GameConfig.Turret.range else { return false }

        // Not from off the edge of the player's screen. Its reach is a blaster's
        // now, and a landscape phone shows far less than that above and below you,
        // so without this a turret you have never seen could open up on you. The
        // same rule the bots fire under - see AIBrain.canOpenFire.
        if id == world.localPlayerID {
            let half = world.visibleHalfExtent
            guard abs(towards.x) <= half.x * GameConfig.AI.visibleMargin,
                  abs(towards.y) <= half.y * GameConfig.AI.visibleMargin else { return false }
        }

        return clearShot(from: turret, along: towards * (1 / distance),
                         for: distance, in: world)
    }

    /// Whether a bullet would get from this barrel to that far along this line.
    ///
    /// Asks the same things a bullet in flight asks - walls, trees, anything
    /// standing - and in the same order, so a turret never holds its fire at a shot
    /// that would have landed or wastes one on a shot that would not. Walked from
    /// the MUZZLE, which is outside the turret's own body; walked from the centre,
    /// the first thing every line would hit is the turret.
    private static func clearShot(from turret: Turret,
                                  along direction: Vec2,
                                  for distance: Double,
                                  in world: World) -> Bool {
        let start = GameConfig.Turret.muzzleReach
        var travelled = start

        while travelled < distance {
            let point = turret.centre + direction * travelled

            if world.map.isOccupied(GridPoint(containing: point)) { return false }
            if world.trees.contains(where: { $0.contains(point) }) { return false }
            if world.structureBlocks(point) { return false }

            travelled += GameConfig.Turret.sightStep
        }

        return true
    }

    // MARK: - Taking damage

    /// Takes a chunk out of a turret, and breaks it if that was the last of it.
    ///
    /// The one door damage comes through, bullet or blast, so there is exactly one
    /// place that knows what a broken turret does. Returns whether there was a
    /// turret there to be hit at all.
    ///
    /// Your own is not damageable - you cannot shoot your own furniture apart,
    /// which would only ever be an accident.
    ///
    /// And whoever just shot it becomes its target, if it can see them. A turret
    /// that kept shooting at the raider by the chest while somebody took it apart
    /// from the doorway would look like it had not noticed - which is the one
    /// thing a gun in somebody's base must never look like.
    @discardableResult
    static func hit(_ turretID: TurretID,
                    for amount: Int,
                    by attacker: ActorID,
                    of team: TeamID,
                    in world: World) -> Bool {
        guard var turret = world.turrets[turretID] else { return false }
        guard turret.owner != team else { return true }

        turret.health -= amount
        turret.secondsSinceHit = 0
        turret.mendTimer = GameConfig.Turret.mendTick

        guard turret.health <= 0 else {
            if canEngage(attacker, from: turret, in: world) { turret.target = attacker }
            world.turrets[turretID] = turret
            world.record(.turretHit(turretID, at: turret.centre))
            return true
        }

        world.removeTurret(turretID)
        world.award(GameConfig.Turret.destroyedScore, to: team)
        world.awardTokens(GameConfig.Turret.destroyedReward, to: attacker)
        world.record(.blast(at: turret.centre))
        return true
    }

    /// Damage coming back to turrets nobody is shooting any more.
    ///
    /// The machine's shape - a delay first, then portions on a tick - so mending
    /// never races a raider in real time. What it undoes is damage that was not
    /// followed up on.
    private static func mend(_ world: World, dt: Double) {
        for id in world.turrets.keys.sorted(by: { $0.raw < $1.raw }) {
            guard var turret = world.turrets[id] else { continue }

            turret.secondsSinceHit += dt

            guard turret.health < GameConfig.Turret.health,
                  turret.secondsSinceHit >= GameConfig.Turret.mendDelay else {
                world.turrets[id] = turret
                continue
            }

            turret.mendTimer -= dt
            guard turret.mendTimer <= 0 else {
                world.turrets[id] = turret
                continue
            }

            turret.mendTimer = GameConfig.Turret.mendTick

            let portion = Double(GameConfig.Turret.health) * GameConfig.Turret.mendPortion
            turret.health = min(GameConfig.Turret.health,
                                turret.health + max(1, Int(portion.rounded())))
            world.turrets[id] = turret
        }
    }

    // MARK: - Angles

    /// The signed turn from one heading to another, the short way round.
    private static func shortestAngle(from: Double, to: Double) -> Double {
        var delta = (to - from).truncatingRemainder(dividingBy: 2 * .pi)
        if delta > .pi { delta -= 2 * .pi }
        if delta < -.pi { delta += 2 * .pi }
        return delta
    }

    /// Kept inside one turn, so a turret that sweeps all match does not carry a
    /// heading in the thousands of radians and lose precision doing it.
    private static func wrapped(_ angle: Double) -> Double {
        var a = angle.truncatingRemainder(dividingBy: 2 * .pi)
        if a < 0 { a += 2 * .pi }
        return a
    }
}
