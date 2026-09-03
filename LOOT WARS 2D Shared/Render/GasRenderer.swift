//
//  GasRenderer.swift
//  Loot Wars
//
//  Clouds of gas standing on the map.
//
//  Drawn as ONE shape whose outline is the union of several overlapping circles,
//  and that construction is the whole difference between this and the first
//  version. Translucent sprites laid over each other double up where they overlap,
//  so a cloud built from three of them is a pale wash with darker patches in it -
//  which reads as a gradient painted on the ground rather than as an object. A
//  union is a single silhouette: one flat fill at one alpha, one hard edge round
//  the outside, and no seams anywhere inside it.
//
//  The lobes then TURN, at their own speeds, and the path is rebuilt from them
//  about a dozen times a second. That is what makes it look alive rather than
//  stamped: the outline rolls slowly, bulges where a lobe swings out, and pulls in
//  behind it, all without the cloud moving off the ground it is holding.
//
//  Density comes from the simulation, so what you see and what hurts you cannot
//  drift apart - see GasCloud.density, which GasSystem gates its damage on.
//

import SpriteKit

final class GasRenderer {

    let node = SKNode()

    /// How many circles make up the silhouette, how often it is rebuilt, and how
    /// fast the lobes travel round.
    ///
    /// Twelve rebuilds a second rather than sixty: a union of six circles is not
    /// free, and the eye cannot tell the difference on something moving this
    /// slowly - where it certainly can tell the difference between a shape that
    /// moves and one that does not.
    private static let lobes = 6
    private static let rebuildInterval: Double = 0.08
    private static let churn: Double = 0.55

    private final class CloudNodes {
        let shape = SKShapeNode()
        var sinceRebuild: Double = 0
        var phase: Double

        init(phase: Double) {
            self.phase = phase
        }
    }

    private var nodesByCloud: [GasCloudID: CloudNodes] = [:]

    func sync(with world: World, dt: TimeInterval) {
        for (id, cloud) in world.gasClouds where nodesByCloud[id] == nil {
            make(cloud)
        }

        for (id, nodes) in Array(nodesByCloud) where world.gasClouds[id] == nil {
            nodesByCloud[id] = nil

            // Thins away rather than blinking out. It stopped hurting anybody a
            // second and a half ago - the tail of a cloud's life is below the
            // biting density - so this is the last of something that has already
            // stopped mattering.
            nodes.shape.run(.sequence([
                .group([
                    .fadeOut(withDuration: 0.5),
                    .scale(to: 1.3, duration: 0.5)
                ]),
                .removeFromParent()
            ]))
        }

        for id in world.gasClouds.keys.sorted(by: { $0.raw < $1.raw }) {
            guard let cloud = world.gasClouds[id], let nodes = nodesByCloud[id] else { continue }

            nodes.phase += dt * GasRenderer.churn
            nodes.sinceRebuild += dt

            if nodes.sinceRebuild >= GasRenderer.rebuildInterval {
                nodes.sinceRebuild = 0
                nodes.shape.path = GasRenderer.outline(of: cloud, phase: nodes.phase)
            }

            // Billows out as it spreads and thins as it goes, both off the one
            // number the damage is gated on.
            nodes.shape.alpha = CGFloat(cloud.density)
            nodes.shape.setScale(CGFloat(0.62 + cloud.density * 0.38))
        }
    }

    private func make(_ cloud: GasCloud) {
        // Seeded off the cloud's own id, so two clouds on screen are not the same
        // drawing twice - and so a given cloud looks the same on every run of a
        // seed, which a random start would quietly break.
        let nodes = CloudNodes(phase: Double(cloud.id.raw) * 1.7)

        nodes.shape.path = GasRenderer.outline(of: cloud, phase: nodes.phase)
        nodes.shape.position = GridGeometry.point(for: cloud.centre)

        // Opaque fill at a fixed alpha rather than a soft edge: you can see the
        // ground through it, but the boundary is a line rather than a fade, which
        // is what makes "in it" and "out of it" a thing you can judge at a glance
        // while somebody is shooting at you.
        nodes.shape.fillColor = RenderPalette.gas.withAlphaComponent(0.72)
        nodes.shape.strokeColor = RenderPalette.gasEdge
        nodes.shape.lineWidth = 3
        nodes.shape.isAntialiased = true

        // Above the ground and the loot, below the actors - somebody standing in
        // gas is standing IN it rather than behind it.
        nodes.shape.zPosition = 6
        nodes.shape.alpha = 0

        node.addChild(nodes.shape)
        nodesByCloud[cloud.id] = nodes
    }

    /// The silhouette: a body circle with lobes riding round its edge, unioned into
    /// one path so nothing overlaps anything.
    private static func outline(of cloud: GasCloud, phase: Double) -> CGPath {
        let radius = GridGeometry.length(ofTiles: cloud.radius)

        var path = CGPath(
            ellipseIn: CGRect(x: -radius * 0.62, y: -radius * 0.62,
                              width: radius * 1.24, height: radius * 1.24),
            transform: nil
        )

        for index in 0..<lobes {
            let spacing = 2 * Double.pi / Double(lobes)

            // Each lobe travels at a slightly different speed, so the outline never
            // repeats a shape it has already been - six circles turning in lockstep
            // would just be one circle wobbling.
            let angle = Double(index) * spacing + phase * (0.7 + Double(index % 3) * 0.22)

            let reach = radius * CGFloat(0.52 + 0.06 * sin(phase * 1.4 + Double(index)))
            let lobe = radius * CGFloat(0.46 + 0.08 * sin(phase * 1.9 + Double(index) * 2.1))

            let centre = CGPoint(x: CGFloat(cos(angle)) * reach,
                                 y: CGFloat(sin(angle)) * reach)

            path = path.union(
                CGPath(
                    ellipseIn: CGRect(x: centre.x - lobe, y: centre.y - lobe,
                                      width: lobe * 2, height: lobe * 2),
                    transform: nil
                )
            )
        }

        return path
    }
}
