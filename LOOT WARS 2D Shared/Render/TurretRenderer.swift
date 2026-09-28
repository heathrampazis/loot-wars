//
//  TurretRenderer.swift
//  Loot Wars
//
//  Turrets standing in bases.
//
//  Synced against the world each frame like the machines and chests, because they
//  come and go the same way: stood up by whoever carried one home, knocked out by
//  whoever got through the wall.
//
//  Everything here is NOTICED rather than announced. Core keeps a heading, a
//  target and a cooldown on each turret for its own reasons, and between them they
//  already say everything worth drawing - which way it is pointing, whether it has
//  seen somebody, and the instant it fired (a cooldown that has gone UP). The only
//  thing state cannot say is "a bullet just hit it", and that one arrives as
//  WorldEvent.turretHit.
//

import SpriteKit

final class TurretRenderer {

    let node = SKNode()

    /// One turret's nodes. The root stands on the middle of the footprint's
    /// bottom edge, so squashing it grows the turret up out of the ground; the
    /// mount sits on the pivot and is the only thing that turns.
    private struct Parts {
        let root: SKNode
        let body: SKSpriteNode
        let mount: SKNode
        let barrel: SKSpriteNode
        let cap: SKSpriteNode?
    }

    private var parts: [TurretID: Parts] = [:]
    private var lastCooldowns: [TurretID: Double] = [:]

    private var bars: [TurretID: SKShapeNode] = [:]
    private var drawnHealth: [TurretID: Int] = [:]

    private var mapHeight = 0

    /// See ArcadeRenderer.hasSynced - a turret that was already standing when this
    /// renderer first looked is drawn, not stood up.
    private var hasSynced = false

    /// The bar is a shade narrower than the two-tile footprint, like the machine's.
    private static let barWidthInTiles: Double = 1.6

    /// Where the bar goes when the tile overhead is taken.
    private static let barFootingDrop: Double = 0.45

    func build(mapHeight: Int) {
        self.mapHeight = mapHeight
    }

    func sync(with world: World) {
        // Sorted so two turrets appearing on the same frame are built in the same
        // order every run - it decides nothing, but it costs nothing either.
        for id in world.turrets.keys.sorted(by: { $0.raw < $1.raw }) where parts[id] == nil {
            guard let turret = world.turrets[id] else { continue }
            make(turret)
            if hasSynced { standUp(id) }
        }

        hasSynced = true

        for (id, turret) in world.turrets {
            guard let turretParts = parts[id] else { continue }

            // Straight off the simulation, every frame. The barrel already turns
            // at a limited rate in Core, so there is nothing to smooth here - and
            // smoothing it would put the drawn barrel somewhere the real one is
            // not, which on the one object whose aim you are trying to read is
            // the worst place to be approximate.
            turretParts.mount.zRotation = CGFloat(turret.heading)

            // The cooldown only ever goes up at the moment of a shot.
            if let previous = lastCooldowns[id], turret.cooldown > previous + 0.0001 {
                fire(turretParts)
            }
            lastCooldowns[id] = turret.cooldown

            setHealth(of: turret, in: world)
        }

        for (id, gone) in Array(parts) where world.turrets[id] == nil {
            parts[id] = nil
            lastCooldowns[id] = nil
            drawnHealth[id] = nil

            // The bar goes with it - see ArcadeRenderer for the bug that forgetting
            // this was.
            if let bar = bars[id]?.parent {
                bar.run(.sequence([.fadeOut(withDuration: 0.14), .removeFromParent()]))
            }
            bars[id] = nil

            knockOut(gone)
        }
    }

    // MARK: - Moments

    /// Shot, rather than blown up: the same flinch a machine gives, so furniture
    /// taking a bullet has one look across the whole game.
    func hit(_ id: TurretID) {
        guard let turretParts = parts[id] else { return }

        turretParts.root.removeAction(forKey: "hit")
        turretParts.root.run(.sequence([
            .scaleX(to: 1.07, y: 0.93, duration: 0.04),
            .scaleX(to: 0.98, y: 1.02, duration: 0.06),
            .scaleX(to: 1, y: 1, duration: 0.16)
        ]), withKey: "hit")

        for sprite in sprites(of: turretParts) {
            sprite.removeAction(forKey: "hit")
            sprite.color = .white
            sprite.run(.sequence([
                .colorize(withColorBlendFactor: 0.85, duration: 0.04),
                .wait(forDuration: 0.06),
                .colorize(withColorBlendFactor: 0, duration: 0.16)
            ]), withKey: "hit")
        }
    }

    /// A kick and a flash at the muzzle.
    ///
    /// The barrel slides back down its own length and springs forward, and the
    /// whole head gives a little bounce - which is what turns a sprite that emits
    /// bullets into a gun that is FIRING them. The flash is the blast colour at a
    /// fraction of the size, so it reads as the same family as a bomb going off
    /// without ever being mistaken for one.
    private func fire(_ turretParts: Parts) {
        let barrel = turretParts.barrel
        let kick = GridGeometry.length(ofTiles: TurretArt.recoil)

        barrel.removeAction(forKey: "recoil")
        barrel.position.x = 0
        barrel.run(.sequence([
            .moveTo(x: -kick, duration: 0.035),
            .moveTo(x: 0, duration: 0.16)
        ]), withKey: "recoil")

        if let cap = turretParts.cap {
            cap.removeAction(forKey: "recoil")
            cap.run(.sequence([
                .scale(to: 1.14, duration: 0.04),
                .scale(to: 1, duration: 0.14)
            ]), withKey: "recoil")
        }

        let flash = SKSpriteNode(texture: GlowArt.pool)
        let side = GridGeometry.length(ofTiles: 0.9)
        flash.size = CGSize(width: side, height: side)
        flash.position = CGPoint(x: GridGeometry.length(ofTiles: TurretArt.barrelLength), y: 0)
        flash.color = RenderPalette.blast
        flash.colorBlendFactor = 1
        flash.blendMode = .add
        flash.zPosition = 0.0003
        flash.setScale(0.4)
        turretParts.mount.addChild(flash)

        flash.run(.sequence([
            .group([.scale(to: 1.1, duration: 0.09), .fadeOut(withDuration: 0.12)]),
            .removeFromParent()
        ]))
    }

    /// Set down, the way a machine is - flat and wide, snapping up past full
    /// height, settling - with a quick spin of the barrel on top, so it looks like
    /// it is switching on and having a look round.
    private func standUp(_ id: TurretID) {
        guard let turretParts = parts[id] else { return }
        let root = turretParts.root

        root.xScale = 1.3
        root.yScale = 0.06
        root.alpha = 0.55

        root.removeAction(forKey: "placed")
        root.run(.sequence([
            .group([.scaleX(to: 0.92, y: 1.12, duration: 0.13),
                    .fadeIn(withDuration: 0.1)]),
            .scaleX(to: 1.06, y: 0.94, duration: 0.07),
            .scaleX(to: 1, y: 1, duration: 0.13)
        ]), withKey: "placed")

        for sprite in sprites(of: turretParts) {
            sprite.color = .white
            sprite.colorBlendFactor = 0.6
            sprite.run(.colorize(withColorBlendFactor: 0, duration: 0.3))
        }

        // The barrel's own flourish is on its SPRITE rather than the mount, which
        // Core points every frame and would simply overwrite.
        turretParts.barrel.zRotation = -.pi * 2
        turretParts.barrel.run(.sequence([
            .wait(forDuration: 0.12),
            .rotate(toAngle: 0, duration: 0.4, shortestUnitArc: false)
        ]))
    }

    /// Knocked out: the head flies off spinning and the box comes apart the way a
    /// machine does. The bomb flash and the payout are the world's; this is just
    /// the turret making it look like it lost.
    private func knockOut(_ turretParts: Parts) {
        let lift = GridGeometry.length(ofTiles: 0.9)

        turretParts.mount.run(.group([
            .moveBy(x: 0, y: lift, duration: 0.24),
            .rotate(byAngle: .pi * 3, duration: 0.24),
            .fadeOut(withDuration: 0.24)
        ]))
        turretParts.cap?.run(.fadeOut(withDuration: 0.18))

        turretParts.root.run(.sequence([
            .group([.scale(to: 1.2, duration: 0.08), .fadeAlpha(to: 0.9, duration: 0.08)]),
            .group([.scale(to: 0.2, duration: 0.2), .fadeOut(withDuration: 0.2)]),
            .removeFromParent()
        ]))
    }

    // MARK: - Damage bar

    /// Exactly the machine's bar: only once it has been hit, in the owner's colour,
    /// over the top unless something is standing there.
    private func setHealth(of turret: Turret, in world: World) {
        guard drawnHealth[turret.id] != turret.health else { return }
        drawnHealth[turret.id] = turret.health

        let share = min(1, max(0, Double(turret.health) / Double(turret.maxHealth)))
        let full = GridGeometry.length(ofTiles: TurretRenderer.barWidthInTiles)

        guard share < 1 else {
            bars[turret.id]?.parent?.isHidden = true
            return
        }

        let fill = bars[turret.id] ?? makeBar(for: turret, full: full)
        fill.parent?.isHidden = false
        if let bar = fill.parent { place(bar, for: turret, in: world) }

        fill.path = BarArt.path(full: full,
                                filled: max(BarArt.height, full * CGFloat(share)))
    }

    private func makeBar(for turret: Turret, full: CGFloat) -> SKShapeNode {
        let (bar, fill) = BarArt.make(full: full,
                                      colour: RenderPalette.colour(for: turret.owner))
        bar.zPosition = (parts[turret.id]?.root.zPosition ?? 10) + 0.5
        node.addChild(bar)
        bars[turret.id] = fill
        return fill
    }

    private func place(_ bar: SKNode, for turret: Turret, in world: World) {
        let footing = GridGeometry.point(
            for: Vec2(x: turret.centre.x, y: Double(turret.origin.row)))

        let above = Double(Turret.height) + 0.55
        let overhead = GridPoint(containing: Vec2(x: turret.centre.x,
                                                  y: Double(turret.origin.row) + above))

        let offset = world.structureOccupies(overhead)
            ? -TurretRenderer.barFootingDrop
            : above

        bar.position = CGPoint(x: footing.x,
                               y: footing.y + GridGeometry.length(ofTiles: offset))
    }

    // MARK: - Building

    private func make(_ turret: Turret) {
        let root = SKNode()
        root.position = GridGeometry.point(
            for: Vec2(x: turret.centre.x, y: Double(turret.origin.row)))

        // Into the actors' band by its base line, the way a machine is - so you
        // walk in front of a turret below you and behind one above you.
        let baseLine = Double(turret.origin.row) + GameConfig.Player.halfDepth
        root.zPosition = 10 + (Double(mapHeight) - baseLine) * 0.001

        let side = GridGeometry.length(ofTiles: Double(Turret.width))
        let body = SKSpriteNode(texture: TurretArt.body(for: turret.owner),
                                size: CGSize(width: side, height: side))
        body.anchorPoint = CGPoint(x: 0.5, y: 0)
        root.addChild(body)

        let mount = SKNode()
        mount.position = GridGeometry.point(for: TurretArt.pivot)
        mount.zPosition = 0.0001
        mount.zRotation = CGFloat(turret.heading)
        root.addChild(mount)

        // Sized by LENGTH, with the height following the texture's own shape, so a
        // drawn barrel from the catalogue keeps its proportions.
        let barrelTexture = TurretArt.barrel(for: turret.owner)
        let art = barrelTexture.size()
        let length = GridGeometry.length(ofTiles: TurretArt.barrelLength + 0.08)
        let barrel = SKSpriteNode(
            texture: barrelTexture,
            size: CGSize(width: length,
                         height: art.width > 0 ? length * art.height / art.width : length * 0.37))
        barrel.anchorPoint = CGPoint(x: 0, y: 0.5)
        mount.addChild(barrel)

        var cap: SKSpriteNode?
        if let capTexture = TurretArt.cap(for: turret.owner) {
            let capSide = GridGeometry.length(ofTiles: 0.8)
            let made = SKSpriteNode(texture: capTexture,
                                    size: CGSize(width: capSide, height: capSide))
            made.position = mount.position
            made.zPosition = 0.0002
            root.addChild(made)
            cap = made
        }

        node.addChild(root)
        parts[turret.id] = Parts(root: root, body: body, mount: mount,
                                 barrel: barrel, cap: cap)
    }

    private func sprites(of turretParts: Parts) -> [SKSpriteNode] {
        [turretParts.body, turretParts.barrel] + (turretParts.cap.map { [$0] } ?? [])
    }
}
