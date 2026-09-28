//
//  TurretArt.swift
//  Loot Wars
//
//  What a turret looks like, drawn in code until somebody draws it properly.
//
//  Three pieces rather than one picture, because a turret is the first piece of
//  furniture that MOVES: the plinth sits still on its two by two, the barrel swings
//  round to follow whoever it is shooting at, and the cap sits on top of the pivot
//  so the join never shows. Everything is in the owner's colour with the same
//  chunky black outline the walls and the characters wear, so a turret reads as
//  belonging to a base before anybody has worked out what it is.
//
//  SWAPPABLE. Add image sets called TurretBase and TurretBarrel to the asset
//  catalogue and they are used instead, with no code change:
//
//    - TurretBase is drawn over the whole two by two footprint, bottom edge on the
//      ground. Leave a clear round spot around the pivot (half-way across, a
//      little over half-way up) for the barrel to sit on.
//    - TurretBarrel is drawn pointing RIGHT, pivoting on the middle of its left
//      edge, about one and a quarter tiles long.
//    - Turret (optional) is the hotbar icon. Without it the icon is these same
//      three pieces composed with the barrel cocked up and to the right.
//
//  Art from the catalogue is used as it comes - it is not tinted - so the team is
//  still said by the damage bar and by the walls around it.
//

import SpriteKit
import UIKit

enum TurretArt {

    // MARK: - Geometry, in tiles, shared with TurretRenderer

    /// Where the barrel turns, measured up from the middle of the footprint's
    /// bottom edge. A shade above the centre, because the plinth is drawn as a box
    /// seen from slightly in front and its top face is the upper part of the tile.
    static let pivot = Vec2(x: 0, y: 1.08)

    /// Pivot to muzzle, which is Core's muzzleReach near enough that a shot visibly
    /// leaves the end of the barrel.
    static let barrelLength: Double = 1.26

    /// How far the barrel kicks back when it fires.
    static let recoil: Double = 0.16

    // MARK: - Textures

    static func body(for team: TeamID) -> SKTexture {
        if let asset = baseAsset { return asset }
        return cached(&bodies, team) { make(bodyImage(colour: RenderPalette.colour(for: team))) }
    }

    static func barrel(for team: TeamID) -> SKTexture {
        if let asset = barrelAsset { return asset }
        return cached(&barrels, team) { make(barrelImage(colour: RenderPalette.colour(for: team))) }
    }

    /// The cap over the pivot, or nil when the barrel came from the catalogue - a
    /// drawn barrel brings its own idea of where it joins, and a code cap stuck on
    /// top of it would be a second one.
    static func cap(for team: TeamID) -> SKTexture? {
        guard barrelAsset == nil else { return nil }
        return cached(&caps, team) { make(capImage(colour: RenderPalette.colour(for: team))) }
    }

    /// The picture for the hotbar, the shop and the ground: all three pieces, with
    /// the barrel cocked up and to the right so it reads as a gun at thumb size.
    ///
    /// In the colour of whoever is LOOKING - see ItemArt.viewer. A turret lying on
    /// the floor belongs to nobody yet, and the question it has to answer is what
    /// it will look like in your base, so it wears your colour from the moment you
    /// see it. Nil (nobody in particular) falls back to blue.
    static func icon(for team: TeamID?) -> SKTexture {
        let key = team?.raw ?? -1
        if let cached = icons[key] { return cached }

        let made = makeIcon(colour: team.map { RenderPalette.colour(for: $0) } ?? iconColour)
        icons[key] = made
        return made
    }

    private static var icons: [Int: SKTexture] = [:]

    private static func makeIcon(colour: SKColor) -> SKTexture {
        if UIImage(named: "Turret") != nil {
            let texture = SKTexture(imageNamed: "Turret")
            texture.usesMipmaps = true
            return texture
        }

        let u = unit
        let side = u * 2
        let base = UIImage(named: "TurretBase") ?? bodyImage(colour: colour)
        let gun = UIImage(named: "TurretBarrel") ?? barrelImage(colour: colour)
        let top: UIImage? = UIImage(named: "TurretBarrel") == nil
            ? capImage(colour: colour)
            : nil

        // The barrel a little short, so cocked at forty-five degrees it stays
        // inside the square rather than poking out of the top of the slot.
        let reach = min(gun.size.width, 1.14 * u)
        let thickness = gun.size.height * reach / max(1, gun.size.width)

        let image = render(CGSize(width: side, height: side)) { context in
            base.draw(in: CGRect(x: 0, y: 0, width: side, height: side))

            // Image space runs top-down, so the pivot is measured from the top.
            let pivot = CGPoint(x: side / 2, y: side - CGFloat(TurretArt.pivot.y) * u)
            let cg = context.cgContext

            cg.saveGState()
            cg.translateBy(x: pivot.x, y: pivot.y)
            // Negative is anticlockwise on screen, because the space is flipped.
            cg.rotate(by: -.pi / 4)
            gun.draw(in: CGRect(x: 0, y: -thickness / 2, width: reach, height: thickness))
            cg.restoreGState()

            if let top {
                top.draw(in: CGRect(x: pivot.x - top.size.width / 2,
                                    y: pivot.y - top.size.height / 2,
                                    width: top.size.width, height: top.size.height))
            }
        }

        return make(image)
    }

    // MARK: - Colour

    /// The owner's colour pushed down, for the sides of things.
    static func deep(_ colour: SKColor) -> SKColor {
        mix(colour, with: .black, by: 0.32)
    }

    /// The owner's colour lifted, for the edges light catches.
    static func light(_ colour: SKColor) -> SKColor {
        mix(colour, with: .white, by: 0.38)
    }

    private static func mix(_ a: SKColor, with b: SKColor, by amount: CGFloat) -> SKColor {
        var (r1, g1, b1, a1): (CGFloat, CGFloat, CGFloat, CGFloat) = (0, 0, 0, 0)
        var (r2, g2, b2, a2): (CGFloat, CGFloat, CGFloat, CGFloat) = (0, 0, 0, 0)
        a.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        b.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)

        return SKColor(red: r1 + (r2 - r1) * amount,
                       green: g1 + (g2 - g1) * amount,
                       blue: b1 + (b2 - b1) * amount,
                       alpha: 1)
    }

    private static let iconColour = SKColor(red: 0x4F / 255.0, green: 0x92 / 255.0,
                                            blue: 0xDC / 255.0, alpha: 1)

    /// The barrel's metal. Not the team colour, deliberately: a gun the same colour
    /// as the box it sits on disappears into it, and the one part of a turret you
    /// most need to read is which way it is pointing.
    private static let steel = SKColor(red: 0x5E / 255.0, green: 0x6B / 255.0,
                                       blue: 0x7D / 255.0, alpha: 1)
    private static let steelDark = SKColor(red: 0x38 / 255.0, green: 0x41 / 255.0,
                                           blue: 0x4E / 255.0, alpha: 1)

    // MARK: - Drawing

    /// Points per tile in the drawn textures. Generous, for the same reason the
    /// wall texture is: a close camera on a big screen asks for about eighty.
    private static let unit: CGFloat = 96

    /// The black line round everything, as a share of a tile. Matched by eye to the
    /// outline on the walls and the characters.
    private static let outline: CGFloat = 0.075

    private static func bodyImage(colour: SKColor) -> UIImage {
        let u = unit
        let side = u * 2

        // Tile space runs bottom-up, image space top-down.
        func y(_ tiles: CGFloat) -> CGFloat { side - tiles * u }

        return render(CGSize(width: side, height: side)) { _ in
            // A soft shadow, so it sits ON the grass rather than being printed on it.
            SKColor(white: 0, alpha: 0.18).setFill()
            UIBezierPath(ovalIn: CGRect(x: 0.08 * u, y: y(0.42),
                                        width: 1.84 * u, height: 0.4 * u)).fill()

            let left = 0.14 * u
            let width = 1.72 * u
            let corner = 0.34 * u

            // The front face first, reaching lower than the top so its bottom strip
            // shows below it: a box seen from a little in front.
            let skirt = UIBezierPath(roundedRect: CGRect(x: left, y: y(1.62),
                                                         width: width, height: 1.44 * u),
                                     cornerRadius: corner)
            deep(colour).setFill()
            skirt.fill()
            stroke(skirt, width: outline * u)

            // Two vents on the front, which is most of what makes a box look like
            // a machine rather than a crate.
            SKColor(white: 0, alpha: 0.28).setFill()
            for x in [0.62, 1.2] as [CGFloat] {
                UIBezierPath(roundedRect: CGRect(x: x * u, y: y(0.36),
                                                 width: 0.18 * u, height: 0.1 * u),
                             cornerRadius: 0.04 * u).fill()
            }

            let top = UIBezierPath(roundedRect: CGRect(x: left, y: y(1.62),
                                                       width: width, height: 1.14 * u),
                                   cornerRadius: corner)
            colour.setFill()
            top.fill()

            // A catch of light along the top edge.
            light(colour).withAlphaComponent(0.8).setFill()
            UIBezierPath(roundedRect: CGRect(x: 0.36 * u, y: y(1.52),
                                             width: 1.28 * u, height: 0.09 * u),
                         cornerRadius: 0.045 * u).fill()

            stroke(top, width: outline * u)

            // The turntable the barrel sits on.
            let pivot = CGPoint(x: u, y: y(CGFloat(TurretArt.pivot.y)))
            let ring = circle(pivot, 0.5 * u)
            deep(colour).setFill()
            ring.fill()
            stroke(ring, width: outline * u)

            SKColor(white: 0, alpha: 0.22).setFill()
            circle(pivot, 0.36 * u).fill()
        }
    }

    private static func barrelImage(colour: SKColor) -> UIImage {
        let u = unit
        let size = CGSize(width: 1.34 * u, height: 0.5 * u)
        let mid = size.height / 2

        return render(size) { _ in
            let tube = UIBezierPath(roundedRect: CGRect(x: 0, y: mid - 0.15 * u,
                                                        width: 1.12 * u, height: 0.3 * u),
                                    cornerRadius: 0.1 * u)
            steel.setFill()
            tube.fill()

            SKColor(white: 1, alpha: 0.35).setFill()
            UIBezierPath(roundedRect: CGRect(x: 0.4 * u, y: mid - 0.1 * u,
                                             width: 0.56 * u, height: 0.06 * u),
                         cornerRadius: 0.03 * u).fill()

            stroke(tube, width: outline * u)

            // A band of the owner's colour, so the gun is theirs from any angle.
            let band = UIBezierPath(roundedRect: CGRect(x: 0.56 * u, y: mid - 0.18 * u,
                                                        width: 0.16 * u, height: 0.36 * u),
                                    cornerRadius: 0.05 * u)
            colour.setFill()
            band.fill()
            stroke(band, width: outline * 0.8 * u)

            // The muzzle, fatter than the tube so the business end is obvious.
            let muzzle = UIBezierPath(roundedRect: CGRect(x: 1.0 * u, y: mid - 0.21 * u,
                                                          width: 0.28 * u, height: 0.42 * u),
                                      cornerRadius: 0.08 * u)
            steelDark.setFill()
            muzzle.fill()
            stroke(muzzle, width: outline * u)
        }
    }

    private static func capImage(colour: SKColor) -> UIImage {
        let u = unit
        let side = 0.8 * u
        let centre = CGPoint(x: side / 2, y: side / 2)

        return render(CGSize(width: side, height: side)) { _ in
            // Shaded like a button: the dark disc underneath, the colour shifted up
            // off it, so the bottom edge reads as the side of a dome.
            let dome = circle(centre, 0.3 * u)
            deep(colour).setFill()
            dome.fill()

            colour.setFill()
            circle(CGPoint(x: centre.x, y: centre.y - 0.035 * u), 0.26 * u).fill()

            SKColor(white: 1, alpha: 0.55).setFill()
            UIBezierPath(ovalIn: CGRect(x: centre.x - 0.2 * u, y: centre.y - 0.24 * u,
                                        width: 0.18 * u, height: 0.1 * u)).fill()

            stroke(dome, width: outline * u)
        }
    }

    // MARK: - Plumbing

    private static var bodies: [Int: SKTexture] = [:]
    private static var barrels: [Int: SKTexture] = [:]
    private static var caps: [Int: SKTexture] = [:]

    private static let baseAsset: SKTexture? = asset(named: "TurretBase")
    private static let barrelAsset: SKTexture? = asset(named: "TurretBarrel")

    private static func asset(named name: String) -> SKTexture? {
        guard UIImage(named: name) != nil else { return nil }
        let texture = SKTexture(imageNamed: name)
        texture.usesMipmaps = true
        return texture
    }

    private static func cached(_ cache: inout [Int: SKTexture],
                               _ team: TeamID,
                               _ build: () -> SKTexture) -> SKTexture {
        if let hit = cache[team.raw] { return hit }
        let made = build()
        cache[team.raw] = made
        return made
    }

    private static func make(_ image: UIImage) -> SKTexture {
        let texture = SKTexture(image: image)
        texture.usesMipmaps = true
        return texture
    }

    private static func render(_ size: CGSize,
                               _ draw: (UIGraphicsImageRendererContext) -> Void) -> UIImage {
        let format = UIGraphicsImageRendererFormat.default()
        format.opaque = false
        return UIGraphicsImageRenderer(size: size, format: format).image(actions: draw)
    }

    private static func stroke(_ path: UIBezierPath, width: CGFloat) {
        SKColor.black.setStroke()
        path.lineWidth = width
        path.lineJoinStyle = .round
        path.stroke()
    }

    private static func circle(_ centre: CGPoint, _ radius: CGFloat) -> UIBezierPath {
        UIBezierPath(ovalIn: CGRect(x: centre.x - radius, y: centre.y - radius,
                                    width: radius * 2, height: radius * 2))
    }
}
