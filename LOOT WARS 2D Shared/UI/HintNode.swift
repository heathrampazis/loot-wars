//
//  HintNode.swift
//  Loot Wars
//
//  A line of text that teaches one gesture and then goes away for good.
//
//  Holding a hotbar slot drops the item, and holding a wall takes it down. Both are
//  good gestures and neither is discoverable: nothing on the screen suggests that
//  pressing something for half a second means anything different from tapping it,
//  so a player either finds it by accident or never finds it at all.
//
//  The rules this follows are the ones that stop a tutorial becoming nagging:
//
//   1. It appears at a moment the gesture is RELEVANT - a slot picked out, a bag
//      with no room in it - not at the start of a match with everything else.
//   2. It goes away by itself.
//   3. It stops for good the moment the player performs the gesture. Somebody who
//      has dropped something knows how to drop something.
//
//  Deliberately not a tutorial system. One line, no queue, no ordering, no state
//  that outlives the match - if a second hint is ever wanted it can have its own
//  instance and the same three rules.
//

import SpriteKit

final class HintNode: SKNode {

    private static let height: CGFloat = 30
    private static let padding: CGFloat = 14

    private let plate = SKShapeNode()
    private let label = SKLabelNode(fontNamed: "AvenirNext-Bold")

    /// What it is currently saying, so re-offering the same hint while it is still
    /// up leaves it alone rather than restarting the animation under the player.
    private var showing: String?

    override init() {
        super.init()
        zPosition = 1050
        isHidden = true

        label.fontSize = 13
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        addChild(label)

        plate.fillColor = RenderPalette.hudPanel
        plate.strokeColor = SKColor(white: 1, alpha: 0.25)
        plate.lineWidth = 1.5
        plate.zPosition = -1
        addChild(plate)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show(_ text: String, seconds: TimeInterval = 3) {
        guard showing != text || isHidden else { return }
        showing = text

        label.text = text

        // The plate is cut to the words rather than to a guessed width, so a longer
        // hint later does not need a second number kept in step with the first.
        let width = label.frame.width + HintNode.padding * 2
        plate.path = CGPath(roundedRect: CGRect(x: -width / 2,
                                                y: -HintNode.height / 2,
                                                width: width,
                                                height: HintNode.height),
                            cornerWidth: HintNode.height / 2,
                            cornerHeight: HintNode.height / 2,
                            transform: nil)

        removeAction(forKey: "hint")
        isHidden = false
        alpha = 0
        setScale(0.92)

        // A nudge downwards on the way in, towards the thing it is talking about.
        run(.sequence([
            .group([.fadeIn(withDuration: 0.16), .scale(to: 1, duration: 0.16)]),
            .wait(forDuration: seconds),
            .fadeOut(withDuration: 0.3),
            .hide(),
            .run { [weak self] in self?.showing = nil }
        ]), withKey: "hint")
    }

    func hide() {
        guard !isHidden else { return }
        showing = nil
        removeAction(forKey: "hint")
        run(.sequence([.fadeOut(withDuration: 0.18), .hide()]), withKey: "hint")
    }
}
