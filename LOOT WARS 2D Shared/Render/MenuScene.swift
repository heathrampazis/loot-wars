//
//  MenuScene.swift
//  Loot Wars
//
//  The door into the game.
//
//  The app used to open straight into a match, which is fine while you are the only
//  person who ever launches it and wrong for everybody else: a game that starts
//  before you have agreed to play gives you no moment to arrive in, no way to stop
//  without killing the app, and nowhere to put anything the game wants to tell you
//  between matches - a best score, a daily seed, a setting, a name.
//
//  It is a SCENE rather than a panel inside the game scene, and that is the whole
//  design decision here. A menu drawn over a paused world means the world has to
//  exist first: forty crates, eight bots and a generated map built before anybody
//  has pressed anything, torn down and rebuilt the moment they do. As its own scene
//  it costs a background and four labels, and the match starts from nothing when
//  it is asked for - which is also what makes the transition into one honest.
//
//  What it draws is deliberately the game's own furniture: the map's grass, the
//  token, a crate, the wall colours. A title screen made of screenshots ages badly;
//  one made of the same pieces the match is made of cannot go out of date, because
//  it is the same pieces.
//

import SpriteKit

final class MenuScene: SKScene {

    private let play = SKNode()
    private static let playSize = CGSize(width: 240, height: 62)

    class func newMenuScene() -> MenuScene {
        let scene = MenuScene(size: CGSize(width: 1024, height: 768))
        scene.scaleMode = .resizeFill
        return scene
    }

    override func didMove(to view: SKView) {
        backgroundColor = RenderPalette.floorLight
        removeAllChildren()

        build()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        guard scene != nil, !children.isEmpty else { return }
        removeAllChildren()
        build()
    }

    // MARK: - Building

    private func build() {
        let middle = CGPoint(x: size.width / 2, y: size.height / 2)

        buildGround()
        buildTitle(centredOn: CGPoint(x: middle.x, y: middle.y + size.height * 0.16))
        buildTrinkets(along: CGPoint(x: middle.x, y: middle.y + size.height * 0.02))
        buildPlayButton(centredOn: CGPoint(x: middle.x, y: middle.y - size.height * 0.16))
        buildRecord(centredOn: CGPoint(x: middle.x, y: middle.y - size.height * 0.30))
    }

    /// The map, seen from further away than a match ever shows it.
    ///
    /// Two tones on a grid, which is exactly what the floor is - the same
    /// checkerboard the tile renderer bakes, drawn at four times the size so it
    /// reads as a backdrop rather than as a level somebody forgot to put actors on.
    private func buildGround() {
        let tile = GridGeometry.tileSize * 4
        let columns = Int(size.width / tile) + 2
        let rows = Int(size.height / tile) + 2

        for column in 0..<columns {
            for row in 0..<rows {
                guard (column + row) % 2 == 0 else { continue }

                let square = SKSpriteNode(color: RenderPalette.floorDark,
                                          size: CGSize(width: tile, height: tile))
                square.position = CGPoint(x: (CGFloat(column) + 0.5) * tile,
                                          y: (CGFloat(row) + 0.5) * tile)
                square.zPosition = -10
                addChild(square)
            }
        }
    }

    /// The name, in the outlined style the game's own artwork uses.
    ///
    /// Four dark copies behind a light one. At payout size that trick read as text
    /// printed twice and came off again; at fifty points it reads as exactly what
    /// it is - the black line round every sprite in this game, applied to a word.
    private func buildTitle(centredOn centre: CGPoint) {
        let word = "LOOT WARS"
        let outline: [CGPoint] = [CGPoint(x: 4, y: 4), CGPoint(x: -4, y: 4),
                                  CGPoint(x: 4, y: -4), CGPoint(x: -4, y: -4)]

        var copies: [(CGPoint, SKColor)] = outline.map { ($0, .black) }
        copies.append((.zero, .white))

        let title = SKNode()
        title.position = centre
        addChild(title)

        for (offset, colour) in copies {
            let label = SKLabelNode(fontNamed: "AvenirNext-Bold")
            label.text = word
            label.fontSize = 54
            label.fontColor = colour
            label.verticalAlignmentMode = .center
            label.position = offset
            title.addChild(label)
        }

        // A slow tilt, so the screen is never completely still.
        title.zRotation = -0.012
        title.run(.repeatForever(.sequence([
            .rotate(toAngle: 0.012, duration: 2.4),
            .rotate(toAngle: -0.012, duration: 2.4)
        ])))
    }

    /// A token, a crate and a bomb, bobbing under the name.
    ///
    /// The three things a match is actually made of - money, loot and the way into
    /// somebody's base - and all three are the game's own artwork rather than
    /// anything drawn for this screen.
    private func buildTrinkets(along centre: CGPoint) {
        let pieces: [Pickup] = [.token(1), .item(.chest), .item(.bomb)]
        let spacing: CGFloat = 92

        for (index, pickup) in pieces.enumerated() {
            let texture = ItemArt.texture(for: pickup)
            let sprite = SKSpriteNode(texture: texture)

            sprite.size = ItemArt.size(of: texture, fittingInto: 46)
            sprite.position = CGPoint(
                x: centre.x + (CGFloat(index) - 1) * spacing,
                y: centre.y
            )
            addChild(sprite)

            // Out of step with each other, the same rule the breathing figures
            // follow: three things bobbing in unison is a chorus line.
            sprite.run(.sequence([
                .wait(forDuration: Double(index) * 0.31),
                .repeatForever(.sequence([
                    .moveBy(x: 0, y: 7, duration: 0.9),
                    .moveBy(x: 0, y: -7, duration: 0.9)
                ]))
            ]))
        }
    }

    /// The only button on the screen, drawn the way the shop draws a price you can
    /// afford: solid, with a darker lip under it and a black outline.
    private func buildPlayButton(centredOn centre: CGPoint) {
        let box = MenuScene.playSize
        play.position = centre
        addChild(play)

        func capsule(offsetBy drop: CGFloat, colour: SKColor) -> SKShapeNode {
            let shape = SKShapeNode(path: CGPath(
                roundedRect: CGRect(x: -box.width / 2, y: -box.height / 2 - drop,
                                    width: box.width, height: box.height),
                cornerWidth: box.height / 2, cornerHeight: box.height / 2,
                transform: nil))

            shape.fillColor = colour
            shape.strokeColor = .black
            shape.lineWidth = 3
            return shape
        }

        play.addChild(capsule(offsetBy: 5, colour: RenderPalette.affordableDeep))
        play.addChild(capsule(offsetBy: 0, colour: RenderPalette.affordable))

        let label = SKLabelNode(fontNamed: "AvenirNext-Bold")
        label.text = "PLAY"
        label.fontSize = 26
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        label.zPosition = 1
        play.addChild(label)

        // Breathing, for the same reason the ghost wall breathes: it is the one
        // thing on this screen that wants pressing, and a still button on a still
        // screen is furniture.
        play.run(.repeatForever(.sequence([
            .scale(to: 1.04, duration: 0.85),
            .scale(to: 1.0, duration: 0.85)
        ])))
    }

    /// What the game remembers about you. Nothing at all, the first time.
    private func buildRecord(centredOn centre: CGPoint) {
        guard Prefs.matchesFinished > 0 else { return }

        let matches = Prefs.matchesFinished
        let label = SKLabelNode(fontNamed: "AvenirNext-Bold")

        label.text = "BEST \(Prefs.bestScore)   ·   \(matches) MATCH\(matches == 1 ? "" : "ES")"
        label.fontSize = 15
        label.fontColor = SKColor(white: 1, alpha: 0.85)
        label.verticalAlignmentMode = .center
        label.position = centre
        addChild(label)
    }

    // MARK: - Pressing it

    #if os(iOS) || os(tvOS)
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first, let view else { return }

        let box = MenuScene.playSize
        let point = touch.location(in: self)
        let local = CGPoint(x: point.x - play.position.x, y: point.y - play.position.y)

        // Generous, because it is the only thing on the screen to hit.
        guard abs(local.x) <= box.width / 2 + 24,
              abs(local.y) <= box.height / 2 + 24 else { return }

        play.removeAllActions()
        play.run(.sequence([
            .scale(to: 0.94, duration: 0.06),
            .scale(to: 1.0, duration: 0.08)
        ]))

        // The match is built when it is asked for, which is what a scene boundary
        // buys: nothing about a world exists while somebody is looking at a menu.
        view.presentScene(GameScene.newGameScene(),
                          transition: .fade(withDuration: 0.35))
    }
    #endif
}
