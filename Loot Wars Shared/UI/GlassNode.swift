//
//  GlassNode.swift
//  Loot Wars
//
//  A patch of frosted glass, cut to a control's shape, behind its plate.
//
//  The control keeps its own see-through tint on top, so with the glass under it
//  the map behind reads blurred rather than sharp - the control looks solid, and
//  what it says is easier to read over a busy screen. See GlassBackdrop for
//  where the blur comes from; this only shows its own piece of it.
//
//  Shows nothing until it is handed a blur. Anywhere that never hands it one -
//  the How to Play pages, the title screen - the control looks as it always did.
//

import SpriteKit

final class GlassNode: SKCropNode {

    /// Every glass alive, so the scene can fill them all in one pass without each
    /// control having to be told.
    private static let all = NSHashTable<GlassNode>.weakObjects()

    private let pane = SKSpriteNode()
    private let area: CGRect

    /// - Parameter path: the control's shape, in the space this node is added to.
    init(path: CGPath) {
        area = path.boundingBoxOfPath
        super.init()

        let mask = SKShapeNode(path: path)
        mask.fillColor = .white
        mask.strokeColor = .clear
        maskNode = mask

        pane.size = area.size
        pane.position = CGPoint(x: area.midX, y: area.midY)
        pane.isHidden = true
        addChild(pane)

        // Under whatever it is added to, which is the plate it sits behind.
        zPosition = -1
        GlassNode.all.add(self)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Fills every glass in this camera's view with its own patch of the blur.
    ///
    /// Measured where each one actually is on screen this frame, so a control
    /// that moves or scales - a pressed button, a stick that follows the thumb -
    /// still shows the map that is really behind it.
    static func fillAll(from texture: SKTexture, under camera: SKCameraNode, screen: CGSize) {
        guard screen.width > 0, screen.height > 0 else { return }
        for glass in all.allObjects where glass.scene === camera.scene {
            glass.fill(from: texture, under: camera, screen: screen)
        }
    }

    private func fill(from texture: SKTexture, under camera: SKCameraNode, screen: CGSize) {
        let low = camera.convert(CGPoint(x: area.minX, y: area.minY), from: self)
        let high = camera.convert(CGPoint(x: area.maxX, y: area.maxY), from: self)

        func clamp(_ value: CGFloat) -> CGFloat { min(1, max(0, value)) }
        let left = clamp((min(low.x, high.x) + screen.width / 2) / screen.width)
        let right = clamp((max(low.x, high.x) + screen.width / 2) / screen.width)
        let bottom = clamp((min(low.y, high.y) + screen.height / 2) / screen.height)
        let top = clamp((max(low.y, high.y) + screen.height / 2) / screen.height)
        guard right > left, top > bottom else {
            pane.isHidden = true
            return
        }

        pane.texture = SKTexture(rect: CGRect(x: left, y: bottom,
                                              width: right - left, height: top - bottom),
                                 in: texture)
        pane.isHidden = false
    }
}
