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
//  A card greys out when you cannot afford it, and that answer comes from
//  ShopSystem.canBuy - the same one the purchase itself will use, so a card that
//  looks buyable is one the simulation will actually sell.
//

import SpriteKit

final class ShopPanelNode: SKNode {

    private static let cardSize = CGSize(width: 140, height: 152)
    private static let cardGap: CGFloat = 14
    private static let padding: CGFloat = 16
    private static let tabSize = CGSize(width: 118, height: 32)
    private static let tabGap: CGFloat = 6

    /// The most cards a tab can show in one row. Two is what fits a phone.
    private static let columns = 2

    static var panelSize: CGSize {
        CGSize(width: padding * 2 + cardSize.width * CGFloat(columns)
                      + cardGap * CGFloat(columns - 1),
               height: padding * 2 + cardSize.height)
    }

    private struct Card {
        let holder: SKNode
        let icon: SKSpriteNode
        let name: SKLabelNode
        let price: SKLabelNode
        let pill: SKShapeNode
        let token: SKSpriteNode
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
            cards.append(makeCard(at: column, in: size))
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

    private func makeCard(at column: Int, in size: CGSize) -> Card {
        let card = ShopPanelNode.cardSize
        let holder = SKNode()
        holder.position = CGPoint(
            x: -size.width / 2 + ShopPanelNode.padding + card.width / 2
                + CGFloat(column) * (card.width + ShopPanelNode.cardGap),
            y: 0)
        addChild(holder)

        let plate = SKShapeNode(path: CGPath(
            roundedRect: CGRect(x: -card.width / 2, y: -card.height / 2,
                                width: card.width, height: card.height),
            cornerWidth: 12, cornerHeight: 12, transform: nil))
        plate.fillColor = SKColor(white: 1, alpha: 0.10)
        plate.strokeColor = .clear
        holder.addChild(plate)

        let name = SKLabelNode(fontNamed: "AvenirNext-Bold")
        name.fontSize = 15
        name.fontColor = .white
        name.verticalAlignmentMode = .center
        name.position = CGPoint(x: 0, y: card.height / 2 - 20)
        holder.addChild(name)

        let tile = SKShapeNode(path: CGPath(
            roundedRect: CGRect(x: -27, y: -27, width: 54, height: 54),
            cornerWidth: 12, cornerHeight: 12, transform: nil))
        tile.fillColor = SKColor(white: 1, alpha: 0.14)
        tile.strokeColor = .black
        tile.lineWidth = 3
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

        return Card(holder: holder, icon: icon, name: name,
                    price: price, pill: pill, token: token, type: nil)
    }

    private func buildBackButton(below size: CGSize) {
        let box = ShopPanelNode.backSize
        back.position = CGPoint(x: 0, y: -size.height / 2 - box.height / 2 - 12)

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

        for entry in cards where entry.type != nil && !entry.holder.isHidden {
            let local = CGPoint(x: point.x - entry.holder.position.x,
                                y: point.y - entry.holder.position.y)
            if abs(local.x) <= card.width / 2 && abs(local.y) <= card.height / 2 {
                return entry.type
            }
        }
        return nil
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
            + items.map { ShopSystem.canBuy($0.type, actor: player) ? 1 : 0 }
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
            card.type = item.type
            card.name.text = ShopPanelNode.name(of: item.type)
            card.icon.texture = texture
            card.icon.size = ItemArt.size(of: texture, fittingInto: 40)
            card.price.text = "\(item.price)"

            // Faint when you cannot have it, from the same answer the purchase uses.
            let affordable = ShopSystem.canBuy(item.type, actor: player)
            card.holder.alpha = affordable ? 1.0 : 0.45

            cards[index] = card
        }
    }

    private static func name(of type: ItemType) -> String {
        switch type {
        case .bandage: return "Bandage"
        case .medkit:  return "Medkit"
        case .bomb:    return "Bomb"
        case .chest:   return "Chest"
        // Named by the TIER rather than by the slot, because on the gear tab the
        // tier is the whole offer - "Helmet" twice would say nothing about which
        // rung you are being sold.
        case .helmet(let tier):  return tier.name
        case .blaster(let tier): return "Blaster \(tier.rawValue)"
        }
    }
}
