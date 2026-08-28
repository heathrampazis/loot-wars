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

    private var nodesByActor: [ActorID: SKSpriteNode] = [:]
    private var textureCache: [TeamID: SKTexture] = [:]

    func sync(with world: World) {
        for (id, actor) in world.actors {
            let sprite = nodesByActor[id] ?? makeNode(for: actor)

            // The art is a standing figure, so it stands ON the hitbox rather than
            // being centred in it: the sprite's feet sit at the bottom of the box
            // and the body rises from there.
            sprite.position = GridGeometry.point(for: actor.feet)

            // Mirror rather than swap art: one image serves both directions.
            sprite.xScale = actor.facesLeft ? -1 : 1
        }

        // Drop nodes for actors that no longer exist.
        for (id, sprite) in Array(nodesByActor) where world.actors[id] == nil {
            sprite.removeFromParent()
            nodesByActor[id] = nil
        }
    }

    private func makeNode(for actor: Actor) -> SKSpriteNode {
        // The sprite is drawn at exactly the hitbox's dimensions, so "the hitbox
        // covers the sprite" is true by construction rather than by two numbers
        // happening to agree.
        let size = CGSize(width: GridGeometry.length(ofTiles: GameConfig.Player.halfWidth * 2),
                          height: GridGeometry.length(ofTiles: GameConfig.Player.halfDepth * 2))

        let sprite = SKSpriteNode(texture: texture(for: actor.team), size: size)
        sprite.anchorPoint = CGPoint(x: 0.5, y: 0)   // stands on its position
        sprite.zPosition = 10                        // over everything in the world

        node.addChild(sprite)
        nodesByActor[actor.id] = sprite
        return sprite
    }

    private func texture(for team: TeamID) -> SKTexture {
        if let cached = textureCache[team] { return cached }

        let texture = SKTexture(imageNamed: ActorRenderer.assetName(for: team))
        // The art is far larger than it is ever drawn, so let the GPU pick a
        // properly downscaled level instead of resampling the full image each frame.
        texture.usesMipmaps = true

        textureCache[team] = texture
        return texture
    }

    /// Eventually one image per team - the eight of them differ only in body colour.
    /// Until those exist every team wears the same one, which is why the lookup is
    /// here rather than scattered through the renderer.
    private static func assetName(for team: TeamID) -> String {
        "Player"
    }
}
