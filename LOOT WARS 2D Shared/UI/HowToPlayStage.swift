//
//  HowToPlayStage.swift
//  Loot Wars
//
//  A tiny match, played for the How to Play pictures.
//
//  The pictures used to be collages: the game's art, moved about by hand-written
//  actions that imitated what the game does. Imitations drift - a wall drawn as a
//  loose square when the real ones join up, a pickup that floated a label the game
//  never shows, a power-up that glowed where the real one sparkles. So the pictures
//  are no longer drawn to look like the game. They ARE the game: a real World,
//  stepped by the real systems, drawn by the real renderers, with the people in it
//  driven by a short script instead of by thumbs.
//
//  Everything is laid out in tiles, exactly as in a match, and the whole thing is
//  scaled down so the picture is five and a half tiles tall. The interface laid
//  over it - sticks, hotbar, leaderboard - is the match's own too.
//
//  Only the page you are looking at runs. A page swiped back into view starts its
//  scene again from the top, from a fresh world, so every loop plays the same.
//

import SpriteKit
import QuartzCore
import UIKit

final class HowToPlayStage {

    // MARK: - Script

    /// Sets a scene up and says what happens when. Handed the stage rather than
    /// capturing it, so nothing the stage keeps holds the stage.
    typealias Setup = (HowToPlayStage) -> Void

    /// Something that happens at a moment in the scene.
    private struct Cue {
        let at: Double
        let run: (HowToPlayStage) -> Void
    }

    /// What a person is doing until told otherwise.
    private enum Errand {
        case walk(to: Vec2)
        case shoot(at: Vec2)
        case shootPerson(ActorID)
        /// Walks to whichever token on the ground is nearest, and keeps doing it.
        case collectTokens
    }

    // MARK: - What is on screen

    private(set) var world: World!

    /// Tiles across and down the picture shows, and the tile at its middle.
    let view: CGSize
    let centre: Vec2

    /// Picture points per game point - the whole match is drawn at this scale.
    let scale: CGFloat

    /// The size of the picture, in its own points.
    let size: CGSize

    private weak var root: SKNode?
    private let content = SKNode()
    private let overlay = SKNode()

    private let setup: Setup
    private var cues: [Cue] = []
    private var errands: [ActorID: Errand] = [:]
    private var once: [ActorID: [Command]] = [:]
    private var length: Double = 6

    private var time: Double = 0
    private var nextCue = 0
    private var accumulator: Double = 0
    private var lastTick: CFTimeInterval?

    // The match's own renderers, every one that a scene could need.
    private var blocks = BlockRenderer()
    private var wallDamage = WallDamageRenderer()
    private var arcades = ArcadeRenderer()
    private var turrets = TurretRenderer()
    private var lootboxes = LootboxRenderer()
    private var supply = SupplyDropRenderer()
    private var chests = ChestRenderer()
    private var groundItems = GroundItemRenderer()
    private var bombs = BombRenderer()
    private var projectiles = ProjectileRenderer()
    private var actors = ActorRenderer()
    private var gas = GasRenderer()
    private var effects = EffectsRenderer()
    private var drawnMapRevision = -1

    // The interface, when a scene asks for it.
    private(set) var hotbar: HotbarNode?
    private(set) var leaderboard: LeaderboardNode?
    private(set) var matchPanel: MatchPanelNode?

    /// How big the interface is drawn against the match. A touch smaller than in
    /// a match, because the picture is a little window rather than a whole screen.
    var interfaceScale: CGFloat { scale * 0.8 }

    // MARK: - Making one

    /// - Parameters:
    ///   - size: the picture, in points.
    ///   - centre: the tile the picture is centred on. Use a tile's middle (x.5)
    ///     so the ground's squares line up with the picture.
    static func make(in size: CGSize, centre: Vec2, setup: @escaping Setup) -> SKNode {
        let stage = HowToPlayStage(size: size, centre: centre, setup: setup)
        let root = SKNode()
        stage.root = root

        // The node owns the stage, not the other way round: when the page is
        // thrown away the node goes, and the stage and its world go with it.
        root.userData = ["stage": stage]

        stage.content.setScale(stage.scale)
        stage.content.position = CGPoint(
            x: -GridGeometry.length(ofTiles: centre.x) * stage.scale,
            y: -GridGeometry.length(ofTiles: centre.y) * stage.scale)
        // Lifted clear of the panel behind it. The renderers use the match's own
        // depths, which start a hundred below zero with the ground.
        stage.content.zPosition = 101
        root.addChild(stage.content)

        stage.overlay.zPosition = 500
        root.addChild(stage.overlay)

        stage.reset()

        root.run(.repeatForever(.sequence([
            .run { [weak stage] in stage?.tick() },
            .wait(forDuration: 1.0 / 60)
        ])))

        return root
    }

    private init(size: CGSize, centre: Vec2, setup: @escaping Setup) {
        self.size = size
        self.centre = centre
        self.setup = setup

        let tile = size.height / 5.5
        self.scale = tile / GridGeometry.tileSize
        self.view = CGSize(width: size.width / tile, height: 5.5)
    }

    // MARK: - Building the world

    /// A world with nothing in it but floor, these claims and these crates.
    ///
    /// Claims are what give a team a person - the world puts one in the middle of
    /// each. A team that needs a person but not a visible base can have its claim
    /// somewhere off the picture; only claims passed to `tint` are drawn.
    func build(claims: [BaseClaim], crates: [Lootbox] = [], local: TeamID) {
        let width = 48, height = 40
        var byTeam: [TeamID: BaseClaim] = [:]
        for claim in claims { byTeam[claim.team] = claim }

        let generated = GeneratedMap(map: TileMap(width: width, height: height),
                                     claims: byTeam,
                                     trees: [],
                                     biomes: BiomeMap(width: width, height: height),
                                     lootboxes: crates,
                                     arcades: [],
                                     baseLayouts: [:],
                                     localTeam: local,
                                     seed: 7)
        world = World(generated: generated)

        // Puppets, every one. The script drives them; nobody thinks for them.
        for id in world.actors.keys {
            world.actors[id]?.ai = nil
        }

        effects.biomes = generated.biomes
        arcades.build(mapHeight: height)
        turrets.build(mapHeight: height)
    }

    /// The person on a team.
    func person(on team: TeamID) -> ActorID {
        world.actors.values.first { $0.team == team }?.id ?? ActorID(team.raw)
    }

    /// Puts a person somewhere and dresses them.
    func place(_ id: ActorID,
               at position: Vec2,
               helmet: HelmetTier = .none,
               blaster: BlasterTier = .starting,
               facingLeft: Bool = false) {
        guard var actor = world.actors[id] else { return }
        actor.position = position
        actor.helmet = helmet
        actor.blaster = blaster
        actor.health = actor.maxHealth
        actor.facesLeft = facingLeft
        actor.aim = Vec2(x: facingLeft ? -1 : 1, y: 0)
        world.actors[id] = actor
    }

    /// A claim's tint, cut to the picture so it never spills past its edges.
    func tint(_ claim: BaseClaim) {
        let halfW = Double(view.width) / 2, halfH = Double(view.height) / 2
        let left = max(Double(claim.origin.col), centre.x - halfW)
        let right = min(Double(claim.origin.col + claim.size), centre.x + halfW)
        let bottom = max(Double(claim.origin.row), centre.y - halfH)
        let top = min(Double(claim.origin.row + claim.size), centre.y + halfH)
        guard right > left, top > bottom else { return }

        let tint = SKSpriteNode(color: RenderPalette.colour(for: claim.team),
                                size: CGSize(width: GridGeometry.length(ofTiles: right - left),
                                             height: GridGeometry.length(ofTiles: top - bottom)))
        tint.anchorPoint = .zero
        tint.position = GridGeometry.point(for: Vec2(x: left, y: bottom))
        tint.alpha = ClaimRenderer.tintAlpha
        tint.zPosition = -50
        content.addChild(tint)
    }

    // MARK: - Interface

    func showHotbar() {
        let bar = HotbarNode()
        bar.setScale(interfaceScale)
        bar.position = CGPoint(x: 0, y: -size.height / 2 + HotbarNode.slotSize * interfaceScale * 0.62)
        overlay.addChild(bar)
        hotbar = bar
    }

    func showLeaderboard() {
        let board = LeaderboardNode()
        board.setScale(interfaceScale)
        // Anchored at its top-right corner, as in a match.
        board.position = CGPoint(x: size.width / 2 - 8, y: size.height / 2 - 8)
        overlay.addChild(board)
        leaderboard = board
    }

    func showMatchPanel() {
        let panel = MatchPanelNode()
        panel.setScale(interfaceScale)
        // Hung from its top edge, top middle, as in a match.
        panel.position = CGPoint(x: 0, y: size.height / 2 - 6)
        overlay.addChild(panel)
        matchPanel = panel
    }

    /// A thumbstick in a bottom corner. Its knob is moved by `push`.
    func stick(onRight: Bool, glyph: SKTexture? = nil) -> JoystickNode {
        let stick = JoystickNode(glyph: glyph)
        stick.setScale(interfaceScale)
        let inset = (JoystickNode.baseRadius + 14) * interfaceScale
        stick.position = CGPoint(x: (size.width / 2 - inset) * (onRight ? 1 : -1),
                                 y: -size.height / 2 + inset)
        overlay.addChild(stick)
        return stick
    }

    /// Moves a stick's knob the way a thumb would - towards a direction, or home.
    func push(_ stick: JoystickNode, towards direction: Vec2) {
        let reach = JoystickNode.baseRadius * 0.7
        stick.update(toLocalPoint: CGPoint(x: CGFloat(direction.x) * reach,
                                           y: CGFloat(direction.y) * reach))
    }

    // MARK: - Directing

    /// Runs this when the scene reaches this many seconds.
    func at(_ seconds: Double, _ run: @escaping (HowToPlayStage) -> Void) {
        cues.append(Cue(at: seconds, run: run))
    }

    /// How long the scene runs before it starts again.
    func loop(after seconds: Double) {
        length = seconds
    }

    func walk(_ id: ActorID, to target: Vec2) { errands[id] = .walk(to: target) }
    func shoot(_ id: ActorID, at target: Vec2) { errands[id] = .shoot(at: target) }
    func shoot(_ id: ActorID, atPerson target: ActorID) { errands[id] = .shootPerson(target) }
    func collectTokens(_ id: ActorID) { errands[id] = .collectTokens }
    func stop(_ id: ActorID) { errands[id] = nil }

    /// A one-off command, sent on the next step.
    func send(_ id: ActorID, _ command: Command) {
        once[id, default: []].append(command)
    }

    /// Points a person, without walking or firing - for a throw.
    func aim(_ id: ActorID, at target: Vec2) {
        guard var actor = world.actors[id] else { return }
        let towards = target - actor.position
        guard towards.length > 0.01 else { return }
        actor.aim = towards.normalized()
        if abs(towards.x) > 0.01 { actor.facesLeft = towards.x < 0 }
        world.actors[id] = actor
    }

    // MARK: - Running

    private func reset() {
        content.removeAllChildren()
        overlay.removeAllChildren()
        hotbar = nil
        leaderboard = nil
        matchPanel = nil

        blocks = BlockRenderer()
        wallDamage = WallDamageRenderer()
        arcades = ArcadeRenderer()
        turrets = TurretRenderer()
        lootboxes = LootboxRenderer()
        supply = SupplyDropRenderer()
        chests = ChestRenderer()
        groundItems = GroundItemRenderer()
        bombs = BombRenderer()
        projectiles = ProjectileRenderer()
        actors = ActorRenderer()
        gas = GasRenderer()
        effects = EffectsRenderer()
        drawnMapRevision = -1

        content.addChild(ground())
        for layer in [actors.groundNode, blocks.node, wallDamage.node, arcades.node,
                      turrets.node, lootboxes.node, supply.node, chests.node,
                      groundItems.node, bombs.node, projectiles.node, actors.node,
                      gas.node, effects.node] {
            content.addChild(layer)
        }

        cues = []
        errands = [:]
        once = [:]
        length = 6
        time = 0
        nextCue = 0
        accumulator = 0

        setup(self)
        cues.sort { $0.at < $1.at }
        draw(dt: 0)
    }

    private func tick() {
        // Only the page somebody is looking at plays. One coming back into view
        // starts again from the top rather than from wherever it was left.
        guard isOnScreen else {
            lastTick = nil
            return
        }

        let now = CACurrentMediaTime()
        guard let last = lastTick else {
            lastTick = now
            if time > 0 { reset() }
            return
        }
        lastTick = now

        let dt = min(0.1, now - last)
        accumulator += dt

        let step = GameConfig.fixedTimeStep
        while accumulator >= step {
            advance(step)
            accumulator -= step
        }

        draw(dt: dt)

        if time >= length { reset() }
    }

    private var isOnScreen: Bool {
        guard let root, let scene = root.scene, !root.isHidden else { return false }
        let point = root.convert(CGPoint.zero, to: scene)
        return scene.frame.insetBy(dx: -size.width / 2, dy: -size.height / 2).contains(point)
    }

    private func advance(_ dt: Double) {
        while nextCue < cues.count, cues[nextCue].at <= time {
            cues[nextCue].run(self)
            nextCue += 1
        }

        var commands = once
        once = [:]

        for id in world.actors.keys.sorted(by: { $0.raw < $1.raw }) {
            guard let actor = world.actors[id], actor.isAlive else { continue }
            var list = commands[id] ?? []

            switch errands[id] {
            case .walk(let target)?:
                let towards = target - actor.position
                if towards.length < 0.12 {
                    errands[id] = nil
                    list.append(.move(.zero))
                } else {
                    list.append(.move(towards.length > 1 ? towards.normalized() : towards))
                }

            case .shoot(let target)?:
                list.append(.move(.zero))
                let towards = target - actor.position
                if towards.length > 0.01 { list.append(.shoot(towards.normalized())) }

            case .shootPerson(let target)?:
                list.append(.move(.zero))
                if let other = world.actors[target], other.isAlive {
                    let towards = other.position - actor.position
                    if towards.length > 0.01 { list.append(.shoot(towards.normalized())) }
                } else {
                    errands[id] = nil
                }

            case .collectTokens?:
                // Nearest first, ties by id, so the walk is the same every loop.
                var nearest: Vec2?
                var shortest = Double.greatestFiniteMagnitude
                for itemID in world.groundItems.keys.sorted(by: { $0.raw < $1.raw }) {
                    guard let item = world.groundItems[itemID],
                          case .token = item.pickup else { continue }
                    let distance = (item.position - actor.position).length
                    guard distance < shortest else { continue }
                    shortest = distance
                    nearest = item.position
                }

                if let target = nearest {
                    let towards = target - actor.position
                    list.append(.move(towards.length > 1 ? towards.normalized() : towards))
                } else {
                    list.append(.move(.zero))
                }

            case nil:
                list.append(.move(.zero))
            }

            commands[id] = list
        }

        world.step(commands: commands, dt: dt)
        time += dt
    }

    // MARK: - Drawing

    private func draw(dt: Double) {
        guard let world = world else { return }

        if world.mapRevision != drawnMapRevision {
            blocks.build(from: world.map)
            drawnMapRevision = world.mapRevision
        }

        // Nowhere near anybody's ears: the pictures are silent.
        let ears = Vec2(x: -10_000, y: -10_000)

        blocks.sync(with: world)
        wallDamage.sync(with: world)
        lootboxes.sync(with: world)
        supply.sync(with: world)
        chests.sync(with: world)
        arcades.sync(with: world)
        turrets.sync(with: world)
        groundItems.sync(with: world)
        bombs.sync(with: world)
        projectiles.sync(with: world, heardFrom: ears)
        actors.sync(with: world, dt: dt)
        gas.sync(with: world, dt: dt)
        effects.sync(with: world)

        hotbar?.update(with: world)
        leaderboard?.update(with: world)
        matchPanel?.update(with: world)

        dispatch(world.takeEvents())
    }

    /// The match's own answers to what just happened, minus the sounds and minus
    /// anything that is about the person holding the phone.
    private func dispatch(_ events: [WorldEvent]) {
        for event in events {
            switch event {
            case .blast(let position):
                bombs.flash(at: position)
            case .jackpot(let position):
                effects.jackpot(at: position)
            case .supplyDropOpened(let position):
                effects.jackpot(at: position)
                bombs.flash(at: position)
            case .perkStarted(let perk, let user):
                guard let actor = world.actors[user] else { break }
                effects.charge(at: actor.position, perk: perk)
                actors.charge(user)
            case .gas(let position):
                effects.burst(at: position)
            case .chestCracked(let position, _):
                effects.jackpot(at: position)
                bombs.flash(at: position)
            case .machineHit(let id, let position):
                arcades.hit(id)
                effects.machineStruck(at: position)
            case .machineDestroyed(_, let position):
                effects.jackpot(at: position)
            case .chestHit(let id, let position):
                chests.hit(id)
                effects.machineStruck(at: position)
            case .turretHit(let id, let position):
                turrets.hit(id)
                effects.machineStruck(at: position)
            case .wallHit(let tile, let position):
                blocks.hit(at: tile)
                effects.machineStruck(at: position)
            case .sealed(let team, let chests):
                let ring = world.enclosure(of: team).wall
                guard !ring.isEmpty else { break }
                effects.seal(GameScene.sweptRound(ring), chests: chests)
            case .kill(_, _, let position, let points, _):
                effects.mark(killAt: position, points: points, mine: false)
            default:
                break
            }
        }
    }

    /// The match's checkered ground, cut to the picture with rounded corners.
    private func ground() -> SKSpriteNode {
        let tile = GridGeometry.tileSize
        let pixels = CGSize(width: CGFloat(view.width) * tile, height: CGFloat(view.height) * tile)
        let tones = RenderPalette.tones(for: .plains)

        let left = centre.x - Double(view.width) / 2
        let bottom = centre.y - Double(view.height) / 2

        let format = UIGraphicsImageRendererFormat.default()
        format.opaque = false
        let image = UIGraphicsImageRenderer(size: pixels, format: format).image { _ in
            UIBezierPath(roundedRect: CGRect(origin: .zero, size: pixels),
                         cornerRadius: 11 / scale).addClip()

            let firstCol = Int(floor(left)), lastCol = Int(ceil(left + Double(view.width)))
            let firstRow = Int(floor(bottom)), lastRow = Int(ceil(bottom + Double(view.height)))

            for col in firstCol..<lastCol {
                for row in firstRow..<lastRow {
                    ((col + row) % 2 == 0 ? tones.light : tones.dark).setFill()
                    // Images run top-down, tiles bottom-up.
                    let x = (Double(col) - left) * Double(tile)
                    let y = (bottom + Double(view.height) - Double(row + 1)) * Double(tile)
                    UIRectFill(CGRect(x: x, y: y, width: Double(tile), height: Double(tile)))
                }
            }
        }

        let sprite = SKSpriteNode(texture: SKTexture(image: image), size: pixels)
        sprite.position = GridGeometry.point(for: centre)
        sprite.zPosition = -100
        return sprite
    }
}
