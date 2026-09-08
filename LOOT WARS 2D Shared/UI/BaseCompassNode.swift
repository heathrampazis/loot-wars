//
//  BaseCompassNode.swift
//  Loot Wars
//
//  A small arrow at the edge of the screen pointing at your own base.
//
//  A base is the one thing in this game you are always meant to be able to get
//  back to, and for most of a match it is somewhere off the side of a phone screen
//  that shows about nine tiles across and four up. There is no map, and there is
//  deliberately not going to be one - so the whole question "which way is home" was
//  answered by remembering, which is a thing to do while somebody is shooting at
//  you.
//
//  IT ONLY EXISTS WHEN IT IS NEEDED, and that single rule is what keeps it from
//  becoming clutter. If the base is on screen the arrow is not, because pointing at
//  something you are looking at is noise. So it appears when you wander off, sits
//  quietly at the edge, and disappears the moment home comes back into view.
//
//  Faint on purpose. It is a fact you glance at, not something to be read, and it
//  spends most of its time next to a health bar and a hotbar that both have a
//  better claim on your attention. In your team's own colour, because the claim
//  tint on the ground is the same colour and the two should obviously be the same
//  thing.
//
//  AND IT IS THE ALARM. Somebody standing in your claim turns it red and shakes
//  it, which is the one moment this has something urgent to say: your chests are
//  being broken open, right now, somewhere you cannot see. It stays hidden while
//  the base is on screen even then, because an alarm about something already in
//  front of you is worse than no alarm - you can see the person.
//
//  The shake lives on a CHILD of this node rather than on the node itself. The
//  position and rotation here are rewritten every frame from where the base is, so
//  an SKAction moving them would be overwritten before it drew once - the same
//  layering the actor sprites use, and the same reason.
//

import SpriteKit

final class BaseCompassNode: SKNode {

    /// How far inside the screen edge the arrow sits, in points.
    ///
    /// Deeper at the top and the bottom than at the sides, because those are the
    /// two edges that are already spoken for: the match timer and the leaderboard
    /// live along the top, the hotbar and the sticks along the bottom, and an arrow
    /// riding the true edge would sit underneath one of them at exactly the bearing
    /// it is most needed. The sides are nearly empty by comparison.
    private static let sideInset: CGFloat = 34
    private static let endInset: CGFloat = 78

    /// How far the base has to be from the edge of the screen before the arrow
    /// bothers, in tiles.
    ///
    /// A margin rather than zero, so an arrow does not flicker on and off while
    /// the base sits exactly on the boundary - which is precisely where somebody
    /// standing at the edge of their own claim is.
    private static let hysteresis: Double = 1.2

    private let arrow = SKShapeNode()
    private let body = SKNode()

    private var alarmed = false

    override init() {
        super.init()

        // A stubby chevron, drawn pointing along +x so the node's own rotation is
        // the bearing and nothing has to be offset by a right angle.
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 11, y: 0))
        path.addLine(to: CGPoint(x: -7, y: 8))
        path.addLine(to: CGPoint(x: -3.5, y: 0))
        path.addLine(to: CGPoint(x: -7, y: -8))
        path.closeSubpath()

        arrow.path = path
        arrow.lineWidth = 0
        arrow.zPosition = 1

        body.addChild(arrow)
        addChild(body)

        alpha = 0
        isHidden = true

        // With the rest of the screen furniture at 1000, and below the panels at
        // 1100 and up - it sits at the edge and they sit in the middle, so they
        // will rarely meet, but when they do the panel is the thing being read.
        zPosition = 1000
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// - Parameter screen: the size of the visible area, in points.
    func update(with world: World, screen: CGSize) {
        guard let player = world.localPlayer, player.isAlive, !world.isOver,
              let claim = world.claim(for: player.team) else {
            retire()
            return
        }

        let home = claim.centreTile.center
        let towards = home - player.position
        guard towards.length > 0.01 else {
            retire()
            return
        }

        // On screen already: nothing to point at. Measured in tiles against what
        // the camera can actually show, which the scene keeps up to date.
        let half = world.visibleHalfExtent
        let onScreen = abs(towards.x) < half.x - BaseCompassNode.hysteresis
            && abs(towards.y) < half.y - BaseCompassNode.hysteresis

        guard !onScreen else {
            retire()
            return
        }

        show(intruder: world.intruderInBase(of: player.team), team: player.team)

        // Out along the bearing until it meets the inset edge of the screen. The
        // smaller of the two crossings is the one that happens first, which is what
        // puts the arrow on the side it should be on rather than off a corner.
        let direction = towards.normalized()
        let limitX = screen.width / 2 - BaseCompassNode.sideInset
        let limitY = screen.height / 2 - BaseCompassNode.endInset

        let toSide = abs(direction.x) > 0.001
            ? limitX / CGFloat(abs(direction.x)) : .greatestFiniteMagnitude
        let toTop = abs(direction.y) > 0.001
            ? limitY / CGFloat(abs(direction.y)) : .greatestFiniteMagnitude
        let reach = min(toSide, toTop)

        position = CGPoint(x: CGFloat(direction.x) * reach,
                           y: CGFloat(direction.y) * reach)
        zRotation = CGFloat(atan2(direction.y, direction.x))
    }

    private func show(intruder: Bool, team: TeamID) {
        let arriving = isHidden

        if arriving {
            isHidden = false
            removeAction(forKey: "fade")
            run(.fadeAlpha(to: intruder ? 1 : BaseCompassNode.resting,
                           duration: 0.25), withKey: "fade")
        }

        guard intruder != alarmed || arriving else { return }
        alarmed = intruder

        arrow.fillColor = intruder ? RenderPalette.alarm : RenderPalette.colour(for: team)

        if !arriving {
            removeAction(forKey: "fade")
            run(.fadeAlpha(to: intruder ? 1 : BaseCompassNode.resting,
                           duration: 0.2), withKey: "fade")
        }

        body.removeAllActions()
        body.position = .zero
        body.setScale(1)

        guard intruder else { return }

        // On the body, not on self - see the note at the top of the file. Quick and
        // small: this has to read as an alarm from the corner of an eye without
        // becoming the thing you are looking at while somebody shoots at you.
        body.run(.repeatForever(.sequence([
            .group([.moveBy(x: 0, y: 3, duration: 0.06), .scale(to: 1.12, duration: 0.06)]),
            .group([.moveBy(x: 0, y: -6, duration: 0.09), .scale(to: 1.0, duration: 0.09)]),
            .moveBy(x: 0, y: 3, duration: 0.06),
            .wait(forDuration: 0.5)
        ])))
    }

    /// How visible it is when there is nothing wrong. Low enough to ignore.
    private static let resting: CGFloat = 0.42

    private func retire() {
        guard !isHidden else { return }

        alarmed = false
        body.removeAllActions()
        body.position = .zero
        body.setScale(1)

        removeAction(forKey: "fade")
        run(.sequence([.fadeOut(withDuration: 0.18), .hide()]), withKey: "fade")
    }
}
