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

final class ActorRenderer {

    let node = SKNode()
    private var nodesByActor: [ActorID: SKNode] = [:]

    func sync(with world: World) {
        for (id, actor) in world.actors {
            let sprite = nodesByActor[id] ?? makeNode(for: id)
            sprite.position = GridGeometry.point(for: actor.position)
        }

        // Drop nodes for actors that no longer exist.
        for (id, sprite) in Array(nodesByActor) where world.actors[id] == nil {
            sprite.removeFromParent()
            nodesByActor[id] = nil
        }
    }

    private func makeNode(for id: ActorID) -> SKNode {
        let side = GridGeometry.length(ofTiles: GameConfig.Player.halfSize * 2)
        let sprite = SKSpriteNode(color: RenderPalette.player,
                                  size: CGSize(width: side, height: side))
        sprite.zPosition = 10
        node.addChild(sprite)
        nodesByActor[id] = sprite
        return sprite
    }
}
