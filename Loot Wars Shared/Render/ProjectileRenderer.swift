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

    /// What each shot was doing last frame, so one that has gone can be told
    /// apart: stopped by something (a puff where it struck), or simply out of
    /// range (it fizzles, because it hit nothing).
    private var lastSeen: [ProjectileID: (position: Vec2, velocity: Vec2, left: Double)] = [:]
    private lazy var texture: SKTexture = ProjectileRenderer.makeTexture()

    /// - Parameter ears: where the player is listening from, so a shot can be
    ///   placed. Passed in rather than looked up, because the scene is the only
    ///   thing that knows - the camera is not always on the player.
    func sync(with world: World, heardFrom ears: Vec2) {
        var stillFlying = Set<ProjectileID>()

        for projectile in world.projectiles {
            stillFlying.insert(projectile.id)

            // A projectile this renderer has not seen before is a shot that has
            // just been fired, and that is the whole hook - no event, nothing
            // announced. The bullet appearing IS the trigger being pulled, and this
            // file already had to notice it in order to draw the thing.
            //
            // Everybody's, including from behind a wall where you cannot see who
            // fired. Especially from behind a wall: a shot you can hear and cannot
            // see is the game telling you somebody is in your base.
            let known = nodesByProjectile[projectile.id]
            if known == nil {
                SoundPlayer.shared.play(.pop, at: projectile.position, heardFrom: ears)
            }

            let sprite = known ?? makeNode(for: projectile.id)
            sprite.position = GridGeometry.point(for: projectile.position)
            lastSeen[projectile.id] = (projectile.position, projectile.velocity,
                                       projectile.distanceRemaining)
        }

        for (id, sprite) in Array(nodesByProjectile) where !stillFlying.contains(id) {
            sprite.removeFromParent()
            nodesByProjectile[id] = nil

            guard let last = lastSeen.removeValue(forKey: id) else { continue }
            // A frame's travel is about a quarter of a tile. A shot with less
            // than that left ran out of range; anything more was stopped.
            let frameTravel = last.velocity.length / 60
            if last.left <= frameTravel * 1.5 {
                fizzle(at: GridGeometry.point(for: last.position))
            } else {
                // Struck between where it was drawn and where it would have
                // been next: half a frame on is close enough to the face.
                let struck = last.position + last.velocity * (0.5 / 60)
                impact(at: GridGeometry.point(for: struck), along: last.velocity)
            }
        }
    }

    // MARK: - Where shots end

    /// A small puff where a shot struck something: a flash, and a few specks
    /// of dust kicked back the way it came.
    private func impact(at point: CGPoint, along velocity: Vec2) {
        let tile = GridGeometry.length(ofTiles: 1)

        let flash = SKSpriteNode(texture: GlowArt.pool)
        flash.size = CGSize(width: tile * 0.55, height: tile * 0.55)
        flash.color = .white
        flash.colorBlendFactor = 1
        flash.position = point
        flash.zPosition = 8.5
        flash.setScale(0.4)
        node.addChild(flash)
        flash.run(.sequence([
            .group([.scale(to: 1, duration: 0.08), .fadeOut(withDuration: 0.16)]),
            .removeFromParent()
        ]))

        // Back along the shot, spread into a small fan.
        let back = atan2(-velocity.y, -velocity.x)
        for index in 0..<3 {
            let angle = CGFloat(back) + CGFloat(index - 1) * 0.7 + CGFloat.random(in: -0.2...0.2)
            let reach = tile * CGFloat.random(in: 0.25...0.4)
            let speck = SKSpriteNode(texture: GlowArt.pool)
            speck.size = CGSize(width: tile * 0.22, height: tile * 0.22)
            speck.color = SKColor(white: 0.9, alpha: 1)
            speck.colorBlendFactor = 1
            speck.position = point
            speck.zPosition = 8.4
            node.addChild(speck)

            let out = SKAction.moveBy(x: cos(angle) * reach, y: sin(angle) * reach, duration: 0.22)
            out.timingMode = .easeOut
            speck.run(.sequence([
                .group([out, .scale(to: 0.3, duration: 0.22),
                        .sequence([.wait(forDuration: 0.08), .fadeOut(withDuration: 0.14)])]),
                .removeFromParent()
            ]))
        }
    }

    /// A shot that ran out of range just shrinks away where it stopped.
    private func fizzle(at point: CGPoint) {
        let diameter = GridGeometry.length(ofTiles: GameConfig.Blaster.projectileRadius * 2)
        let ghost = SKSpriteNode(texture: texture, size: CGSize(width: diameter, height: diameter))
        ghost.position = point
        ghost.zPosition = 8
        node.addChild(ghost)
        ghost.run(.sequence([
            .group([.scale(to: 0.2, duration: 0.12), .fadeOut(withDuration: 0.12)]),
            .removeFromParent()
        ]))
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
