//
//  ProjectileRenderer.swift
//  Loot Wars
//
//  One sprite per shot in flight, all sharing a single texture.
//
//  Nodes are created and destroyed purely by following what is in the world - the
//  renderer never decides a bullet is finished, it just notices one is gone.
//

import SpriteKit
import UIKit

final class ProjectileRenderer {

    let node = SKNode()

    private var nodesByProjectile: [ProjectileID: SKSpriteNode] = [:]
    private lazy var texture: SKTexture = ProjectileRenderer.makeTexture()

    func sync(with world: World) {
        var stillFlying = Set<ProjectileID>()

        for projectile in world.projectiles {
            stillFlying.insert(projectile.id)
            let sprite = nodesByProjectile[projectile.id] ?? makeNode(for: projectile.id)
            sprite.position = GridGeometry.point(for: projectile.position)
        }

        for (id, sprite) in Array(nodesByProjectile) where !stillFlying.contains(id) {
            sprite.removeFromParent()
            nodesByProjectile[id] = nil
        }
    }

    private func makeNode(for id: ProjectileID) -> SKSpriteNode {
        let diameter = GridGeometry.length(ofTiles: GameConfig.Blaster.projectileRadius * 2)
        let sprite = SKSpriteNode(texture: texture,
                                  size: CGSize(width: diameter, height: diameter))
        sprite.zPosition = 8    // over walls, under actors
        node.addChild(sprite)
        nodesByProjectile[id] = sprite
        return sprite
    }

    private static func makeTexture() -> SKTexture {
        let side: CGFloat = 64
        let centre = CGPoint(x: side / 2, y: side / 2)

        let format = UIGraphicsImageRendererFormat.default()
        format.opaque = false

        let image = UIGraphicsImageRenderer(
            size: CGSize(width: side, height: side),
            format: format
        ).image { _ in
            RenderPalette.projectileOutline.setFill()
            circle(centre, 30).fill()

            RenderPalette.projectile.setFill()
            circle(centre, 22).fill()
        }

        return SKTexture(image: image)
    }

    private static func circle(_ centre: CGPoint, _ radius: CGFloat) -> UIBezierPath {
        UIBezierPath(ovalIn: CGRect(x: centre.x - radius,
                                    y: centre.y - radius,
                                    width: radius * 2,
                                    height: radius * 2))
    }
}
