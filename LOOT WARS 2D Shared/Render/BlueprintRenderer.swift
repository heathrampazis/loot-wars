//
//  BlueprintRenderer.swift
//  Loot Wars
//
//  Two ghost walls that ask to be tapped, and then go away for good.
//
//  This is a TUTORIAL, not a build interface, and getting that distinction wrong is
//  what the first two versions of this file did. Building used to be the most
//  invisible thing in the game - you may build inside your own claim, on a free
//  tile, while standing on your own ground, and not for a few seconds after being
//  bombed, and a tap that missed any of those did nothing at all, which looks
//  exactly like the game ignoring your finger. The fix for that is not a permanent
//  overlay of everywhere you could ever build. It is showing somebody, once, that
//  tapping the ground puts up a wall - and then getting out of the way.
//
//  So: at most two ghosts, the nearest unbuilt tiles of your own base plan, drawn
//  as the wall they would become rather than as an abstract marker. A stand-in
//  shape would teach a player to look for something the game never puts down; a
//  translucent wall pulsing on the exact tile teaches the gesture and the result in
//  one picture.
//
//  They pulse because a still thing on the ground is scenery. The whole job of this
//  animation is to be the only thing moving in your base when you walk into it.
//
//  And they retire. Two or three walls in, the player has the mechanic, and Prefs
//  remembers it for every match after this one. What is left behind is the part
//  that was always missing and is not a lesson: a refused tap flashes the tile red,
//  so "you cannot build there" stops being indistinguishable from "the game did not
//  see you".
//

import SpriteKit

final class BlueprintRenderer {

    /// On the ground with the claim tint, under everything that stands on it.
    let node = SKNode()

    /// How many ghosts stand at once.
    ///
    /// Two. One is a single instruction and reads as a bug when you build it and
    /// nothing takes its place; the whole plan is a diagram of a building, which is
    /// a different and much louder claim than "tap here". Two says "and another one
    /// after that", which is the shape of the actual mechanic.
    private static let ghostCount = 2

    /// How faint the wall is, at the bottom and the top of its breath.
    private static let dimmest: CGFloat = 0.3
    private static let brightest: CGFloat = 0.62

    private var ghosts: [SKSpriteNode] = []
    private var shownFor: TeamID?

    /// Whether a ghost is standing anywhere - the scene asks before spending the
    /// text hint, so nobody is told to tap an outline that is not there.
    private(set) var hasSlots = false

    // MARK: - Drawing

    func sync(with world: World, dt: TimeInterval) {
        guard Prefs.isFirstMatch, !Prefs.taughtBuilding,
              let player = world.localPlayer, player.isAlive, !world.isOver,
              world.canBuild(player.team),
              world.claim(for: player.team)?
                  .contains(GridPoint(containing: player.feet)) == true
        else {
            retire()
            return
        }

        build(for: player.team)

        // The nearest unbuilt tiles of the plan, so the ghosts are always the ones
        // you could reach out and touch rather than the next two in the plan's own
        // order - which on a wall built from both ends can be halfway round the
        // base from where you are standing.
        let plan = world.baseLayouts[player.team]?.tiles ?? []

        let targets = Array(
            plan
                .filter { BuildSystem.isBuildableTile($0, for: player.team, in: world) }
                .sorted { first, second in
                    distance(from: player.feet, to: first)
                        < distance(from: player.feet, to: second)
                }
                .prefix(BlueprintRenderer.ghostCount)
        )

        hasSlots = !targets.isEmpty
        node.isHidden = targets.isEmpty

        for (index, ghost) in ghosts.enumerated() {
            guard index < targets.count else {
                ghost.isHidden = true
                continue
            }

            let tile = targets[index]
            ghost.isHidden = false
            ghost.position = GridGeometry.pointAtCentre(of: tile)
        }
    }

    private func distance(from feet: Vec2, to tile: GridPoint) -> Double {
        (Vec2(x: Double(tile.col) + 0.5, y: Double(tile.row) + 0.5) - feet).length
    }

    /// Built once, on the first frame anybody needs one, because the team is not
    /// known before that.
    private func build(for team: TeamID) {
        guard shownFor != team else { return }
        shownFor = team

        for ghost in ghosts { ghost.removeFromParent() }
        ghosts.removeAll()

        let side = GridGeometry.tileSize

        for _ in 0..<BlueprintRenderer.ghostCount {
            let ghost = SKSpriteNode(texture: BlockRenderer.ghostTexture(for: team),
                                     size: CGSize(width: side, height: side))
            ghost.zPosition = 1
            ghost.alpha = BlueprintRenderer.dimmest
            ghost.setScale(0.9)

            // In step with each other rather than staggered: two ghosts breathing
            // out of phase read as two separate things happening, and these are one
            // instruction written twice.
            ghost.run(.repeatForever(.sequence([
                .group([
                    .fadeAlpha(to: BlueprintRenderer.brightest, duration: 0.55),
                    .scale(to: 1.0, duration: 0.55)
                ]),
                .group([
                    .fadeAlpha(to: BlueprintRenderer.dimmest, duration: 0.65),
                    .scale(to: 0.9, duration: 0.65)
                ])
            ])))

            node.addChild(ghost)
            ghosts.append(ghost)
        }
    }

    /// Off, and off for good once the lesson is learned.
    private func retire() {
        hasSlots = false
        node.isHidden = true
    }

    // MARK: - Answering a tap

    /// A tap that built here.
    ///
    /// The ghost pops out of the way rather than being switched off, so the wall
    /// looks like it came FROM the ghost rather than replacing it. A copy pops -
    /// the ghost itself is about to be moved to the next tile, and something that
    /// animates and then jumps somewhere else is a glitch.
    func fill(at tile: GridPoint) {
        guard let team = shownFor, !node.isHidden else { return }

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
