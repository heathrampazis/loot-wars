//
//  ShopPanelNode.swift
//  Loot Wars
//
//  Spending tokens, laid out from the reference: a strip of tabs sitting on top of
//  a panel of cards, each card a name, the item, and what it costs.
//
//  Only tabs that have something in them are drawn. The catalogue is grouped by tab
//  in GameConfig, so a second one appears here the day something is added to it -
//  today that means one tab, because a BUILDING tab with nothing behind it would be
//  a promise the shop cannot keep.
//
//  Exactly one thing greys a card out: a machine you already own, which the shop
//  will not sell you a second of however rich you get. Nothing else does - not the
//  price, not a full bag - because those are facts about YOU, they change minute to
//  minute, and greying the shelf out for them had the shop looking permanently
//  shut. The tap carries the rest: it asks ShopSystem.canBuy and shakes the card
//  when the answer is no. See ShopSystem.isSoldOut.
//

import SpriteKit

final class ShopPanelNode: SKNode {

    /// Bigger cards, and a panel measured to fit on the smallest phone it will
    /// ever run on. Landscape on an SE is 568 x 320 points: the panel comes out
    /// 450 x 204, and with the tab strip above and the back button below the whole
    /// thing stands 286 tall - which leaves about seventeen points of air top and
    /// bottom. That is the constraint every number here is up against.
    private static let cardSize = CGSize(width: 200, height: 168)
    private static let cardGap: CGFloat = 14
    private static let padding: CGFloat = 18
    private static let tabSize = CGSize(width: 134, height: 34)
    private static let tabGap: CGFloat = 6

    /// The most cards a tab can show in one row, read off the catalogue rather than
    /// written down here - so a third thing added to a tab widens the shop instead
    /// of quietly not being drawn. Cards are CENTRED as a group, so a tab with
    /// fewer than the maximum does not sit lopsided against the left edge.
    private static var columns: Int { GameConfig.Shop.widestTab }

    /// Wide enough for the cards OR the row of tabs, whichever needs more. The tabs
    /// sit on top of the panel and would hang off the end of a panel sized only for
    /// two cards - which is exactly what happened when the bomb came off the
    /// building shelf and the widest tab went from three items to two.
    static var panelSize: CGSize {
        let cards = cardSize.width * CGFloat(columns) + cardGap * CGFloat(columns - 1)
        let tabs = tabSize.width * CGFloat(GameConfig.Shop.tabs.count)
                 + tabGap * CGFloat(GameConfig.Shop.tabs.count - 1)

        return CGSize(width: padding * 2 + max(cards, tabs),
                      height: padding * 2 + cardSize.height)
    }

    private struct Card {
        let holder: SKNode
        /// The square behind the item, washed with its rarity.
        let tile: SKShapeNode
        let icon: SKSpriteNode
        let name: SKLabelNode
        let price: SKLabelNode
        let pill: SKShapeNode
        let token: SKSpriteNode
        /// Lit for a moment when the sale goes through. Its own node rather than a
        /// colour on the plate, because the plate's fill and the holder's alpha are
        /// both rewritten by the next redraw - which lands on the same frame as the
        /// purchase, and would wipe the confirmation before it was seen.
        let flash: SKShapeNode
        var type: ItemType?
    }

    private let panel = SKShapeNode()
    private let back = SKNode()
    private var tabs: [(holder: SKNode, shape: SKShapeNode, label: SKLabelNode)] = []
    private var cards: [Card] = []

    private static let backSize = CGSize(width: 104, height: 40)

    private(set) var isOpen = false
    private var selectedTab = 0
    private var lastDrawn: [Int] = []

    /// The card the finger last landed on.
    ///
    /// Remembered rather than matched by item, because the card does not always
    /// still hold what you bought: buying a Rare helmet redraws that column as an
    /// Epic, so by the time the sale is confirmed there is nothing on the panel
    /// with the bought item's name on it. The position is the thing that stays put.
    private var lastPressed: Int?

    override init() {
        super.init()
        zPosition = 1100
        isHidden = true

        let size = ShopPanelNode.panelSize
        panel.path = CGPath(roundedRect: CGRect(x: -size.width / 2, y: -size.height / 2,
                                                width: size.width, height: size.height),
                            cornerWidth: 20, cornerHeight: 20, transform: nil)
        panel.fillColor = RenderPalette.hudPanel
        panel.strokeColor = .clear
        addChild(panel)

        buildTabs(above: size)
        for column in 0..<ShopPanelNode.columns {
            cards.append(makeCard(at: column))
        }
        buildBackButton(below: size)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Building

    private func buildTabs(above size: CGSize) {
        let tab = ShopPanelNode.tabSize

        for (index, definition) in GameConfig.Shop.tabs.enumerated() {

            let holder = SKNode()
            holder.position = CGPoint(
                x: -size.width / 2 + ShopPanelNode.padding + tab.width / 2
                    + CGFloat(index) * (tab.width + ShopPanelNode.tabGap),
                y: size.height / 2 + tab.height / 2 - 4)
            holder.zPosition = -1      // tucked behind the panel, so it reads as a tab
            addChild(holder)

            // Square along the bottom edge so it meets the panel, rounded on top.
            let path = CGMutablePath()
            let r: CGFloat = 10
            let l = -tab.width / 2, rr = tab.width / 2
            let b = -tab.height / 2, t = tab.height / 2
            path.move(to: CGPoint(x: l, y: b))
            path.addLine(to: CGPoint(x: l, y: t - r))
            path.addQuadCurve(to: CGPoint(x: l + r, y: t), control: CGPoint(x: l, y: t))
            path.addLine(to: CGPoint(x: rr - r, y: t))
            path.addQuadCurve(to: CGPoint(x: rr, y: t - r), control: CGPoint(x: rr, y: t))
            path.addLine(to: CGPoint(x: rr, y: b))
            path.closeSubpath()

            let shape = SKShapeNode(path: path)
            shape.strokeColor = .clear
            holder.addChild(shape)

            let label = SKLabelNode(fontNamed: "AvenirNext-Bold")
            label.text = definition.name
            label.fontSize = 15
            label.fontColor = .white
            label.verticalAlignmentMode = .center
            label.position = CGPoint(x: 0, y: 1)

            holder.addChild(label)

            tabs.append((holder, shape, label))
        }
    }

    /// Where a card sits when a tab is showing `count` of them, centred as a group.
    private static func centreX(of column: Int, outOf count: Int) -> CGFloat {
        let card = cardSize
        let spread = card.width * CGFloat(count) + cardGap * CGFloat(count - 1)
        return -spread / 2 + card.width / 2 + CGFloat(column) * (card.width + cardGap)
    }

    private func makeCard(at column: Int) -> Card {
        let card = ShopPanelNode.cardSize

        let holder = SKNode()
        holder.position = CGPoint(x: ShopPanelNode.centreX(of: column, outOf: ShopPanelNode.columns),
                                  y: 0)
        addChild(holder)

        let outline = CGPath(
            roundedRect: CGRect(x: -card.width / 2, y: -card.height / 2,
                                width: card.width, height: card.height),
            cornerWidth: 12, cornerHeight: 12, transform: nil)

        let plate = SKShapeNode(path: outline)
        plate.fillColor = SKColor(white: 1, alpha: 0.10)
        plate.strokeColor = .clear
        holder.addChild(plate)

        let flash = SKShapeNode(path: outline)
        flash.fillColor = RenderPalette.placementValid
        flash.strokeColor = RenderPalette.placementValid
        flash.lineWidth = 3
        flash.alpha = 0
        flash.zPosition = 5
        holder.addChild(flash)

        let name = SKLabelNode(fontNamed: "AvenirNext-Bold")
        name.fontSize = 15
        name.fontColor = .white
        name.verticalAlignmentMode = .center
        name.position = CGPoint(x: 0, y: card.height / 2 - 20)
        holder.addChild(name)

        let tile = SKShapeNode(path: CGPath(
            roundedRect: CGRect(x: -32, y: -32, width: 64, height: 64),
            cornerWidth: 14, cornerHeight: 14, transform: nil))
        tile.fillColor = SKColor(white: 1, alpha: 0.14)
        tile.strokeColor = .clear
        tile.lineWidth = 2.5
        tile.position = CGPoint(x: 0, y: 8)
        holder.addChild(tile)

        let icon = SKSpriteNode()
        icon.position = tile.position
        icon.zPosition = 1
        holder.addChild(icon)

        // The price pill, from the reference: a light capsule with the cost and the
        // token you pay it in.
        let pill = SKShapeNode(path: CGPath(
            roundedRect: CGRect(x: -card.width / 2 + 12, y: -card.height / 2 + 12,
                                width: card.width - 24, height: 32),
            cornerWidth: 10, cornerHeight: 10, transform: nil))
        pill.fillColor = RenderPalette.floorLight
        pill.strokeColor = .black
        pill.lineWidth = 3
        holder.addChild(pill)

        let pillCentre = CGPoint(x: 0, y: -card.height / 2 + 28)

        let price = SKLabelNode(fontNamed: "AvenirNext-Bold")
        price.fontSize = 17
        price.fontColor = .black
        price.horizontalAlignmentMode = .right
        price.verticalAlignmentMode = .center
        price.position = CGPoint(x: pillCentre.x + 4, y: pillCentre.y)
        price.zPosition = 1
        holder.addChild(price)

        let token = SKSpriteNode(texture: ItemArt.texture(for: .token(1)))
        token.size = ItemArt.size(of: ItemArt.texture(for: .token(1)), fittingInto: 22)
        token.position = CGPoint(x: pillCentre.x + 20, y: pillCentre.y)
        token.zPosition = 1
        holder.addChild(token)

        return Card(holder: holder, tile: tile, icon: icon, name: name,
                    price: price, pill: pill, token: token, flash: flash, type: nil)
    }

    private func buildBackButton(below size: CGSize) {
        let box = ShopPanelNode.backSize
        back.position = CGPoint(x: 0, y: -size.height / 2 - box.height / 2 - 10)

        let pill = SKShapeNode(path: CGPath(
            roundedRect: CGRect(x: -box.width / 2, y: -box.height / 2,
                                width: box.width, height: box.height),
            cornerWidth: box.height / 2, cornerHeight: box.height / 2, transform: nil))
        pill.fillColor = RenderPalette.hudPanel
        pill.strokeColor = .clear
        back.addChild(pill)

        let label = SKLabelNode(fontNamed: "AvenirNext-Bold")
        label.text = "BACK"
        label.fontSize = 16
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        back.addChild(label)

        addChild(back)
    }

    // MARK: - Opening

    func open() {
        isOpen = true
        isHidden = false
        lastDrawn = []
    }

    func close() {
        isOpen = false
        isHidden = true
    }

    // MARK: - Hit testing

    func isBackButton(atLocalPoint point: CGPoint) -> Bool {
        let box = ShopPanelNode.backSize
        let local = CGPoint(x: point.x - back.position.x, y: point.y - back.position.y)
        return abs(local.x) <= box.width / 2 + 14 && abs(local.y) <= box.height / 2 + 14
    }

    /// Whether a point in this node's own space is on the shop at all.
    ///
    /// Everything the panel owns: the card area, the strip of tabs sitting on top
    /// of it and the back button hanging below. A tap anywhere else is a tap
    /// outside, and closes the shop.
    ///
    /// The tab STRIP rather than the tabs themselves, deliberately. The six points
    /// of gap between two tabs is somewhere a thumb lands often, and a gap that
    /// shut the whole shop would feel like the panel had a hole in it.
    func contains(localPoint point: CGPoint) -> Bool {
        let size = ShopPanelNode.panelSize
        let tab = ShopPanelNode.tabSize

        if abs(point.x) <= size.width / 2, abs(point.y) <= size.height / 2 { return true }
        if isBackButton(atLocalPoint: point) { return true }

        let strip = size.height / 2 - 4
        return abs(point.x) <= size.width / 2
            && point.y >= strip && point.y <= strip + tab.height
    }

    func tabIndex(atLocalPoint point: CGPoint) -> Int? {
        let tab = ShopPanelNode.tabSize

        for (index, entry) in tabs.enumerated() {
            let local = CGPoint(x: point.x - entry.holder.position.x,
                                y: point.y - entry.holder.position.y)
            if abs(local.x) <= tab.width / 2 && abs(local.y) <= tab.height / 2 { return index }
        }
        return nil
    }

    /// Which item a tap landed on, or nil.
    func item(atLocalPoint point: CGPoint) -> ItemType? {
        let card = ShopPanelNode.cardSize

        for (index, entry) in cards.enumerated()
        where entry.type != nil && !entry.holder.isHidden {
            let local = CGPoint(x: point.x - entry.holder.position.x,
                                y: point.y - entry.holder.position.y)
            if abs(local.x) <= card.width / 2 && abs(local.y) <= card.height / 2 {
                lastPressed = index
                return entry.type
            }
        }
        return nil
    }

    /// The sale was refused: shake the card that was pressed.
    ///
    /// The other half of not greying cards out for a full bag. Something has to
    /// answer a tap that cannot go through, and a card that simply sat there would
    /// be the shop looking broken rather than the shop saying no.
    func refuse() {
        guard let index = lastPressed, cards.indices.contains(index) else { return }
        let card = cards[index]

        card.holder.removeAction(forKey: "bought")
        card.holder.setScale(1)

        // A wobble rather than a slide, and that is not a stylistic choice. The
        // redraw owns card POSITION - it is what puts a card in its column - so a
        // moveBy interrupted by a tab change would fight it and could leave the
        // card parked at the position it had before. Rotation and scale are
        // nobody else's, so an interrupted wobble can only ever end where it
        // started.
        card.holder.run(.sequence([
            .group([.rotate(toAngle: -0.05, duration: 0.05),
                    .scale(to: 0.95, duration: 0.05)]),
            .rotate(toAngle: 0.05, duration: 0.09),
            .group([.rotate(toAngle: 0, duration: 0.05),
                    .scale(to: 1.0, duration: 0.05)])
        ]), withKey: "bought")

        card.flash.removeAllActions()
        card.flash.fillColor = RenderPalette.placementBlocked
        card.flash.strokeColor = RenderPalette.placementBlocked
        card.flash.alpha = 0.38
        card.flash.run(.fadeAlpha(to: 0, duration: 0.35))
    }

    /// The sale went through: light the card that was pressed.
    ///
    /// Driven by the world rather than by the tap, so a card that was pressed and
    /// refused stays dark. Nothing here decides whether the purchase happened -
    /// it is told.
    func confirm() {
        guard let index = lastPressed, cards.indices.contains(index) else { return }
        let card = cards[index]

        card.holder.removeAction(forKey: "bought")
        card.holder.setScale(1)
        card.holder.zRotation = 0
        card.holder.run(.sequence([
            .scale(to: 1.09, duration: 0.07),
            .scale(to: 1.0, duration: 0.13)
        ]), withKey: "bought")

        card.flash.removeAllActions()
        card.flash.fillColor = RenderPalette.placementValid
        card.flash.strokeColor = RenderPalette.placementValid
        card.flash.alpha = 0.42
        card.flash.run(.fadeAlpha(to: 0, duration: 0.45))
    }

    func selectTab(_ index: Int) {
        guard index != selectedTab, GameConfig.Shop.tabs.indices.contains(index) else { return }
        selectedTab = index
        lastDrawn = []
    }

    // MARK: - Drawing

    func update(with world: World) {
        guard isOpen, let player = world.localPlayer else { return }

        // The gear tab's cards depend on what you are wearing, so the offers come
        // from Core rather than straight out of the config.
        let items = ShopSystem.offers(on: selectedTab, for: player)

        // Redraw only when the tab, your purse, your gear or your bag changes - the
        // things that can alter what this panel should say.
        let fingerprint = [selectedTab, player.tokens, items.count]
            + items.map { $0.price }
            + items.map { ShopSystem.isSoldOut($0.type, actor: player, in: world) ? 1 : 0 }
        guard fingerprint != lastDrawn else { return }
        lastDrawn = fingerprint

        for (index, entry) in tabs.enumerated() {
            let active = index == selectedTab
            entry.shape.fillColor = active
                ? RenderPalette.hudPanel
                : SKColor(white: 0, alpha: 0.34)
            entry.label.alpha = active ? 1 : 0.7
        }

        for (index, var card) in cards.enumerated() {
            guard index < items.count else {
                card.holder.isHidden = true
                cards[index] = card
                continue
            }

            let item = items[index]
            let texture = ItemArt.texture(for: .item(item.type))

            card.holder.isHidden = false
            card.holder.position = CGPoint(
                x: ShopPanelNode.centreX(of: index, outOf: items.count), y: 0)
            card.type = item.type
            card.name.text = ItemArt.name(for: item.type)
            card.icon.texture = texture
            card.icon.size = ItemArt.size(of: texture, fittingInto: 48)

            // The same rarity wash the bag uses, so a Rare in the shop and a Rare
            // in your hotbar are recognisably the same thing before you have read
            // either label.
            let rarity = RenderPalette.colour(of: item.type.rarity)
            card.tile.fillColor = rarity.withAlphaComponent(0.22)
            card.tile.strokeColor = rarity.withAlphaComponent(0.8)
            card.price.text = "\(item.price)"

            // Faint only for the one machine you already own. Nothing else greys -
            // see ShopSystem.isSoldOut for why the price and a full bag are a
            // different kind of no, and belong to the tap rather than the card.
            let soldOut = ShopSystem.isSoldOut(item.type, actor: player, in: world)
            card.holder.alpha = soldOut ? 0.45 : 1.0

            cards[index] = card
        }
    }
}
