//
//  ShopPanelNode.swift
//  Loot Wars
//
//  Spending tokens: one page, four cards, a header and a way out.
//
//  ONE PAGE, and that is the change this file exists in its current shape for. It
//  had tabs - GEAR and HEALING - and tabs are a way of hiding half a shop from
//  somebody who is standing in the open with the game running. Everything this shop
//  will ever sell is a helmet rung, a blaster rung, a bandage and a medkit: four
//  things, which is not enough to be worth paging through. The tab strip cost a
//  tap, a heading and thirty points of height to organise four items nobody needed
//  organised.
//
//  The HOTBAR is hidden while this is up, which is the other half of the same idea.
//  The bar used to double as the sell counter here, and it meant the shop was two
//  interfaces stacked on top of each other with different rules - tap a card to
//  buy, tap a slot to sell. Selling now lives where it belongs, on the bar during
//  play: hold an item and it turns into tokens. So the shop is exactly one thing,
//  and while it is open nothing else is on screen competing to be read.
//
//  Cards are laid out in ONE ROW, which is how a shelf is read: everything the shop
//  sells is in your eye at once, at the same size, and choosing is a glance along a
//  line rather than a scan around a block. The layout is still written as a grid -
//  as many columns as there are things to sell - so a fifth item would start a
//  second row rather than run off the side of a phone, and each row is centred on
//  its own, which is what gives a player who has topped out a ladder three
//  deliberate cards instead of a hole where the fourth was.
//
//  Exactly one thing greys a card out: a machine you already own, which the shop
//  will not sell you a second of however rich you get. Nothing else does - not the
//  price, not a full bag - because those are facts about YOU, they change minute to
//  minute, and greying the shelf out for them had the shop looking permanently
//  shut. The tap carries the rest: it asks ShopSystem.canBuy and shakes the card
//  when the answer is no.
//

import SpriteKit

final class ShopPanelNode: SKNode {

    // MARK: - Measurements

    /// Sized against the smallest phone this runs on - an SE is 568 x 320 in
    /// landscape, with no safe-area inset to give away - so a 530-wide panel leaves
    /// 19 points of margin either side there and a great deal more on everything
    /// newer. It is the row of four that sets that width, and the width that sets
    /// how tall a card has to be.
    ///
    /// The HEIGHT has a harder limit than it looks: 230 points is what fits between
    /// the bottom of the HUD and the bottom of an SE's screen, and the panel is
    /// hung in exactly that gap - see GameScene.layOutUI - so that health and
    /// tokens stay readable while you are deciding what to spend them on. Every
    /// point of it went into the cards rather than the frame: the padding and the
    /// header came in, the cards grew by nearly a fifth.
    ///
    /// ONE ROW. Four cards side by side is how a shelf is read: everything the shop
    /// sells is in your eye at once, at the same size, and choosing between them is
    /// a glance along a line rather than a scan around a block. It costs the cards
    /// their width - 112 points is not enough to put a picture beside its words, so
    /// they go back to being portrait, picture over name over price - and that is
    /// the trade, taken deliberately.
    private static let cardSize = CGSize(width: 106, height: 164)
    private static let cardGap: CGFloat = 10
    private static let padding: CGFloat = 14
    private static let headerHeight: CGFloat = 38

    /// As many columns as there are things to sell, which is what makes it a row.
    ///
    /// Written as the grid it still is rather than as a special case: home() lays
    /// cards out left to right and wraps, so a fifth item added to this shop would
    /// start a second row on its own instead of running off the side of a phone.
    private static var columns: Int { max(1, slots) }

    /// Every card the shop could ever need at once: both gear rungs plus the shelf.
    private static var slots: Int { GameConfig.Shop.catalogueSize }

    private static var rows: Int {
        max(1, Int(ceil(Double(slots) / Double(columns))))
    }

    static var panelSize: CGSize {
        CGSize(
            width: padding * 2
                + cardSize.width * CGFloat(columns)
                + cardGap * CGFloat(columns - 1),
            height: padding * 2
                + headerHeight
                + cardSize.height * CGFloat(rows)
                + cardGap * CGFloat(rows - 1)
        )
    }

    private static let backSize = CGSize(width: 38, height: 38)

    // MARK: - Parts

    private struct Card {
        let holder: SKNode

        /// A pool of the item's rarity colour behind the artwork - the same
        /// language the hotbar and the ground use, rather than a coloured panel.
        let glow: SKSpriteNode

        let icon: SKSpriteNode
        let name: SKLabelNode
        let price: SKLabelNode
        let pill: SKShapeNode

        /// The darker lip under the price button. Recoloured with it, and the
        /// reason the button reads as something you press rather than a label.
        let bevel: SKShapeNode

        /// Lit for a moment when the sale goes through. Its own node rather than a
        /// colour on the plate, because the plate's fill and the holder's alpha are
        /// both rewritten by the next redraw - which lands on the same frame as the
        /// purchase, and would wipe the confirmation before it was seen.
        let flash: SKShapeNode

        var type: ItemType?

        /// Which of your slots this card is selling, in the SELL tab.
        var slot: Int?
    }

    /// The two halves of the shop: what it sells you, and what it will buy off
    /// you. One at a time, behind two tabs in the header - selling used to be the
    /// hotbar sprouting prices UNDER the panel while it was open, which was two
    /// interfaces with two rules on one screen. A tab is one interface that can
    /// be pointed at either.
    enum Mode { case buy, sell }

    private(set) var mode: Mode = .buy

    private struct Tab {
        let mode: Mode
        let node: SKNode
        let plate: SKShapeNode
        let label: SKLabelNode
    }

    private var tabs: [Tab] = []

    /// The picture on a SELL card at the moment it was tapped. The sale lands a
    /// frame later, by which time the card may already be showing the next thing
    /// in your bag - so what flies into the purse is taken from here.
    private var saleSnapshot: (texture: SKTexture, size: CGSize, at: CGPoint)?
    private static let tabSize = CGSize(width: 82, height: 28)

    /// Said in the SELL tab when there is nothing in your bag.
    private let emptyNote = SKLabelNode(fontNamed: "AvenirNext-Bold")

    private let panel = SKShapeNode()
    private let back = SKNode()

    /// The cards, on a layer that slides sideways between BUY and SELL - see
    /// drag(by:) - cut to the panel so they slide out of sight at its edges.
    private let crop = SKCropNode()
    private let deck = SKNode()

    /// How far a swipe has to travel to turn the page, in points. Short of it,
    /// the cards spring back.
    private static let swipeToTurn: CGFloat = 70
    private let purse = SKLabelNode(fontNamed: "AvenirNext-Bold")

    private var cards: [Card] = []

    private(set) var isOpen = false
    private var lastDrawn: [Int] = []

    /// The card the finger last landed on.
    ///
    /// Remembered rather than matched by item, because the card does not always
    /// still hold what you bought: buying a Rare helmet redraws that slot as an
    /// Epic, so by the time the sale is confirmed there is nothing on the panel
    /// with the bought item's name on it. The position is the thing that stays put.
    ///
    /// It SURVIVES A REDRAW, and that is the whole reason a purchase ever animated.
    /// The redraw used to clear this, which looked harmless and was not: a purchase
    /// changes your token count, the count is in the fingerprint, so buying
    /// anything redrew the panel - and the scene drains world events AFTER it syncs
    /// the renderers, so by the time the purchase arrived the card that had been
    /// pressed was already forgotten and confirm() quietly did nothing. Cleared on
    /// a tap, an open and a close instead, which are the three moments it actually
    /// stops meaning anything.
    private var lastPressed: Int?

    /// A deal waiting for the next redraw, and how long to hold it first.
    ///
    /// Set by open, spent by update. It cannot fire from open directly: dealing
    /// animates each card from just below its HOME, and the home is whatever the
    /// redraw is about to put it at.
    private var pendingDeal: TimeInterval?

    // MARK: - Building

    override init() {
        super.init()

        zPosition = 1100
        isHidden = true

        let size = ShopPanelNode.panelSize

        panel.path = CGPath(
            roundedRect: CGRect(
                x: -size.width / 2,
                y: -size.height / 2,
                width: size.width,
                height: size.height
            ),
            cornerWidth: 22,
            cornerHeight: 22,
            transform: nil
        )

        panel.fillColor = RenderPalette.hudPanel

        // A thin edge, the same as every in-match control. Small, and it does more
        // than it sounds: the panel and the map behind it are both mid-toned, and
        // without an edge the corners dissolve into whatever is under them.
        panel.strokeColor = RenderPalette.glassRim
        panel.lineWidth = RenderPalette.glassRimWidth

        // Frosted map behind it - see GlassNode.
        if let path = panel.path { panel.addChild(GlassNode(path: path)) }

        addChild(panel)

        let window = SKShapeNode(path: panel.path ?? CGPath(rect: .zero, transform: nil))
        window.fillColor = .white
        window.strokeColor = .clear
        crop.maskNode = window
        crop.zPosition = 1
        crop.addChild(deck)
        addChild(crop)

        buildHeader(inside: size)
        buildTabs(inside: size)

        for index in 0..<ShopPanelNode.slots {
            cards.append(makeCard(at: index))
        }

        buildCloseButton(inside: size)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// What is in your pocket, and a band under it.
    ///
    /// No title. A panel with four things for sale on it, that opened because you
    /// pressed the shop button, does not need the word SHOP written across the top
    /// - it was the one thing up there saying something the player already knew.
    /// The purse takes its place at the left, which is where the eye lands first:
    /// every card on this panel is a question about whether you can afford
    /// something, and the answer used to live in the opposite corner of the screen,
    /// behind the panel you were reading.
    private func buildHeader(inside size: CGSize) {
        let top = size.height / 2
        let centreY = top - ShopPanelNode.headerHeight / 2 - 4

        let band = SKShapeNode(
            rect: CGRect(
                x: -size.width / 2 + 8,
                y: top - ShopPanelNode.headerHeight - 8,
                width: size.width - 16,
                height: ShopPanelNode.headerHeight
            ),
            cornerRadius: 14
        )

        band.fillColor = SKColor(white: 1, alpha: 0.07)
        band.strokeColor = .clear
        addChild(band)

        let left = -size.width / 2 + ShopPanelNode.padding + 6

        let texture = ItemArt.texture(for: Pickup.token(1))
        let coin = SKSpriteNode(texture: texture)

        coin.size = ItemArt.size(of: texture, fittingInto: 26)
        coin.position = CGPoint(x: left + 13, y: centreY)
        addChild(coin)

        // Bigger than it was in the corner it came from: it is the only number on
        // this header now, and the one every card is asking about.
        purse.fontSize = 21
        purse.fontColor = .white
        purse.horizontalAlignmentMode = .left
        purse.verticalAlignmentMode = .center
        purse.position = CGPoint(x: left + 34, y: centreY)
        addChild(purse)
    }

    /// The way out: a round cross in the panel's own top-right corner.
    ///
    /// It has to be BUILT as well as declared, and the reason that is worth a note
    /// is that forgetting to build it does not fail to compile. The node exists
    /// either way, so isBackButton keeps happily measuring against it - and an
    /// unpositioned node sits at the origin, which for this panel is dead centre
    /// among the cards. The symptom is not a missing button, it is the shop
    /// closing when you tap an item.
    private func buildTabs(inside size: CGSize) {
        let centreY = size.height / 2 - ShopPanelNode.headerHeight / 2 - 4
        let box = ShopPanelNode.tabSize
        let gap: CGFloat = 6

        for (index, mode) in [Mode.buy, Mode.sell].enumerated() {
            let node = SKNode()
            node.position = CGPoint(x: (CGFloat(index) - 0.5) * (box.width + gap), y: centreY)
            node.zPosition = 2

            let plate = SKShapeNode(rect: CGRect(x: -box.width / 2, y: -box.height / 2,
                                                 width: box.width, height: box.height),
                                    cornerRadius: box.height / 2)
            plate.strokeColor = .clear
            node.addChild(plate)

            let label = SKLabelNode(fontNamed: "AvenirNext-Bold")
            label.text = mode == .buy ? "BUY" : "SELL"
            label.fontSize = 14
            label.horizontalAlignmentMode = .center
            label.verticalAlignmentMode = .center
            label.zPosition = 1
            node.addChild(label)

            addChild(node)
            tabs.append(Tab(mode: mode, node: node, plate: plate, label: label))
        }

        emptyNote.text = "NOTHING TO SELL"
        emptyNote.fontSize = 18
        emptyNote.fontColor = SKColor(white: 1, alpha: 0.55)
        emptyNote.horizontalAlignmentMode = .center
        emptyNote.verticalAlignmentMode = .center
        emptyNote.position = CGPoint(x: 0, y: -ShopPanelNode.headerHeight / 2)
        emptyNote.isHidden = true
        deck.addChild(emptyNote)

        drawTabs()
    }

    /// The chosen tab lit white, the other a quiet outline-free label.
    private func drawTabs() {
        for tab in tabs {
            let chosen = tab.mode == mode
            tab.plate.fillColor = chosen ? SKColor(white: 1, alpha: 0.92) : SKColor(white: 1, alpha: 0.08)
            tab.label.fontColor = chosen ? RenderPalette.hudPanel : SKColor(white: 1, alpha: 0.75)
        }
    }

    /// Switches between buying and selling by sliding the page across: BUY
    /// sits to the left of SELL, so going to SELL slides the cards off to the
    /// left and the new ones in from the right, and back the other way.
    ///
    /// - Parameter from: where the cards already are, if a swipe has dragged
    ///   them part of the way.
    func setMode(_ mode: Mode, from offset: CGFloat = 0) {
        guard mode != self.mode else {
            settleDeck()
            return
        }
        let width = ShopPanelNode.panelSize.width
        let leaving: CGFloat = mode == .sell ? -width : width

        deck.removeAction(forKey: "slide")
        deck.position.x = offset

        let out = SKAction.moveTo(x: leaving, duration: 0.14)
        out.timingMode = .easeIn
        let inbound = SKAction.moveTo(x: 0, duration: 0.2)
        inbound.timingMode = .easeOut

        deck.run(.sequence([
            out,
            .run { [weak self] in
                guard let self else { return }
                self.mode = mode
                self.lastDrawn = []
                self.lastPressed = nil
                self.drawTabs()
                self.deck.position.x = -leaving
            },
            // A frame for the redraw, so the old cards never slide back in.
            .wait(forDuration: 0.02),
            inbound
        ]), withKey: "slide")
    }

    // MARK: - Swiping

    /// Follows a sideways swipe across the cards. Towards the other page it moves
    /// with the finger; the other way there is nothing to go to, so it gives a
    /// little and no more.
    func drag(by dx: CGFloat) {
        deck.removeAction(forKey: "slide")
        let towardsOther = mode == .buy ? dx < 0 : dx > 0
        deck.position.x = towardsOther ? dx : dx * 0.25
    }

    /// The finger has come off after a swipe: turns the page if it went far
    /// enough towards the other one, springs back if not.
    ///
    /// - Returns: the page it turned to, or nil.
    @discardableResult
    func endDrag(by dx: CGFloat) -> Mode? {
        let other: Mode = mode == .buy ? .sell : .buy
        let towardsOther = mode == .buy ? dx < 0 : dx > 0
        guard towardsOther, abs(dx) >= ShopPanelNode.swipeToTurn else {
            settleDeck()
            return nil
        }
        setMode(other, from: deck.position.x)
        return other
    }

    /// Springs the cards back to where they belong.
    private func settleDeck() {
        guard deck.position.x != 0 else { return }
        deck.removeAction(forKey: "slide")
        let home = SKAction.moveTo(x: 0, duration: 0.18)
        home.timingMode = .easeOut
        deck.run(home, withKey: "slide")
    }

    private func buildCloseButton(inside size: CGSize) {
        let box = ShopPanelNode.backSize

        back.position = CGPoint(
            x: size.width / 2 - box.width / 2 - 12,
            y: size.height / 2 - box.height / 2 - 10
        )

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

    /// Where a card sits when `count` of them are showing.
    ///
    /// Filled left to right, top to bottom, with each ROW centred on its own. Four
    /// cards make a block; three make a full row above a single centred card, which
    /// is a deliberate arrangement rather than a gap where something used to be -
    /// and three is what the shop shows the moment anybody tops out a ladder.
    private static func home(of index: Int, outOf count: Int) -> CGPoint {
        let card = cardSize
        let row = index / columns
        let column = index % columns

        let inRow = min(columns, count - row * columns)
        let spread = card.width * CGFloat(inRow) + cardGap * CGFloat(inRow - 1)

        let usedRows = max(1, Int(ceil(Double(count) / Double(columns))))
        let block = card.height * CGFloat(usedRows) + cardGap * CGFloat(usedRows - 1)

        // The cards own everything below the header, and sit centred in it.
        let top = panelSize.height / 2 - headerHeight - padding
        let bottom = -panelSize.height / 2 + padding
        let middle = (top + bottom) / 2

        return CGPoint(
            x: -spread / 2 + card.width / 2 + CGFloat(column) * (card.width + cardGap),
            y: middle + block / 2 - card.height / 2
                - CGFloat(row) * (card.height + cardGap)
        )
    }

    /// A card is read top to bottom: what it is, what it is called, what it costs.
    ///
    /// Portrait, because the row of four leaves it 112 points of width and a
    /// picture beside its words needs nearly twice that. On a narrow card the
    /// stack is not a compromise anyway - it is how a shelf label works, and the
    /// eye running down one card and along to the next is the same motion it makes
    /// in a shop.
    private func makeCard(at index: Int) -> Card {
        let card = ShopPanelNode.cardSize
        let holder = SKNode()

        holder.position = ShopPanelNode.home(of: index, outOf: ShopPanelNode.slots)
        deck.addChild(holder)

        let outline = CGPath(
            roundedRect: CGRect(
                x: -card.width / 2,
                y: -card.height / 2,
                width: card.width,
                height: card.height
            ),
            cornerWidth: 14,
            cornerHeight: 14,
            transform: nil
        )

        let plate = SKShapeNode(path: outline)
        plate.fillColor = SKColor(white: 1, alpha: 0.10)
        plate.strokeColor = SKColor(white: 1, alpha: 0.10)
        plate.lineWidth = 1
        holder.addChild(plate)

        let flash = SKShapeNode(path: outline)
        flash.fillColor = RenderPalette.placementValid
        flash.strokeColor = RenderPalette.placementValid
        flash.lineWidth = 3
        flash.alpha = 0
        flash.zPosition = 5
        holder.addChild(flash)

        // The picture, on its own tile at the top.
        let tileCentre = CGPoint(x: 0, y: card.height / 2 - 44)

        let tile = SKShapeNode(
            path: CGPath(
                roundedRect: CGRect(x: -33, y: -33, width: 66, height: 66),
                cornerWidth: 14,
                cornerHeight: 14,
                transform: nil
            )
        )

        tile.fillColor = SKColor(white: 1, alpha: 0.14)
        tile.strokeColor = .clear
        tile.position = tileCentre
        holder.addChild(tile)

        let glow = SKSpriteNode(texture: GlowArt.pool)
        glow.size = CGSize(width: 80, height: 80)
        glow.colorBlendFactor = 1
        glow.alpha = 0.7
        glow.position = tileCentre
        glow.zPosition = 0.5
        holder.addChild(glow)

        let icon = SKSpriteNode()
        icon.position = tileCentre
        icon.zPosition = 1
        holder.addChild(icon)

        let name = SKLabelNode(fontNamed: "AvenirNext-Bold")
        name.fontSize = 16
        name.fontColor = .white
        name.horizontalAlignmentMode = .center
        name.verticalAlignmentMode = .center
        name.position = CGPoint(x: 0, y: -card.height / 2 + 74)
        holder.addChild(name)

        // The price button: a solid capsule sitting on the bottom margin like a
        // price tag on a shelf edge.
        //
        // SOLID, with a darker lip under it and no outline at all. Both of the
        // other things tried here are worth writing down. A black outline read as
        // an OBJECT: black rings are how this game draws things in the world - the
        // token, the crates, the figures - so a black-ringed capsule looked like
        // loot lying on a card rather than a control. And a dark plate with a
        // coloured edge, borrowed from the quick-buy prompt, lost the one thing the
        // solid version does best: at a glance across four cards, green and red
        // ARE the answer, and a thin edge makes you look twice to read it.
        //
        // What the bevel adds is the press. A flat shape with a darker shade along
        // its bottom edge is the whole of how a button is drawn in a game that
        // looks like this one, and it costs one more node.
        let pillWidth = card.width - 20
        let pillCentre = CGPoint(x: 0, y: -card.height / 2 + 29)

        func capsule(offsetBy drop: CGFloat) -> SKShapeNode {
            SKShapeNode(
                path: CGPath(
                    roundedRect: CGRect(
                        x: pillCentre.x - pillWidth / 2,
                        y: pillCentre.y - 16 - drop,
                        width: pillWidth,
                        height: 32
                    ),
                    cornerWidth: 16,
                    cornerHeight: 16,
                    transform: nil
                )
            )
        }

        let bevel = capsule(offsetBy: 3)
        bevel.fillColor = RenderPalette.affordableDeep
        bevel.strokeColor = .clear
        holder.addChild(bevel)

        // Both fills are recoloured on every redraw - see update.
        let pill = capsule(offsetBy: 0)
        pill.fillColor = RenderPalette.affordable
        pill.strokeColor = .clear
        holder.addChild(pill)

        // The coin and the number are CENTRED as a pair rather than pinned to the
        // ends of the pill: at this width a number pushed to one edge and a coin to
        // the other reads as two things that happen to share a capsule.
        let tokenTexture = ItemArt.texture(for: Pickup.token(1))
        let token = SKSpriteNode(texture: tokenTexture)

        token.size = ItemArt.size(of: tokenTexture, fittingInto: 21)
        token.position = CGPoint(x: pillCentre.x + 10, y: pillCentre.y)
        token.zPosition = 1
        holder.addChild(token)

        let price = SKLabelNode(fontNamed: "AvenirNext-Bold")
        // Number first, coin after it - the way a price is spoken. The pair is
        // centred on the button rather than pushed to its ends, which at this width
        // is the difference between one price and two things sharing a capsule.
        price.fontSize = 18
        price.fontColor = .white
        price.horizontalAlignmentMode = .right
        price.verticalAlignmentMode = .center
        price.position = CGPoint(x: pillCentre.x - 4, y: pillCentre.y)
        price.zPosition = 1
        holder.addChild(price)

        return Card(
            holder: holder,
            glow: glow,
            icon: icon,
            name: name,
            price: price,
            pill: pill,
            bevel: bevel,
            flash: flash,
            type: nil
        )
    }

    // MARK: - Opening

    func open() {
        isOpen = true
        isHidden = false
        lastDrawn = []
        lastPressed = nil

        // Always opens on BUY, which is what nearly every visit is for.
        mode = .buy
        drawTabs()
        deck.removeAction(forKey: "slide")
        deck.position = .zero

        // Comes up rather than appearing. A panel this size arriving between two
        // frames reads as a glitch - the eye gets no chance to follow where it came
        // from, so it has to re-find everything on it. An eighth of a second of
        // scale and fade is enough to be followed and short enough that nobody
        // waiting to buy a bandage notices they waited.
        removeAction(forKey: "curtain")
        alpha = 0
        setScale(0.94)

        run(
            .group([
                .fadeIn(withDuration: 0.13),
                .scale(to: 1, duration: 0.15)
            ]),
            withKey: "curtain"
        )

        pendingDeal = 0.06
    }

    func close() {
        isOpen = false
        lastPressed = nil

        // Out faster than in, which is the usual asymmetry: opening is something
        // you are about to read, closing is something you have finished with.
        // isHidden is set at the END rather than now, or the fade would have
        // nothing to fade.
        removeAction(forKey: "curtain")

        run(
            .sequence([
                .group([
                    .fadeOut(withDuration: 0.09),
                    .scale(to: 0.96, duration: 0.09)
                ]),
                .hide(),
                .run { [weak self] in self?.setScale(1) }
            ]),
            withKey: "curtain"
        )
    }

    // MARK: - Hit testing

    func isBackButton(atLocalPoint point: CGPoint) -> Bool {
        let box = ShopPanelNode.backSize

        let local = CGPoint(
            x: point.x - back.position.x,
            y: point.y - back.position.y
        )

        // A generous margin round a small target, which is the whole reason a
        // 38-point button is allowed to be this small: the hit box is 66.
        return abs(local.x) <= box.width / 2 + 14
            && abs(local.y) <= box.height / 2 + 14
    }

    /// Whether a point in this node's own space is on the shop at all. A tap
    /// anywhere else is a tap outside, and closes the shop.
    func contains(localPoint point: CGPoint) -> Bool {
        let size = ShopPanelNode.panelSize

        return abs(point.x) <= size.width / 2
            && abs(point.y) <= size.height / 2
    }

    /// Which tab a tap landed on, or nil. A generous margin, like the close
    /// button's.
    func tab(atLocalPoint point: CGPoint) -> Mode? {
        let box = ShopPanelNode.tabSize
        for tab in tabs {
            if abs(point.x - tab.node.position.x) <= box.width / 2 + 3,
               abs(point.y - tab.node.position.y) <= box.height / 2 + 8 {
                return tab.mode
            }
        }
        return nil
    }

    /// Which of your slots a tap in the SELL tab landed on, or nil.
    func sellSlot(atLocalPoint point: CGPoint) -> Int? {
        guard mode == .sell else { return nil }
        guard let index = cardIndex(atLocalPoint: point) else {
            lastPressed = nil
            return nil
        }
        lastPressed = index

        let card = cards[index]
        saleSnapshot = card.icon.texture.map {
            (texture: $0, size: card.icon.size,
             at: CGPoint(x: card.holder.position.x + card.icon.position.x,
                         y: card.holder.position.y + card.icon.position.y))
        }
        return card.slot
    }

    private func cardIndex(atLocalPoint point: CGPoint) -> Int? {
        let card = ShopPanelNode.cardSize
        for (index, entry) in cards.enumerated()
        where entry.type != nil && !entry.holder.isHidden {
            if abs(point.x - entry.holder.position.x) <= card.width / 2,
               abs(point.y - entry.holder.position.y) <= card.height / 2 {
                return index
            }
        }
        return nil
    }

    /// Which item a tap landed on, or nil.
    func item(atLocalPoint point: CGPoint) -> ItemType? {
        guard mode == .buy else { return nil }
        let card = ShopPanelNode.cardSize

        for (index, entry) in cards.enumerated()
        where entry.type != nil && !entry.holder.isHidden {

            let local = CGPoint(
                x: point.x - entry.holder.position.x,
                y: point.y - entry.holder.position.y
            )

            if abs(local.x) <= card.width / 2,
               abs(local.y) <= card.height / 2 {

                lastPressed = index
                return entry.type
            }
        }

        lastPressed = nil
        return nil
    }

    // MARK: - Answering a tap

    /// The card that was pressed shakes, and washes over in a colour.
    ///
    /// ONE movement for both answers, and the colour is what tells them apart. That
    /// is deliberate rather than lazy: what the shake says is "your tap landed on
    /// THIS card", which is equally true of a yes and a no, and the eye reads a
    /// wash of green or red faster than it reads any difference between two
    /// wobbles. Two motions meant learning two motions.
    ///
    /// A wobble rather than a slide, and that is not a stylistic choice. The redraw
    /// owns card POSITION - it is what puts a card in its place - so a moveBy
    /// interrupted by a redraw would fight it and could leave the card parked where
    /// it used to be. Rotation and scale are nobody else's, so an interrupted
    /// wobble can only ever end where it started.
    private func shake(_ card: Card, washedIn colour: SKColor, strength: CGFloat) {
        card.holder.removeAction(forKey: "bought")
        card.holder.setScale(1)
        card.holder.zRotation = 0

        card.holder.run(
            .sequence([
                .group([
                    .rotate(toAngle: -0.055, duration: 0.05),
                    .scale(to: 0.95, duration: 0.05)
                ]),
                .rotate(toAngle: 0.055, duration: 0.09),
                .rotate(toAngle: -0.035, duration: 0.07),
                .group([
                    .rotate(toAngle: 0, duration: 0.06),
                    .scale(to: 1.0, duration: 0.06)
                ])
            ]),
            withKey: "bought"
        )

        card.flash.removeAllActions()
        card.flash.fillColor = colour
        card.flash.strokeColor = colour
        card.flash.alpha = strength
        card.flash.run(.fadeAlpha(to: 0, duration: 0.42))
    }

    /// The sale was refused: shake the card red.
    ///
    /// The other half of not greying cards out for a full bag. Something has to
    /// answer a tap that cannot go through, and a card that simply sat there would
    /// be the shop looking broken rather than the shop saying no.
    func refuse() {
        guard let index = lastPressed,
              cards.indices.contains(index) else {
            return
        }

        shake(cards[index], washedIn: RenderPalette.placementBlocked, strength: 0.38)
        lastPressed = nil
    }

    /// The sale went through: light the card that was pressed.
    ///
    /// Driven by the world rather than by the tap, so a card that was pressed and
    /// refused stays dark. Nothing here decides whether the purchase happened - it
    /// is told.
    ///
    /// - Parameter destination: where the thing you bought should appear to go, in
    ///   this panel's own coordinates. The scene passes the hotbar's position -
    ///   hidden behind the panel while the shop is up, but still where your things
    ///   live, and the whole point of the flight is to say WHERE IT WENT.
    func confirm(flyingTo destination: CGPoint) {
        guard let index = lastPressed,
              cards.indices.contains(index) else {
            return
        }

        let card = cards[index]
        deliver(card, to: destination)
        pulse(card)

        // The same shake the refusal uses, washed green instead of red - and
        // harder, because this is the good one. A purchase is the thing you came
        // to the shop to do and it used to be the quieter of the two answers.
        shake(card, washedIn: RenderPalette.placementValid, strength: 0.6)

        lastPressed = nil
    }

    /// A green ring thrown off the card that was just bought from.
    ///
    /// The card's own outline, growing outwards and fading - so the confirmation
    /// starts at the exact shape you tapped and leaves it, which is what makes it
    /// read as coming FROM the card rather than being drawn on top of one. Built
    /// fresh each time and thrown away after: it exists for a third of a second and
    /// a node kept around for that would be a node to keep in sync with a card
    /// whose contents change every purchase.
    /// A sale went through: the item flies into the purse and the card flashes
    /// green, the same answer a purchase gets in the other direction.
    func confirmSale() {
        guard let index = lastPressed, cards.indices.contains(index) else { return }

        let card = cards[index]
        if let snapshot = saleSnapshot {
            fly(snapshot.texture, size: snapshot.size, from: snapshot.at,
                to: CGPoint(x: purse.position.x - 21, y: purse.position.y))
        }
        saleSnapshot = nil
        shake(card, washedIn: RenderPalette.placementValid, strength: 0.6)

        purse.removeAction(forKey: "paid")
        purse.setScale(1)
        purse.run(.sequence([.scale(to: 1.25, duration: 0.08),
                             .scale(to: 1, duration: 0.14)]), withKey: "paid")

        lastPressed = nil
    }

    private func pulse(_ card: Card) {
        let size = ShopPanelNode.cardSize

        let ring = SKShapeNode(
            path: CGPath(
                roundedRect: CGRect(
                    x: -size.width / 2,
                    y: -size.height / 2,
                    width: size.width,
                    height: size.height
                ),
                cornerWidth: 14,
                cornerHeight: 14,
                transform: nil
            )
        )

        ring.fillColor = .clear
        ring.strokeColor = RenderPalette.affordable
        ring.lineWidth = 3
        ring.zPosition = 6
        card.holder.addChild(ring)

        ring.run(
            .sequence([
                .group([
                    .scale(to: 1.18, duration: 0.34),
                    .sequence([
                        .wait(forDuration: 0.06),
                        .fadeOut(withDuration: 0.28)
                    ])
                ]),
                .removeFromParent()
            ])
        )
    }

    /// Throws a copy of the item from its card down to the bag.
    ///
    /// A copy rather than the icon itself: the card behind it is still a shop card
    /// and is about to be redrawn with the next rung on it, so the thing that flies
    /// has to be something nobody else owns.
    ///
    /// Arced rather than moved in a straight line. A straight line between two
    /// points on a screen reads as a UI element being repositioned; a curve reads
    /// as an object being thrown, and the difference is most of why this feels like
    /// a purchase rather than a layout change.
    private func deliver(_ card: Card, to destination: CGPoint) {
        guard let texture = card.icon.texture else { return }

        fly(texture, size: card.icon.size,
            from: CGPoint(x: card.holder.position.x + card.icon.position.x,
                          y: card.holder.position.y + card.icon.position.y),
            to: destination)
    }

    /// A copy of a picture, flown in an arc and shrunk to nothing.
    private func fly(_ texture: SKTexture, size: CGSize, from start: CGPoint,
                     to destination: CGPoint) {
        let parcel = SKSpriteNode(texture: texture)
        parcel.size = size
        parcel.position = start
        parcel.zPosition = 50
        addChild(parcel)

        let path = CGMutablePath()
        path.move(to: parcel.position)

        // Up and over: the peak sits above BOTH ends, so the parcel leaves the card
        // rising rather than sliding sideways out of it.
        path.addQuadCurve(
            to: destination,
            control: CGPoint(
                x: (parcel.position.x + destination.x) / 2,
                y: max(parcel.position.y, destination.y) + 70
            )
        )

        parcel.run(
            .sequence([
                .group([
                    .follow(path, asOffset: false, orientToPath: false, duration: 0.42),
                    .scale(to: 0.45, duration: 0.42),
                    .sequence([
                        .wait(forDuration: 0.26),
                        .fadeOut(withDuration: 0.16)
                    ])
                ]),
                .removeFromParent()
            ])
        )
    }

    /// Slides the visible cards in, one just after another.
    ///
    /// A stagger rather than all at once, and only 30 milliseconds of it. Together
    /// they read as a hand being dealt - which is what opening a shop is - where
    /// simultaneous movement reads as the panel twitching.
    private func dealCards(from delay: TimeInterval) {
        for (index, card) in cards.enumerated() where !card.holder.isHidden {
            card.holder.removeAction(forKey: "deal")

            // Faded back to where the redraw wanted it rather than to 1: a card
            // drawn faint should still be faint when it lands.
            let settled = card.holder.alpha
            let home = card.holder.position

            card.holder.alpha = 0
            card.holder.position = CGPoint(x: home.x, y: home.y - 14)

            card.holder.run(
                .sequence([
                    .wait(forDuration: delay + Double(index) * 0.03),
                    .group([
                        .fadeAlpha(to: settled, duration: 0.12),
                        .move(to: home, duration: 0.14)
                    ])
                ]),
                withKey: "deal"
            )
        }
    }

    // MARK: - Drawing

    func update(with world: World) {
        guard isOpen, let player = world.localPlayer else { return }

        guard mode == .buy else {
            drawSellTab(for: player)
            return
        }
        emptyNote.isHidden = true

        // The whole catalogue at once. What the gear half offers depends on what
        // you are wearing, so this comes from Core rather than straight out of the
        // config.
        let items = ShopSystem.everythingOffered(to: player, unlocks: world.unlocks)

        // Redrawn when the purse, the offers, their prices or their sold-out state
        // change - and not otherwise, because a redraw resets card positions and
        // would stamp on the animations.
        var fingerprint: [Int] = [player.tokens, items.count]

        for item in items {
            fingerprint.append(item.type.hashValue)
            fingerprint.append(item.price)

            let soldOut = ShopSystem.isSoldOut(item.type, actor: player, in: world)
            fingerprint.append(soldOut ? 1 : 0)
        }

        guard fingerprint != lastDrawn else { return }

        lastDrawn = fingerprint
        purse.text = "\(player.tokens)"

        for (index, var card) in cards.enumerated() {
            guard index < items.count else {
                card.holder.isHidden = true
                card.type = nil
                cards[index] = card
                continue
            }

            let item = items[index]
            let texture = ItemArt.texture(for: .item(item.type))

            card.holder.isHidden = false
            card.holder.position = ShopPanelNode.home(of: index, outOf: items.count)

            card.type = item.type
            card.slot = nil
            card.name.text = ItemArt.name(for: item.type)
            card.icon.texture = texture
            card.icon.size = ItemArt.size(of: texture, fittingInto: 48)
            card.glow.color = RenderPalette.colour(of: item.type.rarity)
            card.price.text = "\(item.price)"

            let soldOut = ShopSystem.isSoldOut(item.type, actor: player, in: world)
            card.holder.alpha = soldOut ? 0.45 : 1.0

            // Lit green when you can have it, dark when you cannot afford it yet -
            // see RenderPalette.unaffordable for why that is grey rather than red.
            // Affordability only: a full bag also refuses a purchase, but that is a
            // fact about you rather than about the shelf, and the card says nothing
            // about it (see ShopSystem.isSoldOut).
            let affordable = player.tokens >= item.price

            card.pill.fillColor = affordable
                ? RenderPalette.affordable
                : RenderPalette.unaffordable

            card.bevel.fillColor = affordable
                ? RenderPalette.affordableDeep
                : RenderPalette.unaffordableDeep

            cards[index] = card
        }

        // Last, so every card is where it belongs before anything moves.
        if let delay = pendingDeal {
            pendingDeal = nil
            dealCards(from: delay)
        }
    }

    /// The SELL tab: one card per thing in your bag, with what the shop pays for
    /// it. Tap one to sell it - see GameScene.handleShopTouch.
    private func drawSellTab(for player: Actor) {
        let offers = ShopSystem.sellOffers(for: player)

        // Redrawn when the purse or the bag changes, and not otherwise - the same
        // rule as the BUY tab, for the same reason. The leading marker keeps a
        // sell fingerprint from ever matching a buy one.
        var fingerprint: [Int] = [-1, player.tokens, offers.count]
        for offer in offers {
            fingerprint += [offer.slot, offer.stack.type.hashValue, offer.stack.count, offer.price]
        }

        guard fingerprint != lastDrawn else { return }

        lastDrawn = fingerprint
        purse.text = "\(player.tokens)"
        emptyNote.isHidden = !offers.isEmpty

        for (index, var card) in cards.enumerated() {
            guard index < offers.count else {
                card.holder.isHidden = true
                card.type = nil
                card.slot = nil
                cards[index] = card
                continue
            }

            let offer = offers[index]
            let type = offer.stack.type
            let texture = ItemArt.texture(for: .item(type))

            card.holder.isHidden = false
            card.holder.position = ShopPanelNode.home(of: index, outOf: offers.count)

            card.type = type
            card.slot = offer.slot
            card.name.text = offer.stack.count > 1
                ? "\(ItemArt.name(for: type)) x\(offer.stack.count)"
                : ItemArt.name(for: type)
            card.icon.texture = texture
            card.icon.size = ItemArt.size(of: texture, fittingInto: 48)
            card.glow.color = RenderPalette.colour(of: type.rarity)

            // A plus, because this is money coming IN - the one thing that tells
            // the two tabs apart at a glance.
            card.price.text = "+\(offer.price)"

            let sellable = offer.price > 0
            card.holder.alpha = sellable ? 1.0 : 0.45
            card.pill.fillColor = sellable ? RenderPalette.affordable : RenderPalette.unaffordable
            card.bevel.fillColor = sellable ? RenderPalette.affordableDeep : RenderPalette.unaffordableDeep

            cards[index] = card
        }

        if let delay = pendingDeal {
            pendingDeal = nil
            dealCards(from: delay)
        }
    }
}
