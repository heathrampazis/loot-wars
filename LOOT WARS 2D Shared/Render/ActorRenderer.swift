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
    private static let barHeightInTiles: Double = 0.224
    private static let barOutlineInTiles: Double = 0.075
    private static let barGapInTiles: Double = 0.08

    /// How far you walk per step, in tiles, and how high the figure rises on one.
    ///
    /// The stride is shared with EffectsRenderer, which puts a tuft of disturbed
    /// grass down on the same beat - the foot planting and the grass moving are
    /// the same event seen twice, and two stride constants would drift apart.
    static let walkStride: Double = 1.05
    private static let walkBob: Double = 0.075      // tiles
    private static let walkLean: Double = 0.045     // radians

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

        init(sprite: SKSpriteNode,
             healthFill: SKShapeNode,
             blaster: SKSpriteNode,
             goalLabel: SKLabelNode?) {
            self.sprite = sprite
            self.healthFill = healthFill
            self.blaster = blaster
            self.goalLabel = goalLabel
        }
    }

    private var nodesByActor: [ActorID: ActorNodes] = [:]
    private var textureCache: [HelmetTier: SKTexture] = [:]
    private var blasterCache: [BlasterTier: SKTexture] = [:]

    func sync(with world: World) {
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
            nodes.body.position.y = GridGeometry.length(
                ofTiles: hop * ActorRenderer.walkBob)

            // And a lean, which is what stops the hop reading as a hiccup. It
            // leans INTO the direction of travel, so it flips with the figure.
            nodes.body.zRotation = sin(nodes.walkPhase * 0.5)
                * ActorRenderer.walkLean
                * (actor.facesLeft ? 1 : -1)

            // A drop in health is the hit, a rise is a heal. No event system needed
            // for something the renderer can simply notice.
            if actor.isAlive, nodes.lastHealth != Int.max {
                if actor.health < nodes.lastHealth { hurt(nodes) }
                if actor.health > nodes.lastHealth { healed(nodes) }
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

            hold(nodes.blaster, aiming: actor.aim, facingLeft: actor.facesLeft)

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

        let nodes = ActorNodes(sprite: sprite,
                               healthFill: fill,
                               blaster: blaster,
                               goalLabel: goalLabel)
        // root -> body -> figure -> sprite, and each layer owns exactly one kind
        // of movement: the root is where the actor IS, the body is the walk, the
        // figure is whatever just happened to it, and the sprite is which way it is
        // facing. Collapsing any two of those means one overwriting the other.
        nodes.figure.addChild(sprite)
        nodes.body.addChild(nodes.figure)
        nodes.body.addChild(blaster)
        nodes.root.addChild(nodes.body)
        nodes.root.addChild(bar)
        if let goalLabel { nodes.root.addChild(goalLabel) }

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
    private func hold(_ blaster: SKSpriteNode, aiming direction: Vec2, facingLeft: Bool) {
        let reach = GridGeometry.length(ofTiles: GameConfig.Blaster.holdDistance)

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
        blaster.zRotation = max(-limit, min(limit, tilt))
        blaster.xScale = facingLeft ? -1 : 1
    }

    /// Took a hit: a red blink and a flinch.
    ///
    /// Red rather than the white it started as. White is the film convention for
    /// an impact, and on this map it is also the brightest thing on a pale green
    /// field - it read as a highlight, or a helmet catching the light, rather than
    /// as damage. Red is what a health bar is already made of here, so the figure
    /// and the bar above it say the same thing in the same colour.
    ///
    /// The flinch is what makes it carry: the figure recoils, squashes and comes
    /// back, which is movement rather than colour and survives being seen out of
    /// the corner of an eye while you are aiming at something else.
    ///
    /// Both keyed, so a burst of hits restarts them rather than stacking up into a
    /// permanently red actor standing permanently sideways.
    private func hurt(_ nodes: ActorNodes) {
        nodes.sprite.removeAction(forKey: "hit")
        nodes.sprite.run(.sequence([
            .colorize(with: RenderPalette.placementBlocked,
                      colorBlendFactor: 0.9, duration: 0.04),
            .colorize(withColorBlendFactor: 0, duration: 0.18)
        ]), withKey: "hit")

        nodes.figure.removeAction(forKey: "react")
        nodes.figure.run(.sequence([
            .group([.scaleX(to: 1.12, y: 0.88, duration: 0.05),
                    .rotate(toAngle: 0.10, duration: 0.05)]),
            .group([.scaleX(to: 1, y: 1, duration: 0.16),
                    .rotate(toAngle: 0, duration: 0.16)])
        ]), withKey: "react")
    }

    /// Patched up: a green wash and a lift.
    ///
    /// Deliberately the opposite shape to the flinch. A hit squashes down and
    /// snaps back; a heal stretches up and settles - so the two are told apart by
    /// the movement, before anybody has read the colour or the health bar.
    private func healed(_ nodes: ActorNodes) {
        nodes.sprite.removeAction(forKey: "hit")
        nodes.sprite.run(.sequence([
            .colorize(with: RenderPalette.placementValid,
                      colorBlendFactor: 0.7, duration: 0.08),
            .colorize(withColorBlendFactor: 0, duration: 0.32)
        ]), withKey: "hit")

        nodes.figure.removeAction(forKey: "react")
        nodes.figure.run(.sequence([
            .scaleX(to: 0.92, y: 1.12, duration: 0.09),
            .scaleX(to: 1, y: 1, duration: 0.22)
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

    /// Same construction as the HUD bars: the path is inset by half the stroke, so
    /// the outline's outer edge lands exactly on the stated width.
    private static func barPath(outerWidth: CGFloat) -> CGPath {
        let full = GridGeometry.length(ofTiles: barWidthInTiles)
        let stroke = GridGeometry.length(ofTiles: barOutlineInTiles)
        let height = GridGeometry.length(ofTiles: barHeightInTiles) - stroke

        let rect = CGRect(x: -full / 2 + stroke / 2,
                          y: -height / 2,
                          width: outerWidth - stroke,
                          height: height)

        return CGPath(roundedRect: rect,
                      cornerWidth: height / 2,
                      cornerHeight: height / 2,
                      transform: nil)
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
