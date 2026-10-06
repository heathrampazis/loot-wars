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
//  IT RECOMMENDS A SQUARE, drawn round whatever you have already built.
//
//  A base can be any shape that encloses ground, and the first attempt at showing
//  that marked every tile touching one of your walls - which is honest and useless.
//  It is a halo, not an outline: it grows on both sides of every run, it has no
//  direction, and it answers "where COULD a wall go" when the only question worth
//  answering is "where should the next one go".
//
//  So the markers commit to a shape. The bounding box of everything you have laid,
//  grown to the smallest square that can hold a legal base and clamped inside your
//  claim, and the markers are the gaps left in that box's outline. Build the
//  generated rectangle and the box IS that rectangle, so it behaves exactly as it
//  always did. Lay a wall somewhere else and the box stretches to take it in, and
//  the recommendation redraws round your idea rather than the game's.
//
//  A guess, and it says so by being a square: nobody has told the game what they
//  are building, and a rectangle round the evidence is the most useful thing that
//  can be inferred from it. What makes the guess cheap to be wrong about is that
//  it costs nothing to ignore - the markers are a suggestion on ground you can
//  build on anywhere.
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
//  A DARK SQUARE, not a ghost of the wall. It was drawn as the block it would
//  become, on the argument that a stand-in shape teaches a player to look for
//  something the game never puts down - which is a fair argument for one tile and
//  falls apart at nine. A row of translucent team-coloured blocks reads as a row of
//  blocks that are already there and slightly broken, so the base looks finished
//  and faulty rather than unfinished. It also put a second saturated version of the
//  team colour on ground that is already tinted in it.
//
//  A square a shade darker than the claim it sits on has no such problem: it is
//  plainly a HOLE rather than a thing, it cannot be mistaken for masonry, and nine
//  of them in a row read as the gap the wall has not filled yet. A tap pictogram was
//  tried on top and came off again - on a screen this busy it was a third thing to
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

    /// How faint a marker gets at the bottom and the top of its breath, before the
    /// distance fade is applied on top.
    ///
    /// Lower than the old team-coloured ghost needed, because this is a dark square
    /// rather than a bright one: black at 0.4 over a tinted claim is about as much
    /// of a step down from the ground as the ground's own checkerboard is, which is
    /// the level where it reads as a shadow on the grass rather than as an object
    /// lying on it.
    private static let dimmest: CGFloat = 0.16
    private static let brightest: CGFloat = 0.40

    /// How far from your feet a tile is still worth showing, in tiles.
    ///
    /// Three and a half rather than four and a half. Most of a base's side was
    /// still too much: a run that long reaches the corner, and once you can see the
    /// corner you are reading a shape rather than being shown a next move. This is
    /// a couple of paces - what you could lay without walking anywhere.
    private static let reach: Double = 3.5

    /// The most markers drawn at once.
    ///
    /// Four, down from eight and fourteen before that. Each cut has been the same
    /// discovery: the markers are a SUGGESTION and a suggestion gets weaker the
    /// more of it there is. Fourteen was a boundary fence, eight was a clear
    /// instruction, and four is a hint - enough to say which way the wall is going
    /// without drawing the wall for you.
    private static let maximum = 4

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

        // Nothing to point at once the base is shut, and this is what makes the
        // markers adaptive rather than merely permanent. A sealed base has no gap,
        // so any tile touching its wall is on the OUTSIDE of it - marking those
        // would be inviting the player to build a second wall round the first.
        // Blow a hole in it and the hole is a gap again, and the markers come back
        // exactly where the repair is needed.
        let base = world.enclosure(of: player.team)
        guard !base.isSealed else {
            retire()
            return
        }

        build(for: player.team)
        phase += dt

        // Where a block would extend your wall - or, before there is a wall, the
        // generated rectangle as a first suggestion.
        //
        // Sorted by distance only to decide what to drop when there are more than
        // the pool holds; the SET is chosen by the radius, which is what stops the
        // run reshuffling itself under your feet as you move.
        // The plan follows you, as auto building does - the same plan AssistSystem
        // builds from, so the markers show where the walls will actually go.
        let near = world.recommendedWalls(for: player.team, walls: base.ownWalls,
                                          towardsMiddle: player.autoChores,
                                          following: player.autoChores ? player.assistFollowing : nil)
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
    /// Keyed on the team even though nothing about the drawing depends on it any
    /// more - a black square is a black square. Kept because the team is still what
    /// decides the pool has to be thrown away and rebuilt, and because a colourless
    /// marker is a decision that could be reversed.
    private func build(for team: TeamID) {
        guard builtFor != team else { return }
        builtFor = team

        pool.forEach { $0.removeFromParent() }
        pool.removeAll()

        let side = GridGeometry.tileSize

        for _ in 0..<BlueprintRenderer.maximum {
            // Inset by a point, so a run of them reads as separate squares rather
            // than as one dark band with a wall-shaped hole in the middle.
            let slot = SKSpriteNode(color: .black,
                                    size: CGSize(width: side - 2, height: side - 2))
            slot.zPosition = 1
            slot.isHidden = true
            node.addChild(slot)
            pool.append(slot)
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

        // The real block, briefly, growing out of where the dark square was. The
        // marker is a hole and the wall is the thing that fills it, so the flourish
        // has to be the WALL - popping another dark square would animate the
        // absence rather than the arrival.
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
