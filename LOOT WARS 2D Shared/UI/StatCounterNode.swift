//
//  StatCounterNode.swift
//  Loot Wars
//
//  An icon and a number, for the things you count rather than the things that run
//  down. Same icon size and spacing as StatBarNode, so a counter row lines up with
//  the bars above it.
//

import SpriteKit

final class StatCounterNode: SKNode {

    static let height: CGFloat = StatBarNode.iconSize

    private let label = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private var lastValue = Int.min

    /// Local origin is the left edge of the icon, vertically centred on the row.
    init(iconNamed iconName: String) {
        super.init()

        let texture = SKTexture(imageNamed: iconName)
        let art = texture.size()

        // Sized by height, not width. The icons are not all the same shape, and a
        // fixed width would make a wide one tower over a narrow one.
        let height = StatBarNode.iconSize * 0.8
        let width = art.height > 0 ? height * (art.width / art.height) : height

        let icon = SKSpriteNode(texture: texture, size: CGSize(width: width, height: height))
        icon.position = CGPoint(x: StatBarNode.iconSize / 2, y: 0)
        addChild(icon)

        label.fontSize = 20
        label.fontColor = .white
        label.horizontalAlignmentMode = .left
        label.verticalAlignmentMode = .center
        label.position = CGPoint(x: StatBarNode.iconSize + StatBarNode.gap, y: 0)
        addChild(label)

        setValue(0)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setValue(_ value: Int) {
        // Runs every frame; setting a label's text rebuilds its glyphs.
        guard value != lastValue else { return }
        lastValue = value
        label.text = "\(value)"
    }
}
