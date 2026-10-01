//
//  ClaimRenderer.swift
//  Loot Wars
//
//  Tints each team's claim in that team's colour.
//
//  One flat translucent square per claim, sitting between the ground and everything
//  else, so the checkerboard still reads through it. The alpha is not a guess: it was
//  solved from the mockup, where both checkerboard shades resolve to the team colour
//  at 29% over the ground.
//

import SpriteKit

final class ClaimRenderer {

    let node = SKNode()

    static let tintAlpha: CGFloat = 0.29

    func build(claims: [TeamID: BaseClaim]) {
        node.removeAllChildren()

        for (team, claim) in claims {
            let side = GridGeometry.length(ofTiles: Double(claim.size))

            let tint = SKSpriteNode(color: RenderPalette.colour(for: team),
                                    size: CGSize(width: side, height: side))
            // Anchored bottom-left so it lines up with the claim's origin tile.
            tint.anchorPoint = CGPoint(x: 0, y: 0)
            tint.position = GridGeometry.point(for: Vec2(x: Double(claim.origin.col),
                                                         y: Double(claim.origin.row)))
            tint.alpha = ClaimRenderer.tintAlpha
            tint.zPosition = -50    // above the baked ground, below everything else

            node.addChild(tint)
        }
    }
}
