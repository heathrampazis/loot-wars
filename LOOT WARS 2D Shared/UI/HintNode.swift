//
//  HintNode.swift
//  Loot Wars
//
//  A line of text that teaches one gesture and then goes away for good.
//
//  Holding a hotbar slot sells the item, and holding a wall takes it down. Both are
//  good gestures and neither is discoverable: nothing on the screen suggests that
//  pressing something for half a second means anything different from tapping it,
//  so a player either finds it by accident or never finds it at all.
//
//  The rules this follows are the ones that stop a tutorial becoming nagging:
//
//   1. It appears at the ONE moment the gesture solves a problem the player can
//      see for themselves: they have walked over something and not picked it up.
//      Not at the start of a match, not every time a slot is picked out, and not
//      merely because the bag happens to be full - a full bag is only a problem
//      once it costs you something.
//   2. It goes away by itself, and it goes away IMMEDIATELY if anybody is near
//      enough to fight - a lesson during a firefight is worse than no lesson.
//   3. It stops for good the moment the player performs the gesture, and it gets
//      two showings a match either way. A budget is simpler than tracking whether
//      a given showing was actually read, and being interrupted by a fight is
//      itself rare enough that spending one of the two on it is survivable.
//
//  WHERE it sits took three goes and the reasoning is worth keeping.
//
//  Above the hotbar was wrong: that is where a thumb is, so the hint arrived under
//  the hand it was talking about. Over the player's own head was worse - it looked
//  janky, and the reason is that the player is the one thing on screen that never
//  holds still. A message pinned to a moving figure inherits the walk cycle, the
//  camera follow and every collision with a health bar, a token and whatever is
//  standing behind them.
//
//  A message is a message. It goes on the glass, it does not move, and it sits in
//  the strip directly under the health panel - the one band of screen nothing else
//  uses while a match is running. Centred, so it reads as an announcement rather
//  than as a label belonging to whatever it happens to be next to.
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


    override init() {
        super.init()
        isHidden = true

        label.fontSize = 12
        label.fontColor = SKColor(white: 1, alpha: 0.92)
        label.verticalAlignmentMode = .center
        addChild(label)

        // Enough plate to be read over grass, not so much that it reads as a
        // permanent part of the furniture: this is the only thing on the screen
        // that is here to be dismissed.
        plate.fillColor = RenderPalette.hudPanel
        plate.strokeColor = .clear
        plate.zPosition = -1
        addChild(plate)

        zPosition = 1050
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Up for a second and a half by default, which is twice as long as it takes
    /// to read five words and no longer. A hint that outstays that is not being
    /// more helpful, it is being furniture.
    func show(_ text: String, seconds: TimeInterval = 1.5) {
        guard showing != text || isHidden else { return }
        showing = text

        // Here rather than at the four places that call this, because a hint
        // arriving makes the noise - that is a fact about the hint, not something
        // each caller has to remember. The guard above is what makes it safe: the
        // same line re-asked while it is already up does not re-announce itself,
        // which matters for the build reminder that fires every time you walk into
        // your own base.
        SoundPlayer.shared.play(.notification)

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
            .group([.fadeIn(withDuration: 0.12), .scale(to: 1, duration: 0.12)]),
            .wait(forDuration: seconds),
            .fadeOut(withDuration: 0.22),
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
