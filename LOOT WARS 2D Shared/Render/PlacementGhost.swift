//
//  PlacementGhost.swift
//  Loot Wars
//
//  The thing you are about to put down, shown where it would go.
//
//  Placing a machine used to be a guess: you tapped, six tiles were tested against
//  rules you could not see, and either something appeared or nothing did. Nothing
//  did about five times out of six, and no part of the screen ever said why.
//
//  So it is drawn instead. The footprint follows the finger, the machine is drawn
//  faintly inside it, and the whole thing turns red the moment it would be refused.
//  Nothing here decides anything - PlacementSystem answers both questions, and this
//  only paints the answer - so the outline cannot promise a spot that then fails.
//

import SpriteKit

final class PlacementGhost {

    let node = SKNode()

    private let plate = SKShapeNode()
    private let sprite = SKSpriteNode()

    /// What the plate and sprite were last built for, so a finger dragging across
    /// the map moves two nodes rather than rebuilding them sixty times a second.
    private var builtFor: ItemType?

    init() {
        // Above everything in the world, including the actors: this is a thing you
        // are aiming, and something standing in front of it would be the one moment
        // it mattered that you could not see it.
        node.zPosition = 80
        node.isHidden = true

        plate.lineWidth = 2
        node.addChild(plate)

        sprite.alpha = 0.6
        node.addChild(sprite)
    }

    func hide() {
        node.isHidden = true
    }

    func show(_ type: ItemType, at origin: GridPoint, valid: Bool) {
        guard let size = PlacementSystem.footprint(of: type) else {
            hide()
            return
        }

        if builtFor != type {
            build(type, size: size)
            builtFor = type
        }

        node.isHidden = false
        node.position = GridGeometry.point(
            for: Vec2(x: Double(origin.col), y: Double(origin.row)))

        let colour = valid ? RenderPalette.placementValid : RenderPalette.placementBlocked
        plate.strokeColor = colour
        plate.fillColor = colour.withAlphaComponent(valid ? 0.16 : 0.30)

        // Blocked is a wash of red OVER the art rather than a border around it -
        // a tinted machine reads as refused at a glance, where a coloured edge is
        // something you have to look for while somebody is shooting at you.
        sprite.color = RenderPalette.placementBlocked
        sprite.colorBlendFactor = valid ? 0 : 0.55
        sprite.alpha = valid ? 0.6 : 0.45
    }

    /// The art, drawn to the same rule as the renderer that will draw it for real -
    /// a preview at a different size or standing on a different line would be a
    /// promise about where the thing goes that the world would not keep.
    private func build(_ type: ItemType, size: PlacementSystem.Footprint) {
        let width = GridGeometry.length(ofTiles: Double(size.width))
        let height = GridGeometry.length(ofTiles: Double(size.height))

        // Drawn from the origin corner, so the node sits on the footprint's own
        // bottom-left and every position below is just a tile coordinate.
        plate.path = CGPath(roundedRect: CGRect(x: 0, y: 0, width: width, height: height),
                            cornerWidth: 4, cornerHeight: 4, transform: nil)

        switch type {
        case .arcade(let kind):
            let fit = ArcadeRenderer.fit(kind)
            sprite.texture = ArcadeRenderer.texture(for: kind)
            sprite.size = fit.size
            sprite.anchorPoint = CGPoint(x: 0.5, y: 0)
            sprite.position = CGPoint(x: width / 2 - fit.content.midX,
                                      y: -fit.size.height / 2 - fit.content.minY)

        case .turret:
            // The icon IS the turret, composed on the same two by two it will
            // stand on, so the ghost fills its footprint exactly.
            sprite.texture = TurretArt.icon
            sprite.size = CGSize(width: width, height: height)
            sprite.anchorPoint = CGPoint(x: 0.5, y: 0.5)
            sprite.position = CGPoint(x: width / 2, y: height / 2)

        default:
            let texture = ItemArt.texture(for: type)
            sprite.texture = texture
            sprite.size = ItemArt.size(of: texture,
                                       fittingInto: min(width, height) * 0.9)
            sprite.anchorPoint = CGPoint(x: 0.5, y: 0.5)
            sprite.position = CGPoint(x: width / 2, y: height / 2)
        }
    }
}
