//
//  ActorRenderer.swift
//  Loot Wars
//
//  Keeps one SKNode per actor in step with the simulation.
//
//  Read the sync method carefully: it only ever READS from the world. A node is a
//  picture of an actor, never the actor itself. The moment health or ammo or a
//  timer lives on an SKNode, the simulation stops being the source of truth.
//

import SpriteKit
import UIKit

final class ActorRenderer {

    let node = SKNode()

    private var nodesByActor: [ActorID: SKNode] = [:]
    private var textureCache: [TeamID: SKTexture] = [:]

    func sync(with world: World) {
        for (id, actor) in world.actors {
            let sprite = nodesByActor[id] ?? makeNode(for: actor)
            sprite.position = GridGeometry.point(for: actor.position)
        }

        // Drop nodes for actors that no longer exist.
        for (id, sprite) in Array(nodesByActor) where world.actors[id] == nil {
            sprite.removeFromParent()
            nodesByActor[id] = nil
        }
    }

    private func makeNode(for actor: Actor) -> SKNode {
        let side = GridGeometry.length(ofTiles: GameConfig.Player.halfSize * 2)
        let sprite = SKSpriteNode(texture: texture(for: actor.team),
                                  size: CGSize(width: side, height: side))
        sprite.zPosition = 10
        node.addChild(sprite)
        nodesByActor[actor.id] = sprite
        return sprite
    }

    private func texture(for team: TeamID) -> SKTexture {
        if let cached = textureCache[team] { return cached }
        let made = ActorRenderer.makeTexture(colour: RenderPalette.colour(for: team))
        textureCache[team] = made
        return made
    }

    /// A rounded square in the team colour with a heavy black outline. The outline is
    /// what keeps an actor readable while standing on a wall of its own colour.
    private static func makeTexture(colour: SKColor) -> SKTexture {
        let side: CGFloat = 128
        let outline: CGFloat = 13

        let format = UIGraphicsImageRendererFormat.default()
        format.opaque = false

        let image = UIGraphicsImageRenderer(
            size: CGSize(width: side, height: side),
            format: format
        ).image { _ in
            SKColor.black.setFill()
            UIBezierPath(roundedRect: CGRect(x: 0, y: 0, width: side, height: side),
                         cornerRadius: 26).fill()

            colour.setFill()
            UIBezierPath(roundedRect: CGRect(x: outline,
                                             y: outline,
                                             width: side - outline * 2,
                                             height: side - outline * 2),
                         cornerRadius: 15).fill()
        }

        return SKTexture(image: image)
    }
}
