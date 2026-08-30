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

    private final class ActorNodes {
        let root = SKNode()
        let sprite: SKSpriteNode
        let healthFill: SKShapeNode
        let blaster: SKSpriteNode
        let goalLabel: SKLabelNode?
        var lastHealthFraction: Double = -1
        /// So the figure can be re-dressed the moment its helmet changes.
        var lastHelmet: HelmetTier?
        var lastBlaster: BlasterTier?
        /// Used only to notice a drop, which is what triggers the hit flash.
        var lastHealth: Int = Int.max

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

            // A drop in health is the hit. No event system needed for something the
            // renderer can simply notice.
            if actor.health < nodes.lastHealth, actor.isAlive {
                flash(nodes.sprite)
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
        nodes.root.addChild(sprite)
        nodes.root.addChild(blaster)
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
        // Mirroring makes the art point left, and a mirrored node's rotation reads
        // backwards - so measuring the tilt from the facing horizontal happens to
        // give the right value for both.
        let facing: CGFloat = facingLeft ? .pi : 0
        var tilt = CGFloat(direction.angle) - facing
        while tilt > .pi { tilt -= 2 * .pi }
        while tilt < -.pi { tilt += 2 * .pi }

        let limit = CGFloat(GameConfig.Blaster.maxTilt)
        tilt = max(-limit, min(limit, tilt))

        // The grip slides down and outward as the weapon angles away from level.
        //
        // Rotating about a grip near the sprite's lower-left swings its far end
        // upwards - level, a Blaster6 reaches 0.37 tiles above the grip; at full
        // tilt, 0.74 - which is what put the barrel across the character's face.
        // Moving the hand rather than the barrel keeps the aim honest, and reads as
        // an arm extending. It applies to downward tilt too, where the back of the
        // weapon swings up instead.
        let lean = abs(sin(tilt))
        let reach = GridGeometry.length(
            ofTiles: GameConfig.Blaster.holdDistance
                + GameConfig.Blaster.tiltReach * Double(lean))
        let height = GridGeometry.length(
            ofTiles: GameConfig.Blaster.holdHeight
                - GameConfig.Blaster.tiltDrop * Double(lean))

        // The weapon pivots around the grip, the way a hand does.
        blaster.position = CGPoint(x: facingLeft ? -reach : reach, y: height)
        blaster.zRotation = tilt
        blaster.xScale = facingLeft ? -1 : 1
    }

    /// A quick white blink. Keyed, so rapid hits restart it rather than stacking up
    /// into a permanently white actor.
    private func flash(_ sprite: SKSpriteNode) {
        sprite.removeAction(forKey: "hit")
        sprite.run(.sequence([
            .colorize(with: .white, colorBlendFactor: 0.85, duration: 0.04),
            .colorize(withColorBlendFactor: 0, duration: 0.14)
        ]), withKey: "hit")
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
