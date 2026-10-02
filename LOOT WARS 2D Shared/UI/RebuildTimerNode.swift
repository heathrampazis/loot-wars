//
//  RebuildTimerNode.swift
//  Loot Wars
//
//  How long until you can build again after a raid.
//
//  When somebody blows a hole in your base, walls are off for a few seconds - see
//  World.canBuild - so a raider can still get back out. Nothing on screen used to
//  say so: the markers simply went away, a tapped tile flashed red, and a hint
//  that hides itself during fights tried to explain. Which is exactly when you
//  are trying to patch the hole.
//
//  So this says it plainly, under the match panel, for as long as it lasts:
//  BUILD BLOCKED 8s, counting down. It appears the moment the wall
//  goes, which also tells you that you have just been raided. A tap on a tile
//  while it is up shakes it, so the refusal points at the reason. When the time
//  is up it says so, and goes.
//
//  It is a status rather than news, so it steps aside while a notice is showing
//  in the same place - see setSuppressed - and comes back when that has gone.
//

import SpriteKit

final class RebuildTimerNode: SKNode {

    static let height: CGFloat = 32

    private let holder = SKNode()
    private let panel = SKShapeNode()
    private let label = SKLabelNode(fontNamed: "AvenirNext-Bold")

    private var shownSeconds = -1
    private var suppressed = false

    /// Whether it has anything to say right now, shown or stepped aside.
    private(set) var isActive = false

    override init() {
        super.init()
        zPosition = 1100
        isHidden = true
        alpha = 0

        addChild(holder)

        panel.fillColor = RenderPalette.hudPanel
        panel.strokeColor = .clear
        holder.addChild(panel)

        label.fontSize = 14
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        label.zPosition = 1
        holder.addChild(label)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Every frame: the seconds left on the lock for the player's own team, or
    /// zero when there is none.
    func update(remaining: Double) {
        guard remaining > 0 else {
            if shownSeconds > 0 { finish() }
            shownSeconds = 0
            return
        }

        let seconds = Int(remaining.rounded(.up))
        guard seconds != shownSeconds else { return }
        let arriving = shownSeconds <= 0
        shownSeconds = seconds

        setText("BUILD BLOCKED \(seconds)s")

        if arriving {
            isActive = true
            removeAllActions()
            isHidden = false
            alpha = 0
            setScale(0.7)
            run(.group([.fadeIn(withDuration: 0.12),
                        .sequence([.scale(to: 1.08, duration: 0.12),
                                   .scale(to: 1, duration: 0.1)])]))
        }
    }

    /// Steps aside while another notice holds the same spot, and comes back after.
    func setSuppressed(_ on: Bool) {
        guard on != suppressed else { return }
        suppressed = on
        holder.removeAllActions()
        holder.run(.fadeAlpha(to: on ? 0 : 1, duration: on ? 0.1 : 0.18))
    }

    /// A tap that was refused because of the lock: a shake, so the refusal
    /// points at this.
    func nudge() {
        guard shownSeconds > 0, !suppressed, action(forKey: "nudge") == nil else { return }
        run(.sequence([
            .group([.scale(to: 1.1, duration: 0.06), .rotate(toAngle: -0.06, duration: 0.06)]),
            .rotate(toAngle: 0.06, duration: 0.09),
            .group([.scale(to: 1, duration: 0.08), .rotate(toAngle: 0, duration: 0.08)])
        ]), withKey: "nudge")
    }

    /// Put away at once, for the end of the match.
    func dismiss() {
        removeAllActions()
        isHidden = true
        alpha = 0
        shownSeconds = -1
        isActive = false
    }

    /// The lock is over: says so briefly, then goes.
    private func finish() {
        setText("BUILD READY")
        removeAllActions()
        zRotation = 0
        run(.sequence([
            .scale(to: 1.1, duration: 0.08),
            .scale(to: 1, duration: 0.12),
            .wait(forDuration: 1.0),
            .fadeOut(withDuration: 0.25),
            .run { [weak self] in
                self?.isHidden = true
                self?.isActive = false
            }
        ]))
    }

    /// The panel fitted round the words. The number changes width as it counts,
    /// so this is redone each change.
    private func setText(_ text: String) {
        label.text = text

        let width = label.frame.width + 28
        let height = RebuildTimerNode.height

        panel.path = CGPath(roundedRect: CGRect(x: -width / 2, y: -height / 2,
                                                width: width, height: height),
                            cornerWidth: height / 2, cornerHeight: height / 2, transform: nil)
    }
}
