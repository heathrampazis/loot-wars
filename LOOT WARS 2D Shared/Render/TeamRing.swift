// The glowing team-coloured ring every person stands on, so you can tell teams apart at a glance.

import SpriteKit

enum TeamRing {
    // Width in tiles; a shade wider than a person so it reads as light they stand in.
    static let widthInTiles: Double = 1.35

    // A soft pool plus a hard ring, flattened to sit on the ground; callers set the z.
    static func make(team: TeamID, width: CGFloat) -> SKNode {
        let colour = RenderPalette.colour(for: team)
        let height = width * 0.5
        let root = SKNode()

        let pool = SKSpriteNode(texture: GlowArt.pool)
        pool.size = CGSize(width: width * 1.45, height: height * 1.45)
        pool.color = colour
        pool.colorBlendFactor = 1
        pool.alpha = 0.5
        root.addChild(pool)

        let ring = SKShapeNode(ellipseOf: CGSize(width: width, height: height))
        ring.fillColor = .clear
        ring.strokeColor = colour
        ring.lineWidth = max(2, width * 0.06)
        ring.alpha = 0.85
        ring.zPosition = 0.01
        root.addChild(ring)

        // Out of phase, so the pair breathes rather than throbbing as one blob.
        let beat: TimeInterval = 1.1
        pool.run(.repeatForever(.sequence([
            .fadeAlpha(to: 0.62, duration: beat),
            .fadeAlpha(to: 0.4, duration: beat)
        ])))
        ring.run(.repeatForever(.sequence([
            .fadeAlpha(to: 0.65, duration: beat),
            .fadeAlpha(to: 0.9, duration: beat)
        ])))

        return root
    }
}
