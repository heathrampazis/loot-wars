//
//  HowToPlayScenes.swift
//  Loot Wars
//
//  The pictures on the How to Play pages: short moments of a real match.
//
//  Each one is a HowToPlayStage - a real World, stepped by the real systems and
//  drawn by the real renderers - with a script saying where people walk, what
//  they shoot and what they tap. Nothing here draws anything. If a wall, a crate
//  or a power-up looks different in a match, it looks different here too,
//  because it is the same code doing the drawing.
//
//  No captions and no floating numbers: the match does not show them either.
//
//  Coordinates are tiles. Every scene is framed on a tile's middle so the ground's
//  squares line up, and kept inside the five and a half tiles the picture shows.
//

import SpriteKit

enum HowToPlayScenes {

    enum Kind {
        case win, moveAndShoot, crates, gear, heal, perks, build, earn, raid, supply
    }

    /// You, always blue, and a red team for you to be up against.
    private static let blue = TeamID(2)
    private static let red = TeamID(1)

    /// Where a team's base goes when the scene only needs its person - well off
    /// the picture, so its tint and its middle are never seen.
    private static func faraway(_ team: TeamID) -> BaseClaim {
        BaseClaim(team: team, centredOn: GridPoint(col: 6 + team.raw * 11, row: 6), size: 9)
    }

    static func make(_ kind: Kind, in size: CGSize) -> SKNode {
        switch kind {
        case .win:
            return HowToPlayStage.make(in: size, centre: Vec2(x: 24.5, y: 20.5), setup: win)
        case .moveAndShoot:
            return HowToPlayStage.make(in: size, centre: Vec2(x: 24.5, y: 20.5), setup: moveAndShoot)
        case .crates:
            return HowToPlayStage.make(in: size, centre: Vec2(x: 24.5, y: 20.5), setup: crates)
        case .gear:
            return HowToPlayStage.make(in: size, centre: Vec2(x: 24.5, y: 20.5), setup: gear)
        case .heal:
            return HowToPlayStage.make(in: size, centre: Vec2(x: 24.5, y: 19.5), setup: heal)
        case .perks:
            return HowToPlayStage.make(in: size, centre: Vec2(x: 24.5, y: 19.5), setup: perks)
        case .build:
            return HowToPlayStage.make(in: size, centre: Vec2(x: 24.5, y: 20.5), setup: build)
        case .earn:
            return HowToPlayStage.make(in: size, centre: Vec2(x: 24.5, y: 20.5), setup: earn)
        case .raid:
            return HowToPlayStage.make(in: size, centre: Vec2(x: 25.5, y: 20.5), setup: raid)
        case .supply:
            return HowToPlayStage.make(in: size, centre: Vec2(x: 24.5, y: 20.5), setup: supply)
        }
    }

    // MARK: - Win

    /// The leaderboard in its corner, and you opening crates until your row is
    /// the one at the top.
    private static func win(_ stage: HowToPlayStage) {
        stage.build(claims: [faraway(blue)],
                    crates: [Lootbox(id: LootboxID(0), tile: GridPoint(col: 21, row: 19)),
                             Lootbox(id: LootboxID(1), tile: GridPoint(col: 25, row: 20))],
                    local: blue)

        let hero = stage.person(on: blue)
        stage.place(hero, at: Vec2(x: 18.5, y: 19.6), helmet: .epic, blaster: .two)

        // A board part-way through a match, with you a few points off the lead.
        let scores = [30, 50, 40, 25, 35, 15, 20, 10]
        for (index, points) in scores.enumerated() {
            stage.world.award(points, to: TeamID(index))
        }
        stage.showLeaderboard()

        stage.at(0.3) { $0.walk(hero, to: Vec2(x: 20.45, y: 19.5)) }
        stage.at(1.0) { $0.send(hero, .openLootbox) }
        stage.at(1.6) { $0.walk(hero, to: Vec2(x: 24.45, y: 20.5)) }
        stage.at(3.0) { $0.send(hero, .openLootbox) }
        stage.at(3.6) { $0.walk(hero, to: Vec2(x: 25.5, y: 20.5)) }
        stage.loop(after: 5.4)
    }

    // MARK: - Move and shoot

    /// The two sticks, you stepping out and holding the aim on somebody until
    /// they go down.
    private static func moveAndShoot(_ stage: HowToPlayStage) {
        stage.build(claims: [faraway(blue), faraway(red)], local: blue)

        let hero = stage.person(on: blue)
        let enemy = stage.person(on: red)
        stage.place(hero, at: Vec2(x: 20.5, y: 19.7), helmet: .epic, blaster: .three)
        stage.place(enemy, at: Vec2(x: 28.0, y: 20.9), blaster: .one, facingLeft: true)

        // The aim stick on the side the player has chosen, as in a match.
        let aimOnRight = !Prefs.leftHanded
        let moveStick = stage.stick(onRight: !aimOnRight)
        let aimStick = stage.stick(onRight: aimOnRight, glyph: Glyphs.crosshair)

        stage.at(0.3) { s in
            s.walk(hero, to: Vec2(x: 22.0, y: 20.9))
            s.push(moveStick, towards: Vec2(x: 0.8, y: 0.6))
        }
        stage.at(0.9) { s in
            s.push(moveStick, towards: .zero)
            s.push(aimStick, towards: Vec2(x: 1, y: 0))
            s.shoot(hero, atPerson: enemy)
            s.shoot(enemy, atPerson: hero)
        }
        stage.at(3.2) { s in
            s.push(aimStick, towards: .zero)
            s.stop(hero)
        }
        stage.at(3.5) { s in
            s.walk(hero, to: Vec2(x: 23.5, y: 20.4))
            s.push(moveStick, towards: Vec2(x: 1, y: -0.3))
        }
        stage.at(4.0) { $0.push(moveStick, towards: .zero) }
        stage.loop(after: 5.0)
    }

    // MARK: - Crates

    /// An ordinary crate and a rare one, opened one after the other.
    private static func crates(_ stage: HowToPlayStage) {
        stage.build(claims: [faraway(blue)],
                    crates: [Lootbox(id: LootboxID(0), tile: GridPoint(col: 22, row: 20)),
                             Lootbox(id: LootboxID(1), tile: GridPoint(col: 27, row: 20), rare: true)],
                    local: blue)

        let hero = stage.person(on: blue)
        stage.place(hero, at: Vec2(x: 19.0, y: 20.5), helmet: .common, blaster: .two)

        stage.at(0.3) { $0.walk(hero, to: Vec2(x: 21.45, y: 20.5)) }
        stage.at(1.1) { $0.send(hero, .openLootbox) }
        stage.at(1.7) { $0.walk(hero, to: Vec2(x: 26.45, y: 20.5)) }
        stage.at(3.3) { $0.send(hero, .openLootbox) }
        stage.at(4.0) { $0.walk(hero, to: Vec2(x: 27.5, y: 20.5)) }
        stage.loop(after: 5.8)
    }

    // MARK: - Gear

    /// A better helmet and a better blaster on the grass, and you walking over
    /// both and wearing them.
    private static func gear(_ stage: HowToPlayStage) {
        stage.build(claims: [faraway(blue)], local: blue)

        let hero = stage.person(on: blue)
        stage.place(hero, at: Vec2(x: 19.0, y: 20.3))

        stage.world.spawnGroundItem(.item(.helmet(.legendary)), at: Vec2(x: 22.5, y: 20.0))
        stage.world.spawnGroundItem(.item(.blaster(.four)), at: Vec2(x: 26.0, y: 20.0))

        stage.at(0.5) { $0.walk(hero, to: Vec2(x: 28.5, y: 20.3)) }
        stage.loop(after: 4.4)
    }

    // MARK: - Heal

    /// Hurt, with healing in the hotbar: a bandage tapped, then a medkit.
    private static func heal(_ stage: HowToPlayStage) {
        stage.build(claims: [faraway(blue)], local: blue)

        let hero = stage.person(on: blue)
        stage.place(hero, at: Vec2(x: 24.5, y: 21.0), helmet: .epic, blaster: .three)

        if var actor = stage.world.actors[hero] {
            actor.health = actor.maxHealth * 3 / 10
            for _ in 0..<3 { _ = actor.inventory.add(.bandage) }
            _ = actor.inventory.add(.medkit)
            _ = actor.inventory.add(.bomb)
            stage.world.actors[hero] = actor
        }
        stage.showHotbar()

        stage.at(0.9) { s in
            s.hotbar?.acknowledge(0)
            s.send(hero, .useItem(slot: 0))
        }
        stage.at(2.1) { s in
            s.hotbar?.acknowledge(1)
            s.send(hero, .useItem(slot: 1))
        }
        stage.at(2.8) { $0.walk(hero, to: Vec2(x: 26.0, y: 21.0)) }
        stage.loop(after: 4.0)
    }

    // MARK: - Power-ups

    /// Four power-ups in the hotbar, used one after another, each with its own
    /// burst and trail of sparkles - which are the match's own, running off the
    /// power-up the world says you have.
    private static func perks(_ stage: HowToPlayStage) {
        stage.build(claims: [faraway(blue)], local: blue)

        let hero = stage.person(on: blue)
        stage.place(hero, at: Vec2(x: 22.5, y: 21.0), helmet: .epic, blaster: .three)

        let order: [Perk] = [.strength, .speed, .regeneration, .overdrive]
        if var actor = stage.world.actors[hero] {
            for perk in order { _ = actor.inventory.add(.perk(perk)) }
            stage.world.actors[hero] = actor
        }
        stage.showHotbar()

        let beat = 1.9
        for index in order.indices {
            let start = 0.5 + Double(index) * beat
            stage.at(start) { s in
                s.hotbar?.acknowledge(index)
                s.send(hero, .useItem(slot: index))
            }
            stage.at(start + 0.2) { s in
                let x = index % 2 == 0 ? 26.5 : 22.5
                s.walk(hero, to: Vec2(x: x, y: 21.0))
            }
            // Cut short, so all four fit in one loop. In a match each runs its
            // full seven seconds.
            stage.at(start + beat - 0.15) { s in
                s.world.actors[hero]?.perkRemaining = 0.001
            }
        }
        stage.loop(after: 0.5 + Double(order.count) * beat + 0.3)
    }

    // MARK: - Build

    /// Your claim, a wall going up round it one block at a time, and the base
    /// sealing - the sweep round the wall, and a chest appearing inside.
    private static func build(_ stage: HowToPlayStage) {
        let claim = BaseClaim(team: blue, centredOn: GridPoint(col: 24, row: 20), size: 9)
        stage.build(claims: [claim], local: blue)
        stage.tint(claim)

        let hero = stage.person(on: blue)
        stage.place(hero, at: Vec2(x: 22.5, y: 20.6), helmet: .epic, blaster: .two)

        // Round the ring in order, the way somebody builds one: along the bottom,
        // up the right, back along the top and down the left.
        let left = claim.origin.col, right = claim.origin.col + claim.size - 1
        let bottom = 18, top = 22
        var ring: [GridPoint] = []
        for col in left...right { ring.append(GridPoint(col: col, row: bottom)) }
        for row in (bottom + 1)...top { ring.append(GridPoint(col: right, row: row)) }
        for col in stride(from: right - 1, through: left, by: -1) { ring.append(GridPoint(col: col, row: top)) }
        for row in stride(from: top - 1, through: bottom + 1, by: -1) { ring.append(GridPoint(col: left, row: row)) }

        for (index, tile) in ring.enumerated() {
            stage.at(0.4 + Double(index) * 0.09) { $0.send(hero, .placeBlock(tile)) }
        }

        stage.at(0.6) { $0.walk(hero, to: Vec2(x: 26.0, y: 20.6)) }
        stage.at(2.0) { $0.walk(hero, to: Vec2(x: 22.5, y: 20.6)) }
        stage.loop(after: 0.4 + Double(ring.count) * 0.09 + 2.4)
    }

    // MARK: - Earn

    /// Your machine paying out, you sweeping the tokens up, and the purse at the
    /// top of the screen counting them in.
    private static func earn(_ stage: HowToPlayStage) {
        let claim = BaseClaim(team: blue, centredOn: GridPoint(col: 23, row: 20), size: 9)
        stage.build(claims: [claim], local: blue)
        stage.tint(claim)

        // The machine stands in a corner of your base, against the wall on three
        // sides - so it can only pay out on its open side, which is where you
        // walk to sweep the tokens up. The match's own rule decides where they
        // land; the wall just leaves it one answer.
        for row in 18...22 {
            stage.world.setTile(.block(owner: blue), at: GridPoint(col: 20, row: row))
        }
        for col in 21...26 {
            stage.world.setTile(.block(owner: blue), at: GridPoint(col: col, row: 18))
            stage.world.setTile(.block(owner: blue), at: GridPoint(col: col, row: 22))
        }

        let machine = stage.world.spawnArcade(at: GridPoint(col: 21, row: 19), owner: blue)
        stage.world.arcades[machine]?.emitTimer = 0.3
        stage.showMatchPanel()

        let hero = stage.person(on: blue)
        stage.place(hero, at: Vec2(x: 26.5, y: 20.5), helmet: .epic, blaster: .three,
                    facingLeft: true)

        // Paid out quicker than a match does, so several come out in one loop.
        for moment in [1.2, 2.2, 3.2] {
            stage.at(moment) { $0.world.arcades[machine]?.emitTimer = 0 }
        }

        // Each token, as it lands, and the purse at the top counting them in.
        stage.at(0.8) { $0.collectTokens(hero) }
        stage.at(4.6) { $0.walk(hero, to: Vec2(x: 25.5, y: 20.5)) }
        stage.loop(after: 5.8)
    }

    // MARK: - Raid

    /// A bomb into an enemy wall, the hole it leaves, and their chest shot open
    /// from inside with the loot spilling out of it.
    private static func raid(_ stage: HowToPlayStage) {
        let theirs = BaseClaim(team: red, centredOn: GridPoint(col: 28, row: 20), size: 9)
        stage.build(claims: [faraway(blue), theirs], local: blue)
        stage.tint(theirs)

        // Their wall: the full ring, as a finished base has.
        let left = theirs.origin.col, right = theirs.origin.col + theirs.size - 1
        for col in left...right {
            for row in 18...22 where col == left || col == right || row == 18 || row == 22 {
                stage.world.setTile(.block(owner: red), at: GridPoint(col: col, row: row))
            }
        }

        let chest = stage.world.spawnChest(at: GridPoint(col: 29, row: 20), owner: red)
        stage.world.chests[chest]?.health = 120
        for item in [ItemType.helmet(.legendary), .medkit, .bomb] {
            _ = stage.world.chests[chest]?.contents.add(item)
        }

        // Their owner is out; this is about the base.
        stage.place(stage.person(on: red), at: Vec2(x: 10.5, y: 35.5))

        let hero = stage.person(on: blue)
        stage.place(hero, at: Vec2(x: 19.0, y: 20.5), helmet: .epic, blaster: .four)
        _ = stage.world.actors[hero]?.inventory.add(.bomb)

        let wall = Vec2(x: 24.5, y: 20.5)

        stage.at(0.3) { $0.walk(hero, to: Vec2(x: 20.6, y: 20.5)) }
        stage.at(0.8) { s in
            s.aim(hero, at: wall)
            s.send(hero, .useItem(slot: 0))
        }
        stage.at(1.8) { $0.walk(hero, to: Vec2(x: 25.7, y: 20.5)) }
        stage.at(3.3) { $0.shoot(hero, at: Vec2(x: 29.5, y: 20.5)) }
        stage.at(4.7) { $0.walk(hero, to: Vec2(x: 29.5, y: 20.5)) }
        stage.at(5.5) { $0.walk(hero, to: Vec2(x: 28.0, y: 20.8)) }
        stage.loop(after: 6.8)
    }

    // MARK: - Turrets and supply drops

    /// A turret trading shots with you until it is knocked out, then a supply
    /// drop landing, counting down, and opened.
    private static func supply(_ stage: HowToPlayStage) {
        stage.build(claims: [faraway(blue), faraway(red)], local: blue)

        let turret = stage.world.spawnTurret(at: GridPoint(col: 19, row: 20), owner: red)
        stage.world.turrets[turret]?.health = 150

        let hero = stage.person(on: blue)
        stage.place(hero, at: Vec2(x: 27.0, y: 20.4), helmet: .mythical, blaster: .five,
                    facingLeft: true)

        stage.at(0.4) { $0.shoot(hero, at: Vec2(x: 20.0, y: 21.0)) }
        stage.at(2.0) { $0.stop(hero) }

        let dropTile = GridPoint(col: 24, row: 19)
        stage.at(2.2) { $0.world.spawnSupplyDrop(at: dropTile, lockedFor: 2.4) }
        stage.at(2.6) { $0.walk(hero, to: Vec2(x: 25.55, y: 19.5)) }
        stage.at(4.8) { $0.send(hero, .openLootbox) }
        stage.at(5.3) { $0.walk(hero, to: dropTile.center) }
        stage.loop(after: 6.8)
    }
}
