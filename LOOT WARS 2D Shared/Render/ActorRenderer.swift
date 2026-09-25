//
//  ActorRenderer.swift
//  Loot Wars
//
//  Keeps one node per actor in step with the simulation.
//
//  Read the sync method carefully: it only ever READS from the world. A node is a
//  picture of an actor, never the actor itself. The moment health or ammo or a
//  timer lives on an SKNode, the simulation stops being the source of truth.
//
//  Each actor is a small tree: a root at its feet, the figure standing on it, and a
//  team-coloured bar above its head. The bar is what tells eight identical sprites
//  apart until there is per-team art, and it is already wired to health, so it will
//  start emptying the moment damage exists.
//

import SpriteKit
import UIKit

final class ActorRenderer {

    let node = SKNode()

    // Measured off the reference art: the overhead bar is exactly one tile wide.
    private static let barWidthInTiles: Double = 1.0
    private static let barHeightInTiles = BarArt.heightInTiles
    private static let barOutlineInTiles = BarArt.outlineInTiles
    private static let barGapInTiles: Double = 0.08

    /// How far you walk per step, in tiles, and how high the figure rises on one.
    ///
    /// The stride is shared with EffectsRenderer, which puts a tuft of disturbed
    /// grass down on the same beat - the foot planting and the grass moving are
    /// the same event seen twice, and two stride constants would drift apart.
    static let walkStride: Double = 1.05

    /// How wide the pool of light under a powered-up figure is, in tiles.
    ///
    /// A shade wider than the person - they are nine tenths of a tile across - so
    /// it reads as light they are standing IN rather than as a plate they are
    /// standing on.
    static let perkAuraInTiles: Double = 1.35

    /// When a running perk starts saying it is nearly over, in seconds left.
    ///
    /// Not a number the simulation knows or should: the aura hurrying up is a thing
    /// the screen does about a countdown it can read, exactly like the match clock
    /// turning red. Long enough to change what you would do with the last of it -
    /// break off, or spend it - and short enough that most of a perk is spent
    /// simply enjoying it.
    static let perkEndsWithin: Double = 1.6

    /// How fast a shot works its way out of the weapon, and how far it moves it.
    ///
    /// Six per second means the kick is over in about 160 milliseconds, which at
    /// four and a half shots a second leaves the gun visibly settling between
    /// rounds rather than sitting permanently shoved back.
    private static let recoilDecay: Double = 6
    private static let recoilKick: Double = 0.10      // tiles, back along the barrel
    private static let recoilLift: Double = 0.17      // radians, muzzle rising

    /// Both dialled back by about a third from the first version. The timing was
    /// right and the amplitude was not: at 0.16 and 17 degrees a held trigger read
    /// as the figure struggling with the weapon rather than firing it, and on a
    /// blaster drawn about a tile long, a kick you can measure is a kick that is
    /// too big. What the eye needs is that SOMETHING moved on every shot, which
    /// three and a half points of travel and ten degrees of lift deliver without
    /// the gun appearing to fight back.
    private static let walkBob: Double = 0.075      // tiles
    private static let walkLean: Double = 0.045     // radians

    /// Standing still: a breath.
    ///
    /// The walk is driven by DISTANCE, which is what makes it honest - stop and it
    /// settles exactly where the foot landed. The cost of that honesty is that a
    /// figure standing still is a figure frozen solid, and eight of them dotted
    /// round a map read as a screenshot with one player in it.
    ///
    /// So the clock takes over when the ground stops: a slow rise and fall with the
    /// chest swelling as it goes up. Three seconds a cycle, which is twenty breaths
    /// a minute - a resting human, near enough - and the two amplitudes together
    /// move the top of the head about three points. That is the size this wants: on
    /// a figure drawn thirty-odd points tall it is unmistakable while you are
    /// looking at somebody and invisible while you are looking at the fight. Bigger
    /// was tried at every stage of this project's animation work and the answer
    /// comes back the same: an idle you can measure is an idle that distracts.
    private static let breathRate: Double = 3.0     // seconds per breath
    private static let breathLift: Double = 0.035   // tiles
    private static let breathSwell: Double = 0.028  // share of height

    /// How fast a figure changes its mind about standing still, per second.
    ///
    /// Blended rather than switched, or the breath would snap on the instant a
    /// thumb left the stick and off again the instant it came back - which is a
    /// twitch, and the one thing an idle must never be. A fifth of a second either
    /// way is quick enough to feel immediate and slow enough to be a settle.
    private static let stillnessRate: Double = 5

    private final class ActorNodes {
        let root = SKNode()

        /// Carries the walk. Written every frame, which is exactly why it is its
        /// own node: the bob would otherwise have to share yScale and zRotation
        /// with the flinch and the heal, and a value rewritten sixty times a second
        /// cannot also be animated by an action - the action simply loses.
        let body = SKNode()

        /// The flinch and the heal act HERE, for the same reason: the sprite's own
        /// xScale is the mirror, rewritten every frame from which way the actor
        /// faces, so a scale action on the sprite is overwritten before it is seen.
        let figure = SKNode()

        let sprite: SKSpriteNode

        let healthFill: SKShapeNode
        let blaster: SKSpriteNode
        let goalLabel: SKLabelNode?
        var lastHealthFraction: Double = -1
        /// So the figure can be re-dressed the moment its helmet changes.
        var lastHelmet: HelmetTier?
        var lastBlaster: BlasterTier?
        /// Used to notice a change either way: down is a hit, up is a heal. The
        /// renderer works both out for itself rather than being told - see
        /// WorldEvent for where that line is drawn.
        var lastHealth: Int = Int.max

        /// Where the walk cycle has got to, advanced by DISTANCE rather than by
        /// time, so a figure that is being shoved along a wall does not moonwalk
        /// and a stationary one does not jog on the spot.
        var walkPhase: Double = 0
        var lastPosition: Vec2?

        /// Where the breathing has got to, and how much of it is showing.
        ///
        /// The phase runs on the CLOCK whether or not it is being used, so a figure
        /// that stops walking joins a breath already in progress rather than
        /// starting one from the bottom - which is the difference between somebody
        /// standing still and somebody being switched on.
        var breathPhase: Double = 0
        var stillness: Double = 0

        /// The muzzle flash, hung at the end of the barrel.
        let muzzle = SKSpriteNode(texture: GlowArt.pool)

        /// The pool of light a powered-up figure stands in, and the ring around it.
        ///
        /// PARENTED TO THE ACTOR, which is the whole reason these exist. The trail
        /// EffectsRenderer throws is drawn on the MAP and stays where it was thrown
        /// - which is exactly right for a trail and is why a moving player leaves
        /// one - but it means that standing still, or seen for the first time from
        /// across the map, a powered-up person looked like an ordinary person with
        /// some glitter near them. These travel with the figure, so being powered
        /// up is something you ARE rather than something you have been leaving
        /// behind you.
        ///
        /// Two nodes rather than one, because they say different things. The pool
        /// is under the feet and reads as standing in light; the ring is a hard
        /// edge around it and reads as a boundary switched on. A soft glow on its
        /// own dissolves into pale grass at any distance, which is the same lesson
        /// the rarity colours record - a colour that only exists as a haze is a
        /// colour this map eats.
        let perkPool = SKSpriteNode(texture: GlowArt.pool)
        let perkRing: SKShapeNode

        /// Which perk was running last frame, and whether it was in its last
        /// moments. The pair is how the aura is switched on, recoloured, hurried up
        /// and switched off without touching an action sixty times a second - see
        /// the note on breathPhase for why that distinction matters here.
        var lastPerk: Perk?
        var perkEnding = false

        /// How much of a shot is still working through the weapon, 1 down to 0.
        ///
        /// A NUMBER that decays rather than an SKAction, because the weapon's
        /// position and rotation are rewritten every frame by hold() - an action
        /// animating either would be overwritten before it drew once. This gets
        /// folded into hold's own arithmetic instead, which is the only way the two
        /// can both have an opinion about where the gun is.
        var recoil: Double = 0

        /// Used to notice a shot: the cooldown is set to its full value the moment
        /// one goes off, so a cooldown that has gone UP is a trigger that was just
        /// pulled. Nothing has to be announced.
        var lastShotCooldown: Double = 0

        init(sprite: SKSpriteNode,
             healthFill: SKShapeNode,
             blaster: SKSpriteNode,
             perkRing: SKShapeNode,
             goalLabel: SKLabelNode?) {
            self.sprite = sprite
            self.healthFill = healthFill
            self.blaster = blaster
            self.perkRing = perkRing
            self.goalLabel = goalLabel
        }
    }

    private var nodesByActor: [ActorID: ActorNodes] = [:]
    private var textureCache: [HelmetTier: SKTexture] = [:]
    private var blasterCache: [BlasterTier: SKTexture] = [:]

    func sync(with world: World, dt: TimeInterval) {
        for (id, actor) in world.actors {
            let nodes = nodesByActor[id] ?? makeNodes(for: actor)

            // The art is a standing figure, so it stands ON the hitbox rather than
            // being centred in it: the sprite's feet sit at the bottom of the box.
            nodes.root.position = GridGeometry.point(for: actor.feet)

            // Mirror rather than swap art: one image serves both directions. Applied
            // to the sprite alone so the bar above never flips with it.
            nodes.sprite.xScale = actor.facesLeft ? -1 : 1

            // Actors lower down the screen draw in front of those behind them.
            nodes.root.zPosition = 10 + (Double(world.map.height) - actor.position.y) * 0.001

            // The dead are simply not drawn. Nothing is removed, because the actor
            // itself still exists and is counting down to respawn.
            nodes.root.isHidden = !actor.isAlive

            // Spawn protection reads as a ghost, so it is obvious why shots are
            // passing straight through someone.
            nodes.root.alpha = actor.invulnerability > 0 ? 0.55 : 1.0

            // The aura, which is a STATE and so is read off the world rather than
            // announced - the same way a bot picking one up gets everything the
            // player gets without a line of code saying so.
            //
            // Diffed on two things: which perk, and whether it is nearly out. Both
            // switch a repeating action on, and a repeating action restarted every
            // frame never plays a single cycle - the lesson this file already
            // records for the walk and the breath. So it is only touched when one
            // of those two answers actually changes.
            let ending = actor.perk != nil && actor.perkRemaining <= ActorRenderer.perkEndsWithin
            if actor.perk != nodes.lastPerk || ending != nodes.perkEnding {
                setAura(actor.perk, ending: ending, on: nodes)
                nodes.lastPerk = actor.perk
                nodes.perkEnding = ending
            }

            // The walk. Distance covered since the last frame turns the cycle, so
            // the bob is tied to the ground rather than to the clock: stop and it
            // settles, get pushed and it still reads as being moved rather than as
            // walking. Only the vertical half of the cycle is used - abs of the
            // sine - so the figure rises on every step instead of every other one.
            let moved = nodes.lastPosition.map { (actor.position - $0).length } ?? 0
            nodes.lastPosition = actor.position

            // A teleport is not a walk - see EffectsRenderer, which draws the same
            // conclusion for the grass. At full speed a frame covers about six
            // hundredths of a tile, so anything past a stride is a respawn.
            if moved < ActorRenderer.walkStride {
                nodes.walkPhase += moved * .pi / ActorRenderer.walkStride
            }

            let hop = abs(sin(nodes.walkPhase))

            // Walking, or standing still? Not a question with two answers: the two
            // are CROSS-FADED, so somebody stopping settles out of the walk and
            // into the breath over about a fifth of a second rather than switching
            // between them on the frame their thumb lifts.
            //
            // "Moving" is measured the way the walk is - ground actually covered -
            // so somebody held against a wall by a stick pushed into it counts as
            // standing still, which is what it looks like.
            let target: Double = moved > 0.0004 ? 0 : 1
            nodes.stillness += (target - nodes.stillness)
                * min(1, dt * ActorRenderer.stillnessRate)

            // Always turning, used or not - see ActorNodes.breathPhase.
            nodes.breathPhase += dt * 2 * .pi / ActorRenderer.breathRate

            let breath = sin(nodes.breathPhase)
            let still = nodes.stillness

            nodes.body.position.y = GridGeometry.length(
                ofTiles: hop * ActorRenderer.walkBob * (1 - still)
                    + (breath + 1) / 2 * ActorRenderer.breathLift * still)

            // And a lean, which is what stops the hop reading as a hiccup. It
            // leans INTO the direction of travel, so it flips with the figure. It
            // fades out with the walk: a figure standing still has nothing to lean
            // into.
            nodes.body.zRotation = sin(nodes.walkPhase * 0.5)
                * ActorRenderer.walkLean
                * (actor.facesLeft ? 1 : -1)
                * (1 - still)

            // The chest. On the BODY rather than the figure, which is the same rule
            // the bob follows: the figure's scale belongs to the flinch and the
            // heal, and a value rewritten every frame cannot also be animated by an
            // action - the action simply loses. Taller and slightly narrower
            // together, so it reads as a breath rather than as growth.
            let swell = breath * ActorRenderer.breathSwell * still
            nodes.body.yScale = 1 + swell
            nodes.body.xScale = 1 - swell * 0.6

            // A drop in health is the hit, a rise is a heal. No event system needed
            // for something the renderer can simply notice.
            if actor.isAlive, nodes.lastHealth != Int.max {
                if actor.health < nodes.lastHealth { hurt(nodes) }
                if actor.health > nodes.lastHealth {
                    healed(nodes, share: Double(actor.health - nodes.lastHealth)
                                       / Double(max(1, actor.maxHealth)))
                }
            }
            nodes.lastHealth = actor.health

            nodes.goalLabel?.text = actor.ai?.goal.debugName

            // Re-dress when the helmet changes. Picking one up has to be visible
            // instantly - it is the main way anybody can tell how dangerous the
            // actor coming at them is.
            if nodes.lastHelmet != actor.helmet {
                nodes.lastHelmet = actor.helmet
                nodes.sprite.texture = texture(for: actor.helmet)
            }

            if nodes.lastBlaster != actor.blaster {
                nodes.lastBlaster = actor.blaster
                nodes.blaster.texture = blasterTexture(for: actor.blaster)
            }

            // A cooldown that jumped up is a shot just fired.
            if actor.shootCooldown > nodes.lastShotCooldown { nodes.recoil = 1 }
            nodes.lastShotCooldown = actor.shootCooldown

            // Decays towards nothing at a fixed rate per second rather than per
            // frame, so the kick is the same length on any device.
            nodes.recoil = max(0, nodes.recoil - dt * ActorRenderer.recoilDecay)

            hold(nodes.blaster,
                 muzzle: nodes.muzzle,
                 aiming: actor.aim,
                 facingLeft: actor.facesLeft,
                 recoil: nodes.recoil)

            setHealth(Double(actor.health) / Double(actor.maxHealth), on: nodes)
        }

        for (id, nodes) in Array(nodesByActor) where world.actors[id] == nil {
            nodes.root.removeFromParent()
            nodesByActor[id] = nil
        }
    }

    // MARK: - Building

    private func makeNodes(for actor: Actor) -> ActorNodes {
        // The sprite is drawn at exactly the hitbox's dimensions, so "the hitbox
        // covers the sprite" is true by construction rather than by two numbers
        // happening to agree.
        let size = CGSize(width: GridGeometry.length(ofTiles: GameConfig.Player.halfWidth * 2),
                          height: GridGeometry.length(ofTiles: GameConfig.Player.halfDepth * 2))

        let sprite = SKSpriteNode(texture: texture(for: actor.helmet), size: size)
        sprite.anchorPoint = CGPoint(x: 0.5, y: 0)   // stands on its root

        let track = SKShapeNode(path: ActorRenderer.barPath(
            outerWidth: GridGeometry.length(ofTiles: ActorRenderer.barWidthInTiles)))
        track.fillColor = RenderPalette.hudTrack
        track.strokeColor = .black
        track.lineWidth = GridGeometry.length(ofTiles: ActorRenderer.barOutlineInTiles)

        let fill = SKShapeNode()
        fill.fillColor = RenderPalette.colour(for: actor.team)
        fill.strokeColor = .black
        fill.lineWidth = track.lineWidth
        fill.zPosition = 1

        let bar = SKNode()
        bar.position = CGPoint(x: 0, y: GridGeometry.length(ofTiles:
            GameConfig.Player.halfDepth * 2
                + ActorRenderer.barGapInTiles
                + ActorRenderer.barHeightInTiles / 2))
        bar.addChild(track)
        bar.addChild(fill)

        // A bot's current goal, drawn above its head. Eight actors all doing
        // something is genuinely hard to read otherwise.
        var goalLabel: SKLabelNode?
        if GameConfig.AI.showDebugLabels, actor.ai != nil {
            let label = SKLabelNode(fontNamed: "AvenirNext-Bold")
            label.fontSize = 10
            label.fontColor = .white
            label.alpha = 0.8
            label.verticalAlignmentMode = .bottom
            label.position = CGPoint(x: 0, y: bar.position.y
                                     + GridGeometry.length(ofTiles: ActorRenderer.barHeightInTiles))
            goalLabel = label
        }

        // Still a sibling of the figure rather than a child: both mirror the same
        // way, but the weapon sits at its own offset from the body and would be
        // dragged around by the figure's own anchor if it were parented to it.
        let side = GridGeometry.length(ofTiles: GameConfig.Blaster.spriteSize)
        let blaster = SKSpriteNode(texture: blasterTexture(for: actor.blaster),
                                   size: CGSize(width: side, height: side))
        // Anchored on the grip, so rotating swings the barrel round the hand.
        blaster.anchorPoint = CGPoint(x: 0.30, y: 0.32)
        blaster.zPosition = 1

        // The aura, built once and hidden. Made rather than made-and-thrown-away
        // for the reason EnchantNode records: a thing built the moment it is needed
        // and destroyed the moment it is not restarts its own animation constantly.
        //
        // An ellipse, because the ground is seen at an angle - the same squash the
        // shadow and the placement ghost wear, so light lying on grass reads as
        // lying on it rather than as a disc hanging in the air.
        let auraWide = GridGeometry.length(ofTiles: ActorRenderer.perkAuraInTiles)
        let auraTall = auraWide * 0.5

        let perkRing = SKShapeNode(ellipseOf: CGSize(width: auraWide, height: auraTall))
        perkRing.fillColor = .clear
        perkRing.lineWidth = 3
        perkRing.isHidden = true
        perkRing.zPosition = -1

        let nodes = ActorNodes(sprite: sprite,
                               healthFill: fill,
                               blaster: blaster,
                               perkRing: perkRing,
                               goalLabel: goalLabel)

        nodes.perkPool.size = CGSize(width: auraWide * 1.45, height: auraTall * 1.45)
        nodes.perkPool.colorBlendFactor = 1
        nodes.perkPool.isHidden = true

        // Behind the figure and its weapon, which both sit on the body at 0 and
        // above. Light on the ground goes under the person standing in it.
        nodes.perkPool.zPosition = -2
        // root -> body -> figure -> sprite, and each layer owns exactly one kind
        // of movement: the root is where the actor IS, the body is the walk, the
        // figure is whatever just happened to it, and the sprite is which way it is
        // facing. Collapsing any two of those means one overwriting the other.
        // Warm rather than white: a white flash on a pale green map is the same
        // mistake the hit blink made, and read as a highlight rather than as fire.
        nodes.muzzle.size = CGSize(
            width: GridGeometry.length(ofTiles: 0.55),
            height: GridGeometry.length(ofTiles: 0.55)
        )
        nodes.muzzle.color = SKColor(red: 1, green: 0.82, blue: 0.32, alpha: 1)
        nodes.muzzle.colorBlendFactor = 1
        nodes.muzzle.alpha = 0
        nodes.muzzle.zPosition = 2

        // On the ROOT, and this is the one place in this file where that is the
        // right answer rather than the lazy one.
        //
        // The root is simply where the actor IS. Every layer below it carries a
        // movement: the body bobs, sways and breathes; the figure is flinched,
        // healed and charged. All of that is correct for a FIGURE and wrong for
        // light lying on the ground - a pool that rose with each step would be
        // hovering, and one that took the body's sway would tilt, which is a thing
        // the ground cannot do. Parented here it stays flat under the feet while
        // the person moves about on top of it.
        //
        // It still inherits the two things it should: the root is hidden when its
        // owner dies, and faded while they are spawn-protected.
        nodes.root.addChild(nodes.perkPool)
        nodes.root.addChild(perkRing)

        nodes.figure.addChild(sprite)
        nodes.body.addChild(nodes.figure)
        nodes.body.addChild(blaster)
        nodes.body.addChild(nodes.muzzle)
        nodes.root.addChild(nodes.body)
        nodes.root.addChild(bar)
        if let goalLabel { nodes.root.addChild(goalLabel) }

        // Everybody breathes at the same rate and nobody breathes together. Eight
        // figures rising and falling in step is a chorus line, and it is the single
        // most obvious way an idle animation gives itself away - so each one starts
        // somewhere else in the cycle, picked off its own id rather than at random
        // so a replay of the same match looks the same both times.
        nodes.breathPhase = Double(actor.id.raw % 11) * 0.57

        node.addChild(nodes.root)
        nodesByActor[actor.id] = nodes
        return nodes
    }

    /// Puts the weapon in the actor's hand, tilted towards where it is aiming.
    ///
    /// The tilt is measured from whichever horizontal the figure is facing and
    /// clamped, rather than following the aim all the way round. That clamp is the
    /// whole trick. A weapon free to swing the full circle has to mirror itself as
    /// it passes vertical, and that flip fires independently of the figure - one
    /// frame the character faces right holding a gun that points up-left. Held
    /// inside 45° of horizontal it never gets near vertical, so the only flip left
    /// is the character turning round, and the weapon turns with it.
    ///
    /// Which way the figure faces comes from Actor.facesLeft, which already
    /// resolves it: walking sets it, aiming overrides it. So the weapon follows
    /// your feet until you pull the trigger and then follows your aim.
    private func hold(_ blaster: SKSpriteNode,
                      muzzle: SKSpriteNode,
                      aiming direction: Vec2,
                      facingLeft: Bool,
                      recoil: Double) {
        // Shoved back along its own barrel, not down the screen: a weapon pointed
        // up and to the left should kick down and to the right, and the only line
        // that is true on is the one it is aiming along.
        let kicked = GameConfig.Blaster.holdDistance
            - recoil * ActorRenderer.recoilKick

        let reach = GridGeometry.length(ofTiles: kicked)

        // The grip stays put on the body; the weapon pivots around it, the way a
        // hand does.
        blaster.position = CGPoint(
            x: facingLeft ? -reach : reach,
            y: GridGeometry.length(ofTiles: GameConfig.Blaster.holdHeight)
        )

        // Mirroring makes the art point left, and a mirrored node's rotation reads
        // backwards - so measuring the tilt from the facing horizontal happens to
        // give the right value for both.
        let facing: CGFloat = facingLeft ? .pi : 0
        var tilt = CGFloat(direction.angle) - facing
        while tilt > .pi { tilt -= 2 * .pi }
        while tilt < -.pi { tilt += 2 * .pi }

        let limit = CGFloat(GameConfig.Blaster.maxTilt)

        // And flicked up, which is the half of a recoil the eye actually reads -
        // a barrel that rises and settles says "fired" from across the map, where
        // a couple of points of travel says nothing at that size.
        let flick = CGFloat(recoil * ActorRenderer.recoilLift)
        blaster.zRotation = max(-limit, min(limit, tilt)) + flick
        blaster.xScale = facingLeft ? -1 : 1

        // The flash rides at the end of the barrel, worked out from the angle the
        // weapon is actually DRAWN at - the clamped tilt - rather than from the
        // node's own rotation. A mirrored node's rotation reads backwards, and
        // undoing that here would be the second place in this file that has to
        // know the trick. Facing simply negates both components, because pointing
        // left is the same angle plus pi.
        let drawn = Double(max(-limit, min(limit, tilt)))
        let sign: Double = facingLeft ? -1 : 1
        let barrel = GameConfig.Blaster.holdDistance + 0.45

        muzzle.position = CGPoint(
            x: GridGeometry.length(ofTiles: sign * cos(drawn) * barrel),
            y: GridGeometry.length(
                ofTiles: GameConfig.Blaster.holdHeight + sign * sin(drawn) * barrel
            )
        )

        // Driven by the same number as the kick, so the flash cannot outlive the
        // shot that made it.
        muzzle.alpha = CGFloat(recoil * 0.75)
        muzzle.setScale(CGFloat(0.62 + recoil * 0.38))
    }

    /// Took a hit: a flinch, and a moment of shadow.
    ///
    /// Two colours have been tried on the figure itself and both were wrong for the
    /// same reason. White read as a highlight - it is the brightest thing on a pale
    /// green map, so it looked like light catching a helmet. Red read as a claim
    /// about the character rather than about the moment: recolouring somebody says
    /// poisoned, or burning, or on the other team, where a hit happens at a point
    /// on them and is over.
    ///
    /// So the figure only DARKENS, briefly and not much, which is what being
    /// knocked back out of the light would actually look like - and the red is
    /// thrown off them instead, as bits, by EffectsRenderer.
    ///
    /// The flinch is what carries it: the figure recoils, squashes and comes back,
    /// which is movement rather than colour and survives being seen out of the
    /// corner of an eye while you are aiming at something else.
    ///
    /// Keyed, so a burst of hits restarts them rather than stacking up into a
    /// permanently dark actor standing permanently sideways.
    private func hurt(_ nodes: ActorNodes) {
        nodes.sprite.removeAction(forKey: "hit")
        nodes.sprite.run(.sequence([
            .colorize(with: .black, colorBlendFactor: 0.35, duration: 0.04),
            .colorize(withColorBlendFactor: 0, duration: 0.16)
        ]), withKey: "hit")

        // The y is in here because the charge lifts the figure off its feet and
        // shares this key: being shot halfway through one would otherwise cut the
        // landing off and leave somebody hovering for the rest of the match. Every
        // reaction on this node puts it back on the ground.
        nodes.figure.removeAction(forKey: "react")
        nodes.figure.run(.sequence([
            .group([.scaleX(to: 1.12, y: 0.88, duration: 0.05),
                    .rotate(toAngle: 0.10, duration: 0.05),
                    .moveTo(y: 0, duration: 0.05)]),
            .group([.scaleX(to: 1, y: 1, duration: 0.16),
                    .rotate(toAngle: 0, duration: 0.16)])
        ]), withKey: "react")
    }

    /// Patched up: a green wash and a lift, SIZED to what was actually healed.
    ///
    /// Deliberately the opposite shape to the flinch. A hit squashes down and
    /// snaps back; a heal stretches up and settles - so the two are told apart by
    /// the movement, before anybody has read the colour or the health bar.
    ///
    /// The proportion matters because there are two kinds of heal now. A bandage is
    /// half a bar and deserves the whole performance; a portion handed back for
    /// standing at home is a twelfth of one, and given the same treatment it turned
    /// a quiet minute in your own base into a strobe. Small heals get the wash and
    /// nothing else.
    private func healed(_ nodes: ActorNodes, share: Double) {
        let slight = share < 0.15

        nodes.sprite.removeAction(forKey: "hit")
        nodes.sprite.run(.sequence([
            .colorize(with: RenderPalette.placementValid,
                      colorBlendFactor: slight ? 0.4 : 0.7,
                      duration: slight ? 0.14 : 0.08),
            .colorize(withColorBlendFactor: 0, duration: slight ? 0.4 : 0.32)
        ]), withKey: "hit")

        guard !slight else { return }

        nodes.figure.removeAction(forKey: "react")
        nodes.figure.run(.sequence([
            .group([.scaleX(to: 0.92, y: 1.12, duration: 0.09),
                    .moveTo(y: 0, duration: 0.09)]),
            .scaleX(to: 1, y: 1, duration: 0.22)
        ]), withKey: "react")
    }

    /// Switching a power-up on, performed by the FIGURE.
    ///
    /// The third shape in the same vocabulary, and it has to be told apart from the
    /// other two at a glance: a hit squashes down and snaps back, a heal stretches
    /// up and settles. This crouches first and THEN throws itself up - a gather and
    /// a release, which is the one movement neither of the others makes, and the
    /// only one that reads as a decision rather than as something that happened to
    /// you.
    ///
    /// It also rises off its own feet for a moment, which nothing else here does.
    /// The lift is on the figure rather than the body, so the walk cycle underneath
    /// keeps running - somebody who switches this on mid-sprint does not stop dead
    /// to do it.
    ///
    /// The wash is deliberately the strongest colour ever put on this sprite -
    /// stronger than a heal's green, twice the flinch's black. It is on screen for
    /// half a second and it is the one moment the game says something about you
    /// rather than about what just hit you.
    ///
    /// And it is not one colour. The figure is run through four hues of the ring on
    /// the way up, which is the only place in this game a SPRITE ever changes
    /// colour more than once - the item twinkles and the trail cycles, but the
    /// person themselves going through a rainbow is reserved for this single
    /// instant, and that is what makes the instant read as the big one.
    /// Switches the standing aura on, recolours it, hurries it up, or takes it off.
    ///
    /// Four jobs in one function because they are one decision - what should the
    /// light under this person be doing - and splitting them was how the old
    /// version of this idea in EffectsRenderer ended up with a trail that could
    /// outlive the perk that made it.
    ///
    /// The pulse is slow while there is time left and twice as fast in the last
    /// second and a half, which is the only warning anybody gets that a perk is
    /// about to go. It is worth having: the powers are big enough that walking into
    /// a fight on the last half second of one is a real mistake, and nothing else
    /// on the screen says so.
    private func setAura(_ perk: Perk?, ending: Bool, on nodes: ActorNodes) {
        nodes.perkPool.removeAllActions()
        nodes.perkRing.removeAllActions()

        guard let perk else {
            // Gone, and it collapses rather than blinking out. A power-up ending is
            // a thing that happens to you, and a light that simply stopped being
            // drawn would be the screen switching off rather than the perk running
            // out.
            let finish = SKAction.sequence([
                .group([.scaleX(to: 1.45, y: 1.45, duration: 0.12),
                        .fadeOut(withDuration: 0.12)]),
                .hide(),
                .scale(to: 1, duration: 0)
            ])

            nodes.perkPool.run(finish)
            nodes.perkRing.run(finish)
            return
        }

        let colours = RenderPalette.colours(for: perk, at: 0)

        nodes.perkPool.color = colours.bright
        nodes.perkPool.isHidden = false
        nodes.perkPool.alpha = 0.55
        nodes.perkPool.setScale(1)

        nodes.perkRing.strokeColor = colours.bright
        nodes.perkRing.isHidden = false
        nodes.perkRing.alpha = 0.8
        nodes.perkRing.setScale(1)

        // Out of phase with each other on purpose: the ring swells while the pool
        // dims, so the pair breathes rather than throbbing as one blob.
        let beat: TimeInterval = ending ? 0.22 : 0.5

        nodes.perkPool.run(.repeatForever(.sequence([
            .group([.fadeAlpha(to: 0.72, duration: beat), .scale(to: 1.1, duration: beat)]),
            .group([.fadeAlpha(to: 0.38, duration: beat), .scale(to: 0.94, duration: beat)])
        ])))

        nodes.perkRing.run(.repeatForever(.sequence([
            .group([.fadeAlpha(to: 0.35, duration: beat), .scale(to: 1.16, duration: beat)]),
            .group([.fadeAlpha(to: 0.9, duration: beat), .scale(to: 1.0, duration: beat)])
        ])))
    }

    func charge(_ id: ActorID) {
        guard let nodes = nodesByActor[id] else { return }

        nodes.sprite.removeAction(forKey: "hit")
        nodes.sprite.run(.sequence([
            .sequence((0..<4).map { index -> SKAction in
                .colorize(with: RenderPalette.hue(at: index * 2),
                          colorBlendFactor: 0.9, duration: 0.08)
            }),
            .colorize(withColorBlendFactor: 0, duration: 0.4)
        ]), withKey: "hit")

        nodes.figure.removeAction(forKey: "react")
        nodes.figure.run(.sequence([
            // Gather.
            .group([.scaleX(to: 1.16, y: 0.8, duration: 0.11),
                    .moveTo(y: -3, duration: 0.11)]),
            // Release.
            .group([.scaleX(to: 0.84, y: 1.26, duration: 0.13),
                    .moveTo(y: 13, duration: 0.13)]),
            // And down, overshooting once so it lands rather than glides.
            .group([.scaleX(to: 1.06, y: 0.94, duration: 0.16),
                    .moveTo(y: 0, duration: 0.16)]),
            .scaleX(to: 1, y: 1, duration: 0.12)
        ]), withKey: "react")
    }

    private func setHealth(_ fraction: Double, on nodes: ActorNodes) {
        let clamped = min(max(fraction, 0), 1)
        guard abs(clamped - nodes.lastHealthFraction) > 0.002 else { return }
        nodes.lastHealthFraction = clamped

        nodes.healthFill.isHidden = clamped <= 0.001
        guard !nodes.healthFill.isHidden else { return }

        let full = GridGeometry.length(ofTiles: ActorRenderer.barWidthInTiles)
        let height = GridGeometry.length(ofTiles: ActorRenderer.barHeightInTiles)
        nodes.healthFill.path = ActorRenderer.barPath(
            outerWidth: max(height, full * CGFloat(clamped)))
    }

    /// The one drawing, shared with the bar over a machine - see BarArt.
    private static func barPath(outerWidth: CGFloat) -> CGPath {
        BarArt.path(full: GridGeometry.length(ofTiles: barWidthInTiles),
                    filled: outerWidth)
    }

    // MARK: - Textures

    private func blasterTexture(for tier: BlasterTier) -> SKTexture {
        if let cached = blasterCache[tier] { return cached }

        let texture = SKTexture(imageNamed: tier.assetName)
        texture.usesMipmaps = true
        blasterCache[tier] = texture
        return texture
    }

    private func texture(for helmet: HelmetTier) -> SKTexture {
        if let cached = textureCache[helmet] { return cached }

        let texture = SKTexture(imageNamed: ActorRenderer.assetName(for: helmet))
        texture.usesMipmaps = true
        textureCache[helmet] = texture
        return texture
    }

    /// The figure wearing a given helmet.
    ///
    /// Falls back to the bare-headed sprite when a tier's artwork is not in the
    /// catalogue yet - a missing asset otherwise renders as a blank rectangle, and
    /// an invisible player is a far worse bug than an under-dressed one.
    private static func assetName(for helmet: HelmetTier) -> String {
        guard helmet != .none else { return "Player" }

        let name = "Player\(helmet.name)"
        return UIImage(named: name) != nil ? name : "Player"
    }
}
