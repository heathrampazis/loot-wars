//
//  GasRenderer.swift
//  Loot Wars
//
//  Clouds of gas standing on the map.
//
//  Drawn as ONE closed shape, and that is the whole difference between this and
//  the first version. Translucent sprites laid over each other double up where
//  they overlap, so a cloud built from three of them is a pale wash with darker
//  patches in it - which reads as a gradient painted on the ground rather than as
//  an object. One silhouette means one flat fill at one alpha, one hard edge round
//  the outside, and no seams anywhere inside it.
//
//  The outline is a radius that rises and falls as it sweeps the circle, and the
//  waves that drive it MOVE - so the shape is rebuilt about a dozen times a second
//  and rolls slowly, bulging on one side and pulling in behind, without the cloud
//  drifting off the ground it is holding.
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
    /// Twelve rebuilds a second rather than sixty. Fourteen samples and a pair of
    /// sines is not free, and the eye cannot tell the difference on something
    /// moving this slowly - where it certainly can tell the difference between a
    /// shape that moves and one that does not.
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
        nodes.shape.fillColor = RenderPalette.gas.withAlphaComponent(0.93)
        nodes.shape.strokeColor = .clear
        nodes.shape.isAntialiased = true

        // Above the ground and the loot, below the actors - somebody standing in
        // gas is standing IN it rather than behind it.
        nodes.shape.zPosition = 6
        nodes.shape.alpha = 0

        node.addChild(nodes.shape)
        nodesByCloud[cloud.id] = nodes
    }

    /// The silhouette: one closed curve whose radius wobbles as it goes round.
    ///
    /// Sampled in polar coordinates rather than assembled out of circles, and the
    /// reason is the deployment target - CGPath.union arrived in iOS 16 and this
    /// ships to 15.6. It turned out to be the better drawing anyway. A union of
    /// discs has circular arcs everywhere you look, which reads as bubbles stuck
    /// together; a radius that rises and falls as it sweeps gives lobes that are
    /// wider at the base and pinched between, which is what gas actually looks like.
    ///
    /// Two waves of different frequencies, moving at different speeds. One would
    /// give a shape with obvious symmetry that visibly repeats; two that do not
    /// divide into each other never come back to the same silhouette.
    ///
    /// Smoothed by curving THROUGH the midpoints of the samples and using each
    /// sample as a control point. Joining the samples directly would show every
    /// corner, and at fourteen samples a polygon is exactly what it would look
    /// like.
    private static func outline(of cloud: GasCloud, phase: Double) -> CGPath {
        let radius = Double(GridGeometry.length(ofTiles: cloud.radius))
        let samples = 14

        var points: [CGPoint] = []
        points.reserveCapacity(samples)

        for index in 0..<samples {
            let angle = 2 * Double.pi * Double(index) / Double(samples)

            let wobble = 0.84
                + 0.13 * sin(angle * 3 + phase * 1.15)
                + 0.09 * sin(angle * 5 - phase * 0.73)

            points.append(
                CGPoint(x: cos(angle) * radius * wobble,
                        y: sin(angle) * radius * wobble)
            )
        }

        func midpoint(_ a: CGPoint, _ b: CGPoint) -> CGPoint {
            CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
        }

        let path = CGMutablePath()
        path.move(to: midpoint(points[samples - 1], points[0]))

        for index in 0..<samples {
            let current = points[index]
            let next = points[(index + 1) % samples]
            path.addQuadCurve(to: midpoint(current, next), control: current)
        }

        path.closeSubpath()
        return path
    }
}
