//
//  ChestPanelNode.swift
//  Loot Wars
//
//  What is inside a chest: four slots on a panel, above your own hotbar.
//
//  Deliberately NOT a modal. There is no scrim and the map stays visible behind it,
//  because the world does not stop while you are rummaging - bots keep moving,
//  bullets keep flying, and somebody can walk into your base while your head is in
//  a box. Dimming the game would tell the player the opposite of the truth.
//
//  Proportions came off the reference mockup, measured against the hotbar in the
//  same image to establish its scale: a chest slot is about one and a half hotbar
//  slots. The mockup's own ratio was nearer twice, which does not survive a short
//  landscape screen - at that size the panel ran into the HUD above it and the
//  hotbar below on anything smaller than a Pro Max.
//
//  IT SPEAKS THE SHOP'S LANGUAGE, which it did not for a long time and should have
//  from the start. Both panels are the same act - a grid of things, tap one, it
//  moves between there and your bag - and the shop had been given a curtain, a
//  dealt-in stagger, a round way out, a header carrying the number every tap is
//  about, and a green or red answer to every press. This had none of it: it
//  appeared between two frames, sat there, and moved things silently.
//
//  Nothing here is new invention. Every gesture below already exists on the shop
//  panel and most of the drawing already existed on ItemSlotNode; what this file
//  was missing was the decision to use them. Two panels that behave differently
//  are worse than either behaviour, which is the note GameScene.handleChestTouch
//  already carries about tapping outside to close.
//
//  ONE THING THE SHOP HAS THAT THIS DOES NOT: a header. The shop's carries your
//  purse, because every card on it is a question about whether you can afford
//  something. The equivalent here was a count of your free bag slots, and it was
//  tried and taken out again - a chest is four squares and a bar of your own
//  things directly underneath it, and a number telling you how full that bar is,
//  above a picture of the bar, is the panel saying something you are already
//  looking at. The refusals say it at the moment it matters instead.
//

import SpriteKit

final class ChestPanelNode: SKNode {

    private static let slotSize: CGFloat = 104
    private static let gap: CGFloat = 24
    private static let padding: CGFloat = 18

    /// The round cross in the corner, which is the shop's way out rather than this
    /// panel's old floating BACK pill.
    ///
    /// A pill reading BACK was a word where a symbol would do, it hung OUTSIDE the
    /// panel where nothing else on this screen lives, and it was a second way of
    /// saying the thing the shop already says with a cross in its own top-right
    /// corner. Somebody who has closed the shop once knows how to close this.
    private static let backSize = CGSize(width: 38, height: 38)

    static var size: CGSize {
        let count = CGFloat(Inventory.slotCount)
        return CGSize(width: count * slotSize + (count - 1) * gap + padding * 2,
                      height: slotSize + padding * 2)
    }

    private var slots: [ItemSlotNode] = []
    private let back = SKNode()
    private var lastContents: Inventory?

    /// Set by open, spent by the next update. It cannot fire from open directly:
    /// dealing animates each slot in from just below its place, and a slot with
    /// nothing drawn in it yet has nothing to deal.
    private var pendingDeal: TimeInterval?

    /// Which chest is on screen. nil when the panel is closed.
    private(set) var openChest: ChestID?

    override init() {
        super.init()
        zPosition = 1100      // above the hotbar, which stays live underneath it
        isHidden = true

        let size = ChestPanelNode.size
        let panel = SKShapeNode(rect: CGRect(x: -size.width / 2, y: -size.height / 2,
                                             width: size.width, height: size.height),
                                cornerRadius: 22)
        panel.fillColor = RenderPalette.hudPanel
        addChild(panel)

        // A hairline of light along the edge, exactly as the shop wears. Small, and
        // it does more than it sounds: the panel and the map behind it are both
        // mid-toned, and without an edge the corners dissolve into whatever happens
        // to be under them.
        panel.strokeColor = SKColor(white: 1, alpha: 0.10)
        panel.lineWidth = 1

        for index in 0..<Inventory.slotCount {
            let slot = ItemSlotNode(side: ChestPanelNode.slotSize)
            slot.position = CGPoint(x: ChestPanelNode.centreX(of: index), y: 0)
            addChild(slot)
            slots.append(slot)
        }

        buildBackButton(inside: size)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private static func centreX(of index: Int) -> CGFloat {
        let inner = size.width - padding * 2
        return -inner / 2 + slotSize / 2 + CGFloat(index) * (slotSize + gap)
    }

    /// The way out: a round cross in the panel's own top-right corner.
    ///
    /// Built as well as declared, and the reason that is worth a note is the one
    /// the shop's version records: forgetting to build it does not fail to
    /// compile. The node exists either way, so isBackButton keeps happily measuring
    /// against it - and an unpositioned node sits at the origin, which for this
    /// panel is dead centre among the slots. The symptom is not a missing button,
    /// it is the chest closing when you tap an item.
    private func buildBackButton(inside size: CGSize) {
        let box = ChestPanelNode.backSize

        // ON the corner rather than inside it. The shop can sit its cross within
        // the panel because it has a header band to sit in; this panel is four
        // slots and their padding and nothing else, so a cross placed inside would
        // be drawn on top of the top-right slot. Straddling the corner keeps it
        // clear of the row - and clear of slotIndex, which claims everything
        // within a slot's height of the middle.
        back.position = CGPoint(x: size.width / 2 - 6, y: size.height / 2 + 6)

        let disc = SKShapeNode(circleOfRadius: box.width / 2)
        disc.fillColor = SKColor(white: 0, alpha: 0.4)
        disc.strokeColor = SKColor(white: 1, alpha: 0.3)
        disc.lineWidth = 1.5
        back.addChild(disc)

        // Two strokes rather than a glyph: a cross is four points, and a font
        // would have to be chosen for it.
        let arm = box.width * 0.24
        let path = CGMutablePath()
        path.move(to: CGPoint(x: -arm, y: -arm))
        path.addLine(to: CGPoint(x: arm, y: arm))
        path.move(to: CGPoint(x: -arm, y: arm))
        path.addLine(to: CGPoint(x: arm, y: -arm))

        let cross = SKShapeNode(path: path)
        cross.strokeColor = .white
        cross.lineWidth = 3
        cross.lineCap = .round
        back.addChild(cross)

        addChild(back)
    }

    // MARK: - Opening and closing

    /// Comes up rather than appearing.
    ///
    /// A panel this size arriving between two frames reads as a glitch - the eye
    /// gets no chance to follow where it came from, so it has to re-find everything
    /// on it. An eighth of a second of scale and fade is enough to be followed and
    /// short enough that nobody rummaging for a bandage notices they waited. The
    /// shop's exact timings, because they are the same act.
    func open(_ chest: ChestID) {
        openChest = chest
        lastContents = nil        // force a redraw for the new chest
        isHidden = false

        removeAction(forKey: "curtain")
        alpha = 0
        setScale(0.94)

        run(.group([.fadeIn(withDuration: 0.13),
                    .scale(to: 1, duration: 0.15)]),
            withKey: "curtain")

        pendingDeal = 0.06
    }

    func close() {
        openChest = nil

        // Out faster than in, which is the usual asymmetry: opening is something
        // you are about to read, closing is something you have finished with.
        // isHidden is set at the END rather than now, or the fade would have
        // nothing to fade.
        removeAction(forKey: "curtain")

        run(.sequence([
            .group([.fadeOut(withDuration: 0.09),
                    .scale(to: 0.96, duration: 0.09)]),
            .hide(),
            .run { [weak self] in self?.setScale(1) }
        ]), withKey: "curtain")
    }

    // MARK: - Answering a tap

    /// The move went through: wash the slot green and fly what left it.
    ///
    /// Driven by the SCENE rather than worked out here, which is the shape the shop
    /// already uses: a panel that decided for itself whether a tap had worked would
    /// be a second opinion about the same rules, and the two would eventually
    /// disagree.
    ///
    /// - Parameter destination: where the thing appears to go, in this panel's own
    ///   coordinates. The scene passes the hotbar, which is where your things live
    ///   - and the whole point of the flight is to say WHERE IT WENT.
    func confirm(slot index: Int, flyingTo destination: CGPoint) {
        guard slots.indices.contains(index) else { return }

        let slot = slots[index]
        if let art = slot.artwork {
            deliver(art, from: slot.position, to: destination)
        }
        slot.confirm()
    }

    /// Something arrived FROM the bag: fly it up into the slot it landed in, then
    /// wash that slot green.
    ///
    /// The mirror of confirm, and both exist because the two directions are the
    /// same gesture seen from either end. A chest that answered taking but not
    /// storing would read as a panel that only half worked.
    func receive(into index: Int,
                 from origin: CGPoint,
                 artwork: (texture: SKTexture, size: CGSize)) {
        guard slots.indices.contains(index) else { return }
        deliver(artwork, from: origin, to: slots[index].position)
        slots[index].confirm()
    }

    /// No room in the bag for what you tried to take.
    func refuse(slot index: Int) {
        guard slots.indices.contains(index) else { return }
        slots[index].refuse()
    }

    /// A line of red over the panel, for a refusal that is not about any one slot.
    ///
    /// The chest being full is the case: the tap landed on the HOTBAR, so the bar
    /// shakes - but the bar's own message would be drawn underneath this panel and
    /// never seen, because the panel sits on top of it and is taller than the gap.
    /// So the words come from whichever of the two is in front.
    func note(_ text: String) {
        childNode(withName: "note")?.removeFromParent()

        let holder = SKNode()
        holder.name = "note"
        holder.position = CGPoint(x: 0, y: ChestPanelNode.size.height / 2 + 26)
        holder.zPosition = 60
        addChild(holder)

        let label = SKLabelNode(fontNamed: "AvenirNext-Bold")
        label.text = text
        label.fontSize = 15
        label.fontColor = .white
        label.horizontalAlignmentMode = .center
        label.verticalAlignmentMode = .center
        label.zPosition = 1

        // Cut to the words rather than to a guessed width, the same way the hint
        // panel and the hotbar's own note are.
        let padding: CGFloat = 14
        let height = label.frame.height + padding
        let pill = SKShapeNode(rect: CGRect(x: -label.frame.width / 2 - padding,
                                            y: -height / 2,
                                            width: label.frame.width + padding * 2,
                                            height: height),
                               cornerRadius: height / 2)
        pill.fillColor = RenderPalette.placementBlocked
        pill.strokeColor = .clear

        holder.addChild(pill)
        holder.addChild(label)

        holder.setScale(0.7)
        holder.run(.sequence([
            .scale(to: 1, duration: 0.11),
            .wait(forDuration: 1.0),
            .fadeOut(withDuration: 0.25),
            .removeFromParent()
        ]))
    }

    /// A copy of the artwork, thrown along an arc from one place to another.
    ///
    /// Up and over: the peak sits above BOTH ends, so the parcel leaves rising
    /// rather than sliding sideways out of where it was. The shop's flight, and the
    /// same arc height, so a thing moving between your bag and a container looks
    /// the same wherever it is going.
    private func deliver(_ art: (texture: SKTexture, size: CGSize),
                         from origin: CGPoint,
                         to destination: CGPoint) {
        let parcel = SKSpriteNode(texture: art.texture)
        parcel.size = art.size
        parcel.position = origin
        parcel.zPosition = 50
        addChild(parcel)

        let path = CGMutablePath()
        path.move(to: origin)
        path.addQuadCurve(to: destination,
                          control: CGPoint(x: (origin.x + destination.x) / 2,
                                           y: max(origin.y, destination.y) + 60))

        parcel.run(.sequence([
            .group([
                .follow(path, asOffset: false, orientToPath: false, duration: 0.34),
                .scale(to: 0.55, duration: 0.34),
                .sequence([.wait(forDuration: 0.2), .fadeOut(withDuration: 0.14)])
            ]),
            .removeFromParent()
        ]))
    }

    /// Slides the slots in, one just after another.
    ///
    /// A stagger rather than all at once, and only 30 milliseconds of it. Together
    /// they read as a chest being tipped out - which is what opening one is - where
    /// simultaneous movement reads as the panel twitching.
    private func dealSlots(from delay: TimeInterval) {
        for (index, slot) in slots.enumerated() {
            slot.removeAction(forKey: "deal")

            let home = slot.position
            slot.alpha = 0
            slot.position = CGPoint(x: home.x, y: home.y - 12)

            slot.run(.sequence([
                .wait(forDuration: delay + Double(index) * 0.03),
                .group([.fadeAlpha(to: 1, duration: 0.12),
                        .move(to: home, duration: 0.14)])
            ]), withKey: "deal")
        }
    }

    /// Redraws, and reports whether the chest is still there to be looked at.
    ///
    /// The panel asks the world rather than remembering what it was shown, so a
    /// chest that stops existing - or that you are shoved away from - closes itself
    /// rather than leaving a picture of something you can no longer reach.
    @discardableResult
    func update(with world: World) -> Bool {
        guard let id = openChest,
              let chest = world.chests[id],
              let player = world.localPlayer,
              player.isAlive,
              ChestSystem.canReach(chest, from: player) else {
            if openChest != nil { close() }
            return false
        }

        if let delay = pendingDeal {
            pendingDeal = nil
            lastContents = nil          // the deal needs the slots drawn first
            redraw(chest.contents)
            dealSlots(from: delay)
            return true
        }

        guard chest.contents != lastContents else { return true }
        redraw(chest.contents)
        return true
    }

    private func redraw(_ contents: Inventory) {
        lastContents = contents
        for (index, stack) in contents.slots.enumerated() {
            slots[index].show(stack)
        }
    }

    // MARK: - Hit testing

    func slotIndex(atLocalPoint point: CGPoint) -> Int? {
        let half = ChestPanelNode.slotSize / 2
        guard abs(point.y) <= half + ChestPanelNode.padding else { return nil }

        for index in 0..<Inventory.slotCount {
            let centreX = ChestPanelNode.centreX(of: index)
            if abs(point.x - centreX) <= half + ChestPanelNode.gap / 2 { return index }
        }

        return nil
    }

    func artwork(inSlot index: Int) -> (texture: SKTexture, size: CGSize)? {
        guard slots.indices.contains(index) else { return nil }
        return slots[index].artwork
    }

    /// Whether a point in this node's own space is on the chest at all.
    ///
    /// The panel and the button above it, and nothing else. What counts as OUTSIDE
    /// is everything this does not claim - see GameScene, which closes the chest on
    /// a tap out there, exactly as the shop does.
    func contains(localPoint point: CGPoint) -> Bool {
        let box = ChestPanelNode.size

        if abs(point.x) <= box.width / 2, abs(point.y) <= box.height / 2 { return true }
        return isBackButton(atLocalPoint: point)
    }

    func isBackButton(atLocalPoint point: CGPoint) -> Bool {
        let box = ChestPanelNode.backSize
        let local = CGPoint(x: point.x - back.position.x, y: point.y - back.position.y)
        // Grown a little: it is a small target and a miss keeps you stuck in a menu.
        return abs(local.x) <= box.width / 2 + 12 && abs(local.y) <= box.height / 2 + 12
    }
}
