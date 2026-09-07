//
//  BlueprintRenderer.swift
//  Loot Wars
//
//  The stretch of wall in front of you, drawn as ghosts you can tap.
//
//  Building is the most invisible thing in this game. You may build inside your own
//  claim, on a free tile, while standing on your own ground, and not for a few
//  seconds after being bombed - and a tap that misses any of those does nothing at
//  all, which looks exactly like the game ignoring your finger. Every version of
//  this file has been an answer to that, and the earlier ones were all too shy.
//
//  IT IS NOT A TUTORIAL ANY MORE. It used to be one ghost that retired after three
//  walls, on the theory that the lesson only had to land once. But the thing it
//  shows is not a lesson, it is INFORMATION - where the wall goes next - and that
//  is worth as much in the fourth minute, patching a hole somebody just blew in
//  your side, as it is in the first. A tutorial that expires takes the map away
//  with it.
//
//  A RUN, NOT AN OUTLINE. Every buildable tile within a few paces, and no further,
//  which is the difference between the two failures this has already been through.
//  Outlining the whole plan draws a box round the base that reads as scenery: it is
//  always there, none of it is nearer than any other, and none of it invites a
//  finger. One ghost re-chosen every frame followed the player around like a shoal.
//  A radius does neither - tiles enter and leave by distance rather than by ranking,
//  so nothing hops, and what you see is the piece of wall you could actually reach
//  from where you are standing.
//
//  It is drawn as the wall it would become, because a stand-in shape teaches a
//  player to look for something the game never puts down. A tap pictogram was tried
//  on top of it and came off again: on a screen this busy it was a third thing to
//  read on a tile that already had two.
//
//  The breathing is arithmetic rather than SKActions, and it has to be. These nodes
//  are a pool - the same sprite is a different tile a second later as you walk - so
//  an action running on one would carry the last tile's phase to the next one and
//  the run would shimmer at random. Phase comes from the TILE, so a given square
//  always breathes the same way no matter which node happens to be drawing it.
//

import SpriteKit

final class BlueprintRenderer {

    /// On the ground with the claim tint, under everything that stands on it.
    let node = SKNode()

    /// How faint a ghost gets at the bottom and the top of its breath, before the
    /// distance fade is applied on top.
    private static let dimmest: CGFloat = 0.26
    private static let brightest: CGFloat = 0.60

    /// How far from your feet a tile is still worth showing, in tiles.
    ///
    /// Four and a half is most of a base's side, so walking one edge lights that
    /// edge and little else. Wider and it becomes the box round the whole plan that
    /// reads as scenery; narrower and you are standing on the only ghost you can
    /// see, which teaches the tile rather than the shape.
    private static let reach: Double = 4.5

    /// The most ghosts drawn at once. A cap rather than a limit that ever really
    /// bites - a radius of four and a half over a plan's perimeter is about nine
    /// tiles - but a pool with no ceiling is a pool that can surprise you on a map
    /// nobody has drawn yet.
    private static let maximum = 14

    private var pool: [SKSpriteNode] = []
    private var builtFor: TeamID?

    /// Advanced by the frame rather than by the clock, so a paused game holds still.
    private var phase: Double = 0

    /// Whether anything is being pointed at - the scene asks before spending the
    /// text hint, so nobody is told to tap something that is not there.
    private(set) var hasSlots = false

    // MARK: - Drawing

    func sync(with world: World, dt: TimeInterval) {
        guard let player = world.localPlayer, player.isAlive, !world.isOver,
              world.canBuild(player.team),
              world.claim(for: player.team)?
                  .contains(GridPoint(containing: player.feet)) == true
        else {
            retire()
            return
        }

        build(for: player.team)
        phase += dt

        // Every tile of the plan still waiting for a wall, near enough to walk to.
        //
        // Sorted by distance only to decide what to drop when there are more than
        // the pool holds; the SET is chosen by the radius, which is what stops the
        // run reshuffling itself under your feet as you move.
        let plan = world.baseLayouts[player.team]?.tiles ?? []
        let near = plan
            .filter { BuildSystem.isBuildableTile($0, for: player.team, in: world) }
            .map { (tile: $0, away: distance(from: player.feet, to: $0)) }
            .filter { $0.away <= BlueprintRenderer.reach }
            .sorted { $0.away < $1.away }
            .prefix(BlueprintRenderer.maximum)

        hasSlots = !near.isEmpty

        for (index, ghost) in pool.enumerated() {
            guard index < near.count else {
                ghost.isHidden = true
                continue
            }

            let entry = near[near.startIndex + index]
            ghost.isHidden = false
            ghost.position = GridGeometry.pointAtCentre(of: entry.tile)

            // Breath, and a fade towards the edge of the reach. The fade is what
            // makes this a run rather than a border: the tile at your feet is the
            // one asking to be tapped and the far end of the row is a hint about
            // where the wall goes after it.
            let beat = sin(phase * 1.9 + tilePhase(of: entry.tile))
            let breathe = BlueprintRenderer.dimmest
                + (BlueprintRenderer.brightest - BlueprintRenderer.dimmest)
                * CGFloat(beat * 0.5 + 0.5)

            let closeness = 1 - min(1, entry.away / BlueprintRenderer.reach)
            ghost.alpha = breathe * CGFloat(0.35 + 0.65 * closeness)
            ghost.setScale(0.9 + 0.1 * CGFloat(beat * 0.5 + 0.5))
        }
    }

    /// A phase that belongs to the SQUARE rather than to the node drawing it, so a
    /// tile keeps its own rhythm as the pool shuffles underneath it and no two
    /// neighbours ever pulse together.
    private func tilePhase(of tile: GridPoint) -> Double {
        Double((tile.col &* 7 &+ tile.row &* 13) % 16) * (.pi / 8)
    }

    private func distance(from feet: Vec2, to tile: GridPoint) -> Double {
        (Vec2(x: Double(tile.col) + 0.5, y: Double(tile.row) + 0.5) - feet).length
    }

    /// Built once per team, on the first frame anybody needs it.
    private func build(for team: TeamID) {
        guard builtFor != team else { return }
        builtFor = team

        pool.forEach { $0.removeFromParent() }
        pool.removeAll()

        let side = GridGeometry.tileSize

        for _ in 0..<BlueprintRenderer.maximum {
            let wall = SKSpriteNode(texture: BlockRenderer.ghostTexture(for: team),
                                    size: CGSize(width: side, height: side))
            wall.zPosition = 1
            wall.isHidden = true
            node.addChild(wall)
            pool.append(wall)
        }
    }

    private func retire() {
        hasSlots = false
        pool.forEach { $0.isHidden = true }
    }

    // MARK: - Answering a tap

    /// A tap that built here.
    ///
    /// The ghost pops out of the way rather than being switched off, so the wall
    /// looks like it came FROM the ghost rather than replacing it. A copy pops -
    /// the ghost itself is about to be moved to the next tile, and something that
    /// animates and then jumps somewhere else is a glitch.
    func fill(at tile: GridPoint) {
        guard let team = builtFor else { return }

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
