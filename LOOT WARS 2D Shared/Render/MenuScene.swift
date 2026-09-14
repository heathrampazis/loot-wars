//
//  MenuScene.swift
//  Loot Wars
//
//  The door into the game: the name, one button, and the grass.
//
//  The button is artwork rather than shapes. It was drawn here for a while - a
//  rounded slab, a lip, a stand-in for a shadow SpriteKit cannot blur, a triangle
//  nudged off centre - which was a program describing a button. The drawing is in
//  the asset catalogue now and this only has to put it in the right place.
//
//  It is a SCENE rather than a panel over a paused world, and that is the design
//  decision worth keeping. A menu drawn on top of the game means the world has to
//  exist first - forty crates, eight bots and a generated map built before anybody
//  has pressed anything, torn down and rebuilt the moment they do. As its own scene
//  it costs a background and three nodes, and the match is built when it is asked
//  for.
//
//  Two versions came before this one and both were wrong in opposite directions.
//  The first put the game's furniture on the screen - grass in giant checks, a
//  token, a crate and a bomb bobbing about - and looked like the game with the
//  level missing. The second went dark and typographic, which was clean and had
//  nothing to do with this game at all.
//
//  This one is the middle: the map's own green, flat and uninterrupted, black type
//  on it, and a single button with a play triangle in it. The green is what makes
//  it belong to Loot Wars; the emptiness is what makes it a menu. Nothing on the
//  screen is decoration - the name, the button, and the one fact worth knowing
//  before pressing it.
//

import SpriteKit
import UIKit

final class MenuScene: SKScene {

    private let logo = SKNode()
    private let play = SKNode()

    /// How much of the screen the logo may take, as shares of each side.
    ///
    /// Both, and the smaller wins. A landscape phone is about 844 by 390, so a
    /// width share on its own would ask for a logo taller than the screen - the
    /// artwork is half again as wide as it is tall and there is a button to fit
    /// underneath it.
    private static let logoWidthShare: CGFloat = 0.62
    private static let logoHeightShare: CGFloat = 0.40

    /// Set once the scene has handed the game over, so a second tap on a button
    /// that is still animating cannot present a second match.
    private var starting = false
    /// A share of the screen's width, capped so it cannot get silly on an iPad.
    /// The height comes from the artwork.
    private static let playWidthShare: CGFloat = 0.38
    private static let playMaxWidth: CGFloat = 260

    /// What the button was actually drawn at, kept for the hit test - which has to
    /// measure the picture on screen rather than a number written down twice.
    private var buttonSize = CGSize(width: 216, height: 96)

    class func newMenuScene() -> MenuScene {
        let scene = MenuScene(size: CGSize(width: 1024, height: 768))
        scene.scaleMode = .resizeFill
        return scene
    }

    override func didMove(to view: SKView) {
        // Before anything asks for a sound. See SoundPlayer.warm.
        SoundPlayer.shared.warm()

        backgroundColor = MenuScene.ground
        removeAllChildren()
        build()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        guard scene != nil, !children.isEmpty else { return }
        removeAllChildren()
        build()
    }

    // MARK: - The one palette this screen has

    /// The map's own grass, flat. No checks, no texture, no gradient - a single
    /// field of the colour the whole game is played on.
    private static let ground = RenderPalette.floorLight

    // MARK: - Building

    private func build() {
        starting = false

        let middle = CGPoint(x: size.width / 2, y: size.height / 2)

        // Measured off the middle rather than off the edges, so the layout holds
        // its shape on every phone: a tall screen gets more air, not more gaps
        // between things that belong together.
        //
        // The stack is centred as a BLOCK rather than each piece being placed at
        // its own offset from the middle. The title used to be a line of type of a
        // known height; it is a picture now, and how tall it comes out depends on
        // the screen - so the gaps have to be measured from it rather than from a
        // number that was right for the old one.
        let logoSize = titleSize()
        let gapUnderLogo: CGFloat = 22
        let gapUnderButton: CGFloat = 26
        let buttonSize = playSize()
        let record: CGFloat = Prefs.matchesFinished > 0 ? 14 : 0

        let block = logoSize.height + gapUnderLogo + buttonSize.height
            + (record > 0 ? gapUnderButton + record : 0)
        var y = middle.y + block / 2

        y -= logoSize.height / 2
        buildTitle(centredOn: CGPoint(x: middle.x, y: y), size: logoSize)
        y -= logoSize.height / 2 + gapUnderLogo

        y -= buttonSize.height / 2
        buildPlayButton(centredOn: CGPoint(x: middle.x, y: y), size: buttonSize)
        y -= buttonSize.height / 2

        if record > 0 {
            buildRecord(centredOn: CGPoint(x: middle.x, y: y - gapUnderButton - record / 2))
        }
    }

    /// How big the logo comes out on this screen, whichever side runs out first.
    private func titleSize() -> CGSize {
        guard let art = MenuScene.logoTexture?.size(), art.width > 0, art.height > 0 else {
            return CGSize(width: 0, height: 48)
        }

        let aspect = art.width / art.height
        let width = min(size.width * MenuScene.logoWidthShare,
                        size.height * MenuScene.logoHeightShare * aspect)
        return CGSize(width: width, height: width / aspect)
    }

    private func playSize() -> CGSize {
        let art = MenuScene.playTexture.size()
        let width = min(MenuScene.playMaxWidth, size.width * MenuScene.playWidthShare)
        return CGSize(width: width, height: art.width > 0 ? width * (art.height / art.width)
                                                          : width)
    }

    /// Loaded once and asked about rather than assumed.
    ///
    /// Nil when the artwork is not in the catalogue, and the title falls back to
    /// type - which is what this screen was for its first three versions, so the
    /// menu is never a blank field of green with a button in it.
    private static let logoTexture: SKTexture? = {
        guard UIImage(named: "logo") != nil else { return nil }
        let texture = SKTexture(imageNamed: "logo")
        texture.usesMipmaps = true
        return texture
    }()

    private static let playTexture: SKTexture = {
        let texture = SKTexture(imageNamed: "Play")
        texture.usesMipmaps = true
        return texture
    }()

    /// The name, which is a picture now.
    ///
    /// It was black type on the grass, and the reasoning for that was sound while
    /// it lasted: black is what every sprite in this game is outlined with, so the
    /// name belonged to the same set of pictures without borrowing the outline. A
    /// drawn logo does that better, because it IS one of the pictures.
    ///
    /// It floats, sways and every few seconds gives a small pop, and the three run
    /// on periods that do not divide into each other. That is the whole trick: a
    /// title that bobs on one clock reads as a loop, and one that bobs, leans and
    /// occasionally shrugs on three different clocks reads as a thing sitting
    /// there. The same argument the crates make on the map - see LootboxRenderer -
    /// and the same tiny amplitudes, because a menu you are about to leave should
    /// not be busy.
    private func buildTitle(centredOn centre: CGPoint, size logoSize: CGSize) {
        logo.removeAllActions()
        logo.removeAllChildren()
        logo.removeFromParent()
        logo.setScale(1)
        logo.zRotation = 0
        logo.alpha = 1
        logo.position = centre
        addChild(logo)

        guard let texture = MenuScene.logoTexture else {
            let label = SKLabelNode()
            label.attributedText = MenuScene.text("LOOT WARS", size: 48, kern: 1,
                                                  colour: SKColor(white: 0.04, alpha: 1))
            label.verticalAlignmentMode = .center
            logo.addChild(label)
            return
        }

        logo.addChild(SKSpriteNode(texture: texture, size: logoSize))

        // Arriving. Small and quick - the menu should look like it settled, not
        // like it is performing.
        logo.setScale(0.94)
        logo.alpha = 0
        logo.run(.group([.fadeIn(withDuration: 0.22),
                         .scale(to: 1, duration: 0.30)]))

        let float = SKAction.sequence([.moveBy(x: 0, y: 7, duration: 1.9),
                                       .moveBy(x: 0, y: -7, duration: 1.9)])
        float.timingMode = .easeInEaseOut
        logo.run(.repeatForever(float), withKey: "float")

        let sway = SKAction.sequence([.rotate(toAngle: 0.011, duration: 2.7),
                                      .rotate(toAngle: -0.011, duration: 2.7)])
        sway.timingMode = .easeInEaseOut
        logo.run(.sequence([.wait(forDuration: 0.4), .repeatForever(sway)]), withKey: "sway")

        // And the shrug. Long wait, short movement: the pause is most of it, the
        // same way a crate's knock is mostly the silence before it.
        logo.run(.repeatForever(.sequence([
            .wait(forDuration: 4.6),
            .scaleX(to: 1.035, y: 0.965, duration: 0.10),
            .scaleX(to: 0.985, y: 1.02, duration: 0.13),
            .scaleX(to: 1, y: 1, duration: 0.18)
        ])), withKey: "pop")
    }

    /// The only thing on the screen you can press, and it is a picture now.
    ///
    /// It was drawn here for a while - a rounded slab, a lip under it, two faint
    /// offset slabs standing in for a shadow SpriteKit cannot blur, and a triangle
    /// nudged right of centre because a centred one looks left-heavy. All of that
    /// was a program describing a button. An artist drawing one is better at it and
    /// far easier to change, so the drawing lives in the asset catalogue and this
    /// puts it on the screen at the right size.
    ///
    /// Sized by WIDTH against the screen, with the height following the artwork's
    /// own proportions - so the button is the same share of every phone rather than
    /// a fixed slab that dominates a small one and gets lost on a large one.
    private func buildPlayButton(centredOn centre: CGPoint, size buttonSize: CGSize) {
        let sprite = SKSpriteNode(texture: MenuScene.playTexture, size: buttonSize)

        // The holder is a property and this runs again on every rotation or resize,
        // so it is emptied rather than appended to - otherwise a second sprite
        // lands on top of the first, at whatever scale the press animation happened
        // to leave behind.
        play.removeAllActions()
        play.removeAllChildren()
        play.removeFromParent()
        play.setScale(1)

        play.position = centre
        play.addChild(sprite)
        addChild(play)

        self.buttonSize = buttonSize
        startBreathing()
    }

    /// The button's idle: a slow breath, and nothing else.
    ///
    /// It is the only thing on this screen you can press, and on a screen with one
    /// button and no instructions the thing that moves is the thing you press. So
    /// it is deliberately the plainer of the two animations - a title can afford to
    /// have character, a control has a job.
    ///
    /// On its own clock rather than the logo's, and not a multiple of it, so the
    /// two drift against each other instead of nodding together. Two things pulsing
    /// in step read as one mechanism, which is the note this screen must not hit:
    /// the button would look like part of the title rather than a thing to touch.
    private func startBreathing() {
        let breath = SKAction.sequence([.scale(to: 1.035, duration: 1.15),
                                        .scale(to: 1.0, duration: 1.15)])
        breath.timingMode = .easeInEaseOut
        play.run(.repeatForever(breath), withKey: "breathe")
    }

    /// What the game remembers about you. Nothing at all, the first time.
    private func buildRecord(centredOn centre: CGPoint) {
        guard Prefs.matchesFinished > 0 else { return }

        let matches = Prefs.matchesFinished
        let played = "\(matches) MATCH\(matches == 1 ? "" : "ES")"

        let label = SKLabelNode()
        label.attributedText = MenuScene.text("BEST \(Prefs.bestScore)   ·   \(played)",
                                              size: 12, kern: 3,
                                              colour: SKColor(white: 0.04, alpha: 0.45))
        label.verticalAlignmentMode = .center
        label.position = centre
        addChild(label)
    }

    /// Tracked type, which SKLabelNode can only do through an attributed string.
    private static func text(_ string: String,
                             size: CGFloat,
                             kern: CGFloat,
                             colour: SKColor) -> NSAttributedString {
        let font = UIFont(name: "AvenirNext-Bold", size: size)
            ?? UIFont.boldSystemFont(ofSize: size)

        return NSAttributedString(string: string, attributes: [
            .font: font,
            .foregroundColor: colour,
            .kern: kern
        ])
    }

    // MARK: - Pressing it

    #if os(iOS) || os(tvOS)
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first, let view else { return }

        let box = buttonSize
        let point = touch.location(in: self)
        let local = CGPoint(x: point.x - play.position.x, y: point.y - play.position.y)

        // Generous, because it is the only thing on the screen to hit.
        guard abs(local.x) <= box.width / 2 + 24,
              abs(local.y) <= box.height / 2 + 24 else { return }

        guard !starting else { return }
        starting = true

        // The press, and then the game - in that order.
        //
        // This used to run the squash and present the scene on the next line, so
        // the transition began on the same frame and the animation played out on a
        // node already being torn down. You pressed a button and the screen simply
        // changed; whether it had reacted was not something you could see. Two tenths
        // of a second is nothing to wait and is the difference between a button and
        // a hotspot.
        //
        // Down hard and fast, up past its own size, then settle - the same shape
        // the figures use when something happens to them, gather and release. It
        // overshoots because a button that returns exactly to where it started
        // reads as having been let go of rather than as having sprung back.
        play.removeAction(forKey: "breathe")
        play.removeAllActions()

        // On the press rather than when the match appears. The button's animation
        // and the fade to the map take the better part of half a second between
        // them, and a sound that arrives at the end of that belongs to the scene
        // change; one that arrives on the press belongs to the finger.
        SoundPlayer.shared.play(.play)

        let press = SKAction.sequence([
            .scale(to: 0.90, duration: 0.05),
            .scale(to: 1.06, duration: 0.09),
            .scale(to: 1.0, duration: 0.07)
        ])
        press.timingMode = .easeOut

        // And the rest of the screen stands down, so the button is the only thing
        // moving at the moment it is pressed.
        logo.removeAction(forKey: "pop")

        play.run(.sequence([
            press,
            .run { [weak view] in
                view?.presentScene(GameScene.newGameScene(),
                                   transition: .fade(withDuration: 0.35))
            }
        ]))
    }
    #endif
}
