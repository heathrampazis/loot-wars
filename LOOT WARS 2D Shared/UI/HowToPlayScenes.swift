//
//  HowToPlayScenes.swift
//  Loot Wars
//
//  The pictures on the How to Play pages: little staged moments of the real game.
//
//  Each is played out on the checkered grass at the game's own proportions (see
//  HowToPlayKit), with the game's own art, and runs as a short loop - somebody
//  walks to a crate and it pops, a bomb goes over a wall and the wall comes down -
//  so a newcomer sees the thing happen rather than a diagram of it.
//
//  The picture is five and a half tiles tall whatever size the sheet gives it,
//  and everything is centred on the origin.
//

import SpriteKit

enum HowToPlayScenes {

    enum Kind {
        case win, moveAndShoot, crates, gear, heal, perks, build, earn, raid, supply
    }

    private static let blue = TeamID(2)
    private static let red = TeamID(1)

    static func make(_ kind: Kind, in size: CGSize) -> SKNode {
        let root = SKNode()
        let t = size.height / 5.5

        root.addChild(HowToPlayKit.ground(size: size, tile: t))

        let stage = SKNode()
        stage.zPosition = 1
        root.addChild(stage)

        switch kind {
        case .win:          win(stage, t: t, size: size)
        case .moveAndShoot: moveAndShoot(stage, t: t, size: size)
        case .crates:       crates(stage, t: t)
        case .gear:         gear(stage, t: t)
        case .heal:         heal(stage, t: t)
        case .perks:        perks(stage, t: t)
        case .build:        build(stage, t: t)
        case .earn:         earn(stage, t: t, size: size)
        case .raid:         raid(stage, t: t)
        case .supply:       supply(stage, t: t)
        }
        return root
    }

    // MARK: - Win

    /// You, scoring, and a leaderboard with your row climbing to the top.
    private static func win(_ stage: SKNode, t: CGFloat, size: CGSize) {
        let hero = HowToPlayKit.person("PlayerEpic", team: blue, tile: t)
        hero.position = CGPoint(x: -2.4 * t, y: -1.2 * t)
        stage.addChild(hero)

        let crateSpot = CGPoint(x: -0.8 * t, y: -0.9 * t)
        let crate = HowToPlayKit.crate("LootboxRed", tile: t)
        crate.position = crateSpot
        stage.addChild(crate)

        // The board, like the one in the corner of a match.
        let rows: [(TeamID, Int)] = [(red, 420), (blue, 380), (TeamID(4), 310), (TeamID(5), 250)]
        let board = SKNode()
        board.position = CGPoint(x: 2.3 * t, y: 1.2 * t)
        stage.addChild(board)

        let rowHeight = 0.62 * t
        let panel = SKShapeNode(rect: CGRect(x: -1.4 * t, y: -rowHeight * 4 + 0.2 * t,
                                             width: 2.8 * t, height: rowHeight * 4 + 0.2 * t),
                                cornerRadius: 0.25 * t)
        panel.fillColor = SKColor(white: 0, alpha: 0.42)
        panel.strokeColor = .clear
        board.addChild(panel)

        var scoreLabels: [TeamID: SKLabelNode] = [:]
        var rowNodes: [TeamID: SKNode] = [:]
        for (index, entry) in rows.enumerated() {
            let row = SKNode()
            row.position = CGPoint(x: 0, y: -rowHeight * (CGFloat(index) + 0.5) + 0.2 * t)
            let swatch = SKShapeNode(rect: CGRect(x: -1.15 * t, y: -0.18 * t, width: 0.36 * t, height: 0.36 * t),
                                     cornerRadius: 0.08 * t)
            swatch.fillColor = RenderPalette.vibrantColour(for: entry.0)
            swatch.strokeColor = .clear
            row.addChild(swatch)
            let score = SKLabelNode()
            score.attributedText = HowToPlayKit.label("\(entry.1)", size: 0.34 * t, colour: .white)
            score.horizontalAlignmentMode = .right
            score.verticalAlignmentMode = .center
            score.position = CGPoint(x: 1.15 * t, y: 0)
            row.addChild(score)
            board.addChild(row)
            scoreLabels[entry.0] = score
            rowNodes[entry.0] = row
        }

        func setScore(_ value: Int) {
            scoreLabels[blue]?.attributedText = HowToPlayKit.label("\(value)", size: 0.34 * t, colour: .white)
        }
        func place(first: Bool) {
            let top = -rowHeight * 0.5 + 0.2 * t
            let second = -rowHeight * 1.5 + 0.2 * t
            rowNodes[blue]?.run(.moveTo(y: first ? top : second, duration: 0.25))
            rowNodes[red]?.run(.moveTo(y: first ? second : top, duration: 0.25))
        }

        HowToPlayKit.loop(stage, [
            (0.1, {
                hero.position = CGPoint(x: -2.4 * t, y: -1.2 * t)
                crate.setScale(1); crate.alpha = 1
                setScore(380); place(first: false)
            }),
            (0.7, { hero.run(HowToPlayKit.walk(hero, by: CGVector(dx: 0.9 * t, dy: 0), duration: 0.6)) }),
            (0.5, {
                crate.run(.sequence([.scale(to: 1.25, duration: 0.08), .group([.scale(to: 0.2, duration: 0.12),
                                                                               .fadeOut(withDuration: 0.12)])]))
                HowToPlayKit.burst(at: crateSpot, in: stage, colour: RenderPalette.treasure, tile: t)
                HowToPlayKit.popText("+50", at: CGPoint(x: crateSpot.x, y: crateSpot.y + 0.6 * t),
                                     in: stage, colour: RenderPalette.treasure, tile: t)
            }),
            (1.6, {
                setScore(430)
                scoreLabels[blue]?.run(.sequence([.scale(to: 1.35, duration: 0.1), .scale(to: 1, duration: 0.15)]))
                place(first: true)
            })
        ])
    }

    // MARK: - Move and shoot

    /// The two sticks, you strafing, an enemy taking hits until it pops.
    private static func moveAndShoot(_ stage: SKNode, t: CGFloat, size: CGSize) {
        let side: CGFloat = Prefs.leftHanded ? -1 : 1
        let radius = 0.9 * t

        let moveStick = HowToPlayKit.stick(radius: radius)
        moveStick.position = CGPoint(x: -side * (size.width / 2 - 1.2 * t), y: -size.height / 2 + 1.2 * t)
        moveStick.zPosition = 10
        stage.addChild(moveStick)

        let aimStick = HowToPlayKit.stick(radius: radius, glyph: Glyphs.crosshair)
        aimStick.position = CGPoint(x: side * (size.width / 2 - 1.2 * t), y: -size.height / 2 + 1.2 * t)
        aimStick.zPosition = 10
        stage.addChild(aimStick)

        let hero = HowToPlayKit.person("PlayerEpic", team: blue, tile: t)
        hero.position = CGPoint(x: -1.6 * t, y: -0.6 * t)
        stage.addChild(hero)

        let enemy = HowToPlayKit.person("PlayerCommon", team: red, tile: t)
        enemy.position = CGPoint(x: 2.0 * t, y: -0.1 * t)
        stage.addChild(enemy)
        let enemyBar = HowToPlayKit.personBar(tile: t)
        enemyBar.node.position = CGPoint(x: 0, y: 2.0 * t)
        enemy.addChild(enemyBar.node)

        let moveKnob = moveStick.childNode(withName: "knob")
        let aimKnob = aimStick.childNode(withName: "knob")
        var health: CGFloat = 1

        func fire() {
            let shot = HowToPlayKit.shot(tile: t)
            let from = CGPoint(x: hero.position.x + 0.45 * t, y: hero.position.y + 0.9 * t)
            let to = CGPoint(x: enemy.position.x - 0.2 * t, y: enemy.position.y + 0.9 * t)
            shot.position = from
            shot.zPosition = 5
            stage.addChild(shot)
            shot.run(.sequence([
                .move(to: to, duration: 0.28),
                .run {
                    HowToPlayKit.burst(at: to, in: stage, colour: .white, tile: t, count: 3)
                    health -= 0.25
                    HowToPlayKit.setHealth(enemyBar.fill, full: enemyBar.full, share: health)
                    enemy.run(.sequence([.moveBy(x: 0.08 * t, y: 0, duration: 0.04),
                                         .moveBy(x: -0.08 * t, y: 0, duration: 0.06)]))
                },
                .removeFromParent()
            ]))
        }

        HowToPlayKit.loop(stage, [
            (0.2, {
                health = 1
                HowToPlayKit.setHealth(enemyBar.fill, full: enemyBar.full, share: 1)
                enemy.alpha = 1; enemy.setScale(1)
                hero.position = CGPoint(x: -1.6 * t, y: -0.6 * t)
                aimKnob?.position = .zero
            }),
            (0.6, {
                moveKnob?.run(.sequence([.move(to: CGPoint(x: 0, y: radius * 0.5), duration: 0.12),
                                         .wait(forDuration: 0.4), .move(to: .zero, duration: 0.1)]))
                hero.run(HowToPlayKit.walk(hero, by: CGVector(dx: 0, dy: 0.5 * t), duration: 0.5))
            }),
            (0.35, { aimKnob?.run(.move(to: CGPoint(x: radius * 0.5, y: radius * 0.1), duration: 0.12)); fire() }),
            (0.35, { fire() }),
            (0.35, { fire() }),
            (0.5, {
                fire()
                enemy.run(.sequence([.wait(forDuration: 0.3),
                                     .group([.scale(to: 0.3, duration: 0.2), .fadeOut(withDuration: 0.2)])]))
            }),
            (0.4, {
                aimKnob?.run(.move(to: .zero, duration: 0.12))
                HowToPlayKit.popText("+100", at: CGPoint(x: enemy.position.x, y: enemy.position.y + 1.4 * t),
                                     in: stage, colour: RenderPalette.treasure, tile: t)
            }),
            (1.0, {})
        ])
    }

    // MARK: - Crates

    /// You walk to a crate, it pops, a bandage lands. A rare crate glows beside it.
    private static func crates(_ stage: SKNode, t: CGFloat) {
        let hero = HowToPlayKit.person("PlayerEpic", team: blue, tile: t)
        stage.addChild(hero)

        let spot = CGPoint(x: -0.6 * t, y: -0.4 * t)
        let crate = HowToPlayKit.crate("LootboxRed", tile: t)
        crate.position = spot
        stage.addChild(crate)

        let rareSpot = CGPoint(x: 2.3 * t, y: 0.4 * t)
        let halo = SKSpriteNode(texture: GlowArt.pool)
        halo.size = CGSize(width: 2.6 * t, height: 2.2 * t)
        halo.color = RenderPalette.colour(of: .mythical)
        halo.colorBlendFactor = 1
        halo.alpha = 0.8
        halo.position = rareSpot
        stage.addChild(halo)
        halo.run(.repeatForever(.sequence([.fadeAlpha(to: 0.45, duration: 0.8), .fadeAlpha(to: 0.8, duration: 0.8)])))
        let rare = HowToPlayKit.crate("LootboxRare", tile: t)
        rare.position = rareSpot
        stage.addChild(rare)
        rare.run(.repeatForever(.sequence([.rotate(toAngle: 0.05, duration: 0.7),
                                           .rotate(toAngle: -0.05, duration: 0.7)])))
        stage.run(.repeatForever(.sequence([
            .run {
                HowToPlayKit.burst(at: CGPoint(x: rareSpot.x + CGFloat.random(in: -0.6...0.6) * t,
                                               y: rareSpot.y + CGFloat.random(in: -0.2...0.6) * t),
                                   in: stage, colour: RenderPalette.colour(of: .mythical), tile: t, count: 1)
            },
            .wait(forDuration: 0.25)
        ])))

        var loot: SKNode?

        HowToPlayKit.loop(stage, [
            (0.1, {
                loot?.removeFromParent(); loot = nil
                hero.position = CGPoint(x: -2.8 * t, y: -1.2 * t)
                crate.setScale(1); crate.alpha = 1
            }),
            (0.8, { hero.run(HowToPlayKit.walk(hero, by: CGVector(dx: 1.4 * t, dy: 0.3 * t), duration: 0.7)) }),
            (0.35, {
                crate.run(.repeat(.sequence([.rotate(toAngle: 0.12, duration: 0.04),
                                             .rotate(toAngle: -0.12, duration: 0.04)]), count: 3))
            }),
            (0.35, {
                crate.run(.sequence([.rotate(toAngle: 0, duration: 0),
                                     .scale(to: 1.3, duration: 0.07),
                                     .group([.scale(to: 0.1, duration: 0.12), .fadeOut(withDuration: 0.12)])]))
                HowToPlayKit.burst(at: spot, in: stage, colour: RenderPalette.treasure, tile: t)
                let item = HowToPlayKit.groundItem(.item(.bandage), tile: t)
                item.position = spot
                item.setScale(0.2)
                stage.addChild(item)
                let hop = SKAction.sequence([.moveBy(x: 0.3 * t, y: 0.7 * t, duration: 0.18),
                                             .moveBy(x: 0.2 * t, y: -0.7 * t, duration: 0.18)])
                item.run(.group([hop, .scale(to: 1, duration: 0.2)]))
                loot = item
            }),
            (1.6, {})
        ])
    }

    // MARK: - Gear

    /// A helmet and a blaster on the grass, and you walking over both and
    /// wearing them. The ladder of helmet rarities along the top.
    private static func gear(_ stage: SKNode, t: CGFloat) {
        let ladder: [HelmetTier] = [.common, .epic, .legendary, .mythical, .cosmic]
        for (index, tier) in ladder.enumerated() {
            let icon = HowToPlayKit.groundItem(.item(.helmet(tier)), tile: t * 0.8)
            icon.position = CGPoint(x: (CGFloat(index) - 2) * 0.95 * t, y: 1.9 * t)
            stage.addChild(icon)
        }

        let helmetSpot = CGPoint(x: -0.4 * t, y: -0.8 * t)
        let blasterSpot = CGPoint(x: 1.4 * t, y: -0.8 * t)

        let hero = HowToPlayKit.person("Player", team: blue, tile: t)
        stage.addChild(hero)

        var helmet: SKNode?
        var blaster: SKNode?

        func pickUp(_ item: SKNode?) {
            item?.run(.sequence([.group([.moveBy(x: 0, y: 0.8 * t, duration: 0.15),
                                         .scale(to: 0.3, duration: 0.15),
                                         .fadeOut(withDuration: 0.15)]),
                                 .removeFromParent()]))
        }

        HowToPlayKit.loop(stage, [
            (0.1, {
                helmet?.removeFromParent(); blaster?.removeFromParent()
                let h = HowToPlayKit.groundItem(.item(.helmet(.legendary)), tile: t)
                h.position = helmetSpot
                stage.addChild(h)
                helmet = h
                let b = HowToPlayKit.groundItem(.item(.blaster(.five)), tile: t)
                b.position = blasterSpot
                stage.addChild(b)
                blaster = b
                hero.position = CGPoint(x: -2.6 * t, y: -1.3 * t)
                HowToPlayKit.dress(hero, in: "Player")
            }),
            (0.75, { hero.run(HowToPlayKit.walk(hero, by: CGVector(dx: 2.2 * t, dy: 0), duration: 0.7)) }),
            (0.25, {
                pickUp(helmet); helmet = nil
                HowToPlayKit.dress(hero, in: "PlayerLegendary")
                HowToPlayKit.burst(at: CGPoint(x: hero.position.x, y: hero.position.y + 1.5 * t), in: stage,
                                   colour: RenderPalette.colour(of: .legendary), tile: t)
            }),
            (0.75, { hero.run(HowToPlayKit.walk(hero, by: CGVector(dx: 1.8 * t, dy: 0), duration: 0.7)) }),
            (1.8, {
                pickUp(blaster); blaster = nil
                HowToPlayKit.burst(at: CGPoint(x: hero.position.x + 0.3 * t, y: hero.position.y + 0.8 * t), in: stage,
                                   colour: RenderPalette.colour(of: .mythical), tile: t)
                HowToPlayKit.popText("BLASTER 5", at: CGPoint(x: hero.position.x, y: hero.position.y + 2.1 * t),
                                     in: stage, colour: RenderPalette.colour(of: .mythical), tile: t)
            })
        ])
    }

    // MARK: - Heal

    /// A hurt figure, a bandage tapped in the hotbar, the bar filling back up.
    private static func heal(_ stage: SKNode, t: CGFloat) {
        let hero = HowToPlayKit.person("PlayerEpic", team: blue, tile: t)
        hero.position = CGPoint(x: 0, y: -0.6 * t)
        stage.addChild(hero)
        let bar = HowToPlayKit.personBar(tile: t)
        bar.node.position = CGPoint(x: 0, y: 2.0 * t)
        hero.addChild(bar.node)

        let side = 0.95 * t
        let slots: [(ItemType?, Int)] = [(.bandage, 3), (.medkit, 1), (.bomb, 2), (nil, 0)]
        var slotNodes: [SKNode] = []
        for (index, entry) in slots.enumerated() {
            let slot = HowToPlayKit.slot(entry.0, count: entry.1, side: side)
            slot.position = CGPoint(x: (CGFloat(index) - 1.5) * (side + 0.12 * t), y: -2.2 * t)
            slot.zPosition = 10
            stage.addChild(slot)
            slotNodes.append(slot)
        }

        func motes() {
            for n in 0..<5 {
                let plus = SKLabelNode(text: "+")
                plus.fontName = "HelveticaNeue-Bold"
                plus.fontSize = 0.55 * t
                plus.fontColor = RenderPalette.payout
                plus.position = CGPoint(x: hero.position.x + CGFloat(n - 2) * 0.25 * t,
                                        y: hero.position.y + 0.3 * t)
                plus.alpha = 0
                plus.zPosition = 8
                stage.addChild(plus)
                plus.run(.sequence([.wait(forDuration: Double(n) * 0.08),
                                    .fadeIn(withDuration: 0.05),
                                    .group([.moveBy(x: 0, y: 1.3 * t, duration: 0.6), .fadeOut(withDuration: 0.6)]),
                                    .removeFromParent()]))
            }
        }

        func tap(_ index: Int, healingTo share: CGFloat, from start: CGFloat) {
            slotNodes[index].run(.sequence([.scale(to: 0.85, duration: 0.06), .scale(to: 1.08, duration: 0.08),
                                            .scale(to: 1, duration: 0.08)]))
            motes()
            bar.fill.run(.customAction(withDuration: 0.6) { _, elapsed in
                let now = start + (share - start) * elapsed / 0.6
                HowToPlayKit.setHealth(bar.fill, full: bar.full, share: now)
            })
        }

        HowToPlayKit.loop(stage, [
            (0.9, { HowToPlayKit.setHealth(bar.fill, full: bar.full, share: 0.25) }),
            (1.1, { tap(0, healingTo: 0.55, from: 0.25) }),
            (1.6, { tap(1, healingTo: 1, from: 0.55) })
        ])
    }

    // MARK: - Power-ups

    /// The four power-ups in the hotbar; each in turn lights you up in its colour.
    private static func perks(_ stage: SKNode, t: CGFloat) {
        let hero = HowToPlayKit.person("PlayerEpic", team: blue, tile: t)
        hero.position = CGPoint(x: 0, y: -0.5 * t)
        stage.addChild(hero)

        let aura = SKSpriteNode(texture: GlowArt.pool)
        aura.size = CGSize(width: 3 * t, height: 3 * t)
        aura.colorBlendFactor = 1
        aura.alpha = 0
        aura.position = CGPoint(x: 0, y: 0.8 * t)
        aura.zPosition = -0.5
        hero.addChild(aura)

        let perks: [Perk] = [.strength, .speed, .regeneration, .overdrive]
        let side = 0.95 * t
        var slotNodes: [SKNode] = []
        for (index, perk) in perks.enumerated() {
            let slot = HowToPlayKit.slot(.perk(perk), side: side)
            slot.position = CGPoint(x: (CGFloat(index) - 1.5) * (side + 0.12 * t), y: -2.2 * t)
            slot.zPosition = 10
            stage.addChild(slot)
            slotNodes.append(slot)
        }

        var steps: [(TimeInterval, () -> Void)] = []
        for (index, perk) in perks.enumerated() {
            steps.append((1.3, {
                let colour = RenderPalette.colours(for: perk, at: index * 3).bright
                slotNodes[index].run(.sequence([.scale(to: 0.85, duration: 0.06), .scale(to: 1.1, duration: 0.08),
                                                .scale(to: 1, duration: 0.08)]))
                aura.color = colour
                aura.removeAllActions()
                aura.alpha = 0
                aura.setScale(0.5)
                aura.run(.sequence([.group([.fadeAlpha(to: 0.9, duration: 0.15), .scale(to: 1, duration: 0.2)]),
                                    .wait(forDuration: 0.8),
                                    .fadeOut(withDuration: 0.25)]))
                HowToPlayKit.burst(at: CGPoint(x: hero.position.x, y: hero.position.y + 0.9 * t),
                                   in: stage, colour: colour, tile: t, count: 8)
                HowToPlayKit.popText(ItemArt.name(for: .perk(perk)).uppercased(),
                                     at: CGPoint(x: hero.position.x, y: hero.position.y + 2.1 * t),
                                     in: stage, colour: colour, tile: t)
                if perk == .speed {
                    hero.run(.sequence([HowToPlayKit.walk(hero, by: CGVector(dx: 1.2 * t, dy: 0), duration: 0.35),
                                        HowToPlayKit.walk(hero, by: CGVector(dx: -1.2 * t, dy: 0), duration: 0.35)]))
                }
            }))
        }
        HowToPlayKit.loop(stage, steps)
    }

    // MARK: - Build

    /// Your claim, a ring of wall going up around you, and the chest that
    /// appears when it closes.
    private static func build(_ stage: SKNode, t: CGFloat) {
        let cols = 7, rows = 5
        let originX = -CGFloat(cols - 1) / 2 * t
        let originY = -CGFloat(rows - 1) / 2 * t

        let claim = SKShapeNode(rect: CGRect(x: originX - 0.5 * t, y: originY - 0.5 * t,
                                             width: CGFloat(cols) * t, height: CGFloat(rows) * t))
        claim.fillColor = RenderPalette.colour(for: blue).withAlphaComponent(0.2)
        claim.strokeColor = .clear
        stage.addChild(claim)

        // Round the ring in order, so it goes up like somebody building it.
        var ring: [(Int, Int)] = []
        for c in 0..<cols { ring.append((c, 0)) }
        for r in 1..<rows { ring.append((cols - 1, r)) }
        for c in stride(from: cols - 2, through: 0, by: -1) { ring.append((c, rows - 1)) }
        for r in stride(from: rows - 2, through: 1, by: -1) { ring.append((0, r)) }

        var blocks: [SKSpriteNode] = []
        for (c, r) in ring {
            let block = HowToPlayKit.wall(team: blue, tile: t)
            block.position = CGPoint(x: originX + CGFloat(c) * t, y: originY + CGFloat(r) * t)
            block.alpha = 0
            stage.addChild(block)
            blocks.append(block)
        }

        let hero = HowToPlayKit.person("PlayerEpic", team: blue, tile: t)
        hero.position = CGPoint(x: -0.9 * t, y: -0.9 * t)
        stage.addChild(hero)

        let chest = SKSpriteNode(texture: ItemArt.texture(for: .chest))
        chest.size = ItemArt.size(of: chest.texture!, fittingInto: 0.95 * t)
        chest.position = CGPoint(x: 1 * t, y: 0)
        chest.alpha = 0
        stage.addChild(chest)

        var steps: [(TimeInterval, () -> Void)] = [(0.4, {
            for block in blocks { block.removeAllActions(); block.alpha = 0; block.setScale(1) }
            chest.alpha = 0
        })]
        for block in blocks {
            steps.append((0.11, {
                block.setScale(0.2)
                block.run(.group([.fadeIn(withDuration: 0.06),
                                  .sequence([.scale(to: 1.25, duration: 0.07), .scale(to: 1, duration: 0.06)])]))
            }))
        }
        steps.append((2.0, {
            for block in blocks {
                block.run(.sequence([.colorize(with: .white, colorBlendFactor: 0.7, duration: 0.08),
                                     .colorize(withColorBlendFactor: 0, duration: 0.3)]))
            }
            chest.setScale(0.2)
            chest.run(.group([.fadeIn(withDuration: 0.1),
                              .sequence([.scale(to: 1.25, duration: 0.12), .scale(to: 1, duration: 0.1)])]))
            HowToPlayKit.popText("SEALED", at: CGPoint(x: 0, y: 1.1 * t), in: stage,
                                 colour: RenderPalette.colour(for: blue), tile: t)
        }))
        steps.append((0.3, { for block in blocks { block.run(.fadeOut(withDuration: 0.25)) }
                             chest.run(.fadeOut(withDuration: 0.25)) }))
        HowToPlayKit.loop(stage, steps)
    }

    // MARK: - Earn

    /// A machine paying out tokens, you sweeping them up, the counter ticking.
    private static func earn(_ stage: SKNode, t: CGFloat, size: CGSize) {
        let arcade = SKSpriteNode(texture: SKTexture(imageNamed: "Arcade"))
        let art = arcade.texture?.size() ?? CGSize(width: 2, height: 3)
        let height = 3 * t
        arcade.size = CGSize(width: height * art.width / max(art.height, 1), height: height)
        arcade.anchorPoint = CGPoint(x: 0.5, y: 0)
        arcade.position = CGPoint(x: -2.2 * t, y: -1.8 * t)
        stage.addChild(arcade)

        let counter = HowToPlayKit.counter(icon: ItemArt.texture(for: .token(1)), text: "12", height: 0.7 * t)
        counter.node.position = CGPoint(x: 0, y: size.height / 2 - 0.6 * t)
        counter.node.zPosition = 10
        stage.addChild(counter.node)

        let shop = SKShapeNode(circleOfRadius: 0.6 * t)
        shop.fillColor = SKColor(white: 0, alpha: 0.42)
        shop.strokeColor = .clear
        shop.position = CGPoint(x: size.width / 2 - 0.9 * t, y: size.height / 2 - 0.9 * t)
        shop.zPosition = 10
        shop.addChild(SKSpriteNode(texture: Glyphs.shoppingBag, size: CGSize(width: 0.6 * t, height: 0.6 * t)))
        stage.addChild(shop)

        let hero = HowToPlayKit.person("PlayerEpic", team: blue, tile: t)
        stage.addChild(hero)

        var tokens: [SKNode] = []
        var count = 12
        let spots = [CGPoint(x: -0.6 * t, y: -1.2 * t), CGPoint(x: 0.3 * t, y: -0.9 * t), CGPoint(x: 1.1 * t, y: -1.3 * t)]

        func setCount(_ value: Int) {
            counter.label.attributedText = HowToPlayKit.label("\(value)", size: 0.35 * t, colour: .white)
        }

        var steps: [(TimeInterval, () -> Void)] = [(0.2, {
            for token in tokens { token.removeFromParent() }
            tokens = []
            count = 12
            setCount(count)
            hero.position = CGPoint(x: -1.2 * t, y: -1.9 * t)
        })]
        for spot in spots {
            steps.append((0.3, {
                arcade.run(.sequence([.scaleX(to: 1.06, y: 0.94, duration: 0.07), .scale(to: 1, duration: 0.15)]))
                let token = HowToPlayKit.groundItem(.token(1), tile: t)
                token.position = CGPoint(x: -1.8 * t, y: -0.2 * t)
                stage.addChild(token)
                let path = CGMutablePath()
                path.move(to: token.position)
                path.addQuadCurve(to: spot, control: CGPoint(x: (token.position.x + spot.x) / 2, y: 1.2 * t))
                token.run(.follow(path, asOffset: false, orientToPath: false, duration: 0.35))
                tokens.append(token)
            }))
        }
        steps.append((0.2, {}))
        steps.append((1.0, {
            hero.run(HowToPlayKit.walk(hero, by: CGVector(dx: 2.6 * t, dy: 0.6 * t), duration: 0.9))
            for (index, token) in tokens.enumerated() {
                token.run(.sequence([
                    .wait(forDuration: 0.25 + Double(index) * 0.25),
                    .group([.move(to: counter.node.position, duration: 0.3), .scale(to: 0.5, duration: 0.3)]),
                    .run { count += 1; setCount(count)
                           counter.node.run(.sequence([.scale(to: 1.15, duration: 0.06), .scale(to: 1, duration: 0.1)])) },
                    .removeFromParent()
                ]))
            }
        }))
        steps.append((1.4, {
            shop.run(.sequence([.scale(to: 1.25, duration: 0.12), .scale(to: 1, duration: 0.15),
                                .scale(to: 1.25, duration: 0.12), .scale(to: 1, duration: 0.15)]))
        }))
        HowToPlayKit.loop(stage, steps)
    }

    // MARK: - Raid

    /// A bomb over an enemy wall, the wall coming down, their chest shot open
    /// and the loot spilling out.
    private static func raid(_ stage: SKNode, t: CGFloat) {
        let wallX = 0.7 * t
        var walls: [SKSpriteNode] = []
        for r in -2...2 {
            let block = HowToPlayKit.wall(team: red, tile: t)
            block.position = CGPoint(x: wallX, y: CGFloat(r) * t)
            stage.addChild(block)
            walls.append(block)
        }
        let breach = [walls[1], walls[2]]

        let chestSpot = CGPoint(x: 2.6 * t, y: -0.5 * t)
        let chest = SKSpriteNode(texture: ItemArt.texture(for: .chest))
        chest.size = ItemArt.size(of: chest.texture!, fittingInto: 1 * t)
        chest.position = chestSpot
        stage.addChild(chest)
        let chestBar = HowToPlayKit.healthBar(team: red, tile: t)
        chestBar.node.position = CGPoint(x: 0, y: 0.75 * t)
        chest.addChild(chestBar.node)

        let hero = HowToPlayKit.person("PlayerLegendary", team: blue, tile: t)
        stage.addChild(hero)

        let bomb = SKSpriteNode(texture: ItemArt.texture(for: .bomb))
        bomb.size = ItemArt.size(of: bomb.texture!, fittingInto: 0.7 * t)
        bomb.zPosition = 6
        stage.addChild(bomb)

        // The dotted aim line a throw shows before it goes.
        let from = CGPoint(x: -2.2 * t, y: 0.2 * t)
        let to = CGPoint(x: wallX, y: -0.5 * t)
        let control = CGPoint(x: -0.8 * t, y: 2.2 * t)
        var dots: [SKShapeNode] = []
        for n in 1...7 {
            let s = CGFloat(n) / 8
            let x = (1 - s) * (1 - s) * from.x + 2 * (1 - s) * s * control.x + s * s * to.x
            let y = (1 - s) * (1 - s) * from.y + 2 * (1 - s) * s * control.y + s * s * to.y
            let dot = SKShapeNode(circleOfRadius: 0.07 * t)
            dot.fillColor = .white
            dot.strokeColor = .clear
            dot.position = CGPoint(x: x, y: y)
            dot.alpha = 0
            stage.addChild(dot)
            dots.append(dot)
        }
        let arc = CGMutablePath()
        arc.move(to: from)
        arc.addQuadCurve(to: to, control: control)

        var spill: [SKNode] = []

        func shoot(_ share: CGFloat) {
            let shot = HowToPlayKit.shot(tile: t)
            shot.position = CGPoint(x: hero.position.x + 0.4 * t, y: hero.position.y + 0.9 * t)
            shot.zPosition = 5
            stage.addChild(shot)
            shot.run(.sequence([.move(to: chestSpot, duration: 0.25),
                                .run {
                                    HowToPlayKit.burst(at: chestSpot, in: stage, colour: .white, tile: t, count: 3)
                                    HowToPlayKit.setBar(chestBar.fill, full: chestBar.full, share: share)
                                    chest.run(.sequence([.scale(to: 1.1, duration: 0.04), .scale(to: 1, duration: 0.08)]))
                                },
                                .removeFromParent()]))
        }

        HowToPlayKit.loop(stage, [
            (0.2, {
                for node in spill { node.removeFromParent() }
                spill = []
                for block in walls { block.removeAllActions(); block.alpha = 1; block.setScale(1) }
                chest.alpha = 1; chest.setScale(1)
                HowToPlayKit.setBar(chestBar.fill, full: chestBar.full, share: 1)
                hero.position = CGPoint(x: -2.6 * t, y: -1 * t)
                bomb.alpha = 0
            }),
            (0.6, { for (n, dot) in dots.enumerated() { dot.run(.sequence([.wait(forDuration: Double(n) * 0.04),
                                                                           .fadeAlpha(to: 0.8, duration: 0.1)])) } }),
            (0.8, {
                for dot in dots { dot.run(.fadeOut(withDuration: 0.1)) }
                bomb.position = from
                bomb.alpha = 1
                bomb.run(.group([.follow(arc, asOffset: false, orientToPath: false, duration: 0.75),
                                 .rotate(byAngle: -4, duration: 0.75)]))
            }),
            (0.8, {
                bomb.alpha = 0
                let flash = SKSpriteNode(texture: GlowArt.pool)
                flash.size = CGSize(width: 3 * t, height: 3 * t)
                flash.color = RenderPalette.blast
                flash.colorBlendFactor = 1
                flash.blendMode = .add
                flash.position = to
                flash.zPosition = 7
                flash.setScale(0.3)
                stage.addChild(flash)
                flash.run(.sequence([.group([.scale(to: 1.2, duration: 0.3), .fadeOut(withDuration: 0.35)]),
                                     .removeFromParent()]))
                HowToPlayKit.burst(at: to, in: stage, colour: RenderPalette.blast, tile: t, count: 9)
                for block in breach {
                    block.run(.group([.scale(to: 0.1, duration: 0.2), .fadeOut(withDuration: 0.2)]))
                }
            }),
            (0.6, { hero.run(HowToPlayKit.walk(hero, by: CGVector(dx: 1.8 * t, dy: 0.5 * t), duration: 0.55)) }),
            (0.3, { shoot(0.66) }),
            (0.3, { shoot(0.33) }),
            (0.35, { shoot(0.05) }),
            (1.6, {
                chest.run(.group([.scale(to: 1.3, duration: 0.1), .fadeOut(withDuration: 0.15)]))
                HowToPlayKit.burst(at: chestSpot, in: stage, colour: RenderPalette.treasure, tile: t, count: 8)
                let loot: [Pickup] = [.item(.medkit), .item(.bomb), .item(.blaster(.four))]
                for (n, pickup) in loot.enumerated() {
                    let item = HowToPlayKit.groundItem(pickup, tile: t)
                    item.position = chestSpot
                    item.setScale(0.2)
                    stage.addChild(item)
                    let angle = CGFloat(n) * 2.1 + 0.4
                    let land = CGPoint(x: chestSpot.x + cos(angle) * 0.9 * t, y: chestSpot.y + sin(angle) * 0.7 * t)
                    item.run(.group([.move(to: land, duration: 0.25), .scale(to: 1, duration: 0.25)]))
                    spill.append(item)
                }
            })
        ])
    }

    // MARK: - Supply

    /// A turret on guard, and a golden supply drop falling out of the sky and
    /// counting down to OPEN.
    private static func supply(_ stage: SKNode, t: CGFloat) {
        let turret = SKSpriteNode(texture: TurretArt.icon(for: red),
                                  size: CGSize(width: 2 * t, height: 2 * t))
        turret.position = CGPoint(x: -2.4 * t, y: -0.4 * t)
        stage.addChild(turret)
        stage.run(.repeatForever(.sequence([
            .run {
                let shot = HowToPlayKit.shot(tile: t)
                shot.position = CGPoint(x: turret.position.x + 0.9 * t, y: turret.position.y + 0.6 * t)
                stage.addChild(shot)
                turret.run(.sequence([.moveBy(x: -0.08 * t, y: 0, duration: 0.04),
                                      .moveBy(x: 0.08 * t, y: 0, duration: 0.1)]))
                shot.run(.sequence([.moveBy(x: 2.5 * t, y: 0.9 * t, duration: 0.4),
                                    .fadeOut(withDuration: 0.08), .removeFromParent()]))
            },
            .wait(forDuration: 0.45)
        ])))

        let spot = CGPoint(x: 1.8 * t, y: -0.6 * t)
        let glow = SKSpriteNode(texture: GlowArt.pool)
        glow.size = CGSize(width: 3 * t, height: 2.6 * t)
        glow.color = RenderPalette.treasure
        glow.colorBlendFactor = 1
        glow.position = spot
        stage.addChild(glow)

        let shadow = SKShapeNode(ellipseOf: CGSize(width: 1.2 * t, height: 0.35 * t))
        shadow.fillColor = .black
        shadow.strokeColor = .clear
        shadow.position = CGPoint(x: spot.x, y: spot.y - 0.35 * t)
        stage.addChild(shadow)

        let drop = HowToPlayKit.crate("LootboxGold", tile: t * 1.15)
        stage.addChild(drop)

        let pill = SKShapeNode(rect: CGRect(x: -0.6 * t, y: -0.25 * t, width: 1.2 * t, height: 0.5 * t),
                               cornerRadius: 0.25 * t)
        pill.fillColor = SKColor(white: 0, alpha: 0.72)
        pill.strokeColor = .black
        pill.lineWidth = 2
        pill.position = CGPoint(x: spot.x, y: spot.y + 0.9 * t)
        pill.zPosition = 8
        let label = SKLabelNode()
        label.verticalAlignmentMode = .center
        pill.addChild(label)
        stage.addChild(pill)

        func say(_ text: String, gold: Bool) {
            label.attributedText = HowToPlayKit.label(text, size: 0.3 * t, colour: gold ? RenderPalette.treasure : .white)
            pill.run(.sequence([.scale(to: 1.2, duration: 0.06), .scale(to: 1, duration: 0.12)]))
        }

        let fall = SKAction.move(to: spot, duration: 0.5)
        fall.timingMode = .easeIn

        HowToPlayKit.loop(stage, [
            (0.1, {
                drop.position = CGPoint(x: spot.x, y: spot.y + 4 * t)
                drop.alpha = 1
                shadow.setScale(0.3); shadow.alpha = 0.1
                glow.alpha = 0
                pill.alpha = 0
            }),
            (0.6, {
                drop.run(.sequence([fall, .scaleX(to: 1.2, y: 0.8, duration: 0.06), .scale(to: 1, duration: 0.12)]))
                shadow.run(.group([.scale(to: 1, duration: 0.5), .fadeAlpha(to: 0.25, duration: 0.5)]))
            }),
            (0.5, {
                HowToPlayKit.burst(at: spot, in: stage, colour: .white, tile: t, count: 6)
                glow.run(.fadeAlpha(to: 0.8, duration: 0.3))
                pill.alpha = 1
                say("3", gold: false)
            }),
            (0.6, { say("2", gold: false) }),
            (0.6, { say("1", gold: false) }),
            (1.8, {
                say("OPEN", gold: true)
                drop.run(.sequence([.scaleX(to: 1.12, y: 0.88, duration: 0.07), .scale(to: 1, duration: 0.12)]))
            }),
            (0.2, { drop.run(.fadeOut(withDuration: 0.15)); pill.run(.fadeOut(withDuration: 0.15))
                    glow.run(.fadeOut(withDuration: 0.15)) })
        ])
    }
}
