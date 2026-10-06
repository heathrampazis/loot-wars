//
//  MenuToggleNode.swift
//  Loot Wars
//
//  An on/off switch for the settings sheet.
//
//  Built like the menu buttons: flat colour edged in a darker shade of itself,
//  never a black outline. On is the play button's green, so "on" on this screen
//  is the same colour as "go"; off is a quiet grey. The knob slides, which is
//  the whole of what makes it read as a switch rather than a coloured pill.
//
//  It does not handle touches itself - the settings content decides that a tap
//  anywhere on the row flips it, which is a far bigger target than the switch.
//

import SpriteKit

final class MenuToggleNode: SKNode {

    static let trackSize = CGSize(width: 52, height: 30)

    private(set) var isOn: Bool

    private let track = SKShapeNode()
    private let knob = SKShapeNode(circleOfRadius: 11)

    init(isOn: Bool) {
        self.isOn = isOn
        super.init()

        let size = MenuToggleNode.trackSize
        track.path = CGPath(roundedRect: CGRect(x: -size.width / 2, y: -size.height / 2,
                                                width: size.width, height: size.height),
                            cornerWidth: size.height / 2, cornerHeight: size.height / 2,
                            transform: nil)
        track.lineWidth = 2.5
        addChild(track)

        knob.fillColor = .white
        knob.strokeColor = SKColor(white: 0, alpha: 0.12)
        knob.lineWidth = 1.5
        knob.zPosition = 1
        addChild(knob)

        paint()
        knob.position = CGPoint(x: knobX, y: 0)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func set(_ on: Bool, animated: Bool = true) {
        guard on != isOn else { return }
        isOn = on
        paint()

        knob.removeAllActions()
        guard animated else {
            knob.position.x = knobX
            return
        }

        let slide = SKAction.moveTo(x: knobX, duration: 0.14)
        slide.timingMode = .easeOut
        knob.run(.group([
            slide,
            .sequence([.scaleX(to: 1.2, y: 0.9, duration: 0.07),
                       .scale(to: 1, duration: 0.07)])
        ]))
    }

    private var knobX: CGFloat {
        let travel = MenuToggleNode.trackSize.width / 2 - 15
        return isOn ? travel : -travel
    }

    private func paint() {
        if isOn {
            track.fillColor = RenderPalette.menuPlay.face
            track.strokeColor = RenderPalette.menuPlay.edge
        } else {
            track.fillColor = SKColor(white: 0.84, alpha: 1)
            track.strokeColor = SKColor(white: 0.72, alpha: 1)
        }
    }
}
