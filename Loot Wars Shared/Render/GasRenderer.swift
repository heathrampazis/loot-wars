//
//  GasRenderer.swift
//  Loot Wars
//
//  Clouds of gas standing on the map.
//
//  Drawn as two closed shapes: a body, and a smaller one drifting inside it.
//
//  The first version was three translucent sprites with soft edges, which double
//  up where they overlap - a pale wash with darker lens-shaped patches wherever
//  two happened to cross, reading as a gradient painted on the ground rather than
//  as an object. The second was one flat silhouette, which fixed the patchiness by
//  removing every trace of depth, and at the opacity it needed it hid the map.
//
//  Two concentric shapes, both thin, is the answer to both: 0.42 at the edge and
//  about 0.6 through the middle, so the ground reads through it everywhere and it
//  is still visibly thicker in the centre. The overlap is deliberate and always in
//  the same place, which is what separates this from the accident the first
//  version was making.
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
        /// The body of the cloud, and a smaller one drifting inside it.
        ///
        /// Two rather than one, and both thin. A single fill at any alpha is a
        /// sheet of colour - see-through or not, it has no depth to it - where two
        /// gives a cloud that is denser through the middle than at its edges, which
        /// is the thing that actually reads as gas.
        ///
        /// This is not the mistake the first version made. That was three equal
        /// blobs of soft gradient overlapping at random, which produced darker
        /// lens-shaped patches wherever two happened to cross. These are
        /// concentric and deliberate: thin at the edge, thicker in the middle,
        /// every time.
        let shape = SKShapeNode()
        let core = SKShapeNode()

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

                nodes.shape.path = GasRenderer.outline(
                    of: cloud, phase: nodes.phase, scale: 1
                )

                // The inner one runs on a different phase, so it drifts about
                // inside the body rather than sitting in it like a target.
                nodes.core.path = GasRenderer.outline(
                    of: cloud, phase: nodes.phase * 1.35 + 2.2, scale: 0.62
                )
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

        nodes.shape.path = GasRenderer.outline(of: cloud, phase: nodes.phase, scale: 1)
        nodes.shape.position = GridGeometry.point(for: cloud.centre)

        // Opaque fill at a fixed alpha rather than a soft edge: you can see the
        // ground through it, but the boundary is a line rather than a fade, which
        // is what makes "in it" and "out of it" a thing you can judge at a glance
        // while somebody is shooting at you.
        // Thin enough to see the ground through, which is what makes it gas rather
        // than paint: 0.42 at the edges and about 0.6 through the middle where the
        // core lies over it. Solid was the last version's mistake in the other
        // direction - it hid the map, and a hazard you cannot see the floor through
        // stops being a place and becomes an obstacle.
        nodes.shape.fillColor = RenderPalette.gas.withAlphaComponent(0.42)
        nodes.shape.strokeColor = .clear
        nodes.shape.isAntialiased = true

        nodes.core.path = GasRenderer.outline(of: cloud, phase: nodes.phase, scale: 0.62)
        nodes.core.fillColor = RenderPalette.gas.withAlphaComponent(0.30)
        nodes.core.strokeColor = .clear
        nodes.core.isAntialiased = true
        nodes.core.zPosition = 1
        nodes.shape.addChild(nodes.core)

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
    private static func outline(of cloud: GasCloud,
                                phase: Double,
                                scale: Double) -> CGPath {
        let radius = Double(GridGeometry.length(ofTiles: cloud.radius)) * scale
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
