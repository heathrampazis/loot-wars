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

    /// How much was left of somebody's power-up last frame.
    ///
    /// Kept so the aura can be emitted on a BEAT rather than every frame, without
    /// this renderer being handed a clock: the perk's own countdown is a clock, and
    /// crossing one of its fifths-of-a-second boundaries is one puff of violet.
    /// Sixty a second would be a solid purple blob with a person somewhere inside.
    private var lastPerk: [ActorID: Double] = [:]

    /// Seconds between motes coming off somebody running a perk.
    private static let auraInterval: Double = 0.17

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

            // Running a power-up, which the world states plainly - so nothing has
            // to be announced. It also means a bot picking one up gets the same
            // violet trail the player does, without a line of code saying so.
            if actor.perk != nil {
                let previous = lastPerk[id] ?? (actor.perkRemaining + EffectsRenderer.auraInterval)
                if Int(previous / EffectsRenderer.auraInterval)
                    != Int(actor.perkRemaining / EffectsRenderer.auraInterval),
                   let perk = actor.perk {
                    aura(at: actor.position, perk: perk)
                }
                lastPerk[id] = actor.perkRemaining
            } else {
                lastPerk[id] = nil
            }

            if let previous = lastHealth[id], previous != Int.max {
                if actor.health > previous {
                    lift(at: actor.position,
                         share: Double(actor.health - previous)
                              / Double(max(1, actor.maxHealth)))
                }
                if actor.health < previous {
                    knock(at: actor.position, hurt: previous - actor.health)
                }
            }
        }

        // An actor that has stopped existing takes its bookkeeping with it.
        for id in Array(lastFeet.keys) where world.actors[id] == nil {
            lastFeet[id] = nil
            sinceStep[id] = nil
            leftFoot[id] = nil
            lastHealth[id] = nil
            lastPerk[id] = nil
        }
    }

    // MARK: - Power-ups

    /// The instant a power-up is switched on, and it is meant to be a MOMENT.
    ///
    /// Four things at once, each doing a job the others cannot. A disc thrown flat
    /// across the ground says where it happened - flattened, because everything
    /// else in this game is drawn standing up and a flat ellipse is the only shape
    /// that reads as lying on the grass. Two rings closing inward say the power is
    /// gathering rather than exploding, which is the opposite of every other ring
    /// here and the whole difference between being buffed and being blown up. A
    /// column of light going up says it is going INTO somebody. And a burst of
    /// motes hands over to the steady aura, so the effect does not stop and start
    /// again a fifth of a second later.
    ///
    /// Grand on purpose. This is a thing you find perhaps twice in a match and
    /// choose the moment for, and the first version - one thin ring - spent that
    /// moment as quietly as a bandage.
    func charge(at position: Vec2, perk: Perk) {
        let origin = GridGeometry.point(for: position)
        let tile = GridGeometry.length(ofTiles: 1)
        let colours = RenderPalette.colours(of: perk)

        // On the ground, under the figure's feet.
        let disc = SKShapeNode(ellipseOf: CGSize(width: tile * 1.7, height: tile * 0.8))
        disc.position = CGPoint(x: origin.x, y: origin.y - tile * 0.42)
        disc.fillColor = colours.bright
        disc.strokeColor = RenderPalette.perkSpark
        disc.lineWidth = 2
        disc.alpha = 0.55
        disc.zPosition = 3
        disc.setScale(0.2)
        node.addChild(disc)

        disc.run(.sequence([
            .group([.scale(to: 1.5, duration: 0.45),
                    .sequence([.fadeAlpha(to: 0.55, duration: 0.1),
                               .fadeOut(withDuration: 0.35)])]),
            .removeFromParent()
        ]))

        // Closing in, one behind the other.
        for index in 0..<2 {
            let ring = SKShapeNode(circleOfRadius: tile * 1.15)

            ring.position = origin
            ring.fillColor = .clear
            ring.strokeColor = index == 0 ? colours.bright : colours.deep
            ring.lineWidth = 4
            ring.alpha = 0
            ring.zPosition = 11
            node.addChild(ring)

            ring.run(.sequence([
                .wait(forDuration: Double(index) * 0.12),
                .group([
                    .sequence([.fadeAlpha(to: 0.95, duration: 0.1),
                               .fadeOut(withDuration: 0.3)]),
                    .scale(to: 0.12, duration: 0.4)
                ]),
                .removeFromParent()
            ]))
        }

        // And a column of it going up through them.
        let column = SKSpriteNode(texture: GlowArt.pool)
        column.size = CGSize(width: tile * 0.9, height: tile * 1.2)
        column.color = colours.bright
        column.colorBlendFactor = 1
        column.anchorPoint = CGPoint(x: 0.5, y: 0.1)
        column.position = CGPoint(x: origin.x, y: origin.y - tile * 0.45)
        column.alpha = 0
        column.zPosition = 10
        node.addChild(column)

        column.run(.sequence([
            .group([
                .scaleX(to: 0.75, y: 2.4, duration: 0.4),
                .sequence([.fadeAlpha(to: 0.75, duration: 0.12),
                           .fadeOut(withDuration: 0.34)])
            ]),
            .removeFromParent()
        ]))

        // Handing over to the aura, which takes it from here.
        for index in 0..<6 {
            let step = Double(index) * 0.05
            node.run(.sequence([
                .wait(forDuration: step),
                .run { [weak self] in self?.aura(at: position, perk: perk) }
            ]))
        }
    }

    /// Violet particles coming off somebody who has a perk running.
    ///
    /// Soft round motes rather than the sparkles the ITEM wears, and the two being
    /// different is the point of the split. The sparkles say "this object is
    /// enchanted" - they belong to a thing lying on the grass or sitting in a slot,
    /// and they twinkle because a still object needs the movement to be noticed.
    /// This says "this PERSON is powered up", and a person is already moving, so
    /// what it needs instead is a haze: something the figure is inside rather than
    /// something decorating it.
    ///
    /// Drawn on the map rather than parented to the figure, which is what makes a
    /// moving player leave a trail and a standing one wear a cloud - one behaviour
    /// out of one emitter, and the reason this is not an SKEmitterNode bolted to
    /// the sprite.
    private func aura(at position: Vec2, perk: Perk) {
        let origin = GridGeometry.point(for: position)

        // Whichever perk is running paints them. Four power-ups all trailing the
        // same violet would be four different things wearing one uniform, and the
        // colour is the only thing that says across a map which of them the person
        // charging at you just drank.
        let colours = RenderPalette.colours(of: perk)

        // Two at a time, on opposite sides of the figure more often than not. One
        // per beat came off the middle in a single file, which read as steam from a
        // kettle rather than as somebody surrounded by it.
        for index in 0..<2 {
            let mote = SKSpriteNode(texture: GlowArt.pool)
            let size = CGFloat.random(in: 9...15)

            mote.size = CGSize(width: size, height: size)
            mote.color = index == 0 ? colours.bright : colours.deep
            mote.colorBlendFactor = 1
            mote.alpha = 0.95

            // Painted ON the map rather than added to it. Additive blending is what
            // fire and muzzle flashes want, because those ARE light - but this map
            // is pale green, and adding violet to pale green gives white. The whole
            // point of the effect is the colour, so it is drawn as pigment.
            mote.zPosition = 11

            let side: CGFloat = index == 0 ? 1 : -1
            mote.position = CGPoint(
                x: origin.x + side * CGFloat.random(in: 2...14),
                y: origin.y + CGFloat.random(in: -18...4)
            )

            node.addChild(mote)

            // Up and slightly inward, which gathers them over the figure's head
            // instead of letting them drift apart into a fog.
            mote.run(.sequence([
                .group([
                    .moveBy(x: -side * CGFloat.random(in: 1...7),
                            y: CGFloat.random(in: 22...38), duration: 0.75),
                    .sequence([.scale(to: 1.3, duration: 0.18),
                               .scale(to: 0.35, duration: 0.57)]),
                    .sequence([.wait(forDuration: 0.25),
                               .fadeOut(withDuration: 0.5)])
                ]),
                .removeFromParent()
            ]))
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
        let tuft = SKSpriteNode(texture: GrassArt.tuft)
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

    /// Motes rising off somebody who has just healed, as many as the heal was big.
    ///
    /// Two for a portion of health handed back for standing at home, six for a
    /// medkit. Before this the two looked identical, so a quiet minute in your own
    /// base threw up the same fountain as being pulled back from the brink - twelve
    /// times over.
    private func lift(at position: Vec2, share: Double) {
        let origin = GridGeometry.point(for: position)
        let count = max(2, min(6, Int((share * 12).rounded())))

        for index in 0..<count {
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

    // MARK: - Being hit

    /// Stars knocked off somebody who has just been shot.
    ///
    /// This is the third thing tried here and the first that is about the HIT
    /// rather than about the person. Tinting the figure white read as a highlight;
    /// tinting it red read as a claim about the character - poisoned, burning, on
    /// the other team - and a spray of red bits, while perfectly clear, is blood in
    /// a game about children raiding each other's forts. A knock throwing off
    /// sparks is the cartoon convention every player already knows, says impact
    /// without saying injury, and is bright yellow on a green map rather than
    /// competing with the health bars for the colour red.
    ///
    /// Sized by the damage - two stars up to seven, which is about the range
    /// between a spent shot at the rim of a blast and a Blaster 6 at arm's length -
    /// so a graze and a hammering do not look alike.
    private func knock(at position: Vec2, hurt: Int) {
        let origin = GridGeometry.point(for: position)
        let count = min(7, 2 + hurt / 9)

        for index in 0..<count {
            let star = SKSpriteNode(texture: ImpactArt.star)
            let side = GridGeometry.length(ofTiles: Double.random(in: 0.28...0.44))
            star.size = CGSize(width: side, height: side)
            star.zPosition = 12
            star.position = CGPoint(x: origin.x + CGFloat.random(in: -5...5),
                                    y: origin.y + CGFloat.random(in: -4...10))

            // Fanned round the whole circle rather than thrown at random, so a
            // burst reads as a single impact rather than as several small ones.
            let angle = (Double(index) / Double(count)) * 2 * .pi
                + Double.random(in: -0.4...0.4)
            let reach = CGFloat.random(in: 14...30)

            node.addChild(star)

            star.setScale(0.4)
            star.zRotation = CGFloat.random(in: 0...(.pi / 2))

            // Out fast and gone: a spark that lingers stops being a spark. The
            // stars grow as they leave and then shrink out, which is what sells
            // them as a flash rather than as objects flying away.
            star.run(.sequence([
                .group([
                    .moveBy(x: cos(angle) * Double(reach),
                            y: sin(angle) * Double(reach), duration: 0.26),
                    .rotate(byAngle: CGFloat.random(in: -1.2...1.2), duration: 0.26),
                    .sequence([.scale(to: 1.15, duration: 0.09),
                               .scale(to: 0.5, duration: 0.17)]),
                    .sequence([.wait(forDuration: 0.12),
                               .fadeOut(withDuration: 0.14)])
                ]),
                .removeFromParent()
            ]))
        }
    }

    // MARK: - Jackpots

    /// A burst of gold rising off a machine that has just started paying out.
    ///
    /// Loud on purpose, and the only thing in this game that is. Everything else
    /// that flashes is telling you about something already happening to you - a
    /// hit, a heal, a sale - where this is an INVITATION, thrown up over a machine
    /// that might be forty tiles away, and it has to survive being seen at the edge
    /// of vision by somebody busy doing something else.
    ///
    /// It rises rather than scattering. Sparks fly out and settle; a fountain goes
    /// up and keeps going, which is the shape of a thing that is still happening
    /// rather than a thing that happened.
    func jackpot(at position: Vec2) {
        let origin = GridGeometry.point(for: position)

        for index in 0..<14 {
            let star = SKSpriteNode(texture: ImpactArt.star)
            let side = GridGeometry.length(ofTiles: Double.random(in: 0.3...0.5))

            star.size = CGSize(width: side, height: side)
            star.color = RenderPalette.treasure
            star.colorBlendFactor = 0.55
            star.zPosition = 14
            star.position = CGPoint(x: origin.x + CGFloat.random(in: -26...26),
                                    y: origin.y + CGFloat.random(in: -10...10))

            node.addChild(star)

            star.setScale(0.4)
            star.run(.sequence([
                .wait(forDuration: Double(index) * 0.035),
                .group([
                    .moveBy(x: CGFloat.random(in: -18...18),
                            y: CGFloat.random(in: 60...110),
                            duration: 0.75),
                    .rotate(byAngle: CGFloat.random(in: -2...2), duration: 0.75),
                    .sequence([
                        .scale(to: 1.1, duration: 0.2),
                        .wait(forDuration: 0.2),
                        .scale(to: 0.5, duration: 0.35)
                    ]),
                    .sequence([
                        .wait(forDuration: 0.35),
                        .fadeOut(withDuration: 0.4)
                    ])
                ]),
                .removeFromParent()
            ]))
        }
    }

    // MARK: - Gas arriving

    /// The puff a stink bomb makes on landing.
    ///
    /// The cloud that follows is state and is drawn from the world; this is the
    /// instant, which state cannot show. A cloud that simply faded up would read as
    /// fog rolling in, where a burst reads as something having been thrown - and
    /// the difference matters because one of those is a thing you should be
    /// backing away from.
    func burst(at position: Vec2) {
        let origin = GridGeometry.point(for: position)

        for index in 0..<10 {
            let puff = SKSpriteNode(texture: GlowArt.pool)
            let side = GridGeometry.length(ofTiles: Double.random(in: 0.5...0.9))

            puff.size = CGSize(width: side, height: side)
            puff.color = RenderPalette.gas
            puff.colorBlendFactor = 1
            puff.alpha = 0.8
            puff.position = origin
            puff.zPosition = 11
            node.addChild(puff)

            // Thrown outwards and slowing, which is what a gas does and a spark
            // does not - so this and the impact stars cannot be confused for one
            // another even though both are a handful of things leaving a point.
            let angle = (Double(index) / 10) * 2 * .pi + Double.random(in: -0.3...0.3)
            let reach = CGFloat.random(in: 16...30)

            puff.run(.sequence([
                .group([
                    .move(by: CGVector(dx: cos(angle) * Double(reach),
                                       dy: sin(angle) * Double(reach)),
                          duration: 0.5),
                    .scale(to: 1.6, duration: 0.5),
                    .fadeOut(withDuration: 0.5)
                ]),
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

}
