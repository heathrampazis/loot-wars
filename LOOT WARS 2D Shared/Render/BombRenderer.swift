//
//  BombRenderer.swift
//  Loot Wars
//
//  Bombs in flight, and the flash where one goes off.
//
//  The blast is drawn from a list the world hands over once a frame rather than
//  from the bombs themselves - by the time anything is drawn the bomb is gone and
//  its damage already applied, so the explosion is a record of something that
//  happened, not a thing that exists.
//

import SpriteKit

final class BombRenderer {

    let node = SKNode()

    private var nodesByBomb: [BombID: SKSpriteNode] = [:]
    private lazy var texture: SKTexture = {
        let texture = SKTexture(imageNamed: "Bomb")
        texture.usesMipmaps = true
        return texture
    }()

    func sync(with world: World) {
        for bomb in world.bombs {
            let sprite = nodesByBomb[bomb.id] ?? makeNode(for: bomb.id)
            sprite.position = GridGeometry.point(for: bomb.position)
        }

        let inFlight = Set(world.bombs.map(\.id))
        for (id, sprite) in Array(nodesByBomb) where !inFlight.contains(id) {
            nodesByBomb[id] = nil
            sprite.removeFromParent()
        }

        for blast in world.takeBlasts() {
            flash(at: blast)
        }
    }

    private func makeNode(for id: BombID) -> SKSpriteNode {
        let side = GridGeometry.length(ofTiles: GameConfig.Bomb.spriteSize)
        let sprite = SKSpriteNode(texture: texture,
                                  size: CGSize(width: side, height: side))
        sprite.zPosition = 9    // over walls and shots, under actors

        // Tumbling reads as thrown rather than fired.
        sprite.run(.repeatForever(.rotate(byAngle: .pi * 2, duration: 0.9)))

        node.addChild(sprite)
        nodesByBomb[id] = sprite
        return sprite
    }

    private func flash(at position: Vec2) {
        let radius = GridGeometry.length(ofTiles: GameConfig.Bomb.blastRadius)

        let ring = SKShapeNode(circleOfRadius: radius)
        ring.position = GridGeometry.point(for: position)
        ring.fillColor = RenderPalette.blast
        ring.strokeColor = .black
        ring.lineWidth = GridGeometry.length(ofTiles: 0.11)
        ring.zPosition = 20
        ring.setScale(0.3)

        node.addChild(ring)
        ring.run(.sequence([
            .group([.scale(to: 1.15, duration: 0.16), .fadeOut(withDuration: 0.28)]),
            .removeFromParent()
        ]))
    }
}
