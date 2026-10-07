//
//  GameScene.swift
//  Loot Wars
//
//  The seam between the simulation and SpriteKit, and it is allowed to do exactly
//  four things:
//
//    1. turn input into Commands
//    2. run the fixed-step loop
//    3. hand the world to the renderers
//    4. lay out the UI
//
//  If this file starts growing game rules, they belong in a system in Core instead.
//  Notice that tapping a tile does not place a block here - it asks for one.
//  BuildSystem decides whether it happens.
//

import SpriteKit

final class GameScene: SKScene {

    // MARK: - Simulation

    private var world: World!

    /// Commands raised by one-off input (taps), waiting for the next tick.
    private var queuedCommands: [Command] = []

    // MARK: - Rendering

    private let worldLayer = SKNode()
    private let tileRenderer = TileMapRenderer()
    private let claimRenderer = ClaimRenderer()
    private let treeRenderer = TreeRenderer()
    private let blockRenderer = BlockRenderer()
    private let arcadeRenderer = ArcadeRenderer()
    private let turretRenderer = TurretRenderer()
    private let wallDamageRenderer = WallDamageRenderer()
    private let lootboxRenderer = LootboxRenderer()
    private let supplyRenderer = SupplyDropRenderer()
    private let supplyCompass = SupplyCompassNode()

    /// Says so when you take somebody out - see KillBannerNode.
    private let killBanner = KillBannerNode()

    /// Counts down the quiet after a raid - see RebuildTimerNode.
    private let rebuildTimer = RebuildTimerNode()

    /// Points home when home is off screen - see BaseCompassNode.
    private let baseCompass = BaseCompassNode()

    /// Whether the base was being raided last frame, so the alarm sounds once
    /// when a raid starts rather than every frame of it.
    private var wasRaided = false

    /// How many supply drops this screen has already called out, so each one is
    /// announced once, on the frame it lands.
    private var supplyDropsAnnounced = 0

    /// Drops already called out as open, so each one is only shouted about once.
    private var supplyDropsCalledOpen: Set<LootboxID> = []
    private let chestRenderer = ChestRenderer()
    private let groundItemRenderer = GroundItemRenderer()
    private let bombRenderer = BombRenderer()
    private let projectileRenderer = ProjectileRenderer()
    private let actorRenderer = ActorRenderer()
    private let gasRenderer = GasRenderer()
    private let effectsRenderer = EffectsRenderer()
    private let placementGhost = PlacementGhost()
    private let blueprint = BlueprintRenderer()
    private let cameraController = CameraController()

    /// The map revision the block layer was last drawn from, so it is only rebuilt
    /// when a tile actually changed.
    private var drawnMapRevision = -1

    // MARK: - UI

    /// Twin sticks: walk with the left, aim and fire with the right.
    ///
    /// Aiming used to be a side effect of walking, which meant you could never
    /// shoot at anything you were not walking towards - and neither could a bot.
    /// Every fight collapsed into two actors marching into each other.
    private let moveStick = JoystickNode()
    ///
    /// The aim stick, always in the bottom-right corner, and the button for your
    /// own chest, which appears in the heal button's spot above it when you are at
    /// your chest. It used to replace the aim stick, which took your shooting away
    /// whenever you walked past a crate or your chest.
    private let aimStick = JoystickNode(glyph: Glyphs.crosshair)
    private let openButton = ActionButtonNode(glyph: Glyphs.chest,
                                              radius: HealButtonNode.radius,
                                              grabRadius: HealButtonNode.grabRadius,
                                              fill: RenderPalette.stickBackground,
                                              glass: true, shadow: true)

    /// What that corner is currently for.
    private enum CornerAction: Equatable {
        case aim
        case lootbox
        /// Your own: opens the storage panel. Somebody else's is not on this
        /// button at all - it is shot open, so it belongs to the blaster rather
        /// than to a corner control. See GameConfig.Chest.health.
        case chest(ChestID)
    }

    private var cornerAction: CornerAction = .aim

    private let leaderboard = LeaderboardNode()

    /// The clock and your purse, one row, top middle. The purse lives in there
    /// rather than out here because the panel owns its layout; see MatchPanelNode
    /// for why those two numbers share a plate.
    private let matchPanel = MatchPanelNode()

    /// Opens the shop. A button, on its own, in the top-left corner - where the
    /// health panel used to be.
    ///
    /// It was briefly a wide plate with the purse standing inside it, on the theory
    /// that tapping your own balance should open the shop. What that actually did
    /// was put a 132-point slab in the corner of the map and leave the two numbers
    /// you read mid-fight - the clock and the purse - at opposite ends of the
    /// screen. A button is a button and a readout is a readout.
    ///
    /// 40 rather than 34, because standing on its own it was the hardest thing on
    /// the top edge to find. It also wore a gold ring for one revision, on the
    /// theory that an outline is what separates a control from a readout when they
    /// share a fill - and it does, but it read as loot in the corner of the map and
    /// was the loudest thing on the screen for the thing you press least often.
    /// Plain and bigger, which was what was asked for first.
    ///
    /// 80 points square costs the corner 12 points of height, which everything
    /// below it inherits through cornerBottom. On an SE - where that gap is
    /// tightest - the shop panel still clears the corner by 18 and the floor by 30.
    private static let shopButtonRadius: CGFloat = 40

    private let shopButton = ActionButtonNode(glyph: Glyphs.shoppingBag,
                                              radius: shopButtonRadius, grabRadius: 50,
                                              shape: .roundedSquare,
                                              fill: RenderPalette.hudPanel,
                                              // Grown with the plate, at the same
                                              // 0.73 the button has always worn.
                                              // The reference draws it at 0.6,
                                              // which left more air round it than
                                              // the button wanted.
                                              glyphSize: 58,
                                              glass: true, shadow: true)
    private let shopPanel = ShopPanelNode()

    /// One offer, unprompted, for a few seconds - see QuickBuyNode.
    private let quickBuy = QuickBuyNode()

    /// Teaches the one gesture nothing on screen suggests: hold a slot to drop it.
    private let hint = HintNode()

    /// Whether tips are on for this match - read once, from Settings.
    private let tipsOn = Prefs.tipsOn

    /// The hold hint's whole budget for a match.
    ///
    /// One showing, spent only on the moment that earns it: walking over something
    /// and not picking it up - which is the moment a full bag stops being an
    /// abstraction. After that it is gone for the rest of the match, one successful
    /// hold retires it early, and Prefs retires it for good: every lesson in this
    /// game is shown on a first match and never again.
    private var holdHintsLeft = 1
    private var hasUsedHold = false

    /// Whether a wall has been laid THIS MATCH, which is the only thing the build
    /// reminder asks about.
    ///
    /// There used to be a budget beside this, and a count of walls laid, and a flag
    /// in Prefs saying the gesture had been learned for good. All three existed to
    /// retire a lesson, and the reminder is not a lesson - it is the answer to "why
    /// is my base still open", which is a question a player can ask in their tenth
    /// match as easily as their first.
    private var hasBuilt = false

    /// Whether the player was standing in their own claim last frame, so the build
    /// hint fires on ARRIVING home rather than once per frame while standing there.
    /// The same shape as wasBlocked, and for the same reason: a hint is a reaction
    /// to a moment, and "being at home" is a state.
    private var wasHome = false

    /// The same pair, for walking up to somebody else's chest.
    ///
    /// This one exists because a control was REMOVED. Standing at an enemy chest
    /// used to put a crowbar glyph on the corner button, and that button was the
    /// whole of how anybody learned that a chest could be taken. A chest is shot
    /// open now, so the corner keeps the aim stick and there is nothing on screen
    /// to discover - which is fine once you know and impossible before.
    ///
    /// Twice, and it does not expire with the early window the way the selling
    /// lesson does. Raiding happens when a raid happens, which for a player still
    /// finding their feet is often well past the first minute, and a lesson that
    /// has timed out before the situation it teaches has arisen is not a lesson.
    private var wasAtEnemyChest = false
    private var raidHintsLeft = 2

    /// Who killed you, while you are waiting to come back - see aimCamera.
    private var killedBy: ActorID?

    /// Whether the player was already standing on something they could not take.
    ///
    /// The hint fires on the EDGE - the step onto the item - rather than the whole
    /// time somebody is standing on it. Otherwise walking a line of loot with a
    /// full bag re-arms the message over and over and it never leaves the screen,
    /// which is exactly how a two-second hint turns into a permanent one.
    private var wasBlocked = false

    /// When the shop button next waves at somebody who has not been in.
    private var nextNudge: TimeInterval = 0
    private let results = ResultsNode()

    /// The pause button by the timer, the menu it opens, and whether the match
    /// is stopped. Paused, the world does not step, its animations hold, and
    /// only the menu answers a tap.
    private let pauseButton = PauseButtonNode()

    /// The blurred map behind every control - see GlassBackdrop and GlassNode.
    private let glass = GlassBackdrop()
    private let pauseMenu = PauseMenuNode()
    private var matchPaused = false
    private let hotbar = HotbarNode()
    private let chestPanel = ChestPanelNode()
    private let respawnBanner = RespawnBanner()

    /// A wash of the perk's own colour over the whole screen, for the instant one
    /// is drunk.
    ///
    /// The one effect in this game that is about the PLAYER rather than about the
    /// world, and the only reason it earns that is what a perk is: a thing you find
    /// twice a match and choose your moment for. Everything else the item does is
    /// drawn on the map and is therefore equally true for a bot - which is correct,
    /// and is also why none of it can ever say "this is happening to YOU".
    ///
    /// Sized from the screen in layOutUI, because the camera zooms and a rectangle
    /// sized once would stop covering the corners the first time somebody opened
    /// the game on an iPad.
    private let perkFlash = SKSpriteNode(color: .white, size: .zero)


    /// The hotbar slot picked out, waiting for a tile.
    ///
    /// ONLY EVER A CHEST OR A MACHINE now. Everything else is spent by the tap that
    /// used to select it - see tapHotbar - so a selection means exactly one thing:
    /// something is waiting to be told where to go.
    ///
    /// Scene state, not world state, and deliberately so: a selection is a thing
    /// this screen remembers between two taps, and the simulation never hears about
    /// it. What crosses into Core is the finished intent - place a chest HERE.
    private var selectedSlot: Int?

    /// Where the thing being placed is currently pointed.
    ///
    /// Scene state like the selection, and for the same reason: an aim is a thing
    /// this screen is holding between two moments of a gesture. What crosses into
    /// Core is the finished intent - put it HERE - and only on release.
    private var ghostOrigin: GridPoint?

    /// Throws whatever throwable you have picked out, tucked above the corner.
    ///
    /// THIS BUTTON CAME BACK, and it is worth being precise about what was wrong
    /// with it the first time, because "we removed it and put it back" is only not
    /// a circle if something actually changed.
    ///
    /// It used to serve SEVEN item types. Which one it would spend depended on a
    /// selection made on a bar at the other end of the screen, with nothing drawn
    /// between the two to connect them - so the button had no fixed meaning, and
    /// the game had to guess for you what should be in it (see the arming helpers
    /// that went with it). That is what players could not follow, and all of it is
    /// still gone: five of the seven are spent by the tap that used to select them.
    ///
    /// What is left is one job. It exists only while something throwable is in
    /// hand, it wears that thing's own art, and it does the one thing a bomb needs
    /// that a tap cannot do - go off in a direction you chose, with the blaster
    /// still available while you choose it.
    ///
    /// The alternative was putting the throw on the aim stick: pull to aim, release
    /// to throw. It reads beautifully written down and it is wrong in the hand.
    /// Arming a bomb took the trigger away entirely, so you could not shoot back
    /// while holding one, and every touch of the stick became a committed throw
    /// with no way to change your mind - including touches you did not mean, since
    /// a cancelled gesture releases exactly like a deliberate one.
    /// Heals with the best thing you carry - see HealButtonNode.
    private let healButton = HealButtonNode()

    private let throwButton = ActionButtonNode(glyph: Glyphs.lootbox,
                                               radius: 40, grabRadius: 48,
                                               fill: RenderPalette.stickBackground,
                                               glass: true, shadow: true)

    /// What the throw button is currently showing, so its glyph is only rebuilt
    /// when the item in hand changes rather than every frame.
    private var throwGlyph: ItemType?

    /// What the ghost is aiming, so a fresh selection starts somewhere sensible
    /// rather than wherever the last one was left pointing.
    private var ghostType: ItemType?

    /// The item picked out of the hotbar that wants a tile, if there is one.
    ///
    /// Asked in three places, so it is one question rather than three spellings of
    /// it - and it reads from the inventory each time, so an item spent, dropped or
    /// stored stops being placeable the same frame.
    private var placingType: ItemType? {
        guard let slot = selectedSlot,
              let type = world?.localPlayer?.inventory.stack(at: slot)?.type,
              type.use == .mapTap else { return nil }
        return type
    }

    /// The slot holding something the aim stick would throw, if one is picked out.
    ///
    /// The mirror of placingType, and it reads from the inventory every time for
    /// the same reason: a bomb spent, dropped or stored stops being throwable on
    /// the same frame, so the stick goes back to shooting without anything having
    /// to remember to put it back.
    private var throwingSlot: Int? {
        guard let slot = selectedSlot,
              let type = world?.localPlayer?.inventory.stack(at: slot)?.type,
              type.use == .thrown else { return nil }
        return slot
    }

    /// The slot holding a heal that has been picked out, if one is. The button
    /// above the corner heals with it - see quickAction.
    private var healingSlot: Int? {
        guard let slot = selectedSlot,
              world?.localPlayer?.inventory.stack(at: slot)?.type.isHealing == true
        else { return nil }
        return slot
    }

    /// How far into a match the drop hint will still offer itself. The opening
    /// third, and no later.
    private static let hintWindow: Double = 0.35

    /// How near an enemy has to be, and how recently you have been shot, for the
    /// screen to stop trying to teach you anything.
    private static let hintCombatRange: Double = 11
    private static let hintCombatQuiet: Double = 4

    /// How long a finger must stay put to become a hold rather than a tap.
    ///
    /// Shorter than the system's half-second long press. This is a game action, not
    /// a context menu, and half a second of nothing happening while you are being
    /// shot at feels like the game has stopped listening.
    private static let holdDuration: TimeInterval = 0.4

    /// The same, for selling off the hotbar - a little longer, because a hold
    /// there now says "SELL +3" and fills up while it waits (HotbarNode.beginHold),
    /// and four tenths was over before anybody could read it. Long enough to see
    /// what is about to happen and let go; short enough not to feel like a menu.
    private static let sellHoldDuration: TimeInterval = 0.65

    private static func holdDuration(for target: PendingPress.Target) -> TimeInterval {
        switch target {
        case .map:    return holdDuration
        case .hotbar: return sellHoldDuration
        }
    }

    #if os(iOS) || os(tvOS)
    /// Which finger owns which control.
    private var moveTouch: UITouch?
    private var aimTouch: UITouch?
    private var throwTouch: UITouch?
    private var healTouch: UITouch?
    private var openTouch: UITouch?

    /// A finger on the shop's cards: a tap (acted on when it lifts) or a swipe
    /// between BUY and SELL, which only becomes clear once it moves.
    private var shopTouch: UITouch?
    private var shopTouchStart: CGPoint = .zero
    private var shopSwiping = false

    /// The finger aiming something onto the map.
    ///
    /// Deliberately NOT a PendingPress. Positioning is a drag, and a drag past the
    /// slop cancels a pending press - so lining a machine up would have quietly
    /// stopped counting as anything. It also has no hold meaning: holding the map
    /// takes a wall down, and doing that while placing a machine on the same spot
    /// is not a gesture anybody wants to discover by accident.
    private var placingTouch: UITouch?

    /// The finger painting a run of wall, and the tiles it has already put one on.
    ///
    /// Not a PendingPress either, and for the same reason placingTouch is not: this
    /// IS the drag a pending press treats as a cancellation. A press on the map has
    /// meant two things - tap to build one, hold to take one down - and a wandering
    /// finger meant neither, which is a whole gesture spent on nothing.
    ///
    /// The set is what keeps a slow finger from queueing the same tile sixty times.
    /// BuildSystem would refuse all but the first, so this is about the commands
    /// and the pops rather than about the walls.
    private var paintTouch: UITouch?
    private var painted: Set<GridPoint> = []

    /// Where the painting finger was last seen, so the gap between two touch
    /// events can be filled in rather than skipped over.
    private var paintedFrom: CGPoint?

    /// A finger that has not yet decided whether it is a tap or a hold.
    ///
    /// One at a time, deliberately. Tapping and holding are opposite meanings of
    /// the same gesture, and two of them resolving at once on different targets is
    /// a class of bug nobody would enjoy reproducing.
    private struct PendingPress {
        enum Target {
            case map
            case hotbar(slot: Int)
        }

        let touch: UITouch
        /// Where the press landed ON SCREEN, in the camera's own space.
        ///
        /// The camera's space rather than the scene's, which is what this used to
        /// be. Two reasons, and the second one was always a bug. The camera is
        /// scaled now, so a scene-space delta is a world measurement and tapSlop -
        /// which is a number of points a thumb moves - would have meant twice as
        /// far on an iPad. And the camera FOLLOWS the player, so a scene-space
        /// origin drifts under a finger that has not moved at all: walk while
        /// holding still and the press would cancel itself. The camera's own space
        /// is neither scaled nor moved by any of that.
        let screenOrigin: CGPoint
        /// Where the press landed on the MAP, captured at press time.
        ///
        /// Not looked up again when the hold fires: the camera follows the player,
        /// so the same point on the screen is a different tile half a second later,
        /// and the wall you pressed is the one you meant.
        let worldOrigin: CGPoint
        let beganAt: TimeInterval
        let target: Target
        /// The hold has already fired, so the release must not act as well.
        var fired = false
    }

    private var pending: PendingPress?

    /// Slide further than this and it was a drag - neither a tap nor a hold.
    private let tapSlop: CGFloat = 24
    #endif

    // MARK: - Fixed timestep

    private var lastUpdateTime: TimeInterval = 0
    private var accumulator: Double = 0

    // MARK: - Setup

    class func newGameScene() -> GameScene {
        // Counted here rather than at the whistle: what it gates is the tutorial,
        // and somebody who quit halfway through their first match has still seen
        // it.
        Prefs.matchesStarted += 1

        let scene = GameScene(size: CGSize(width: 1024, height: 768))
        scene.scaleMode = .resizeFill
        return scene
    }

    override func didMove(to view: SKView) {
        backgroundColor = RenderPalette.background
        anchorPoint = CGPoint(x: 0.5, y: 0.5)

        // A fresh map every launch. The seed is logged so any map worth keeping -
        // or worth debugging - can be pinned in GameConfig.Map.fixedSeed.
        let seed = GameConfig.Map.fixedSeed ?? UInt64.random(in: UInt64.min...UInt64.max)
        print("Loot Wars map seed: \(seed)")

        let generated = MapFactory.generate(seed: seed)
        world = World(generated: generated)

        // What this match has in it: your level's unlocks, or everything in dev
        // mode - see Progress. Before the first step, so nothing is ever rolled
        // or handed out from a fuller set.
        world.unlocks = Progress.matchUnlocks
        world.duration = Progress.matchLength
        world.difficulty = Prefs.difficulty
        world.setLocalName(Prefs.playerName)
        world.setLocalAssist(Prefs.easyControls)

        // Before anything draws an item, so a turret on the floor is in your
        // colour from the first frame - see ItemArt.viewer.
        ItemArt.viewer = world.localPlayer?.team

        // Before the first frame rather than on whichever frame first needs it -
        // see ArtFit.warm.
        ArtFit.warm(["Chest", "Arcade", "Mini Arcade"])

        tileRenderer.build(from: generated.map, biomes: generated.biomes)
        claimRenderer.build(claims: generated.claims)
        treeRenderer.build(patches: generated.trees, biomes: generated.biomes)
        effectsRenderer.biomes = generated.biomes
        arcadeRenderer.build(mapHeight: generated.map.height)
        turretRenderer.build(mapHeight: generated.map.height)
        worldLayer.addChild(tileRenderer.node)
        worldLayer.addChild(claimRenderer.node)

        // On the ground with the claim tint, under everything that stands on it.
        worldLayer.addChild(blueprint.node)

        worldLayer.addChild(actorRenderer.groundNode)
        worldLayer.addChild(treeRenderer.node)
        worldLayer.addChild(blockRenderer.node)
        worldLayer.addChild(wallDamageRenderer.node)
        worldLayer.addChild(arcadeRenderer.node)
        worldLayer.addChild(turretRenderer.node)
        worldLayer.addChild(lootboxRenderer.node)
        worldLayer.addChild(supplyRenderer.node)
        worldLayer.addChild(chestRenderer.node)
        worldLayer.addChild(groundItemRenderer.node)
        worldLayer.addChild(bombRenderer.node)
        worldLayer.addChild(projectileRenderer.node)
        worldLayer.addChild(actorRenderer.node)
        worldLayer.addChild(gasRenderer.node)
        worldLayer.addChild(effectsRenderer.node)
        worldLayer.addChild(placementGhost.node)
        addChild(worldLayer)

        // The UI rides on the camera, so it stays put on screen while the map moves.
        camera = cameraController.node
        addChild(cameraController.node)
        cameraController.node.addChild(moveStick)
        cameraController.node.addChild(aimStick)
        cameraController.node.addChild(openButton)
        openButton.isHidden = true
        cameraController.node.addChild(throwButton)
        throwButton.isHidden = true
        cameraController.node.addChild(healButton)
        healButton.isHidden = true

        cameraController.node.addChild(leaderboard)
        cameraController.node.addChild(matchPanel)
        cameraController.node.addChild(shopButton)
        cameraController.node.addChild(shopPanel)
        cameraController.node.addChild(quickBuy)
        cameraController.node.addChild(hint)
        cameraController.node.addChild(supplyCompass)
        cameraController.node.addChild(killBanner)
        cameraController.node.addChild(rebuildTimer)
        cameraController.node.addChild(baseCompass)
        cameraController.node.addChild(results)
        cameraController.node.addChild(pauseButton)
        cameraController.node.addChild(pauseMenu)
        cameraController.node.addChild(hotbar)
        cameraController.node.addChild(chestPanel)
        cameraController.node.addChild(respawnBanner)

        // Over the map and UNDER every control, so a flash never washes out the
        // stick you are holding or the bar you are reading. It is drawn on the
        // camera, so it covers the screen wherever the camera is.
        perkFlash.zPosition = 500
        perkFlash.alpha = 0
        perkFlash.isHidden = true
        cameraController.node.addChild(perkFlash)
        layOutUI()

        syncRenderers()

        #if os(iOS)
        // A call, a notification pulled down, the app switcher: the match stops
        // and waits rather than carrying on without you.
        NotificationCenter.default.addObserver(self, selector: #selector(appWillResignActive),
                                               name: UIApplication.willResignActiveNotification,
                                               object: nil)
        #endif
    }

    override func willMove(from view: SKView) {
        NotificationCenter.default.removeObserver(self)
    }

    #if os(iOS)
    @objc private func appWillResignActive() {
        pauseMatch()
    }
    #endif

    // MARK: - Pausing

    /// Stops the match and shows the pause menu. Not once it is over.
    private func pauseMatch() {
        guard world != nil, !matchPaused, !world.isOver, results.isHidden else { return }
        matchPaused = true

        // Let go of everything held, so nothing is still firing or walking when
        // the match comes back.
        #if os(iOS) || os(tvOS)
        let held = [moveTouch, aimTouch, throwTouch, healTouch, openTouch].compactMap { $0 }
        releaseControls(matching: Set(held))
        #endif

        worldLayer.isPaused = true
        let place = world.localPlayer.flatMap { player in
            world.standings.firstIndex { $0.team == player.team }
        }
        pauseMenu.show(timeLeft: world.timeRemaining, place: place)
    }

    private func resumeMatch() {
        guard matchPaused else { return }
        matchPaused = false
        worldLayer.isPaused = false
        pauseMenu.hide()
        // The clock starts again from now, not from when it stopped.
        lastUpdateTime = 0
        accumulator = 0
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        layOutUI()
    }

    /// How much of each short edge is eaten by the notch, the island or the
    /// rounded corner, in points.
    ///
    /// BOTH EDGES, and asking only about one was the bug. This read
    /// safeAreaInsets.right and nothing else, on the reasoning that in landscape
    /// the island lands in the top-right corner - which is true of exactly one of
    /// the two landscape rotations. Turn the phone the other way and the whole
    /// inset moves to the LEFT edge, where nothing was asking about it, so the
    /// panels in that corner sat under the island while the leaderboard opposite
    /// them politely inset itself away from nothing at all.
    ///
    /// Nothing here decides which way up the phone is. It reads both numbers and
    /// applies each to its own side, so whichever edge is eaten is the edge that
    /// moves and the other one stays where it was.
    /// Supply drops: called out when one lands, and pointed at from the edge of
    /// the screen while it is out of sight - see SupplyCompassNode.
    private func updateSupplyDrops() {
        // A fresh match starts the count again.
        if world.supplyDropsSent < supplyDropsAnnounced {
            supplyDropsAnnounced = 0
            supplyDropsCalledOpen = []
        }

        // And again the moment one opens, which is when it matters: whoever gets
        // there first takes it.
        for drop in world.supplyDrops where !drop.isLocked && !supplyDropsCalledOpen.contains(drop.id) {
            supplyDropsCalledOpen.insert(drop.id)
            SoundPlayer.shared.play(.notification)
            hint.show("SUPPLY DROP IS OPEN", seconds: 2.2)
        }

        if world.supplyDropsSent > supplyDropsAnnounced {
            supplyDropsAnnounced = world.supplyDropsSent
            SoundPlayer.shared.play(.notification)
            hint.show("SUPPLY DROP INCOMING", seconds: 2.4)
        }

        // Where each drop is relative to the middle of the screen, in the screen
        // points the interface is laid out in: the camera's scale undone, since
        // the interface hangs off the camera and is not zoomed with the map.
        let zoom = max(GridGeometry.zoom(for: size), 0.0001)
        let eye = cameraController.node.position

        let targets = world.supplyDrops.map { drop -> SupplyCompassNode.Target in
            let spot = GridGeometry.point(for: drop.position)
            return SupplyCompassNode.Target(
                id: drop.id,
                offset: CGPoint(x: (spot.x - eye.x) / zoom, y: (spot.y - eye.y) / zoom),
                secondsLeft: drop.isLocked ? Int(drop.lockTimer.rounded(.up)) : nil)
        }

        // Kept in from the edges, the notch and the home bar, so a marker is
        // never half off the glass.
        let edge: CGFloat = 38
        let bounds = CGRect(x: -size.width / 2 + safeLeft + edge,
                            y: -size.height / 2 + edge,
                            width: size.width - safeLeft - safeRight - edge * 2,
                            height: size.height - edge * 2)
        supplyCompass.update(targets: targets, bounds: bounds)
    }

    private var safeLeft: CGFloat {
        #if os(iOS) || os(tvOS)
        return view?.safeAreaInsets.left ?? 0
        #else
        return 0
        #endif
    }

    private var safeRight: CGFloat {
        #if os(iOS) || os(tvOS)
        return view?.safeAreaInsets.right ?? 0
        #else
        return 0
        #endif
    }

    /// The pair this interface was last laid out against - left in x, right in y.
    private var laidOutForInsets = CGPoint(x: -1, y: -1)

    /// The insets are not known when the scene first lays itself out, and they
    /// change on rotation. Rather than hunt for the callback that covers both, this
    /// notices the values moving - two float compares a frame, against a reposition
    /// that is a handful of assignments.
    ///
    /// Scoped to the READOUTS on purpose, and that line has not moved. Laying the
    /// whole interface out from the safe area put the sticks sixty points inboard
    /// and you did not like it, so the controls still measure from the glass -
    /// where your thumbs are is a fact about your hands rather than about the
    /// hardware. What changed is which readouts: it is the panels in both top
    /// corners now, not just the one on the right.
    private func repositionForSafeAreaIfNeeded() {
        guard laidOutForInsets != CGPoint(x: safeLeft, y: safeRight) else { return }
        layOutUI()
    }

    /// The screen takes the colour of what you just drank, and lets it go.
    ///
    /// Short and not very strong - a fifth of a second up, a third back down, and
    /// it never passes a third of an alpha. A power-up is drunk in the middle of a
    /// fight, usually because the fight is going badly, and an effect that blanked
    /// the screen for half a second would be at its most spectacular exactly when
    /// it could get you killed. This is a flourish, not a cutaway.
    ///
    /// Under the controls - see where it is parented - so the stick under your
    /// thumb and the health bar you are reading are never washed out by it.
    private func flashScreen(for perk: Perk) {
        perkFlash.removeAllActions()
        perkFlash.color = RenderPalette.colours(for: perk, at: 0).bright
        perkFlash.isHidden = false
        perkFlash.alpha = 0

        perkFlash.run(.sequence([
            .fadeAlpha(to: 0.30, duration: 0.09),
            .fadeAlpha(to: 0.12, duration: 0.12),
            .fadeOut(withDuration: 0.34),
            .hide()
        ]))
    }

    private func layOutUI() {
        // How far in the camera has to sit to show the same amount of world as a
        // phone - see GridGeometry.zoom. One on a phone, about a half on an iPad.
        //
        // On the CAMERA rather than on the world layer, because the interface is
        // parented to the camera and a camera's own children are drawn at their
        // natural point size whatever it is scaled to. So the map zooms and the
        // buttons do not, which is the whole reason the HUD hangs off the camera.
        let zoom = GridGeometry.zoom(for: size)
        cameraController.node.setScale(zoom)

        // Tell the simulation how much of the map this screen is actually showing,
        // so bots will not open fire from somewhere the player cannot look. Done
        // here because this is where the size is known, and it is the only thing
        // Render ever pushes INTO the world - a plain number, no SpriteKit.
        //
        // Through the zoom, and it has to be: this is the rectangle the player can
        // SEE, and on a pulled-in camera that is a good deal less of the map than
        // the screen is points wide.
        if world != nil {
            world.visibleHalfExtent = Vec2(
                x: Double(size.width / 2 * zoom / GridGeometry.tileSize),
                y: Double(size.height / 2 * zoom / GridGeometry.tileSize))
        }

        let margin: CGFloat = 110

        // Left-handed controls (Settings) mirror the two sticks, and the throw
        // button goes with the aim stick. Everything else stays where it is.
        let side: CGFloat = Prefs.leftHanded ? -1 : 1

        moveStick.position = CGPoint(x: -side * (size.width / 2 - margin),
                                     y: -size.height / 2 + margin)
        aimStick.position = CGPoint(x: side * (size.width / 2 - margin),
                                    y: -size.height / 2 + margin)

        // Right edges flush with the stick below it, and tucked down close.
        //
        // The offset is solved, not eyeballed. This button has to be offered a
        // touch BEFORE the aim stick (see touchesBegan), because it sits inside the
        // stick's 120pt grab radius and would otherwise never be pressed at all.
        // That priority then makes its OWN grab radius the hazard: no part of the
        // stick you can see may fall inside it, or a thumb meaning to aim would
        // throw a bomb instead. So the centres must stay further apart than
        // 48 + 62 = 110, and moving right buys some of that distance back - which
        // is what lets it come down as far as it has.
        //
        // The heal button shares the spot. Only one of the two is ever up - see
        // quickAction - so the thumb always goes to the same place.
        throwButton.position = CGPoint(
            x: aimStick.position.x + side * (JoystickNode.baseRadius - 40),
            y: aimStick.position.y + 115)
        healButton.position = throwButton.position
        // Your chest's button takes the same spot too - the aim stick stays the
        // aim stick, always.
        openButton.position = throwButton.position

        // Generously oversized rather than exactly the screen: the camera can be
        // mid-shake when this plays, and a rectangle cut to the glass would show a
        // hard edge sliding in from one side.
        perkFlash.size = CGSize(width: size.width * 1.3, height: size.height * 1.3)

        // The top-left corner itself, plus whatever the hardware is eating off the
        // left edge. Everything in that corner is measured from this one point, so
        // the block moves together.
        let inset: CGFloat = 16
        let corner = CGPoint(x: -size.width / 2 + inset + safeLeft,
                             y: size.height / 2 - inset)

        // Mirrored in the opposite corner, off its own edge's inset.
        //
        // In landscape the island eats about sixty points off one short edge, and
        // WHICH edge depends on which way round the phone is being held. This used
        // to be the only thing in here that inset itself at all, and it only ever
        // asked about the right - so held the other way it moved away from an edge
        // that was clear while the panels opposite it sat under the island. Both
        // corners ask about their own side now.
        //
        // The sticks still measure from the glass: this is a thing you read rather
        // than a thing you press, and readouts are what have to get out of the way.
        leaderboard.position = CGPoint(x: size.width / 2 - inset - safeRight,
                                       y: size.height / 2 - inset)
        laidOutForInsets = CGPoint(x: safeLeft, y: safeRight)

        // The one strip of the top edge nothing else wants: the shop button holds
        // the left corner, the leaderboard the right, and the middle is clear on
        // every size those two fit on. Its origin is its own top edge, so it wants
        // a top edge and nothing else.
        //
        // 176 across and centred. On an SE - the tightest screen - that finishes
        // 161 points clear of the button and 37 clear of the leaderboard, and both
        // of those grow on every larger phone.
        matchPanel.position = CGPoint(x: 0, y: size.height / 2 - inset)
        // One spot for every notice, under the match panel - the kill banner, the
        // hints and the rebuild countdown all use it, one at a time. See
        // updateNotices for who gets it.
        let noticeY = matchPanel.position.y - MatchPanelNode.size.height
            - 10 - KillBannerNode.height / 2
        killBanner.restingY = noticeY
        rebuildTimer.position = CGPoint(x: 0, y: noticeY)
        results.layOut(for: size)
        pauseMenu.layOut(for: size)

        // Just left of the timer, its top edge level with the timer's.
        pauseButton.position = CGPoint(
            x: matchPanel.position.x - MatchPanelNode.size.width / 2 - 10 - PauseButtonNode.side / 2,
            y: matchPanel.position.y - PauseButtonNode.side / 2)

        // IN the corner, where the health panel used to be. Nothing to clamp
        // against: it is square, it starts at the corner, and the nearest thing to
        // it is the centred panel a long way off to the right.
        let radius = GameScene.shopButtonRadius
        shopButton.position = CGPoint(x: corner.x + radius, y: corner.y - radius)

        // The hotbar's origin is its own centre, so it only needs a bottom edge.
        hotbar.position = CGPoint(x: 0,
                                  y: -size.height / 2 + inset + HotbarNode.size.height / 2)

        // Hung in the gap between the HUD and the hotbar, measured rather than
        // guessed at, so it lands correctly on every screen instead of on the one
        // this was written against.
        //
        // Not stacked directly on the hotbar: that put the panel's bottom-left
        // corner inside the move stick's grab radius, which is deliberately far
        // wider than the stick you can see. The stick gets first refusal on every
        // touch, so the leftmost slot would have quietly stopped responding.
        // The bottom of the corner, which is what everything below it hangs off -
        // the quick offer, the hint, the chest panel and the shop panel.
        let cornerBottom = shopButton.position.y - radius
        let hotbarTop = hotbar.position.y + HotbarNode.size.height / 2
        chestPanel.position = CGPoint(x: 0, y: (cornerBottom + hotbarTop) / 2)

        // Hung in the gap the hotbar leaves behind: centred between the bottom of
        // the HUD and the bottom of the screen.
        //
        // Not the middle of the screen, which is where this sat first. The panel is
        // 230 tall and an SE gives it 234 points down there, so centring it moved
        // the whole thing up over the health bar - and health is the one number you
        // are still reading while you decide whether to buy a bandage. Hung here it
        // clears the HUD by a point on the smallest phone and by plenty on every
        // other one, which is also why the panel's own height is capped where it
        // is: it is sized to the gap it lives in.
        shopPanel.position = CGPoint(
            x: 0,
            y: (cornerBottom + (-size.height / 2 + 12)) / 2)

        // Hung under the health panel, left edges flush with it. It is a reading
        // of your purse as much as an offer, so it belongs with the other numbers
        // about you rather than out among the controls - and the top-left corner is
        // where the eye already goes for those.
        //
        // Still offered to a finger BEFORE the move stick in touchesBegan: on a
        // phone this small the stick's grab circle reaches most of the left-hand
        // side, and the stick gets first refusal on everything it covers.
        quickBuy.position = CGPoint(
            x: corner.x + QuickBuyNode.size.width / 2,
            y: cornerBottom - 10 - QuickBuyNode.size.height / 2)

        // The strip directly under the health panel, centred: the one band of
        // screen nothing else occupies mid-match. Measured off the HUD rather than
        // off the top edge, so it follows the panel if that ever changes height -
        // which it just did, when the ammo bar came out.
        hint.position = CGPoint(x: 0, y: matchPanel.position.y - MatchPanelNode.size.height
                                     - 10 - KillBannerNode.height / 2)

    }

    // MARK: - Loop

    override func update(_ currentTime: TimeInterval) {
        guard world != nil else { return }

        // Paused: nothing moves, and the clock is held so that resuming does not
        // try to catch up on the time spent in the menu.
        if matchPaused {
            lastUpdateTime = currentTime
            accumulator = 0
            return
        }

        if lastUpdateTime == 0 { lastUpdateTime = currentTime }
        frameDelta = min(0.25, currentTime - lastUpdateTime)
        accumulator += currentTime - lastUpdateTime
        lastUpdateTime = currentTime

        // After a stall (breakpoint, app backgrounded) do not try to catch up on
        // every missed tick at once, or the game freezes trying to fast-forward.
        accumulator = min(accumulator, 0.25)

        // The clock is the one thing that stops the simulation, and it stops it
        // HERE rather than inside Core. Whether the world should advance is a
        // question about the app - a networked host would answer it somewhere else
        // again - so nothing in a system has to know a match can end.
        while accumulator >= GameConfig.fixedTimeStep, !world.isOver {
            world.step(commands: gatherCommands(), dt: GameConfig.fixedTimeStep)
            accumulator -= GameConfig.fixedTimeStep
        }

        if world.isOver {
            accumulator = 0
            endMatch()
        }

        #if os(iOS) || os(tvOS)
        // Checked against the frame clock rather than a timer, so a hold fires while
        // the finger is still down - which is the whole difference between a hold
        // and a slow tap.
        resolveHold(at: currentTime)
        #endif

        syncRenderers()
        refreshGlass()
    }

    /// Re-blurs the map behind the controls and hands each one its patch. After
    /// the renderers, so the glass shows this frame's map rather than the last.
    private func refreshGlass() {
        guard GlassBackdrop.enabled, let view else { return }
        let camera = cameraController.node
        glass.refresh(view: view, world: worldLayer, centre: camera.position,
                      zoom: camera.xScale, screen: size)
        guard let texture = glass.texture else { return }
        GlassNode.fillAll(from: texture, under: camera, screen: size)
    }

    /// How long the last frame took, for the renderers that decay a value rather
    /// than animating one - see ActorRenderer's recoil, which cannot use an action
    /// because the thing it moves is rewritten every frame.
    private var frameDelta: TimeInterval = 1.0 / 60

    private func syncRenderers() {
        // Blocks only get rebuilt when a tile actually changed.
        if world.mapRevision != drawnMapRevision {
            blockRenderer.build(from: world.map)
            drawnMapRevision = world.mapRevision
        }

        blockRenderer.sync(with: world)
        wallDamageRenderer.sync(with: world)
        blueprint.sync(with: world, dt: frameDelta)
        lootboxRenderer.sync(with: world)
        supplyRenderer.sync(with: world)
        updateSupplyDrops()
        chestRenderer.sync(with: world)
        arcadeRenderer.sync(with: world)
        turretRenderer.sync(with: world)
        groundItemRenderer.sync(with: world)
        bombRenderer.sync(with: world)
        projectileRenderer.sync(with: world, heardFrom: ears)
        actorRenderer.sync(with: world, dt: frameDelta)
        matchPanel.update(with: world)
        repositionForSafeAreaIfNeeded()
        leaderboard.update(with: world)
        
        shopPanel.update(with: world)
        hotbar.update(with: world)
        respawnBanner.update(with: world)

        // The panel closes itself if the chest stops existing, or if you are moved
        // out of reach of it. Nothing else has to remember to do that.
        chestPanel.update(with: world)

        // Forget a selection whose slot has emptied - the last chest placed,
        // dropped, or stored in another chest. It stops a stale slot index arming
        // the ghost for whatever lands there next.
        if let slot = selectedSlot,
           world.localPlayer?.inventory.stack(at: slot) == nil {
            selectedSlot = nil
        }

        hotbar.setSelected(shopPanel.isOpen ? nil : selectedSlot)

        updateRightControl(with: world)
        updateQuickButton(with: world)
        updateNotices(with: world)
        updateBaseCompass()
        updatePlacementGhost(with: world)
        updateQuickBuy(with: world)
        updateHint(with: world)
        gasRenderer.sync(with: world, dt: frameDelta)
        effectsRenderer.sync(with: world)
        dispatch(world.takeEvents(), in: world)
        aimCamera(in: world)
    }

    /// Offers the one thing worth offering, and waves at the shop button.
    ///
    /// Both hang off the same question - ShopSystem.quickOffer - so the prompt and
    /// the nudge can never disagree about whether there is anything to buy. The
    /// prompt now STAYS while the answer is yes, changing what it offers as the
    /// match changes; the button waves on a timer, and only while the shop is shut.
    ///
    /// The wave is back on whenever something is affordable, and stopping it was a
    /// mistake worth naming. The argument was that a permanent prompt plus a button
    /// waving at it every fourteen seconds is the same message twice - true, and
    /// beside the point, because the prompt was the half nobody could see. Making
    /// it permanent and silencing the button at the same time left NOTHING on that
    /// side of the screen moving, and watching people play, they found neither.
    private func updateQuickBuy(with world: World) {
        guard !world.isOver,
              !shopPanel.isOpen,
              chestPanel.openChest == nil,
              let player = world.localPlayer else {
            quickBuy.dismiss()
            return
        }

        let offer = ShopSystem.quickOffer(for: player, in: world)
        quickBuy.update(with: offer)

        guard offer != nil else { return }

        if lastUpdateTime >= nextNudge {
            nextNudge = lastUpdateTime + GameConfig.Shop.nudgeInterval
            shopButton.nudge()
        }
    }

    /// Floats the drop hint over the player, at the one moment it is worth saying.
    ///
    /// A full bag is that moment and the only one. It is when the gesture stops
    /// being a convenience and starts being the answer to a problem the player can
    /// see for themselves - they are standing on loot and nothing is happening.
    ///
    /// And it clears out the instant anybody is close enough to fight. A sentence
    /// floating over your own head while somebody shoots at you is worse than
    /// never having been told, and this is the one thing on screen with no claim
    /// on that attention.
    private func updateHint(with world: World) {
        guard tipsOn else { return }
        guard let player = world.localPlayer, player.isAlive, !world.isOver else {
            wasBlocked = false
            wasAtEnemyChest = false
            hint.hide()
            return
        }

        // Walked over something and did not pick it up. LootSystem answers this,
        // not the scene, so the screen can never claim a refusal about an item that
        // is quietly being collected.
        let blocked = LootSystem.blockedPickup(for: player, in: world)
        let stepped = blocked && !wasBlocked
        wasBlocked = blocked

        let fighting = player.secondsSinceHit < GameScene.hintCombatQuiet
            || world.enemyNear(player, within: GameScene.hintCombatRange)

        guard !fighting, !shopPanel.isOpen, chestPanel.openChest == nil else {
            hint.hide()
            return
        }

        // Standing in your own base with nothing built in it.
        //
        // NOT a lesson any more, and that is the whole change. It used to be one:
        // shown once, on a first match, retired for good once three walls were
        // laid. Every one of those gates was about the PLAYER - what they had been
        // told, what they had learned - and none of them about the thing actually
        // in front of them, which is a base with no walls in it.
        //
        // So it is a fact about the match now. You are home, you have built
        // nothing, there is somewhere to build: it says so. It says so on the first
        // frame of the match, because you spawn in your own claim and spawning
        // there is arriving there - which is why there is no separate opening
        // message. It says so again the next time you walk back in having still
        // built nothing. And it stops the moment you lay one, for the rest of the
        // match, because then it is not true any more.
        //
        // On the rising edge of being home rather than while standing there, so it
        // is a reaction to a moment rather than a sign hung over the base.
        let home = world.claim(for: player.team)?
            .contains(GridPoint(containing: player.feet)) == true

        let arrivedHome = home && !wasHome
        wasHome = home

        if arrivedHome, !hasBuilt, blueprint.hasSlots, world.canBuild(player.team) {
            hint.show("WALK THE MARKED TILES TO BUILD WALLS", seconds: 2.2)
            return
        }

        // Within reach of somebody else's chest, on the rising edge of getting
        // there. Reach rather than line of sight, because being close enough to
        // touch one is the moment somebody looks for the button that is not there.
        let atEnemyChest = world.reachableChest(for: player)
            .map { $0.owner != player.team } ?? false

        let arrivedAtChest = atEnemyChest && !wasAtEnemyChest
        wasAtEnemyChest = atEnemyChest

        if arrivedAtChest, raidHintsLeft > 0 {
            raidHintsLeft -= 1
            hint.show("SHOOT THE CHEST TO BREAK IT OPEN", seconds: 2.2)
            return
        }

        // Early only, and only from here down. A lesson has a shelf life: somebody
        // four minutes into a match has either worked the gesture out or settled
        // into playing without it, and a tip arriving then is not teaching, it is
        // interrupting. The build reminder above is not subject to it, because it
        // is not a lesson - a base with no walls in it at four minutes is more
        // worth mentioning than it was at thirty seconds, not less.
        guard world.matchProgress < GameScene.hintWindow else { return }

        guard stepped, !hasUsedHold, holdHintsLeft > 0, !hint.isShowing,
              !Prefs.taughtSelling else { return }

        // Shown, not learned. The lesson ends when a slot is actually held and
        // sold - see resolveHold - on the same principle the build lesson follows:
        // being told something is not the same as being able to do it.
        holdHintsLeft -= 1
        hint.show(GameScene.holdSells ? "HOLD AN ITEM TO SELL IT"
                                      : "HOLD AN ITEM TO DROP IT")
    }

    /// Points the camera at whoever it should be watching.
    ///
    /// You while you are alive, and while you are dead, whoever killed you - which
    /// is the only interesting thing on the map at that moment and is usually what
    /// you most want to see. It answers the question every death asks and none of
    /// them used to: where did that come from.
    ///
    /// Falls back to your own body if the killer is gone by the time you look. They
    /// can be killed themselves inside your three second wait, and a camera that
    /// insisted on following a corpse would spend the rest of it watching an empty
    /// patch of grass.
    private func aimCamera(in world: World) {
        guard let player = world.localPlayer else { return }

        if player.isAlive { killedBy = nil }

        if !player.isAlive,
           let id = killedBy,
           let killer = world.actors[id],
           killer.isAlive {
            cameraController.follow(killer.position, subject: id, dt: frameDelta)
            return
        }

        cameraController.follow(player.position,
                                subject: world.localPlayerID,
                                dt: frameDelta)
    }

    /// Takes everything the world announced this frame and hands it to whoever
    /// draws it.
    ///
    /// ONE drain, in one place. Every kind of event has to be taken off the world
    /// every frame whether or not anything is currently listening - a sale made
    /// behind a closed shop, an explosion off the edge of the screen - or they pile
    /// up and arrive together the next time somebody looks. One loop that always
    /// runs cannot forget; three renderers that each drain their own kind can.
    ///
    /// Note what is NOT here: the money. The token counter animates on any change
    /// it sees, so the price leaving your purse is already drawn.
    /// A ring of tiles put into the order light should travel round them.
    ///
    /// By angle from the middle, which is the one ordering that works for a shape
    /// nobody specified: a rectangle, an L, a room with a tree for one side. Sorted
    /// rather than walked, so a wall that is two tiles thick somewhere - or that has
    /// an awkward spur - still sweeps once round instead of stalling where the
    /// walk would have had to choose a direction.
    static func sweptRound(_ ring: Set<GridPoint>) -> [GridPoint] {
        let count = Double(ring.count)
        let mid = ring.reduce(Vec2.zero) { running, tile in
            Vec2(x: running.x + Double(tile.col) / count,
                 y: running.y + Double(tile.row) / count)
        }

        return ring.sorted {
            atan2(Double($0.row) - mid.y, Double($0.col) - mid.x)
                < atan2(Double($1.row) - mid.y, Double($1.col) - mid.x)
        }
    }

    /// Where the player's ears are.
    ///
    /// The CAMERA rather than the player, and they are not always the same thing:
    /// die and the camera goes to watch whoever killed you, so for those ten
    /// seconds the screen is somewhere else entirely. Hearing your own corpse's
    /// surroundings while looking at a fight across the map would be two senses
    /// disagreeing about where you are.
    ///
    /// NOT called `listener`, which is what it was and which does not compile.
    /// SKScene already has one - `var listener: SKNode?`, the node SpriteKit uses
    /// as the ear for its own positional audio - so declaring a Vec2 of that name
    /// on a subclass of it is a redeclaration of an inherited property with a
    /// different type. A good name for the concept, already taken by the framework
    /// for the same concept.
    private var ears: Vec2 {
        GridGeometry.position(for: cameraController.node.position)
    }

    private func dispatch(_ events: [WorldEvent], in world: World) {
        for event in events {
            switch event {
            case .blast(let position):
                bombRenderer.flash(at: position)
                SoundPlayer.shared.play(.bomb, at: position, heardFrom: ears)

            case .jackpot(let position):
                effectsRenderer.jackpot(at: position)

            case .supplyDropOpened(let position):
                // The biggest crate in the game going off, heard from wherever it
                // happened - somebody across the map just got a Cosmic.
                effectsRenderer.jackpot(at: position)
                bombRenderer.flash(at: position)
                SoundPlayer.shared.play(.complete, at: position, heardFrom: ears)

            case .perkStarted(let perk, let user):
                // The steady trail comes off the world state a frame later; this is
                // only the switch being thrown, which nothing about the state a
                // second afterwards can show.
                //
                // WHICH perk used to be thrown away here, and the comment said it
                // was still sent because the day there were two again this would be
                // a one-word change rather than a plumbing job. It was.
                guard let actor = world.actors[user] else { break }
                effectsRenderer.charge(at: actor.position, perk: perk)
                actorRenderer.charge(user)

                // And the screen itself, for the one person it happened to.
                //
                // Only the local player, which is the whole point: everything else
                // a perk does is drawn on the map and is equally true for the seven
                // bots, because it is a fact about the world. This is not a fact
                // about the world - it is what it feels like from inside, and a
                // screen that flashed when somebody across the map drank something
                // would be lying about whose moment it was.
                //
                // And it was SILENT, which is most of why drinking one did not feel
                // like doing anything. The whole board makes a noise - a gun pops, a
                // base completes, a bomb goes off, buying a helmet plays a fanfare -
                // and the best item in the game went off without one.
                //
                // Upgrade rather than a sound of its own, because there is no sound
                // of its own to play yet and the nearest thing is the right kind of
                // thing: it is what a picked-up upgrade plays, and a power-up is an
                // upgrade you get to keep for seven seconds. A dedicated one would
                // be better and this is one line when there is one.
                if user == world.localPlayer?.id {
                    flashScreen(for: perk)
                    SoundPlayer.shared.play(.upgrade)
                }

            case .gas(let position):
                // The cloud itself is drawn from the world every frame; this is the
                // burst that says it arrived, which state alone cannot show.
                effectsRenderer.burst(at: position)

            case .chestCracked(let position, let items):
                // The same burst a crate gets, scaled by what came out of it.
                effectsRenderer.jackpot(at: position)
                bombRenderer.flash(at: position)
                _ = items   // the pile that lands says how much better than this

            case .machineHit(let id, let position):
                // Sparks off the casing rather than a hit marker: a machine being
                // shot has to read differently from a person being shot, or the
                // screen says somebody is in there taking it. It used to borrow the
                // BOMB's flash, which said the cabinet had just been destroyed and
                // then left it standing.
                arcadeRenderer.hit(id)
                effectsRenderer.machineStruck(at: position)

            case .machineDestroyed(_, let position):
                // The cabinet's own break-up and the coins flying out of it are
                // drawn by the renderers off the world; this is the shower of gold
                // over the top, which says "money came out of that" from across
                // the map.
                effectsRenderer.jackpot(at: position)
                SoundPlayer.shared.play(.pop, at: position, heardFrom: ears)

            case .chestHit(let id, let position):
                // The machine's answer, for the same reason it has one: a chest
                // being shot has to read differently from a person being shot, or
                // the screen says somebody is in there taking it.
                chestRenderer.hit(id)
                effectsRenderer.machineStruck(at: position)

            case .turretHit(let id, let position):
                // Sparks off the casing, the same as the other furniture.
                turretRenderer.hit(id)
                effectsRenderer.machineStruck(at: position)

            case .wallHit(let tile, let position):
                // Your own wall, being shot down on purpose.
                blockRenderer.hit(at: tile)
                effectsRenderer.machineStruck(at: position)

            case .sealed(let team, let chests):
                // Everybody's, not only yours. Eight bases close over a match and
                // each one is a place that has just become worth breaking into -
                // seeing somebody else's light go round is the game telling you
                // where to take your next bomb, which is information rather than
                // noise. It is off-camera most of the time anyway.
                // The wall AS BUILT, swept round in ring order rather than in the
                // order a plan would have had it laid - because with any shape
                // allowed there may not have been a plan involved at all.
                let ring = world.enclosure(of: team).wall
                guard !ring.isEmpty else { break }
                effectsRenderer.seal(GameScene.sweptRound(ring), chests: chests)

                // Heard from wherever it happened, which for seven of the eight is
                // somewhere off-screen. That is the useful half of it: a wall
                // closing away to your left is a base that has just become worth
                // taking a bomb to, and the sound is the only thing that says so.
                // Worked out first rather than written into the call. A nested ??
                // chain ending in an inferred .zero, inside an argument list, is
                // the shape that has twice cost this project an afternoon of
                // "unable to type-check in reasonable time".
                let heart: Vec2
                if let claim = world.claim(for: team) {
                    heart = claim.centreTile.center
                } else {
                    heart = world.localPlayer?.position ?? Vec2.zero
                }

                SoundPlayer.shared.play(.complete, at: heart, heardFrom: ears)

            case .vault(let points, let team, let position):
                // Only your own base, and only when you can see it. Somebody else's
                // wall paying out is a number over a base you are not standing in,
                // and eight of those every twelve seconds is a screen full of
                // arithmetic nobody asked for.
                guard team == world.localPlayer?.team else { break }

                effectsRenderer.earned(at: position, points: points)

                // And once, ever, the sentence that explains what the number is.
                if tipsOn, !Prefs.taughtHolding {
                    Prefs.taughtHolding = true
                    hint.show("YOUR BASE EARNS WHILE IT HOLDS", seconds: 2.0)
                }

            case .sold(let slot, let tokens, let seller):
                guard seller == world.localPlayerID else { break }
                SoundPlayer.shared.play(.purchase)

                // Sold from the shop's SELL tab, the bar is hidden behind the
                // panel, so the panel answers instead.
                if shopPanel.isOpen {
                    shopPanel.confirmSale()
                } else {
                    hotbar.reward(slot: slot, tokens: tokens)
                }

            case .purchase(let bought, let buyer):
                guard buyer == world.localPlayerID else { break }

                // Gear gets the upgrade noise wherever it was bought, and
                // everything else gets the till. Sorted on WHAT rather than on
                // which panel sold it: the quick offer and the shop are two ways
                // into the same purchase, and a helmet that sounded different
                // depending on which one you used would be telling you about the
                // interface instead of about the helmet.
                SoundPlayer.shared.play(bought.isGear ? .upgrade : .purchase)

                // Nothing is armed here any more. A heal you just bought used to be
                // selected for you, so the corner button would already be showing a
                // bandage when you shut the shop - which was worth doing precisely
                // because nothing on screen said that button belonged to the slot
                // you had picked. There is no button, a tap on the bandage is the
                // heal, and a slot left looking chosen for no reason would be the
                // bar claiming something is in your hand when nothing is.

                // Whichever of the two asked for it answers. The panel's confirm
                // does nothing unless a card was pressed, and the prompt's does
                // nothing unless it is waiting, so neither has to know about the
                // other.
                if quickBuy.awaiting { quickBuy.confirm() }

                // Where the thing you just bought should appear to land: your own
                // bar, converted into the panel's coordinates, because the panel is
                // what animates it. The scene is the only thing that knows where
                // both of those are.
                shopPanel.confirm(
                    flyingTo: shopPanel.convert(.zero, from: hotbar)
                )

            case .healed(let who):
                guard who == world.localPlayerID else { break }
                SoundPlayer.shared.play(.heal)

            case .pickedUp(_, let who, let worn):
                // Yours only. Seven bots sweeping the map is a constant patter of
                // somebody else's good fortune, and none of it is about you.
                guard who == world.localPlayerID else { break }

                // Worn means it beat what you had on, which is the one pickup worth
                // a different noise - see WorldEvent.pickedUp for why the world has
                // to say so rather than this working it out, which it cannot.
                SoundPlayer.shared.play(worn ? .upgrade : .collect)

            case .kill(let victim, let killer, let position, let points, _):
                // Remembered so the camera can go and watch them - see aimCamera.
                // Taken from the EVENT rather than worked out later, because by the
                // time anything is drawn the body has been stripped and moved home,
                // and nothing left in the world says who did it.
                if victim == world.localPlayerID { killedBy = killer }

                effectsRenderer.mark(killAt: position,
                                     points: points,
                                     mine: killer == world.localPlayerID)

                // Yours: the banner under the clock, and a sound, so a kill
                // registers even when your eyes were on something else. The hint
                // shares that strip of screen and gives way.
                if killer == world.localPlayerID, victim != world.localPlayerID {
                    hint.hide()
                    killBanner.confirm()
                    SoundPlayer.shared.play(.upgrade)
                }
            }
        }
    }

    /// Keeps the placement outline honest.
    ///
    /// Re-asked every frame rather than only when the finger moves, because the
    /// answer changes while standing still: walk two tiles and the spot that was
    /// out of your claim is inside it, and the spot under your own feet stops being
    /// blocked the moment you step off it. An outline that went green at press time
    /// and stayed green would be the same lie the old blind tap told, just prettier.
    private func updatePlacementGhost(with world: World) {
        guard !world.isOver,
              chestPanel.openChest == nil,
              !shopPanel.isOpen,
              let type = placingType,
              let player = world.localPlayer else {
            ghostType = nil
            ghostOrigin = nil
            placementGhost.hide()
            return
        }

        // A fresh selection starts on a spot that works, so picking a machine out
        // shows you where it could go instead of a red rectangle over your feet.
        // Only the FIRST frame - after that it is yours to aim.
        if ghostType != type {
            ghostType = type
            ghostOrigin = PlacementSystem.suggestion(for: type, by: player, in: world)
                ?? PlacementSystem.origin(of: type, tappedAt: player.feet)
        }

        guard let origin = ghostOrigin else {
            placementGhost.hide()
            return
        }

        placementGhost.show(type, at: origin,
                            valid: PlacementSystem.canPlace(type, at: origin,
                                                            by: player, in: world))
    }

    /// The right-hand controls: the aim stick, always, and your chest's button in
    /// the heal button's spot while you are at your own chest.
    private func updateRightControl(with world: World) {
        // The match is finished; nothing gets its controls back.
        guard !world.isOver else { return }
        guard let player = world.localPlayer else { return }

        // Dead: no shopping until you are back. The shop shuts if it was open -
        // nothing can be bought while respawning anyway - and its button goes
        // until you are on your feet again.
        if !player.isAlive, shopPanel.isOpen { shopPanel.close() }

        // Both sticks go away while you have your head in a chest.
        //
        // You therefore stand still to rummage, which is a real cost and the
        // intended one: a chest is inside your own walls, and a moment spent not
        // watching the door is the trade for reorganising your bag. The panel is
        // never a trap - the back button is large, and it closes itself the instant
        // anything puts the chest out of reach.
        // Note what is NOT touched here: cornerAction. It records what the corner
        // is SHOWING, and while the panel is up the corner shows nothing. Writing
        // .aim into it here - which this used to do - was a lie that outlived the
        // panel: on closing, the corner wanted .aim, found it already believed
        // .aim, and skipped the work of putting the stick back. The stick stayed
        // gone until walking back to the chest forced a different value through,
        // which is exactly how the bug presented.
        if chestPanel.openChest != nil || shopPanel.isOpen {
            hint.hide()
            moveStick.isHidden = true
            moveStick.end()
            aimStick.isHidden = true
            aimStick.end()
            openButton.isHidden = true
            shopButton.isHidden = shopPanel.isOpen

            // The bar stays up for a CHEST, where it is half the transaction - what
            // you can store is what is in it - and goes away for the SHOP, where it
            // is nothing but clutter behind a panel. That difference is the whole
            // reason the shop stopped being two interfaces at once.
            hotbar.isHidden = shopPanel.isOpen

            // And the standings go with it. The panel is as wide as a small phone
            // allows, so its top-right corner and the leaderboard's bottom-left
            // corner want the same points - and of the two, a table of scores is
            // the one nobody is reading while they shop.
            leaderboard.isHidden = shopPanel.isOpen
            return
        }

        shopButton.isHidden = !player.isAlive
        hotbar.isHidden = false
        leaderboard.isHidden = false


        moveStick.isHidden = false

        // The aim stick is always the aim stick. Your own chest, when you are at
        // it, gets a button in the heal button's spot instead - see
        // updateQuickButton, which stands aside for it. Crates need no button:
        // they open as you reach them (see AssistSystem).
        aimStick.isHidden = false

        #if os(iOS) || os(tvOS)
        // Not swapped under a thumb that is pressing it.
        guard openTouch == nil else { return }
        #endif

        // Only YOURS. Standing next to somebody else's leaves it to the blaster:
        // shooting it is what opens it.
        let wanted: CornerAction
        if let chest = world.reachableChest(for: player), chest.owner == player.team {
            wanted = .chest(chest.id)
        } else {
            wanted = .aim
        }
        cornerAction = wanted
        openButton.isHidden = wanted == .aim
    }

    /// Puts the controls away and brings the table up.
    ///
    /// Called every frame once the clock runs out, and guarded by the results node
    /// already being visible, so the work happens exactly once.
    private func endMatch() {
        guard results.isHidden else { return }

        // XP for the match, worked out and saved BEFORE the results come up so
        // the screen can play the bar filling and any unlock.
        var award: Progress.Award?
        if let team = world.localPlayer?.team,
           let place = world.standings.firstIndex(where: { $0.team == team }) {
            award = Progress.award(score: world.score(for: team), place: place)
        }

        results.show(with: world, award: award)

        // The first thing this game has ever remembered about how a match WENT.
        // A high-water mark and a count, so a bad match can never take anything
        // away - see Prefs, and the menu, which reads both.
        if let team = world.localPlayer?.team {
            Prefs.finishedMatch(scoring: world.score(for: team))
        }

        // Everything you could press goes, including the chest panel if you happened
        // to have your head in one when the whistle went.
        chestPanel.close()
        shopPanel.close()

        // Put the standings back if the shop had them hidden when the whistle
        // went. The results panel covers them either way, but leaving a control's
        // visibility owned by a screen that no longer exists is how the aim stick
        // once went missing for a whole match.
        leaderboard.isHidden = false
        shopButton.isHidden = true
        moveStick.isHidden = true
        moveStick.end()
        aimStick.isHidden = true
        aimStick.end()
        openButton.isHidden = true
        throwButton.isHidden = true
        healButton.isHidden = true
        hotbar.isHidden = true
        respawnBanner.isHidden = true
        killBanner.dismiss()
        rebuildTimer.dismiss()
        baseCompass.update(offset: nil, bounds: .zero)

        #if os(iOS) || os(tvOS)
        moveTouch = nil
        aimTouch = nil
        openTouch = nil
        throwTouch = nil
        healTouch = nil
        pending = nil
        #endif
    }

    /// One notice at a time, in the one spot under the match panel.
    ///
    /// A kill is the most urgent news and takes the spot outright; a hint waits
    /// for it. The rebuild countdown is a status rather than news, so it steps
    /// aside for either and comes back once they have gone.
    private func updateNotices(with world: World) {
        if let player = world.localPlayer, !world.isOver {
            rebuildTimer.update(remaining: world.buildLockRemaining(for: player.team))
        }

        let killShowing = !killBanner.isHidden
        hint.isSuppressed = killShowing
        rebuildTimer.setSuppressed(killShowing || hint.isShowing)
    }

    /// The arrow home, on the edge of the screen while your base is out of view.
    ///
    /// Red and shaking while you are being raided: somebody standing in your
    /// claim, or your wall freshly blown open.
    private func updateBaseCompass() {
        guard !world.isOver,
              let team = world.localPlayer?.team,
              let claim = world.claim(for: team) else {
            baseCompass.update(offset: nil, bounds: .zero)
            baseCompass.setAlarm(false)
            return
        }

        let raided = world.intruder(in: team) != nil
            || world.buildLockRemaining(for: team) > 0
        if raided, !wasRaided { SoundPlayer.shared.play(.notification) }
        wasRaided = raided
        baseCompass.setAlarm(raided)

        let zoom = max(GridGeometry.zoom(for: size), 0.0001)
        let eye = cameraController.node.position
        let home = GridGeometry.point(for: claim.centreTile.center)
        let offset = CGPoint(x: (home.x - eye.x) / zoom, y: (home.y - eye.y) / zoom)

        // The same frame the supply markers ride round.
        let edge: CGFloat = 38
        let bounds = CGRect(x: -size.width / 2 + safeLeft + edge,
                            y: -size.height / 2 + edge,
                            width: size.width - safeLeft - safeRight - edge * 2,
                            height: size.height - edge * 2)
        baseCompass.update(offset: offset, bounds: bounds)
    }

    /// What the button above the corner is offering.
    private enum QuickAction: Equatable {
        case none
        /// The best heal for the damage taken; green when you are hurt enough
        /// that healing is the right call.
        case heal(slot: Int, recommended: Bool)
        /// A throw along your aim; green when that aim is on an enemy wall in
        /// range.
        case throwBomb(slot: Int, onTarget: Bool)
    }

    /// One button, one spot, and whichever job matters most right now - so there
    /// is never a second thing to find mid-fight. In order:
    ///
    ///   1. A bomb or a heal you picked out of the hotbar. You chose it; it
    ///      stays. A heal goes green when you are hurt enough to need it.
    ///   2. A heal, once you are below Player.tapHealBelow - green.
    ///   3. A bomb in your bag, while your aim is on an enemy wall in range -
    ///      green. Nothing to pick out: line up on a wall and the button is there.
    ///   4. A heal, if you are hurt at all.
    ///   5. Nothing: the button goes away.
    private func quickAction(for player: Actor, in world: World) -> QuickAction {
        guard player.isAlive else { return .none }

        let onWall = GameScene.aimingAtEnemyWall(player, in: world)

        if let slot = throwingSlot {
            return .throwBomb(slot: slot, onTarget: onWall)
        }

        let heal = ConsumableSystem.bestHeal(for: player)
        let urgent = Double(player.health)
            < Double(player.maxHealth) * GameConfig.Player.tapHealBelow

        if let slot = healingSlot {
            return .heal(slot: slot, recommended: urgent && player.canUse(slot: slot))
        }

        if urgent, let slot = heal {
            return .heal(slot: slot, recommended: true)
        }

        if onWall, let slot = BombSystem.loadedSlot(of: player),
           BombSystem.canThrow(player, from: slot) {
            return .throwBomb(slot: slot, onTarget: true)
        }

        if let slot = heal {
            return .heal(slot: slot, recommended: false)
        }

        return .none
    }

    /// Whether a bomb thrown now, along the way you are pointing, would land on
    /// somebody else's wall.
    ///
    /// Walks the throw's path the way BombSystem flies it: the first solid thing
    /// it meets is what it hits, so a tree or your own wall in the way is a no.
    /// Out to the throw's full range, from where the bomb leaves the hand.
    private static func aimingAtEnemyWall(_ player: Actor, in world: World) -> Bool {
        let heading = player.aim.normalized()
        guard heading.length > 0 else { return false }

        let start = player.position + heading * GameConfig.Bomb.launchOffset
        let step = 0.2
        var travelled = 0.0

        while travelled <= GameConfig.Bomb.throwRange {
            let point = start + heading * travelled
            let tile = GridPoint(containing: point)

            if let owner = world.map[tile].blockOwner {
                return owner != player.team
            }
            if world.map.isOccupied(tile) || world.treeTiles.contains(tile) {
                return false
            }
            travelled += step
        }
        return false
    }

    /// What the button is showing, held so a press does what it showed.
    private var shownQuickAction: QuickAction = .none

    /// Puts the right one of the two buttons up, or neither.
    ///
    /// Not swapped while a finger is on either - the thumb gets what it pressed.
    private func updateQuickButton(with world: World) {
        let wanted: QuickAction
        if world.isOver || chestPanel.openChest != nil || shopPanel.isOpen {
            wanted = .none
        } else if !openButton.isHidden, healTouch == nil, throwTouch == nil {
            // At your chest: its button has this spot.
            wanted = .none
        } else if healTouch != nil || throwTouch != nil {
            wanted = shownQuickAction
        } else if let player = world.localPlayer {
            wanted = quickAction(for: player, in: world)
        } else {
            wanted = .none
        }
        shownQuickAction = wanted

        switch wanted {
        case .throwBomb(let slot, let onTarget):
            if let stack = world.localPlayer?.inventory.stack(at: slot),
               throwGlyph != stack.type {
                throwGlyph = stack.type
                throwButton.setGlyph(ItemArt.texture(for: stack.type))
            }
            throwButton.setHighlighted(onTarget)
            throwButton.isHidden = false

        case .heal(let slot, let recommended):
            if let stack = world.localPlayer?.inventory.stack(at: slot) {
                healButton.show(stack.type, recommended: recommended)
            }
            healButton.isHidden = false

        case .none:
            break
        }

        if case .throwBomb = wanted {} else if !throwButton.isHidden {
            throwButton.isHidden = true
            throwButton.end()
            throwGlyph = nil
        }

        if case .heal = wanted {} else if !healButton.isHidden {
            healButton.isHidden = true
            healButton.end()
        }
    }

    // GONE WITH THE OLD VERSION OF THAT BUTTON: the two helpers that used to put a
    // heal in your hand for you - one on being hit, one on picking one up.
    //
    // Both were scaffolding for a control that served everything. "Arming" meant
    // selecting a slot so the corner button would show a bandage, and it was worth
    // doing precisely because the connection between the bar and that button was
    // invisible: the game had to make the choice for you because the interface
    // could not explain it. A tap that heals needs no arming, and there is nothing
    // left for the game to guess - the button above shows the one thing it throws.

    /// Input becomes a Command. Later, AI brains and network packets produce their
    /// Commands exactly the same way, and the world cannot tell them apart.
    private func gatherCommands() -> [ActorID: [Command]] {
        var commands: [Command] = [.move(moveStick.direction)]

        // Any deflection of the aim stick is both an aim and a trigger pull.
        // WeaponSystem owns the fire rate, so holding it over cannot shoot faster
        // than the blaster allows.
        if aimStick.direction.length > 0.01 {
            commands.append(.shoot(aimStick.direction))
        }
        commands.append(contentsOf: queuedCommands)
        queuedCommands.removeAll()
        return [world.localPlayerID: commands]
    }
}

#if os(iOS) || os(tvOS)
extension GameScene {

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        // Once the whistle has gone there are two things left to press.
        if world != nil, world.isOver {
            for touch in touches {
                let point = touch.location(in: results)

                // Play again first: it is the bigger target and the common answer,
                // and asking about it first means an overlap can only ever resolve
                // towards another match rather than out of the game.
                if results.isPlayAgain(atLocalPoint: point) {
                    results.pressPlayAgain { [weak self] in self?.restart() }
                    return
                }

                if results.isMenu(atLocalPoint: point) {
                    results.pressMenu { [weak self] in self?.openMenu() }
                    return
                }
            }
            return
        }

        // Paused, only the pause menu answers.
        if matchPaused {
            for touch in touches {
                let point = touch.location(in: pauseMenu)
                if pauseMenu.isResume(atLocalPoint: point) {
                    SoundPlayer.shared.play(.select)
                    pauseMenu.pressResume { [weak self] in self?.resumeMatch() }
                    return
                }
                if pauseMenu.isQuit(atLocalPoint: point) {
                    SoundPlayer.shared.play(.exit)
                    pauseMenu.pressQuit { [weak self] in self?.openMenu() }
                    return
                }
                // Anywhere off the card carries on, like Resume.
                if pauseMenu.isOffCard(atLocalPoint: point) {
                    SoundPlayer.shared.play(.select)
                    pauseMenu.dismiss { resumeMatch() }
                    return
                }
            }
            return
        }

        for touch in touches {
            // The pause button first: it is small, it sits up by the timer away
            // from everything else, and a tap on it should never also do something.
            if pauseButton.contains(localPoint: touch.location(in: pauseButton)) {
                pauseButton.press()
                SoundPlayer.shared.play(.select)
                pauseMatch()
                return
            }

            // BEFORE the move stick, which otherwise swallows it: the prompt sits
            // under the health panel, and on a small phone the stick's grab circle
            // reaches that far up the left-hand side. Same trade the item button
            // makes against the aim stick - a small target that is only there for a
            // few seconds beats a large forgiving one that is always there, and the
            // stick loses nothing it needs.
            if quickBuy.isPressed(atLocalPoint: touch.location(in: quickBuy)),
               let type = quickBuy.offer {
                guard let player = world.localPlayer,
                      ShopSystem.canBuy(type, actor: player, in: world) else {
                    // Cannot afford it, or nowhere to put it. Say so and leave the
                    // offer up: both of those can change in a few seconds.
                    quickBuy.refuse()
                    SoundPlayer.shared.play(.error)
                    continue
                }

                // Sent, not spent. The prompt waits for the purchase to come back
                // as an event before it celebrates - it used to vanish on the tap,
                // which meant the one moment worth showing happened to a node that
                // was already fading out.
                queuedCommands.append(.buyItem(type))
                quickBuy.arm()
                continue
            }

            // Order matters. The two sticks get first refusal, then the hotbar and
            // the contextual button, and only what is left over counts as a tap on
            // the map - otherwise healing or opening would also try to lay a block.
            if moveTouch == nil, !moveStick.isHidden,
               moveStick.begin(atLocalPoint: touch.location(in: moveStick)) {
                moveTouch = touch
                continue
            }

            // With a chest open, every touch belongs to the panel.
            if chestPanel.openChest != nil {
                handleChestTouch(touch)
                continue
            }

            // Same for the shop. A finger on the cards waits to see whether it is
            // a tap or a swipe to the other page; the way out, the tabs and the
            // background answer straight away, as before.
            if shopPanel.isOpen {
                let point = touch.location(in: shopPanel)
                if shopTouch == nil,
                   shopPanel.contains(localPoint: point),
                   !shopPanel.isBackButton(atLocalPoint: point),
                   shopPanel.tab(atLocalPoint: point) == nil {
                    shopTouch = touch
                    shopTouchStart = point
                    shopSwiping = false
                } else {
                    handleShopTouch(touch)
                }
                continue
            }

            if !shopButton.isHidden,
               shopButton.begin(atLocalPoint: touch.location(in: shopButton)) {
                shopButton.end()
                shopPanel.open()
                SoundPlayer.shared.play(.select)
                continue
            }

            // BEFORE the aim stick, and that ordering is load-bearing. The small
            // button sits inside the stick's 120pt grab circle, so offering the
            // stick first would swallow every press aimed at it. Small precise
            // targets beat large forgiving ones; the stick loses nothing it needs.
            // The heal button, ahead of the stick for the same reason.
            if healTouch == nil, !healButton.isHidden,
               healButton.begin(atLocalPoint: touch.location(in: healButton)) {
                healTouch = touch

                // On PRESS, like the throw: a heal that waits for the finger to
                // lift is a heal a fraction late.
                if case .heal(let slot, _) = shownQuickAction,
                   let player = world.localPlayer, player.canUse(slot: slot) {
                    queuedCommands.append(.useItem(slot: slot))
                    hotbar.acknowledge(slot)
                } else {
                    healButton.refuse()
                    SoundPlayer.shared.play(.error)
                }
                continue
            }

            if throwTouch == nil, !throwButton.isHidden,
               throwButton.begin(atLocalPoint: touch.location(in: throwButton)) {
                throwTouch = touch

                // A one-shot action, so it fires on PRESS, along the aim you are
                // holding. Next to a chest or crate the corner offers that instead
                // of the stick, and the throw goes along your last aim.
                if case .throwBomb(let slot, _) = shownQuickAction {
                    queuedCommands.append(.useItem(slot: slot))
                    hotbar.acknowledge(slot)
                }
                continue
            }

            // Your chest's button sits where the heal button does, inside the aim
            // stick's grab circle, so it is offered the touch first, like the heal.
            if openTouch == nil, !openButton.isHidden,
               openButton.begin(atLocalPoint: touch.location(in: openButton)) {
                openTouch = touch

                // A one-shot action, so it fires on press. Opening a chest is the
                // odd one out: it raises no Command at all, because looking into a
                // chest changes nothing about the world - only what this screen is
                // showing. Only moving something in or out is an intent.
                switch cornerAction {
                case .lootbox:
                    queuedCommands.append(.openLootbox)
                case .chest(let id):
                    openOwnChest(id)
                case .aim:
                    break
                }
                continue
            }

            if aimTouch == nil, !aimStick.isHidden,
               aimStick.begin(atLocalPoint: touch.location(in: aimStick)) {
                aimTouch = touch
                continue
            }


            // Note the hotbar no longer acts on PRESS. It cannot: a hold means drop
            // it, and acting on press would use the item first and then drop it.
            // Both targets now decide what they meant on release.
            if let slot = hotbar.slotIndex(atLocalPoint: touch.location(in: hotbar)) {
                beginPress(touch, target: .hotbar(slot: slot))
                continue
            }

            // Something out of the bag wants a tile, so a finger on the map is
            // aiming it rather than tapping. It places on release, and only if the
            // outline is green - which is why it can be dragged around first.
            //
            // One finger owns the aim, like every other control on this screen, and
            // any others are swallowed rather than passed on. Taking a second one
            // would orphan the first, whose release would then go nowhere; letting
            // it through to the map would arm a HOLD, and a second thumb quietly
            // demolishing a wall while you line up a machine is not a gesture
            // anybody would go looking for.
            if placingType != nil {
                if placingTouch == nil {
                    placingTouch = touch
                    aimPlacement(at: touch.location(in: worldLayer))
                }
                continue
            }

            beginPress(touch, target: .map)
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        // Sideways across the shop's cards: the page follows the finger.
        if let active = shopTouch, touches.contains(active), shopPanel.isOpen {
            let now = active.location(in: shopPanel)
            let dx = now.x - shopTouchStart.x
            let dy = now.y - shopTouchStart.y
            if !shopSwiping, abs(dx) > 14, abs(dx) > abs(dy) { shopSwiping = true }
            if shopSwiping { shopPanel.drag(by: dx) }
        }

        // A hidden stick is not being driven, whatever the finger is doing.
        if let active = moveTouch, touches.contains(active), !moveStick.isHidden {
            moveStick.update(toLocalPoint: active.location(in: moveStick))
        }

        if let active = aimTouch, touches.contains(active) {
            aimStick.update(toLocalPoint: active.location(in: aimStick))
        }

        if let active = placingTouch, touches.contains(active) {
            aimPlacement(at: active.location(in: worldLayer))
        }

        // A finger that wanders was neither a tap nor a hold. On the map it is now
        // a third thing - a run of wall - and everywhere else it is still nothing.
        if let press = pending, touches.contains(press.touch) {
            let moved = press.touch.location(in: cameraController.node) - press.screenOrigin
            if hypot(moved.x, moved.y) > tapSlop {
                if case .map = press.target, !press.fired { beginPainting(from: press) }
                cancelPress()
            }
        }

        // Deliberately after the block above, so the tile the finger STARTED on and
        // the tile it has reached are both laid on the frame the drag is recognised.
        // Beginning a run and then waiting for the next touch event to lay anything
        // reads as the wall lagging a tile behind the finger.
        if let active = paintTouch, touches.contains(active) {
            paint(at: active.location(in: worldLayer))
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        releaseControls(matching: touches)

        // The shop finger lifting: a swipe turns the page or springs back, and
        // anything else was a tap, acted on now.
        if let active = shopTouch, touches.contains(active) {
            shopTouch = nil
            if shopSwiping {
                shopSwiping = false
                let dx = active.location(in: shopPanel).x - shopTouchStart.x
                if shopPanel.endDrag(by: dx) != nil { SoundPlayer.shared.play(.tap) }
            } else if shopPanel.isOpen {
                handleShopTouch(active)
            }
        }

        if let active = placingTouch, touches.contains(active) {
            placingTouch = nil
            commitPlacement()
        }

        guard let press = pending, touches.contains(press.touch) else { return }

        // A hold that already fired has had its turn. Letting the release act too
        // would delete a wall and then try to build one back on the same spot.
        if !press.fired {
            switch press.target {
            case .map:
                tapMap(at: press.touch.location(in: worldLayer))
            case .hotbar(let slot):
                tapHotbar(slot)
            }
        }

        cancelPress()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        releaseControls(matching: touches)

        // A cancelled shop finger buys nothing; a half swipe springs back.
        if let active = shopTouch, touches.contains(active) {
            shopTouch = nil
            if shopSwiping { shopPanel.endDrag(by: 0) }
            shopSwiping = false
        }

        // A cancelled placing finger leaves the outline where it was and places
        // nothing. The item is still picked out, so it can be aimed again - a call
        // arriving mid-gesture should not cost you a machine, and it should not
        // spend one either. Note this is NOT done in releaseControls: that runs
        // first on release too, and clearing the finger there would unset it before
        // the release could act on it.
        if let active = placingTouch, touches.contains(active) {
            placingTouch = nil
        }

        if let press = pending, touches.contains(press.touch) {
            cancelPress()
        }
    }

    // MARK: - Tap or hold

    private func beginPress(_ touch: UITouch, target: PendingPress.Target) {
        guard pending == nil else { return }

        pending = PendingPress(touch: touch,
                               screenOrigin: touch.location(in: cameraController.node),
                               worldOrigin: touch.location(in: worldLayer),
                               // UITouch timestamps share the frame clock's base,
                               // so this is directly comparable in resolveHold.
                               beganAt: touch.timestamp,
                               target: target)

        if case .hotbar(let slot) = target {
            let price = world.localPlayer?.inventory.stack(at: slot).map {
                ShopSystem.sellPrice(of: $0.type)
            }
            hotbar.beginHold(slot, duration: GameScene.sellHoldDuration,
                             price: GameScene.holdSells ? price : nil)
        }

        if case .map = target { beginPrising(at: touch.location(in: worldLayer)) }
    }

    /// Starts a wall working loose under a finger, when that is what the finger is
    /// actually on.
    ///
    /// Asked of BuildSystem.canRemove rather than answered here, which is the same
    /// rule the placement preview follows: the moment this file starts deciding for
    /// itself which walls can come up, it can promise one that the simulation then
    /// refuses. A hold on grass, on somebody else's wall, or from outside your own
    /// claim shows nothing and does nothing, and those are the same sentence.
    private func beginPrising(at pointInWorld: CGPoint) {
        guard let player = world.localPlayer, player.isAlive else { return }

        let tile = GridGeometry.gridPoint(for: pointInWorld)
        guard BuildSystem.canRemove(at: tile, by: player, in: world) else { return }

        blockRenderer.prise(at: tile, duration: GameScene.holdDuration)
    }

    private func cancelPress() {
        if let press = pending, case .hotbar = press.target { hotbar.endHold() }

        // Covers every way a hold can end without firing - lifted early, dragged
        // off into a run of wall, or interrupted by a call arriving. All three
        // reach here, which is why the wall is put back here rather than in three
        // places that each have to remember.
        blockRenderer.release()
        pending = nil
    }

    /// What a long press on a hotbar slot does.
    ///
    /// Both answers are built and only one is wired up, which is deliberate. This
    /// gesture used to throw the item on the floor, and dropping is still the
    /// honest reading of it - you can pick the thing back up, you can hand it to
    /// somebody, and nothing about it is irreversible. Selling is the more USEFUL
    /// reading: what a full bag is actually full of is junk, and a bandage on the
    /// grass helps nobody while three tokens do.
    ///
    /// Which of those feels better is not a question anybody can answer by
    /// thinking about it, so the drop path stays exactly where it is - Command,
    /// LootSystem and all - and this one line decides which of them a hold means.
    private static let holdSells = true

    /// Turns a finger that has stayed put into the second meaning of that gesture:
    /// take your own wall back down, or turn the item into tokens.
    private func resolveHold(at now: TimeInterval) {
        guard var press = pending,
              !press.fired,
              now - press.beganAt >= GameScene.holdDuration(for: press.target) else { return }

        press.fired = true
        pending = press

        switch press.target {
        case .map:
            let tile = GridGeometry.gridPoint(for: press.worldOrigin)
            queuedCommands.append(.removeBlock(tile))

            // Let go WITHOUT putting it back, but only when it is actually about to
            // go. The wall is gone next frame and BlockRenderer will crumble it, so
            // springing it back to full size first would put a bounce in the middle
            // of it coming apart.
            //
            // The check matters, and leaving it out was a bug for about a minute: a
            // hold that BuildSystem then refuses - you wandered out of your own
            // claim while the finger was down - would have left the wall squeezed
            // to four fifths and tilted, for the rest of the match, with nothing
            // left tracking it to put it right. Asked with the same predicate the
            // simulation is about to use on the same state, so the two cannot
            // disagree.
            let coming = world.localPlayer.map {
                BuildSystem.canRemove(at: tile, by: $0, in: world)
            } ?? false

            blockRenderer.release(settling: !coming)
        case .hotbar(let slot):
            queuedCommands.append(GameScene.holdSells ? .sellItem(slot: slot)
                                                      : .dropItem(slot: slot))
            hotbar.endHold()

            // Somebody who has done it once knows how to do it - this match, and
            // every match after it.
            hasUsedHold = true
            Prefs.taughtSelling = true
            hint.hide()
        }
    }

    private func releaseControls(matching touches: Set<UITouch>) {
        if let active = moveTouch, touches.contains(active) {
            moveStick.end()
            moveTouch = nil
        }

        if let active = aimTouch, touches.contains(active) {
            // Letting go stops the firing, but Actor.aim keeps its last value, so
            // the character stays pointed where it was rather than snapping round.
            aimStick.end()
            aimTouch = nil
        }

        if let active = throwTouch, touches.contains(active) {
            throwButton.end()
            throwTouch = nil
        }

        if let active = healTouch, touches.contains(active) {
            healButton.end()
            healTouch = nil
        }

        if let active = openTouch, touches.contains(active) {
            openButton.end()
            openTouch = nil
        }

        // Nothing is committed when a run ends - every wall in it was laid as the
        // finger crossed the tile - so unlike placingTouch this is safe to clear
        // here, where the rest of the finger bookkeeping lives.
        if let active = paintTouch, touches.contains(active) {
            paintTouch = nil
            paintedFrom = nil
            painted.removeAll()
        }
    }

    /// Starts a whole new match by presenting a fresh scene.
    ///
    /// A new scene rather than resetting this one. Half a dozen renderers cache
    /// nodes against ids - chests, lootboxes, ground items, bombs - and clearing
    /// every one of those correctly is a list somebody eventually forgets to add to.
    /// Building a scene from nothing is the same code path as launching the game,
    /// which is the path that gets exercised every single time.
    private func restart() {
        guard let view else { return }
        view.presentScene(GameScene.newGameScene(),
                          transition: .fade(withDuration: 0.25))
    }

    /// Back to the title screen.
    ///
    /// The other half of having a menu at all: a way in is only a way in if there
    /// is also a way back, and PLAY AGAIN on its own made the results screen a
    /// door that only opened one way.
    private func openMenu() {
        guard let view else { return }
        view.presentScene(MenuScene.newMenuScene(),
                          transition: .fade(withDuration: 0.35))
    }

    /// Picks a slot out, or puts it back.
    ///
    /// A TAP USES IT. That is the whole of this screen's item handling now.
    ///
    /// There was a button above the bottom-right corner that spent whatever the
    /// hotbar had picked out, and it went because players could not work out what
    /// it was for. The diagnosis is already written into the commit that added the
    /// heal shortcut below, which made exactly this change for exactly one item:
    /// "two presses and an invisible rule stood between deciding to patch up and
    /// patching up - pick the slot, then find the button above the corner, which
    /// nothing on screen connects to the slot you picked." That was true of
    /// bandages and it was true of everything else; only bandages got fixed.
    ///
    /// The reason it is safe to go further is that the button never ADDED anything.
    /// Five of the seven things it could spend - a bandage, a medkit, a helmet, a
    /// blaster, a power-up - need no aim at all. The other two, a bomb and a stink
    /// bomb, are thrown along the aim you are already holding, which the button
    /// read at the moment it was pressed and did nothing to set. So the second
    /// press was never a second decision. It was a confirmation nobody had asked
    /// for, sitting in a corner of the screen that had nothing to do with the bar
    /// the item was in.
    ///
    /// The things that DO need a second decision keep one, and only those. A chest
    /// and a machine need a tile; a bomb and a stink bomb need a direction. Neither
    /// of those can be decided for you, which is exactly what separates them from
    /// the five that can.
    ///
    /// The bomb is the one that came back. It was instant for a revision and it was
    /// wrong, for a reason the analysis above got backwards: a bomb thrown along
    /// "the aim you are already holding" is fine when you are already aiming and
    /// useless when you are not, and you are usually not - the stick is idle most
    /// of a match, and an idle stick leaves the aim pointing wherever you last
    /// walked. So the old button was hiding a real gap, and removing it exposed it.
    ///
    /// Picking one out puts it on throwButton, which is a much smaller thing than
    /// the control that used to live there - see its own note for what changed.
    private func tapHotbar(_ slot: Int) {
        guard let player = world.localPlayer,
              let stack = player.inventory.stack(at: slot) else {
            selectedSlot = nil
            return
        }

        // Something you own and cannot use right now: the tap is answered rather
        // than obeyed. FIRST, because everything below it spends something.
        //
        // This is canUse directly, where it used to be a separate refusesTap that
        // excused healing. That exemption existed because a tap merely SELECTED -
        // picking a bandage out at full health was a reasonable thing to want, and
        // the faint button was where the warning belonged. There is no button and
        // no selecting any more, so a tap on a bandage at full health would throw
        // it away, and the one answer both the hotbar and the simulation give is
        // the right one again.
        // A bandage or a medkit. Badly hurt, it goes at once - the tap you make
        // when there is no time. Otherwise it is PICKED OUT: ready on the button
        // above the corner, a thumb's move from the aim stick, for whenever you
        // want it. Picking one out is allowed at full health too, which is the
        // point of "ready".
        if stack.type.isHealing {
            let low = Double(player.health)
                < Double(player.maxHealth) * GameConfig.Player.instantHealBelow

            // Tapping a heal that is ALREADY picked out uses it, exactly as the
            // heal button would. It used to put it back, so the hotbar habit -
            // tap the bandage when you are hurt - stopped working the moment one
            // had been picked out, and the only way to heal was the other button.
            // Both work now. At full health a second tap still puts it back, since
            // there is nothing to heal.
            let alreadyPicked = selectedSlot == slot

            if low || alreadyPicked, player.canUse(slot: slot) {
                queuedCommands.append(.useItem(slot: slot))
                hotbar.acknowledge(slot)
                selectedSlot = nil
                return
            }

            SoundPlayer.shared.play(.tap)
            selectedSlot = (selectedSlot == slot) ? nil : slot
            return
        }

        guard player.canUse(slot: slot) else {
            SoundPlayer.shared.play(.error)
            hotbar.refuse(slot: slot, saying: GameScene.refusal(for: stack.type))
            return
        }

        // Base furniture your base already has its fill of. Said now, on the
        // tap, rather than by opening a placement that could only ever show red.
        if PlacementSystem.baseIsFull(for: stack.type, team: player.team, in: world),
           let cap = PlacementSystem.limit(of: stack.type) {
            SoundPlayer.shared.play(.error)
            hotbar.refuse(slot: slot, saying: "Base full - \(cap) max")
            return
        }

        // Anything that still needs a decision out of you is PICKED OUT rather than
        // spent, and what happens next depends on which decision it is: a bomb
        // wants a direction and gets the aim stick, a chest wants a tile and gets
        // the map. See ItemType.Use, throwingSlot and placingType.
        guard stack.type.use == .instant else {
            SoundPlayer.shared.play(.tap)
            selectedSlot = (selectedSlot == slot) ? nil : slot
            return
        }

        // Everything else goes now.
        queuedCommands.append(.useItem(slot: slot))
        hotbar.acknowledge(slot)

        // Nothing stays picked out: there is nothing left for a selection to mean
        // once the thing is spent, and a slot still looking chosen after its
        // contents went would be the bar lying about what is in your hand.
        selectedSlot = nil
    }

    /// Why a tap on this was refused, in as few words as will fit over the bar.
    ///
    /// Exhaustive and listed one by one rather than defaulted, which is the rule
    /// everywhere a switch reads an ItemType here: a new kind of item should make
    /// this fail to compile and be given its own sentence, not inherit somebody
    /// else's. The cases that CANNOT get here still answer, because a wrong-looking
    /// sentence on screen is easier to find than a silent tap.
    ///
    /// The gear pair names the thing rather than the rule. "Your helmet is better"
    /// is the reason; "you cannot downgrade" is the rulebook, and nobody reads a
    /// rulebook with a finger on the bar.
    private static func refusal(for type: ItemType) -> String {
        switch type {
        case .helmet:  return "Your helmet is better"
        case .blaster: return "Your blaster is better"
        case .perk:    return "One power-up at a time"
        case .bandage, .medkit: return "Already at full health"
        case .bomb, .stink, .chest, .arcade, .turret: return "Not right now"
        }
    }

    /// Taps while the shop is open: a tab, a card, or done.
    ///
    /// A card raises a buyItem and nothing more. Whether you can afford it, and
    /// whether it has anywhere to go, are ShopSystem's answers - the panel greys a
    /// card out from that same answer, so it never asks for something that will be
    /// refused, and could not charge you if it did.
    private func handleShopTouch(_ touch: UITouch) {
        // Nothing about the bar here any more. It used to be the sell counter while
        // the shop was up, which made this screen two interfaces with two rules
        // stacked on each other; selling is a hold on the bar during play now, and
        // the bar itself is hidden behind the panel. Every tap on this screen is
        // either a card, the way out, or outside.
        let point = touch.location(in: shopPanel)

        // Anywhere off the panel shuts it, the same way tapping off a menu does
        // everywhere else. The BACK button stays - it is the obvious way out, and
        // the one somebody looks for before they think to try the background.
        // Both ways out of the shop, and only these two. The bulk close at the
        // whistle is deliberately silent - that is the match ending, not you
        // leaving, and a panel shutting itself is not a thing you did.
        guard shopPanel.contains(localPoint: point) else {
            shopPanel.close()
            SoundPlayer.shared.play(.exit)
            return
        }

        if shopPanel.isBackButton(atLocalPoint: point) {
            shopPanel.close()
            SoundPlayer.shared.play(.exit)
            return
        }

        // BUY or SELL.
        if let mode = shopPanel.tab(atLocalPoint: point) {
            if mode != shopPanel.mode {
                shopPanel.setMode(mode)
                SoundPlayer.shared.play(.tap)
            }
            return
        }

        // A card in the SELL tab: sell that slot. Checked here as well as by the
        // simulation so a refusal can be said out loud, as a purchase's is.
        if let slot = shopPanel.sellSlot(atLocalPoint: point) {
            guard let player = world.localPlayer,
                  let stack = player.inventory.stack(at: slot),
                  ShopSystem.sellPrice(of: stack.type) > 0 else {
                shopPanel.refuse()
                SoundPlayer.shared.play(.error)
                return
            }

            queuedCommands.append(.sellItem(slot: slot))

            // Somebody who has sold something knows selling exists.
            Prefs.taughtSelling = true
            return
        }

        if let item = shopPanel.item(atLocalPoint: point) {
            // Asked HERE as well as by the simulation, because the card no longer
            // greys out for a bag with no room in it - so a tap can now be refused
            // by something the shop never showed you. Same answer either way; this
            // one just gets to say no out loud instead of the command quietly
            // going nowhere.
            guard let player = world.localPlayer,
                  ShopSystem.canBuy(item, actor: player, in: world) else {
                shopPanel.refuse()
                SoundPlayer.shared.play(.error)
                return
            }

            queuedCommands.append(.buyItem(item))
            return
        }
    }

    /// Taps while a chest is open: out of the chest, into the chest, or done.
    private func handleChestTouch(_ touch: UITouch) {
        guard let id = chestPanel.openChest,
              let chest = world.chests[id],
              let player = world.localPlayer else { return }

        if chestPanel.isBackButton(atLocalPoint: touch.location(in: chestPanel)) {
            chestPanel.close()
            SoundPlayer.shared.play(.exit)
            return
        }

        // Out of the chest.
        //
        // The answer is worked out HERE and the panel is told, which is the shape
        // the shop already uses: a panel that decided for itself whether a tap had
        // worked would be a second opinion about the same rules, and the two would
        // eventually disagree. Asked against the same inventory the simulation will
        // ask, one frame earlier.
        if let slot = chestPanel.slotIndex(atLocalPoint: touch.location(in: chestPanel)) {
            guard let stack = chest.contents.stack(at: slot) else { return }

            guard player.inventory.canAccept(stack.type) else {
                chestPanel.refuse(slot: slot)
                chestPanel.note("YOUR BAG IS FULL")
                SoundPlayer.shared.play(.error)
                return
            }

            queuedCommands.append(.takeItem(chest: id, slot: slot))

            // Flown to the hotbar, in the panel's own space.
            //
            // Converted FROM the hotbar rather than from the scene, which is the
            // difference between right and nearly right: both nodes are children of
            // the camera, so hotbar.position is in the camera's space and handing it
            // to the panel as a scene point would put the parcel somewhere else
            // entirely on any screen where the camera is not at the origin - which
            // is every frame of a match.
            chestPanel.confirm(slot: slot,
                               flyingTo: chestPanel.convert(.zero, from: hotbar))
            SoundPlayer.shared.play(.collect)
            return
        }

        // And into it.
        if let slot = hotbar.slotIndex(atLocalPoint: touch.location(in: hotbar)) {
            guard let stack = player.inventory.stack(at: slot) else { return }

            guard let landing = chest.contents.firstFreeSlot(for: stack.type) else {
                // The shake here, the words on the panel: the bar's own note would
                // be drawn underneath the chest panel and never seen.
                hotbar.deny(slot: slot)
                chestPanel.note("THE CHEST IS FULL")
                SoundPlayer.shared.play(.error)
                return
            }

            queuedCommands.append(.storeItem(chest: id, slot: slot))
            hotbar.acknowledge(slot)

            if let art = hotbar.artwork(inSlot: slot) {
                chestPanel.receive(into: landing,
                                   from: chestPanel.convert(.zero, from: hotbar),
                                   artwork: art)
            }
            SoundPlayer.shared.play(.tap)
            return
        }

        // And anywhere else shuts it, the way the shop does.
        //
        // This used to be ignored on the grounds that a stray thumb should not
        // throw you out of a chest you are halfway through - which was the right
        // instinct and the wrong conclusion. The two panels behaving differently
        // is worse than either behaviour: having learned that tapping the map
        // closes the shop, you try it on a chest and nothing happens, so you go
        // looking for the button you had stopped needing. And the cost of being
        // wrong here is one tap to reopen, since the chest is standing right there.
        if !chestPanel.contains(localPoint: touch.location(in: chestPanel)) {
            chestPanel.close()
            SoundPlayer.shared.play(.exit)
        }
    }

    /// Asks for a block. Whether one appears is BuildSystem's call, not the
    /// scene's, and bombs are thrown from the hotbar like everything else you carry.
    ///
    /// Placing a chest or a machine no longer arrives here. It used to: a tap was
    /// read straight into a placement, which is why putting a machine down felt
    /// like a coin flip - the footprint went up and to the right of the finger,
    /// nothing showed you where it would land, and a refusal looked exactly like
    /// the game ignoring you. That is a drag with an outline on it now, below.
    /// How far outside a crate a tap still counts as being on it, in tiles.
    ///
    /// A crate is under a tile across and a fingertip is wider than that, so the
    /// hitbox alone would refuse taps that visibly landed on the thing. Generous
    /// enough to forgive a finger, small enough that it cannot swallow a tap meant
    /// for a wall a tile away.
    private static let tapSlop: Double = 0.35

    /// Look into a chest of your own - from the corner button or from the chest.
    ///
    /// Shared because the two ways in have to do the same things, and one of them
    /// is not obvious: letting go of the walking thumb. The move stick is about to
    /// be hidden, and a finger still tracked against a hidden stick kept driving
    /// it, walking the player straight out of range of the chest they had just
    /// opened - which looked like a fault in the panel rather than in a touch that
    /// outlived its control.
    ///
    /// It raises no Command. Looking into a chest changes nothing about the world,
    /// only what this screen is showing, so there is nothing for the simulation to
    /// hear about and nothing for a renderer to notice - which is why the chest is
    /// told to move rather than left to work it out.
    private func openOwnChest(_ id: ChestID) {
        selectedSlot = nil
        chestPanel.open(id)
        chestRenderer.nudge(id)
        SoundPlayer.shared.play(.select)

        moveStick.end()
        moveTouch = nil
    }

    /// What a touch at this point would OPEN, if anything.
    ///
    /// Nil means the touch is about the GROUND, which is the whole reason this is
    /// its own question: a run of wall may only begin on ground. Start a drag on a
    /// crate you are standing at and it stays what it has always been - a slightly
    /// sloppy tap on the crate - because somebody reaching for a crate and moving
    /// their thumb a few points should not get a wall for it.
    ///
    /// Asked once and used twice, so what the tap opens and what the drag refuses
    /// to start on cannot come apart.
    private enum Touchable {
        case lootbox
        case chest(ChestID)
    }

    private func touchable(at pointInWorld: CGPoint) -> Touchable? {
        guard let player = world.localPlayer, player.isAlive else { return nil }
        let touched = GridGeometry.position(for: pointInWorld)

        // Your own chest before a crate, which is the order the corner button uses
        // - it is inside your base and it is yours.
        if let chest = world.reachableChest(for: player),
           chest.owner == player.team,
           chest.hitbox.expanded(by: GameScene.tapSlop).contains(touched) {
            return .chest(chest.id)
        }

        if let box = world.reachableLootbox(for: player),
           box.hitbox.expanded(by: GameScene.tapSlop).contains(touched) {
            return .lootbox
        }

        return nil
    }

    /// Starts a run of wall from the tile the press landed on.
    private func beginPainting(from press: PendingPress) {
        guard touchable(at: press.worldOrigin) == nil else { return }

        paintTouch = press.touch
        paintedFrom = nil
        painted.removeAll()
        paint(at: press.worldOrigin)
    }

    /// Lays wall along everything the finger has crossed since it was last seen.
    ///
    /// Along, rather than at the point itself, and that is the difference between
    /// this working and this being infuriating. A quick swipe reports a handful of
    /// positions a tile or more apart, and building only the tiles those positions
    /// happen to land in leaves a wall with holes in it - which does not read as
    /// "you moved too fast", it reads as the game dropping half your inputs.
    private func paint(at pointInWorld: CGPoint) {
        let previous = paintedFrom ?? pointInWorld
        paintedFrom = pointInWorld

        let delta = pointInWorld - previous

        // Half a tile, so no step can straddle a whole one.
        let steps = max(1, Int((hypot(delta.x, delta.y)
                                / (GridGeometry.tileSize / 2)).rounded(.up)))

        for step in 0...steps {
            let along = CGFloat(step) / CGFloat(steps)
            let tile = GridGeometry.gridPoint(for: CGPoint(x: previous.x + delta.x * along,
                                                           y: previous.y + delta.y * along))

            guard painted.insert(tile).inserted else { continue }

            // Silently, because a run crosses whatever is in its path. A finger
            // swept over a tree, a crate and somebody else's wall would set off
            // three red flashes for tiles it was only passing over - see build.
            build(at: tile, explainRefusals: false)
        }
    }

    private func tapMap(at pointInWorld: CGPoint) {
        // A crate or a chest you are standing at opens when you tap IT, not only
        // when you find the button in the corner.
        //
        // The button is not going anywhere - it is faster once you know it is
        // there, it works while your thumb is on the stick, and it is the only way
        // to open something you cannot see. But "walk up to the thing and touch the
        // thing" is what a person tries first, and until now that did nothing at
        // all, which reads as the game ignoring the tap rather than as a control
        // waiting to be discovered elsewhere.
        //
        // Checked before the build below rather than after, because a crate
        // standing on your own claim would otherwise eat the tap as a wall.
        switch touchable(at: pointInWorld) {
        case .chest(let id):
            openOwnChest(id)
            return

        case .lootbox:
            queuedCommands.append(.openLootbox)
            return

        case nil:
            break
        }

        build(at: GridGeometry.gridPoint(for: pointInWorld), explainRefusals: true)
    }

    /// Puts a wall on one tile, and says what happened.
    ///
    /// Shared by the tap and the drag, so a run of walls painted with one finger is
    /// the same act as nine separate taps - same command, same rules, same pop.
    ///
    /// - Parameter explainRefusals: whether a tile that will not take a wall should
    ///   flash red and, when the reason is temporary, say so. True for a tap, which
    ///   is one deliberate act at one place and deserves an answer. False for a
    ///   drag, which crosses whatever is in its path - a finger swept over a tree,
    ///   a crate and a chest would set off three red flashes and a line of text for
    ///   tiles the player was only passing over.
    @discardableResult
    private func build(at tile: GridPoint, explainRefusals: Bool) -> Bool {
        queuedCommands.append(.placeBlock(tile))

        // And then say what will happen to it, which the map never used to. The
        // answer comes from BuildSystem rather than from a copy of its rules kept
        // here, so the outline that lights up, the brick that pops and the wall
        // that appears are all one decision seen three times.
        guard let player = world.localPlayer else { return false }

        if BuildSystem.canPlace(at: tile, by: player, in: world) {
            blueprint.fill(at: tile)

            // One wall is all it takes to stop the reminder for this match. Not
            // three: three was the number for having LEARNED the gesture, and this
            // no longer asks that question - somebody who has laid a wall does not
            // need to be told they can lay walls.
            hasBuilt = true
            return true
        }

        // Walls are off after a raid: point at the countdown, which says why and
        // for how long. Even while dragging a run of wall, where no other refusal
        // is explained - this one is the reason every tile is failing.
        if !world.canBuild(player.team),
           world.claim(for: player.team)?.contains(tile) == true {
            rebuildTimer.nudge()
        }

        guard explainRefusals else { return false }

        // Only inside your own ground. A red flash out on the open map would be the
        // game telling you off for tapping the scenery.
        guard world.claim(for: player.team)?.contains(tile) == true else { return false }

        blueprint.refuse(at: tile)
        SoundPlayer.shared.play(.error)


        return false
    }

    // MARK: - Aiming something onto the map

    /// Points the outline at a spot on the map.
    ///
    /// Where the footprint goes is PlacementSystem's answer, not this file's, so
    /// what is drawn under the finger is the same rectangle the placement will use.
    private func aimPlacement(at pointInWorld: CGPoint) {
        guard let type = placingType else { return }
        ghostOrigin = PlacementSystem.origin(
            of: type, tappedAt: GridGeometry.position(for: pointInWorld))
    }

    /// Lets go of it.
    ///
    /// A refusal keeps both the item and the aim. The outline was already red, so
    /// nothing is being explained after the fact - and having to pick the machine
    /// back out of the bag to try one tile further left would be a punishment for
    /// the screen's own vagueness.
    private func commitPlacement() {
        // A panel that opened under the finger takes the gesture with it. Placing
        // something you can no longer see the map for would be the same class of
        // fault as the corner button that stayed hidden: an input outliving the
        // state it was made in.
        guard chestPanel.openChest == nil, !shopPanel.isOpen, !world.isOver else { return }

        guard let type = placingType,
              let origin = ghostOrigin,
              let player = world.localPlayer,
              PlacementSystem.canPlace(type, at: origin, by: player, in: world),
              let command = PlacementSystem.command(for: type, at: origin) else { return }

        queuedCommands.append(command)
        selectedSlot = nil
        ghostOrigin = nil
    }
}

private func - (a: CGPoint, b: CGPoint) -> CGPoint {
    CGPoint(x: a.x - b.x, y: a.y - b.y)
}
#endif
