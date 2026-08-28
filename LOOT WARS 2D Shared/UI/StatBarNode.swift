//
//  StatBarNode.swift
//  Loot Wars
//
//  An icon and a bar. Knows nothing about health or ammo - it is handed a fraction
//  between 0 and 1 and draws it, which is why the same node serves both rows.
//

import SpriteKit

final class StatBarNode: SKNode {

    static let iconSize: CGFloat = 30
    static let barWidth: CGFloat = 150
    static let barHeight: CGFloat = 20
    static let gap: CGFloat = 10

    /// Total width of icon plus bar, so the panel can size itself around it.
    static var totalWidth: CGFloat { iconSize + gap + barWidth }

    private let fill = SKShapeNode()
    private var lastFraction: Double = -1

    /// Local origin is the left edge of the icon, vertically centred on the row.
    init(iconNamed iconName: String, fillColour: SKColor) {
        super.init()

        let icon = SKSpriteNode(texture: SKTexture(imageNamed: iconName))
        icon.size = CGSize(width: StatBarNode.iconSize, height: StatBarNode.iconSize)
        icon.position = CGPoint(x: StatBarNode.iconSize / 2, y: 0)
        addChild(icon)

        let track = SKShapeNode(path: StatBarNode.barPath(width: StatBarNode.barWidth))
        track.fillColor = RenderPalette.hudTrack
        track.strokeColor = .clear
        addChild(track)

        fill.fillColor = fillColour
        fill.strokeColor = .clear
        addChild(fill)

        setFraction(1)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setFraction(_ value: Double) {
        let clamped = min(max(value, 0), 1)
        // Rebuilding a path is cheap but not free, and this runs every frame.
        guard abs(clamped - lastFraction) > 0.002 else { return }
        lastFraction = clamped

        fill.isHidden = clamped <= 0.001
        guard !fill.isHidden else { return }

        // Never narrower than it is tall, or the rounded ends collapse into a sliver.
        let width = max(StatBarNode.barHeight, StatBarNode.barWidth * CGFloat(clamped))
        fill.path = StatBarNode.barPath(width: width)
    }

    private static func barPath(width: CGFloat) -> CGPath {
        let rect = CGRect(x: iconSize + gap,
                          y: -barHeight / 2,
                          width: width,
                          height: barHeight)
        return CGPath(roundedRect: rect,
                      cornerWidth: barHeight / 2,
                      cornerHeight: barHeight / 2,
                      transform: nil)
    }
}
