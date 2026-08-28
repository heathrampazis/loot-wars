//
//  CameraController.swift
//  Loot Wars
//
//  Locks the camera onto a position in tile space. That is what makes the player
//  appear to sit still in the middle of the screen while the map slides past.
//

import SpriteKit

final class CameraController {

    let node = SKCameraNode()

    func follow(_ position: Vec2) {
        node.position = GridGeometry.point(for: position)
    }
}
