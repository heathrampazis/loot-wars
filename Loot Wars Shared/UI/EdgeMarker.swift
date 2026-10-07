//
//  EdgeMarker.swift
//  Loot Wars
//
//  Keeps the markers on the edge of the screen - home, supply drops - off the
//  controls and panels.
//
//  A marker sits where the line from the middle of the screen to what it points
//  at leaves the screen, and that line often ends on the hotbar, a stick or the
//  leaderboard. Drawn under them it was lost; drawn over them it covered them.
//  So it steps aside instead: out of the way of whatever it landed on, towards
//  the middle of the screen, by as little as it can.
//

import Foundation

enum EdgeMarker {

    /// Space left between a marker and the thing it is keeping clear of.
    private static let gap: CGFloat = 4

    /// Where a marker should sit so it covers none of these.
    ///
    /// - Parameters:
    ///   - point: where it would sit, in the same space as everything else here.
    ///   - keepOut: the controls and panels to stay clear of.
    ///   - radius: the marker's own size.
    ///   - bounds: the screen it has to stay on.
    static func clear(_ point: CGPoint, of keepOut: [CGRect], radius: CGFloat,
                      within bounds: CGRect) -> CGPoint {
        var spot = point
        let room = bounds.insetBy(dx: -1, dy: -1)

        // A few rounds, for a spot that steps off one thing onto another.
        for _ in 0..<3 {
            guard let hit = keepOut.first(where: {
                $0.insetBy(dx: -(radius + gap), dy: -(radius + gap)).contains(spot)
            }) else { return spot }

            let grown = hit.insetBy(dx: -(radius + gap), dy: -(radius + gap))
            let options = [
                CGPoint(x: grown.minX, y: spot.y),
                CGPoint(x: grown.maxX, y: spot.y),
                CGPoint(x: spot.x, y: grown.minY),
                CGPoint(x: spot.x, y: grown.maxY)
            ].filter { room.contains($0) }

            guard let best = options.min(by: {
                hypot($0.x - spot.x, $0.y - spot.y) < hypot($1.x - spot.x, $1.y - spot.y)
            }) else { return spot }
            spot = best
        }
        return spot
    }
}
