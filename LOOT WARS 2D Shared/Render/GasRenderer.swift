//
//  GasRenderer.swift
//  Loot Wars
//
//  Clouds of gas standing on the map.
//
//  Drawn as three overlapping blobs rather than one circle, and that is the whole
//  trick: a single disc reads as a coloured zone painted on the ground - a rule
//  being displayed - where three offset blobs of different sizes, each turning at
//  its own speed, read as something with volume that happens to be there.
//
//  Density comes from the simulation rather than from an animation, so what you see
//  and what hurts you cannot drift apart: the cloud billows up as it spreads, sits
//  thick while it bites, and thins out as it expires, all off the one number in
//  GasCloud.density that GasSystem also gates its damage on.
//

import SpriteKit

final class GasRenderer {

    let node = SKNode()

    private final class CloudNodes {
        let root = SKNode()
        let blobs: [SKSpriteNode]

        init(blobs: [SKSpriteNode]) {
            self.blobs = blobs
        }
    }

    private var nodesByCloud: [GasCloudID: CloudNodes] = [:]

    func sync(with world: World) {
        for (id, cloud) in world.gasClouds where nodesByCloud[id] == nil {
            make(cloud)
        }

        for (id, nodes) in Array(nodesByCloud) where world.gasClouds[id] == nil {
            nodesByCloud[id] = nil

            // Thins away rather than blinking out. The simulation has already
            // stopped it hurting anybody by this point - the last second and a half
            // of a cloud's life is below the biting density - so this is the tail
            // of something that has already stopped mattering.
            nodes.root.run(.sequence([
                .group([
                    .fadeOut(withDuration: 0.5),
                    .scale(to: 1.25, duration: 0.5)
                ]),
                .removeFromParent()
            ]))
        }

        for (id, cloud) in world.gasClouds {
            guard let nodes = nodesByCloud[id] else { continue }
            nodes.root.alpha = CGFloat(cloud.density) * 0.72
            nodes.root.setScale(CGFloat(0.55 + cloud.density * 0.45))
        }
    }

    private func make(_ cloud: GasCloud) {
        let nodes = CloudNodes(blobs: [])
        let side = GridGeometry.length(ofTiles: cloud.radius * 2)

        nodes.root.position = GridGeometry.point(for: cloud.centre)

        // Above the ground and the loot, below the actors - so somebody standing in
        // gas is standing IN it rather than behind it.
        nodes.root.zPosition = 6
        nodes.root.alpha = 0
        node.addChild(nodes.root)

        let offsets: [(CGFloat, CGFloat, CGFloat)] = [
            (0, 0, 1.0),
            (-side * 0.16, side * 0.10, 0.78),
            (side * 0.15, -side * 0.09, 0.70)
        ]

        for (index, offset) in offsets.enumerated() {
            let blob = SKSpriteNode(texture: GlowArt.pool)
            blob.size = CGSize(width: side * offset.2, height: side * offset.2)
            blob.position = CGPoint(x: offset.0, y: offset.1)
            blob.color = RenderPalette.gas
            blob.colorBlendFactor = 1
            blob.alpha = 0.75
            nodes.root.addChild(blob)

            // Each turning at its own speed and in its own direction, which is what
            // stops three circles reading as one circle with a texture on it.
            let spin = 5.0 + Double(index) * 2.5
            let way: CGFloat = index % 2 == 0 ? 1 : -1

            blob.run(.repeatForever(
                .rotate(byAngle: way * .pi * 2, duration: spin)
            ))
        }

        nodesByCloud[cloud.id] = nodes
    }
}
