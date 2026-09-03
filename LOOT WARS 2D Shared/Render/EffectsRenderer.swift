//
//  EffectsRenderer.swift
//  Loot Wars
//
//  The things that happen ON the map and then stop existing.
//
//  Grass moving under somebody's feet, a wash of green when they patch up, the
//  mark left where somebody went down. None of it is in the world and none of it
//  should be: an effect that outlived the frame it was seen in would be state, and
//  state is Core's business.
//
//  Two sources, and the split is the same one WorldEvent describes. Most of this is
//  NOTICED - a figure that has moved is walking, a health bar that went up is a
//  heal - and works from nothing but two frames of the world side by side. Kills
//  are the exception: who killed whom, and what it paid, exist for one instant
//  inside CombatSystem, so those arrive as events the scene hands over.
//
//  Everything here is drawn in tile space and lives on the world layer, so it moves
//  with the map rather than sitting on the glass.
//

import SpriteKit
import UIKit

final class EffectsRenderer {

    let node = SKNode()

    /// Where each actor's feet were last frame, and how far they have walked since
    /// the last footfall. Kept here rather than read off the actor because it is a
    /// question about the PICTURE - how often to disturb the grass - and Core has
    /// no opinion about grass.
    private var lastFeet: [ActorID: Vec2] = [:]
    private var sinceStep: [ActorID: Double] = [:]
    private var leftFoot: [ActorID: Bool] = [:]
    private var lastHealth: [ActorID: Int] = [:]

    // MARK: - Noticing

    func sync(with world: World) {
        for id in world.actors.keys.sorted(by: { $0.raw < $1.raw }) {
            guard let actor = world.actors[id] else { continue }

            defer {
                lastFeet[id] = actor.feet
                lastHealth[id] = actor.health
            }

            guard actor.isAlive else { continue }

            if let previous = lastFeet[id] {
                step(actor, travelling: actor.feet - previous)
            }

            if let previous = lastHealth[id], actor.health > previous {
                lift(at: actor.position)
            }
        }

        // An actor that has stopped existing takes its bookkeeping with it.
        for id in Array(lastFeet.keys) where world.actors[id] == nil {
            lastFeet[id] = nil
            sinceStep[id] = nil
            leftFoot[id] = nil
            lastHealth[id] = nil
        }
    }

    // MARK: - Footfalls

    /// A tuft of grass, put down on the same beat the figure lands on.
    ///
    /// The stride is ActorRenderer's, deliberately: the figure rising and the grass
    /// moving are one event drawn twice, and two constants would drift apart within
    /// a week of tuning either.
    ///
    /// Measured by DISTANCE, not by time. A figure held against a wall by a stick
    /// pushed into it is not walking, whatever its input says, and grass appearing
    /// under somebody who is not going anywhere is the exact tell this is meant to
    /// remove.
    private func step(_ actor: Actor, travelling delta: Vec2) {
        let distance = delta.length
        guard distance > 0.0005 else { return }

        // A respawn is not a walk. At full speed a frame covers about six
        // hundredths of a tile, so anything on this scale is somebody being MOVED -
        // and without this the accumulator swallows the whole trip home and then
        // pays it out one tuft per frame, laying a trail of footprints across a map
        // nobody walked over.
        guard distance < ActorRenderer.walkStride * 2 else {
            sinceStep[actor.id] = 0
            return
        }

        var walked = (sinceStep[actor.id] ?? 0) + distance
        guard walked >= ActorRenderer.walkStride else {
            sinceStep[actor.id] = walked
            return
        }

        walked -= ActorRenderer.walkStride
        sinceStep[actor.id] = walked

        let left = !(leftFoot[actor.id] ?? false)
        leftFoot[actor.id] = left

        // Beside the foot rather than under the middle of the figure, and swapping
        // sides each step - a single line of tufts down the centre reads as a
        // dragged sack rather than as somebody walking.
        // Perpendicular to where they are actually GOING, not to where the gun is
        // pointing: on a twin-stick game those are different most of the time, and
        // footprints belong to the feet.
        let heading = delta.normalized()
        let across = Vec2(x: -heading.y, y: heading.x) * (left ? 0.16 : -0.16)

        plant(at: actor.feet + across)
    }

    private func plant(at position: Vec2) {
        let tuft = SKSpriteNode(texture: EffectsRenderer.grass)
        tuft.size = CGSize(width: GridGeometry.length(ofTiles: 0.42),
                           height: GridGeometry.length(ofTiles: 0.30))
        tuft.position = GridGeometry.point(for: position)
        tuft.anchorPoint = CGPoint(x: 0.5, y: 0.35)

        // Under everything that stands on the ground, over the ground itself.
        tuft.zPosition = 2
        tuft.alpha = 0.85
        tuft.setScale(0.55)
        tuft.zRotation = CGFloat.random(in: -0.3...0.3)

        node.addChild(tuft)

        // Springs up, sways back, settles away. Quick: this is the ghost of a
        // footstep, and grass that hangs about turns a walk into a scar.
        tuft.run(.sequence([
            .group([.scale(to: 1.0, duration: 0.09),
                    .rotate(byAngle: CGFloat.random(in: -0.22...0.22), duration: 0.09)]),
            .wait(forDuration: 0.06),
            .group([.fadeOut(withDuration: 0.34),
                    .scale(to: 0.7, duration: 0.34)]),
            .removeFromParent()
        ]))
    }

    // MARK: - Patching up

    /// Motes rising off somebody who has just healed.
    private func lift(at position: Vec2) {
        let origin = GridGeometry.point(for: position)

        for index in 0..<6 {
            let mote = SKShapeNode(circleOfRadius: CGFloat.random(in: 1.6...3.2))
            mote.fillColor = RenderPalette.placementValid
            mote.strokeColor = .clear
            mote.zPosition = 12
            mote.position = CGPoint(x: origin.x + CGFloat.random(in: -12...12),
                                    y: origin.y + CGFloat.random(in: -8...8))
            node.addChild(mote)

            let rise = CGFloat.random(in: 26...44)
            mote.run(.sequence([
                .wait(forDuration: Double(index) * 0.035),
                .group([.moveBy(x: CGFloat.random(in: -6...6), y: rise, duration: 0.55),
                        .sequence([.wait(forDuration: 0.2),
                                   .fadeOut(withDuration: 0.35)])]),
                .removeFromParent()
            ]))
        }
    }

    // MARK: - Kills

    /// The mark left where somebody went down, and what it paid.
    ///
    /// Everyone gets the ring, because a kill anywhere on screen is worth knowing
    /// about. The number is only for YOURS - a floating score above every death in
    /// an eight-way match would be arithmetic nobody asked for.
    func mark(killAt position: Vec2, points: Int, mine: Bool) {
        let origin = GridGeometry.point(for: position)

        let ring = SKShapeNode(circleOfRadius: GridGeometry.length(ofTiles: 0.5))
        ring.strokeColor = mine ? RenderPalette.countBadge : SKColor(white: 1, alpha: 0.7)
        ring.lineWidth = 3
        ring.fillColor = .clear
        ring.position = origin
        ring.zPosition = 13
        node.addChild(ring)

        ring.run(.sequence([
            .group([.scale(to: 2.6, duration: 0.34), .fadeOut(withDuration: 0.34)]),
            .removeFromParent()
        ]))

        guard mine, points > 0 else { return }

        let label = SKLabelNode(fontNamed: "AvenirNext-Bold")
        label.text = "+\(points)"
        label.fontSize = 18
        label.fontColor = RenderPalette.countBadge
        label.verticalAlignmentMode = .center
        label.position = CGPoint(x: origin.x, y: origin.y + 14)
        label.zPosition = 14
        node.addChild(label)

        label.setScale(0.6)
        label.run(.sequence([
            .group([.scale(to: 1.15, duration: 0.12), .moveBy(x: 0, y: 10, duration: 0.12)]),
            .scale(to: 1.0, duration: 0.1),
            .group([.moveBy(x: 0, y: 22, duration: 0.6),
                    .sequence([.wait(forDuration: 0.25), .fadeOut(withDuration: 0.35)])]),
            .removeFromParent()
        ]))
    }

    // MARK: - The grass itself

    /// Three blades, drawn once.
    ///
    /// Drawn rather than shipped as art, and in the map's own colours: this has to
    /// read as the ground being disturbed rather than as a sprite appearing on top
    /// of it, so it is the darker of the two floor greens with the terrain colour
    /// underneath - which is what the map is already made of.
    private static let grass: SKTexture = {
        let size = CGSize(width: 48, height: 34)

        let format = UIGraphicsImageRendererFormat.default()
        format.opaque = false

        let image = UIGraphicsImageRenderer(size: size, format: format).image { context in
            let cg = context.cgContext
            cg.setLineCap(.round)

            // Splayed outwards from a common root, the way a tuft actually grows -
            // and the outer two lean further, so the shape has a middle.
            let blades: [(dx: CGFloat, lean: CGFloat, height: CGFloat, width: CGFloat)] = [
                (-11, -9, 20, 4.5),
                (0, 1, 26, 5.0),
                (11, 10, 19, 4.5)
            ]

            for blade in blades {
                let root = CGPoint(x: size.width / 2 + blade.dx, y: size.height - 3)
                let tip = CGPoint(x: root.x + blade.lean, y: root.y - blade.height)
                let control = CGPoint(x: root.x + blade.lean * 0.2, y: root.y - blade.height * 0.6)

                let path = CGMutablePath()
                path.move(to: root)
                path.addQuadCurve(to: tip, control: control)

                cg.setStrokeColor(RenderPalette.terrain.withAlphaComponent(0.75).cgColor)
                cg.setLineWidth(blade.width)
                cg.addPath(path)
                cg.strokePath()

                cg.setStrokeColor(RenderPalette.floorDark.withAlphaComponent(0.9).cgColor)
                cg.setLineWidth(blade.width * 0.45)
                cg.addPath(path)
                cg.strokePath()
            }
        }

        let texture = SKTexture(image: image)
        texture.usesMipmaps = true
        return texture
    }()
}
