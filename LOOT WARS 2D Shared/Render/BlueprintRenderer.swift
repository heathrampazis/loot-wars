//
//  BlueprintRenderer.swift
//  Loot Wars
//
//  The wall you have not built yet, drawn where it goes.
//
//  Building used to be the most invisible thing in this game, and the reason is
//  worth stating plainly: every rule about it was true and none of it was VISIBLE.
//  You may build inside your own claim, on a free tile, while standing on your own
//  ground, and not for a few seconds after being bombed. A tap that satisfied all
//  four put up a wall; a tap that missed any of them did nothing whatsoever - and
//  nothing whatsoever looks exactly like the game not registering your finger. So
//  the first question a new player has - "can I even do this here?" - had no answer
//  on screen at all, and the second - "what am I supposed to be building?" - had
//  never been asked out loud.
//
//  Both are answered by drawing the plan. Every team already has one: BaseLayout is
//  the ordered list of wall tiles the bots lay, generated per claim at map time, and
//  it exists for the player's team exactly as it does for theirs. Nobody was showing
//  it to the one team that could read it.
//
//  So the unbuilt tiles of your own base are drawn as empty bricks. Faint from
//  across the map - which incidentally is the only thing on screen that says which
//  base is yours - and lit up when you are standing inside your claim, because that
//  is exactly when tapping one will work. The affordance and the rule are the same
//  shape: if it is glowing, it will build.
//
//  It stays a SUGGESTION. Tapping any free tile in your claim still builds there,
//  the same as it always did - the plan is what the game recommends, not a track it
//  puts you on. What it buys is that a player who has no idea what a base should
//  look like is shown the answer the bots are already using, and can trace it with
//  a finger.
//

import SpriteKit

final class BlueprintRenderer {

    /// Above the claim tint and the ground, below the trees, the walls and
    /// everybody - these are holes in a wall, so things stand in front of them.
    let node = SKNode()

    /// How faint the plan is from across the map, and how bright it goes when you
    /// are stood in your base with the tap available.
    ///
    /// The dim state earns its keep on a 64 x 64 map with no minimap: it is the one
    /// mark on screen that says "your base is over there". The bright state is the
    /// button.
    private static let restingAlpha: CGFloat = 0.22
    private static let readyAlpha: CGFloat = 0.85

    /// Seconds per breath of the lit state. Slow: this is a thing waiting for you,
    /// not a thing demanding attention.
    private static let pulseRate: Double = 1.9

    private var bricks: [GridPoint: SKShapeNode] = [:]

    /// What the plan was last drawn against.
    ///
    /// The map's revision counts walls going up and coming down; the structure
    /// count catches the other thing that can occupy a tile a brick is sitting on -
    /// a chest or a machine put down inside your own base. Without the second, you
    /// get an outline drawn over your own chest that flashes red when tapped, which
    /// is the exact confusion this file exists to remove.
    private var drawnRevision = -1
    private var drawnStructures = -1
    private var drawnTeam: TeamID?
    private var phase: Double = 0

    /// Whether there is anything left to build at all - the scene asks, so the hint
    /// is never offered to somebody whose base is already finished.
    private(set) var hasSlots = false

    // MARK: - Drawing

    func sync(with world: World, dt: TimeInterval) {
        guard let player = world.localPlayer, player.isAlive, !world.isOver else {
            node.isHidden = true
            return
        }

        let structures = world.chests.count + world.arcades.count

        if world.mapRevision != drawnRevision
            || structures != drawnStructures
            || drawnTeam != player.team {
            drawnRevision = world.mapRevision
            drawnStructures = structures
            drawnTeam = player.team
            rebuild(for: player.team, in: world)
        }

        hasSlots = !bricks.isEmpty
        node.isHidden = bricks.isEmpty

        // Lit exactly when a tap would work, which is the whole point: the two
        // conditions the player cannot see - standing on your own ground, and the
        // seconds of quiet after being bombed - are the two that turn it on.
        let standingHome = world.claim(for: player.team)?
            .contains(GridPoint(containing: player.feet)) == true

        let ready = standingHome && world.canBuild(player.team)

        phase += dt * 2 * .pi / BlueprintRenderer.pulseRate

        // Written every frame rather than run as an action, so nothing can be left
        // half-faded by a state change mid-animation.
        node.alpha = ready
            ? BlueprintRenderer.readyAlpha - 0.18 * CGFloat((sin(phase) + 1) / 2)
            : BlueprintRenderer.restingAlpha
    }

    private func rebuild(for team: TeamID, in world: World) {
        for brick in bricks.values { brick.removeFromParent() }
        bricks.removeAll()

        guard let plan = world.baseLayouts[team]?.tiles else { return }

        let colour = RenderPalette.colour(for: team)
        let side = GridGeometry.tileSize

        for tile in plan where BuildSystem.isBuildableTile(tile, for: team, in: world) {
            let brick = SKShapeNode(
                rect: CGRect(x: -side / 2 + 2, y: -side / 2 + 2,
                             width: side - 4, height: side - 4),
                cornerRadius: 5
            )

            // An outline with almost nothing inside it. A filled ghost reads as a
            // wall that is already there and greys out your own base; an outline
            // reads as a space waiting for one.
            brick.fillColor = colour.withAlphaComponent(0.16)
            brick.strokeColor = colour
            brick.lineWidth = 2
            brick.position = GridGeometry.pointAtCentre(of: tile)
            brick.zPosition = 1

            node.addChild(brick)
            bricks[tile] = brick
        }
    }

    // MARK: - Answering a tap

    /// A tap that would have built here, and did.
    ///
    /// The wall itself appears on the next frame, so this is only the brick getting
    /// out of the way - it pops and vanishes rather than being switched off, which
    /// is what makes the wall look like it came from the outline rather than
    /// replacing it.
    func fill(at tile: GridPoint) {
        guard let brick = bricks[tile] else { return }
        bricks[tile] = nil

        brick.run(.sequence([
            .group([.scale(to: 1.25, duration: 0.12),
                    .fadeOut(withDuration: 0.12)]),
            .removeFromParent()
        ]))
    }

    /// A tap that could not build here.
    ///
    /// Something has to happen. A refused tap used to be indistinguishable from a
    /// tap the game had not noticed, which is the single worst failure state an
    /// interface can have: the player cannot tell whether to try again, try
    /// elsewhere, or stop trying.
    func refuse(at tile: GridPoint) {
        let side = GridGeometry.tileSize

        let flash = SKShapeNode(
            rect: CGRect(x: -side / 2 + 2, y: -side / 2 + 2,
                         width: side - 4, height: side - 4),
            cornerRadius: 5
        )

        flash.fillColor = RenderPalette.placementBlocked.withAlphaComponent(0.4)
        flash.strokeColor = RenderPalette.placementBlocked
        flash.lineWidth = 2.5
        flash.position = GridGeometry.pointAtCentre(of: tile)

        // Above the plan and above its own parent's fade: a refusal has to be
        // readable whether or not the blueprint happens to be lit.
        flash.zPosition = 2
        flash.alpha = 1

        // Parented to the world layer's own node rather than to the blueprint, or
        // it would inherit the resting alpha and be a whisper exactly when it needs
        // to be a word.
        node.parent?.addChild(flash)

        flash.run(.sequence([
            .wait(forDuration: 0.1),
            .group([.fadeOut(withDuration: 0.3),
                    .scale(to: 1.15, duration: 0.3)]),
            .removeFromParent()
        ]))
    }
}
