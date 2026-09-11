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
    /// crossing one of its fifths-of-a-second boundaries is one puff of colour.
    /// Sixty a second would be a solid smear with a person somewhere inside.
    ///
    /// The beat now doubles as the position on the colour ring, so the same
    /// countdown that decides WHEN a mote is thrown decides which hue it is.
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
            if let perk = actor.perk {
                let previous = lastPerk[id] ?? (actor.perkRemaining + EffectsRenderer.auraInterval)
                let beat = Int(actor.perkRemaining / EffectsRenderer.auraInterval)
                if Int(previous / EffectsRenderer.auraInterval) != beat {
                    // The beat number IS the hue. Counting down rather than up, so
                    // the rainbow runs one way for everybody on the map regardless
                    // of when they drank it, and two people running a perk side by
                    // side are never mirror images of each other.
                    aura(at: actor.position, step: -beat, perk: perk)
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
    /// that reads as lying on the grass. Rings closing inward say the power is
    /// gathering rather than exploding, which is the opposite of every other ring
    /// here and the whole difference between being buffed and being blown up. A
    /// column of light going up says it is going INTO somebody. And a burst of
    /// motes hands over to the steady aura, so the effect does not stop and start
    /// again a fifth of a second later.
    ///
    /// Every one of them in a different hue, which is the only reason this reads as
    /// bigger than it used to while lasting exactly as long. The old version said
    /// one thing loudly in violet; this says the same thing in four colours, and
    /// four colours is the whole claim the item is making.
    ///
    /// Grand on purpose. This is a thing you find perhaps twice in a match and
    /// choose the moment for, and the first version - one thin ring - spent that
    /// moment as quietly as a bandage.
    func charge(at position: Vec2, perk: Perk) {
        let origin = GridGeometry.point(for: position)
        let tile = GridGeometry.length(ofTiles: 1)

        // On the ground, under the figure's feet, walking the ring as it spreads.
        let disc = SKShapeNode(ellipseOf: CGSize(width: tile * 1.7, height: tile * 0.8))
        disc.position = CGPoint(x: origin.x, y: origin.y - tile * 0.42)
        disc.fillColor = RenderPalette.hue(at: 0)
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

        // Closing in, one behind the other, each a different hue.
        //
        // Four rather than two, and this is where the rainbow does its work: two
        // rings of one colour said "something is happening", four rings of four
        // said "and it is all of them". They arrive close enough together to read
        // as one gesture, so the extra pair costs the moment nothing in length -
        // which matters more than it did, because a perk that runs for seven seconds
        // cannot afford a second and a half of ceremony in front of it.
        for index in 0..<4 {
            let ring = SKShapeNode(circleOfRadius: tile * (1.15 + CGFloat(index) * 0.14))

            ring.position = origin
            ring.fillColor = .clear
            ring.strokeColor = RenderPalette.hue(at: index * 2)
            ring.lineWidth = 4
            ring.alpha = 0
            ring.zPosition = 11
            node.addChild(ring)

            ring.run(.sequence([
                .wait(forDuration: Double(index) * 0.075),
                .group([
                    .sequence([.fadeAlpha(to: 0.95, duration: 0.1),
                               .fadeOut(withDuration: 0.3)]),
                    .scale(to: 0.12, duration: 0.4)
                ]),
                .removeFromParent()
            ]))
        }

        // And a column of it going up through them, changing colour on the way.
        let column = SKSpriteNode(texture: GlowArt.pool)
        column.size = CGSize(width: tile * 0.9, height: tile * 1.2)
        column.color = RenderPalette.hue(at: 0)
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
                           .fadeOut(withDuration: 0.34)]),
                .sequence((0..<5).map { index -> SKAction in
                    .colorize(with: RenderPalette.hue(at: index * 2),
                              colorBlendFactor: 1, duration: 0.1)
                })
            ]),
            .removeFromParent()
        ]))

        // Handing over to the aura, which takes it from here - already partway
        // round the ring, so the first steady motes carry on from the column
        // rather than snapping back to where it started.
        for index in 0..<6 {
            let step = Double(index) * 0.05
            node.run(.sequence([
                .wait(forDuration: step),
                .run { [weak self] in self?.aura(at: position, step: index, perk: perk) }
            ]))
        }
    }

    /// Sparkles coming off somebody who has a perk running.
    ///
    /// The same four-pointed spark an enchanted ITEM wears - EnchantArt.spark, the
    /// one texture - and that is the change. This used to be soft round motes, on
    /// the argument that the sparkles said "this object is enchanted" while a haze
    /// said "this person is powered up", and that the two should not be confused.
    /// It was a tidy distinction and it cost more than it bought: a player who has
    /// learned that sparkles mean a power-up has learned the one thing this effect
    /// needs to say, and teaching them a second vocabulary for the same fact only
    /// gave them something else to learn. The bottle sparkles, and so does the
    /// person who drank it.
    ///
    /// White in front, colour behind. The spark itself is always the same near-white
    /// - it is a glint, and a glint is light rather than a hue - and the rainbow
    /// lives entirely in the soft glow underneath it, which is what lets the ring
    /// be as saturated as it now is without any single particle stopping reading as
    /// a sparkle. The glow is drawn as pigment rather than added: this map is pale
    /// green, and adding violet light to pale green gives white, which would take
    /// the colour out of the very thing carrying it.
    ///
    /// Drawn on the map rather than parented to the figure, which is what makes a
    /// moving player leave a trail and a standing one wear a cloud - one behaviour
    /// out of one emitter, and the reason this is not an SKEmitterNode bolted to
    /// the sprite.
    private func aura(at position: Vec2, step: Int, perk: Perk) {
        let origin = GridGeometry.point(for: position)

        // One step round the ring per puff, so the trail somebody leaves behind
        // them is itself a rainbow laid out in the order they ran it.
        //
        // The step comes from the perk's own countdown rather than from a counter
        // in here, which is what keeps the colour on the ground true when frames
        // are dropped: a stutter loses a puff, it does not shift the whole trail
        // out of phase with everybody else's.
        // The disco ball walks the ring; a single holds its own colour. One call,
        // so the trail says which power-up somebody is running from across the map
        // - see RenderPalette.colours(for:at:).
        let colours = RenderPalette.colours(for: perk, at: step)

        // Two at a time, on opposite sides of the figure more often than not. One
        // per beat came off the middle in a single file, which read as steam from a
        // kettle rather than as somebody surrounded by it.
        for index in 0..<2 {
            let sparkle = SKNode()
            let size = CGFloat.random(in: 10...16)
            let side: CGFloat = index == 0 ? 1 : -1

            // The colour, and only the colour. Wider than the spark and softer, so
            // what reads at a distance is a coloured light with something bright in
            // the middle of it.
            let glow = SKSpriteNode(texture: GlowArt.pool)
            glow.size = CGSize(width: size * 2.1, height: size * 2.1)
            glow.color = index == 0 ? colours.bright : colours.deep
            glow.colorBlendFactor = 1
            glow.alpha = 0.9

            // And the glint, which never takes a colour from anybody.
            let spark = SKSpriteNode(texture: EnchantArt.spark)
            spark.size = CGSize(width: size, height: size)
            spark.color = RenderPalette.perkSpark
            spark.colorBlendFactor = 1
            spark.zPosition = 1

            // Started at its own angle, so a trail is not a row of identical
            // crosses - the eye finds a repeat like that immediately.
            spark.zRotation = CGFloat.random(in: 0..<(.pi / 2))
            spark.run(.rotate(byAngle: side * 1.1, duration: 0.75))

            sparkle.addChild(glow)
            sparkle.addChild(spark)

            sparkle.zPosition = 11
            sparkle.position = CGPoint(
                x: origin.x + side * CGFloat.random(in: 2...14),
                y: origin.y + CGFloat.random(in: -18...4)
            )
            sparkle.setScale(0.35)

            node.addChild(sparkle)

            // Up and slightly inward, which gathers them over the figure's head
            // instead of letting them drift apart into a fog. It twinkles ON the
            // way - snapping to full size and easing down - so each one has the
            // beat an item's sparkle has rather than simply appearing.
            sparkle.run(.sequence([
                .group([
                    .moveBy(x: -side * CGFloat.random(in: 1...7),
                            y: CGFloat.random(in: 22...38), duration: 0.75),
                    .sequence([.scale(to: 1.25, duration: 0.16),
                               .scale(to: 0.4, duration: 0.59)]),
                    .sequence([.wait(forDuration: 0.28),
                               .fadeOut(withDuration: 0.47)])
                ]),
                .removeFromParent()
            ]))
        }
    }

    /// A bullet off the casing of a machine.
    ///
    /// Deliberately not the knock a PERSON gets, and deliberately not the bomb's
    /// flash it used to borrow. The flash was a blast: it said the cabinet had just
    /// been destroyed, every single time, and then the cabinet was still standing
    /// there. The knock is the other mistake in the other direction - a shower of
    /// yellow stars off a machine reads as somebody inside it taking a hit.
    ///
    /// So: fewer, smaller, whiter, and thrown back the way the shot came rather
    /// than fanned round the whole circle. Sparks off metal, which is a thing
    /// everybody has seen and nobody has to be taught.
    func machineStruck(at position: Vec2) {
        let origin = GridGeometry.point(for: position)

        for _ in 0..<3 {
            let spark = SKSpriteNode(texture: ImpactArt.star)
            let side = GridGeometry.length(ofTiles: Double.random(in: 0.16...0.24))

            spark.size = CGSize(width: side, height: side)
            spark.color = .white
            spark.colorBlendFactor = 0.75
            spark.zPosition = 12
            spark.position = CGPoint(x: origin.x + CGFloat.random(in: -6...6),
                                     y: origin.y + CGFloat.random(in: -4...8))
            spark.zRotation = CGFloat.random(in: 0...(.pi / 2))
            spark.setScale(0.5)

            node.addChild(spark)

            // Up and out, and dropping - a spark has weight, unlike the stars a
            // person throws off, which is most of what makes this read as metal.
            let angle = Double.random(in: 0.5...2.6)
            let reach = CGFloat.random(in: 9...18)

            spark.run(.sequence([
                .group([
                    .sequence([
                        .moveBy(x: cos(angle) * Double(reach),
                                y: sin(angle) * Double(reach), duration: 0.12),
                        .moveBy(x: cos(angle) * Double(reach) * 0.4,
                                y: -6, duration: 0.14)
                    ]),
                    .rotate(byAngle: CGFloat.random(in: -1.6...1.6), duration: 0.26),
                    .sequence([.scale(to: 1, duration: 0.07),
                               .scale(to: 0.3, duration: 0.19)]),
                    .sequence([.wait(forDuration: 0.1),
                               .fadeOut(withDuration: 0.16)])
                ]),
                .removeFromParent()
            ]))
        }
    }

    // MARK: - A base closing

    /// The moment a wall goes all the way round, run once round the wall.
    ///
    /// Building is the slowest, least dramatic thing this game asks of anybody:
    /// twenty-odd taps spread over minutes, each one indistinguishable from the
    /// last, and at the end of it the only thing that happened was that a gap
    /// stopped being there. Somebody who has just finished should be in no doubt
    /// that they finished.
    ///
    /// So the light travels the plan IN BUILD ORDER, which is the order the tiles
    /// were laid, so the flourish traces the same path round the base the player
    /// walked to make it - and it arrives back where it started, which is the one
    /// thing a wall does that a row of bricks does not.
    ///
    /// Then a chest lands, and this fires just before the chests appear, so the
    /// sweep is what hands over to them: the wall closes, the light goes round, the
    /// loot is there. That is the payoff for the whole errand, and until now the
    /// payoff was a number changing in the corner of the screen.
    func seal(_ tiles: [GridPoint], chests: Int) {
        guard !tiles.isEmpty else { return }

        // A fixed budget rather than a fixed delay per tile: the plan is between
        // 24 and 32 tiles depending on the size of the base, and a per-tile stagger
        // would make the big base's celebration a third longer than the small one's
        // for no reason anybody would enjoy.
        let lap = 0.85
        let step = lap / Double(tiles.count)
        let side = GridGeometry.tileSize

        for (index, tile) in tiles.enumerated() {
            let spark = SKSpriteNode(texture: GlowArt.pool)
            spark.size = CGSize(width: side * 1.7, height: side * 1.7)
            spark.color = RenderPalette.sealLight
            spark.colorBlendFactor = 1
            spark.position = GridGeometry.pointAtCentre(of: tile)
            spark.alpha = 0
            spark.zPosition = 9
            node.addChild(spark)

            spark.run(.sequence([
                .wait(forDuration: Double(index) * step),
                .group([
                    .sequence([.fadeAlpha(to: 0.9, duration: 0.09),
                               .fadeOut(withDuration: 0.42)]),
                    .sequence([.scale(to: 1.25, duration: 0.12),
                               .scale(to: 0.7, duration: 0.39)])
                ]),
                .removeFromParent()
            ]))
        }

        // And a ring off the middle once the lap is done, sized to the haul. One
        // chest gets a ring, three get a ring you cannot miss - so the reward for
        // having walled in a big awkward yard is legible in the moment it pays out
        // rather than only when you next open the thing.
        let centre = tiles.reduce(CGPoint.zero) { running, tile in
            let point = GridGeometry.pointAtCentre(of: tile)
            return CGPoint(x: running.x + point.x / CGFloat(tiles.count),
                           y: running.y + point.y / CGFloat(tiles.count))
        }

        for index in 0..<max(1, chests) {
            let ring = SKShapeNode(circleOfRadius: side * 0.9)
            ring.position = centre
            ring.fillColor = .clear
            ring.strokeColor = RenderPalette.sealLight
            ring.lineWidth = 3
            ring.alpha = 0
            ring.zPosition = 9
            node.addChild(ring)

            ring.run(.sequence([
                .wait(forDuration: lap + Double(index) * 0.11),
                .group([
                    .sequence([.fadeAlpha(to: 0.85, duration: 0.1),
                               .fadeOut(withDuration: 0.44)]),
                    .scale(to: 3.4, duration: 0.54)
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

    /// A quiet number rising off your own base, for points that arrived on a clock.
    ///
    /// Deliberately NOT the kill mark. That draws a ring, and a ring means somebody
    /// died on that spot - borrowing it for a wall that is simply still standing
    /// would be the screen telling a small lie every twelve seconds. What is left
    /// when the ring comes off is the part that was always doing the work: the
    /// number, floating up and away.
    ///
    /// Smaller and slower than a kill's, too. This one arrives twenty times a match
    /// whether or not you are looking at it, so it has to be readable when you are
    /// standing at home and ignorable when you are not.
    func earned(at position: Vec2, points: Int) {
        guard points > 0 else { return }

        let origin = GridGeometry.point(for: position)

        let label = SKLabelNode(fontNamed: "AvenirNext-Bold")
        label.text = "+\(points)"
        label.fontSize = 15
        label.fontColor = RenderPalette.countBadge
        label.verticalAlignmentMode = .center
        label.position = CGPoint(x: origin.x, y: origin.y)
        label.zPosition = 14
        label.alpha = 0
        node.addChild(label)

        label.setScale(0.7)
        label.run(.sequence([
            .group([.fadeAlpha(to: 0.95, duration: 0.18),
                    .scale(to: 1.0, duration: 0.18)]),
            .group([.moveBy(x: 0, y: 26, duration: 0.9),
                    .sequence([.wait(forDuration: 0.35),
                               .fadeOut(withDuration: 0.55)])]),
            .removeFromParent()
        ]))
    }

}
