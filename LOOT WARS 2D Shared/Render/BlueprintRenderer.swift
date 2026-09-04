//
//  BlueprintRenderer.swift
//  Loot Wars
//
//  One ghost wall, with a tap on it, that goes away once you can build.
//
//  This is a TUTORIAL, not a build interface, and every wrong version of it came
//  from forgetting that. Building used to be the most invisible thing in the game -
//  you may build inside your own claim, on a free tile, while standing on your own
//  ground, and not for a few seconds after being bombed, and a tap that missed any
//  of those did nothing at all, which looks exactly like the game ignoring your
//  finger. The fix is not an overlay of everywhere you could ever build. It is
//  showing somebody, once, that tapping the ground puts up a wall.
//
//  ONE, AND IT STAYS PUT. Two ghosts chosen fresh every frame followed the player
//  around the base like a shoal - each step re-sorted the plan by distance and the
//  pair hopped to different tiles, which reads as something alive to be watched
//  rather than a square to be pressed. A target is picked once and held until it is
//  built or something else takes the tile, so the instruction stops moving while
//  you walk towards it.
//
//  It is drawn as the wall it would become, because a stand-in shape teaches a
//  player to look for something the game never puts down. A tap pictogram was tried
//  on top of it - a ring going out of a dot - and came off again: on a screen this
//  busy it was a third thing to read on a tile that already had two, and a wall
//  fading in and out on a piece of ground you are standing next to is an invitation
//  on its own.
//
//  It retires after three walls, remembered by Prefs, and not after a match count:
//  somebody whose first five minutes were spent being shot at in a field has not
//  learned anything, and a tutorial that expires on a clock is a tutorial for
//  whoever happened to have a quiet first match.
//
//  What is left behind afterwards is the part that was never a lesson: a refused
//  tap flashes the tile red, so "you cannot build there" stops being
//  indistinguishable from "the game did not see you".
//

import SpriteKit

final class BlueprintRenderer {

    /// On the ground with the claim tint, under everything that stands on it.
    let node = SKNode()

    /// How faint the ghost wall is, at the bottom and the top of its breath.
    private static let dimmest: CGFloat = 0.3
    private static let brightest: CGFloat = 0.62

    /// Everything that marks the tile: the ghost wall and the tap on top of it.
    private let marker = SKNode()

    private var shownFor: TeamID?

    /// The tile being pointed at. Held rather than recomputed, which is the whole
    /// difference between an instruction and a distraction.
    private var target: GridPoint?

    /// Whether the marker is standing anywhere - the scene asks before spending the
    /// text hint, so nobody is told to tap something that is not there.
    private(set) var hasSlots = false

    // MARK: - Drawing

    func sync(with world: World, dt: TimeInterval) {
        guard !Prefs.taughtBuilding,
              let player = world.localPlayer, player.isAlive, !world.isOver,
              world.canBuild(player.team),
              world.claim(for: player.team)?
                  .contains(GridPoint(containing: player.feet)) == true
        else {
            retire()
            return
        }

        build(for: player.team)

        // Keep the tile it is already pointing at. It is only re-chosen when it
        // stops being a place a wall can go - because it just became one, or
        // because a chest landed on it.
        if let held = target,
           BuildSystem.isBuildableTile(held, for: player.team, in: world) {
            place(at: held)
            return
        }

        let plan = world.baseLayouts[player.team]?.tiles ?? []
        let free = plan.filter { BuildSystem.isBuildableTile($0, for: player.team, in: world) }

        // On the OUTSIDE of the plan, not simply the nearest tile.
        //
        // The nearest one is usually behind you or beside your own chest, which
        // teaches "tapping the ground makes a wall" and nothing else. A wall is not
        // a wall until it goes round something, and the thing this tutorial is
        // actually for is the shape: the first tile it points at should be one a
        // player would recognise as the EDGE of their base, so the wall they build
        // next to it continues an outline rather than starting a stump in the
        // middle of their own yard.
        //
        // So: the ring of tiles furthest from the middle of the claim, and the one
        // of those nearest the player - out on the perimeter, but the part of the
        // perimeter they are already standing by.
        let centre = world.claim(for: player.team)?.centreTile
        let outermost = free.map { edginess(of: $0, from: centre) }.max() ?? 0

        let next = free
            .filter { edginess(of: $0, from: centre) >= outermost - 0.75 }
            .min { distance(from: player.feet, to: $0) < distance(from: player.feet, to: $1) }

        target = next

        guard let next else {
            hasSlots = false
            marker.isHidden = true
            return
        }

        place(at: next)
    }

    private func place(at tile: GridPoint) {
        hasSlots = true
        marker.isHidden = false
        marker.position = GridGeometry.pointAtCentre(of: tile)
    }

    /// How far out towards the edge of the claim a tile sits. Chebyshev rather than
    /// straight-line distance, because a claim is a square and its edge is a square:
    /// by this measure every tile on the same ring scores the same, which is what
    /// makes "the outer ring" a set rather than four corners.
    private func edginess(of tile: GridPoint, from centre: GridPoint?) -> Double {
        guard let centre else { return 0 }
        return Double(max(abs(tile.col - centre.col), abs(tile.row - centre.row)))
    }

    private func distance(from feet: Vec2, to tile: GridPoint) -> Double {
        (Vec2(x: Double(tile.col) + 0.5, y: Double(tile.row) + 0.5) - feet).length
    }

    /// Built once, on the first frame anybody needs it, because the team is not
    /// known before that.
    private func build(for team: TeamID) {
        guard shownFor != team else { return }
        shownFor = team

        marker.removeAllChildren()
        marker.removeFromParent()
        node.addChild(marker)

        let side = GridGeometry.tileSize

        // The wall it would become.
        let wall = SKSpriteNode(texture: BlockRenderer.ghostTexture(for: team),
                                size: CGSize(width: side, height: side))
        wall.zPosition = 1
        wall.alpha = BlueprintRenderer.dimmest
        wall.setScale(0.9)

        wall.run(.repeatForever(.sequence([
            .group([.fadeAlpha(to: BlueprintRenderer.brightest, duration: 0.55),
                    .scale(to: 1.0, duration: 0.55)]),
            .group([.fadeAlpha(to: BlueprintRenderer.dimmest, duration: 0.65),
                    .scale(to: 0.9, duration: 0.65)])
        ])))

        marker.addChild(wall)

    }

    /// Off, and off for good once the lesson is learned.
    private func retire() {
        hasSlots = false
        marker.isHidden = true
    }

    // MARK: - Answering a tap

    /// A tap that built here.
    ///
    /// The ghost pops out of the way rather than being switched off, so the wall
    /// looks like it came FROM the ghost rather than replacing it. A copy pops -
    /// the ghost itself is about to be moved to the next tile, and something that
    /// animates and then jumps somewhere else is a glitch.
    func fill(at tile: GridPoint) {
        guard let team = shownFor, !marker.isHidden else { return }

        // The tile it was pointing at is about to have a wall on it, so the next
        // frame picks the next one.
        if target == tile { target = nil }

        let side = GridGeometry.tileSize
        let flourish = SKSpriteNode(texture: BlockRenderer.ghostTexture(for: team),
                                    size: CGSize(width: side, height: side))

        flourish.position = GridGeometry.pointAtCentre(of: tile)
        flourish.zPosition = 2
        flourish.alpha = 0.7
        node.addChild(flourish)

        flourish.run(.sequence([
            .group([.scale(to: 1.3, duration: 0.16),
                    .fadeOut(withDuration: 0.16)]),
            .removeFromParent()
        ]))
    }

    /// A tap that could not build here.
    ///
    /// This one outlives the tutorial. Something has to happen: a refused tap used
    /// to be indistinguishable from a tap the game had not noticed, which is the
    /// worst failure state an interface has - the player cannot tell whether to try
    /// again, try elsewhere, or stop trying.
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
        flash.zPosition = 2

        // Parented to the world layer rather than to this node, which spends most
        // of a match hidden - a refusal has to be readable whether or not the
        // tutorial is still running.
        node.parent?.addChild(flash)

        flash.run(.sequence([
            .wait(forDuration: 0.1),
            .group([.fadeOut(withDuration: 0.3),
                    .scale(to: 1.15, duration: 0.3)]),
            .removeFromParent()
        ]))
    }
}
