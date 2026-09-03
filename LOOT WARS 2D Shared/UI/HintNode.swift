//
//  HintNode.swift
//  Loot Wars
//
//  A line of text that floats over the player, teaches one gesture, and then goes
//  away for good.
//
//  Holding a hotbar slot drops the item, and holding a wall takes it down. Both are
//  good gestures and neither is discoverable: nothing on the screen suggests that
//  pressing something for half a second means anything different from tapping it,
//  so a player either finds it by accident or never finds it at all.
//
//  The rules this follows are the ones that stop a tutorial becoming nagging:
//
//   1. It appears at the ONE moment the gesture solves a problem the player
//      actually has: a bag with no room left in it. Not at the start of a match,
//      not every time a slot is picked out.
//   2. It goes away by itself, and it goes away IMMEDIATELY if anybody is near
//      enough to fight - a lesson during a firefight is worse than no lesson.
//   3. It stops for good the moment the player performs the gesture, and it only
//      ever offers itself once a match either way.
//
//  It rides over the player rather than sitting on the glass with the HUD. A hint
//  about the thing you are carrying belongs on the person carrying it, where the
//  eye already is, rather than in a corner competing with the score.
//
//  Deliberately not a tutorial system. One line, no queue, no ordering, no state
//  that outlives the match - if a second hint is ever wanted it can have its own
//  instance and the same three rules.
//

import SpriteKit

final class HintNode: SKNode {

    private static let height: CGFloat = 26
    private static let padding: CGFloat = 12

    private let plate = SKShapeNode()
    private let label = SKLabelNode(fontNamed: "AvenirNext-Bold")

    /// What it is currently saying, so re-offering the same hint while it is still
    /// up leaves it alone rather than restarting the animation under the player.
    private var showing: String?

    /// Up right now.
    var isShowing: Bool { showing != nil }

    /// Ran its full course rather than being cut short.
    ///
    /// The distinction is the whole reason a hint gets only one turn: a lesson that
    /// was yanked off screen after a fifth of a second because somebody rounded the
    /// corner was never READ, and retiring it on the strength of having technically
    /// been shown would be the most annoying possible outcome - the one time it
    /// appears is the one time nobody sees it.
    private(set) var completed = false

    override init() {
        super.init()
        isHidden = true

        label.fontSize = 12
        label.fontColor = SKColor(white: 1, alpha: 0.92)
        label.verticalAlignmentMode = .center
        addChild(label)

        // Barely there. It is standing on top of the game rather than beside it,
        // so it has to be readable against grass without becoming a sign nailed to
        // the player's head - just enough shade under the words to hold them.
        plate.fillColor = SKColor(white: 0, alpha: 0.38)
        plate.strokeColor = .clear
        plate.zPosition = -1
        addChild(plate)

        // Above the actors it floats over, below anything on the glass.
        zPosition = 20
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
            .run { [weak self] in
                self?.showing = nil
                self?.completed = true
            }
        ]), withKey: "hint")
    }

    func hide() {
        guard !isHidden else { return }
        showing = nil
        removeAction(forKey: "hint")
        run(.sequence([.fadeOut(withDuration: 0.18), .hide()]), withKey: "hint")
    }
}
