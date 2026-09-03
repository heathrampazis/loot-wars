//
//  CameraController.swift
//  Loot Wars
//
//  Locks the camera onto a position in tile space. That is what makes the player
//  appear to sit still in the middle of the screen while the map slides past.
//
//  Locked, and not smoothed - deliberately. A camera that eases towards the player
//  every frame lags behind them by speed over rate, which at walking pace is most
//  of a tile: you aim from a screen whose centre is not quite where you are, and on
//  a twin-stick game that is felt long before it is noticed.
//
//  The one time it does move on its own is when the SUBJECT changes: you die, and
//  the camera goes to watch whoever killed you. Cutting there would be a different
//  screen arriving between two frames, with no way to tell whether the map moved or
//  you did. So a change of subject is a journey, and once it arrives the camera is
//  locked again.
//

import SpriteKit

final class CameraController {

    let node = SKCameraNode()

    /// How long a change of subject takes to travel, in seconds.
    ///
    /// Long enough to be followed by eye - which is the whole point, since the
    /// player has to understand that the screen is now showing somebody else - and
    /// short enough that a three second respawn does not spend a fifth of itself
    /// in transit.
    private static let travelTime: TimeInterval = 0.55

    /// Who the camera is watching, so a change can be noticed without being told.
    private var subject: ActorID?

    private var travelling: TimeInterval = 0
    private var origin: CGPoint = .zero

    /// - Parameters:
    ///   - position: where to look, in tile space.
    ///   - subject: whose position that is. A different id starts a journey.
    func follow(_ position: Vec2, subject: ActorID, dt: TimeInterval) {
        let target = GridGeometry.point(for: position)

        if subject != self.subject {
            // Only after the first frame: the opening frame of a match has no
            // previous subject to travel FROM, and starting there would fly the
            // camera in from the corner of the world.
            travelling = self.subject == nil ? 0 : CameraController.travelTime
            origin = self.subject == nil ? target : node.position
            self.subject = subject
        }

        guard travelling > 0 else {
            node.position = target
            return
        }

        travelling = max(0, travelling - dt)

        // Eased at both ends rather than linear. A camera that starts and stops
        // abruptly reads as a cut with extra steps; one that accelerates away and
        // settles reads as something turning to look.
        let done = 1 - travelling / CameraController.travelTime
        let eased = done * done * (3 - 2 * done)

        node.position = CGPoint(
            x: origin.x + (target.x - origin.x) * CGFloat(eased),
            y: origin.y + (target.y - origin.y) * CGFloat(eased)
        )
    }
}
