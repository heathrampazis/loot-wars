//
//  StatBarNode.swift
//  Loot Wars
//
//  An icon and a bar. Knows nothing about health or ammo - it is handed a fraction
//  between 0 and 1 and draws it, which is why the same node serves both rows.
//
//  Both the track and the fill are outlined, so a part-full bar shows a black cap
//  where the colour stops. The outline weight is the same 0.11 tiles used on walls
//  and trees, which is what keeps the HUD looking like part of the same game.
//

import SpriteKit

final class StatBarNode: SKNode {

    /// Rescaled to bring the HUD down to the leaderboard's 192 x 84. The whole set
    /// moved together rather than only the bar, because shrinking one part of a row
    /// and not the rest is how a panel ends up looking assembled instead of drawn.
    static let iconSize: CGFloat = 24
    /// Outer dimensions, outline included.
    static let barWidth: CGFloat = 144
    static let barHeight: CGFloat = 18
    static let outline: CGFloat = 3.5
    static let gap: CGFloat = 8

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

        let track = SKShapeNode(path: StatBarNode.barPath(outerWidth: StatBarNode.barWidth))
        track.fillColor = RenderPalette.hudTrack
        track.strokeColor = .black
        track.lineWidth = StatBarNode.outline
        addChild(track)

        fill.fillColor = fillColour
        fill.strokeColor = .black
        fill.lineWidth = StatBarNode.outline
        fill.zPosition = 1
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
        fill.path = StatBarNode.barPath(outerWidth: width)
    }

    /// - Parameter outerWidth: width including the outline.
    private static func barPath(outerWidth: CGFloat) -> CGPath {
        // A stroke straddles its path, so inset by half of it - that puts the
        // outline's OUTER edge exactly on the dimensions asked for, rather than
        // letting every bar grow by half an outline in each direction.
        let height = barHeight - outline
        let rect = CGRect(x: iconSize + gap + outline / 2,
                          y: -height / 2,
                          width: outerWidth - outline,
                          height: height)

        return CGPath(roundedRect: rect,
                      cornerWidth: height / 2,
                      cornerHeight: height / 2,
                      transform: nil)
    }
}
