//
//  FlagRenderer.swift
//  Loot Wars
//
//  The flag in the middle of every base (Nov 2026) - see GameConfig.Flag.
//
//  A grey pole with a team-coloured pennant, in the game's flat colours and
//  even black outline. While an enemy is taking it, a ring round its foot
//  fills red. Taken, it falls and fades.
//

import SpriteKit

final class FlagRenderer {

    let node = SKNode()

    private struct Nodes {
        let root: SKNode
        let pennant: SKShapeNode
        let ring: SKShapeNode
        let fill: SKShapeNode
    }

    private var nodes: [TeamID: Nodes] = [:]
    private var drawnProgress: [TeamID: Double] = [:]

    private static let outline: CGFloat = 2.5

    func sync(with world: World) {
        // Only flags that have gone up (Nov 2026) - see FlagState.placed. One
        // raised mid-match pops in.
        for (team, flag) in world.flags where nodes[team] == nil && flag.placed {
            guard let spot = world.flagPosition(of: team) else { continue }
            make(team, at: spot)
            if world.elapsed > 0.5, let root = nodes[team]?.root {
                root.setScale(0)
                root.run(.sequence([.scale(to: 1.2, duration: 0.16), .scale(to: 1, duration: 0.1)]))
            }
        }

        for (team, drawn) in nodes {
            guard let flag = world.flags[team] else { continue }

            if !flag.standing {
                if drawn.root.action(forKey: "fall") == nil, drawn.root.alpha > 0 {
                    drawn.ring.isHidden = true
                    drawn.root.run(.group([
                        .rotate(toAngle: -.pi / 2, duration: 0.35),
                        .sequence([.wait(forDuration: 0.6), .fadeOut(withDuration: 0.5)])
                    ]), withKey: "fall")
                }
                continue
            }

            // The capture ring, redrawn only when it moves. None when capture
            // is instant (captureTime 0).
            guard GameConfig.Flag.captureTime > 0 else { continue }
            let share = min(1, flag.progress / GameConfig.Flag.captureTime)
            guard abs(share - (drawnProgress[team] ?? -1)) > 0.01 else { continue }
            drawnProgress[team] = share
            drawn.ring.isHidden = share <= 0
            let r = CGFloat(GameConfig.Flag.captureRadius) * GridGeometry.tileSize * 0.55
            let path = CGMutablePath()
            path.addArc(center: .zero, radius: r, startAngle: .pi / 2,
                        endAngle: .pi / 2 - CGFloat(share) * 2 * .pi, clockwise: true)
            drawn.fill.path = path
            // In the colour of whoever is taking it - their base colour.
            if let taker = flag.capturer {
                drawn.fill.strokeColor = RenderPalette.colour(for: taker)
            }
        }
    }

    private func make(_ team: TeamID, at spot: Vec2) {
        let t = GridGeometry.tileSize
        let root = SKNode()
        // Foot of the pole a little under the tile's middle, so it stands on it.
        root.position = GridGeometry.point(for: Vec2(x: spot.x, y: spot.y - 0.3))
        // Under the actors, so whoever is standing by it is drawn over it.
        root.zPosition = 9.5

        let ring = SKShapeNode(circleOfRadius: CGFloat(GameConfig.Flag.captureRadius) * t * 0.55)
        ring.strokeColor = SKColor(white: 1, alpha: 0.35)
        ring.lineWidth = 3
        ring.fillColor = .clear
        ring.isHidden = true
        root.addChild(ring)

        let fill = SKShapeNode()
        fill.strokeColor = RenderPalette.healthBar
        fill.lineWidth = 4
        fill.lineCap = .round
        ring.addChild(fill)

        // The original flag, a fifth smaller (Nov 2026: the plain version was
        // tried and dropped). A base, a pole and a notched pennant in the team's
        // colour, each with the game's even black outline, waving gently.
        let k: CGFloat = 0.8
        let base = SKShapeNode(ellipseOf: CGSize(width: t * 0.5 * k, height: t * 0.2 * k))
        base.fillColor = SKColor(white: 0.35, alpha: 1)
        base.strokeColor = .black
        base.lineWidth = FlagRenderer.outline
        root.addChild(base)

        let poleHeight = t * 1.5 * k
        let pole = SKShapeNode(rect: CGRect(x: -t * 0.05 * k, y: 0,
                                            width: t * 0.1 * k, height: poleHeight),
                               cornerRadius: t * 0.04 * k)
        pole.fillColor = SKColor(white: 0.62, alpha: 1)
        pole.strokeColor = .black
        pole.lineWidth = FlagRenderer.outline
        root.addChild(pole)

        let x0 = t * 0.05 * k, w = t * 0.85 * k, h = t * 0.55 * k, top = poleHeight - 2
        let shape = CGMutablePath()
        shape.move(to: CGPoint(x: x0, y: top))
        shape.addLine(to: CGPoint(x: x0 + w, y: top - h * 0.15))
        shape.addLine(to: CGPoint(x: x0 + w * 0.82, y: top - h * 0.5))
        shape.addLine(to: CGPoint(x: x0 + w, y: top - h * 0.85))
        shape.addLine(to: CGPoint(x: x0, y: top - h))
        shape.closeSubpath()
        let pennant = SKShapeNode(path: shape)
        pennant.fillColor = RenderPalette.vibrantColour(for: team)
        pennant.strokeColor = .black
        pennant.lineWidth = FlagRenderer.outline
        pennant.lineJoin = .round
        root.addChild(pennant)

        // A gentle wave, so it reads as a flag and not a sign.
        let wave = SKAction.sequence([.scaleX(to: 0.88, duration: 0.7),
                                      .scaleX(to: 1, duration: 0.7)])
        wave.timingMode = .easeInEaseOut
        pennant.run(.repeatForever(wave))

        node.addChild(root)
        nodes[team] = Nodes(root: root, pennant: pennant, ring: ring, fill: fill)
    }
}
