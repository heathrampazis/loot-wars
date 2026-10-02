//
//  RenderPalette.swift
//  Loot Wars
//
//  Placeholder colours, sampled straight out of the target mockup so the game reads
//  correctly long before there is any real art. Sprites replace all of this later;
//  until then, everything visual comes from here and nowhere else.
//

import SpriteKit

enum RenderPalette {

    // The menu, which is the one screen in this game that is not the map.
    //
    // Every colour here is the GAME'S, and that is the point rather than a
    // convenience. A menu painted in colours the match never uses is a menu that
    // belongs to a different product - it was a set of tasteful mid-tones for one
    // revision and read as a settings screen bolted onto a cartoon.
    //
    // Play is offerPlate, the green this game already uses to mean yes - it is the
    // fill under every offer the shop makes you. Info and Settings are two of the
    // eight TEAM colours, blue pulled a little deeper so white type clears it.
    // White clears 4.3:1, 4.1:1 and 4.9:1 respectively.
    /// A button's fill and the darker shade it is edged and shadowed with, as ONE
    /// thing.
    ///
    /// A pair rather than a colour and a function that darkens it. The function
    /// version wanted UIColor.getRed to pull the components back out, which is a
    /// UIKit call in a file that imports SpriteKit and nothing else - it would
    /// most likely have resolved and it is not worth finding out on somebody
    /// else's build. Two numbers written down together cannot come apart either.
    struct MenuTone {
        let face: SKColor
        /// The border AND the lip, which are the same colour on purpose: a button
        /// edged in one shade and standing on another reads as two objects.
        let edge: SKColor
    }

    /// THE RARITY LADDER, straight off the assets.
    ///
    /// Epic green, Legendary blue, Mythical purple - the three colours a player has
    /// already seen glowing under loot on the grass and worn by the figures
    /// themselves. That is what makes them the right ones rather than merely
    /// available: the menu is painted in the colours the game hands out as prizes.
    ///
    /// They replace a set of muted mid-tones picked for text contrast, which looked
    /// exactly like what they were. The note worth keeping from that mistake is
    /// that contrast on a BUTTON is not the same problem as contrast in a
    /// paragraph. White on this green is 2.8:1, which would be unreadable as body
    /// text and is perfectly clear as a forty-point bold word beside a solid white
    /// triangle; the purple clears 4:1 outright. If white ever does look weak on
    /// the green, the lever is a one-point dark shadow behind the label rather than
    /// a duller green.
    ///
    /// Each edge is its own face at 0.72 brightness. Dark enough to read as an
    /// edge, close enough that it is obviously the same colour and not a border
    /// somebody chose separately - which is what a black outline looked like, and
    /// why it went.
    ///
    /// SUPERSEDED by Heath's mock-up: green, blue and orange, the brighter of the
    /// two versions he drew. The softer set, matching the team colours on the
    /// map exactly, was: green 3DA17D / 2F7C61, blue 6AB1FE / 4D86C3,
    /// orange FF935D / D0784F - swap these back to try it.
    static let menuPlay = MenuTone(face: rgb(0x00, 0xA6, 0x7A),
                                   edge: rgb(0x00, 0x84, 0x61))
    static let menuInfo = MenuTone(face: rgb(0x4F, 0xB3, 0xFF),
                                   edge: rgb(0x3A, 0x8B, 0xD2))
    static let menuSettings = MenuTone(face: rgb(0xFF, 0x8B, 0x4F),
                                       edge: rgb(0xE0, 0x75, 0x49))

    /// Near-black rather than black. A true black on a light ground vibrates at
    /// large sizes, which is exactly the size the wordmark is set at.
    static let menuInk = SKColor(white: 0.08, alpha: 1)

    /// The veil over the drifting map.
    ///
    /// THE GRASS'S OWN COLOUR, and it has now been black and white and both were
    /// wrong in the same way: a neutral veil over a coloured map does not soften
    /// it, it drains it. Black took the lawn to olive and read as dusk. White took
    /// it to a pale wash and read as a photograph behind frosted glass - a menu
    /// that had a game somewhere behind it rather than a menu made of one.
    ///
    /// Tinting with floorLight pulls everything towards the colour the whole game
    /// is played on. The claims stay coloured, the woods stay green, nothing goes
    /// grey, and what the blur is doing reads as distance rather than as a filter.
    /// Kept light enough - under a third - that it unifies rather than flattens.
    static let menuVeil = SKColor(red: 0xC0 / 255.0, green: 0xDD / 255.0,
                                  blue: 0x7A / 255.0, alpha: 0.28)

    // Terrain
    static let floorLight = rgb(0xC0, 0xDD, 0x7A)
    static let floorDark  = rgb(0xAF, 0xCC, 0x71)
    static let terrain    = rgb(0x6F, 0x8F, 0x4B)   // impassable scenery
    static let background = rgb(0x7A, 0x8F, 0x4F)   // only past the drawn overhang; matches its darkest ground

    // The ground colours for one biome: the floor checker, the map edge, and footstep tufts.
    struct BiomeTones {
        let light: SKColor
        let dark: SKColor
        let edge: SKColor
        let tuftOuter: SKColor
        let tuftInner: SKColor
    }

    static func tones(for biome: Biome) -> BiomeTones {
        switch biome {
        case .plains:
            return BiomeTones(light: floorLight, dark: floorDark, edge: terrain,
                              tuftOuter: terrain, tuftInner: floorDark)
        case .forest:
            return BiomeTones(light: rgb(0xA8, 0xC6, 0x68), dark: rgb(0x9A, 0xB8, 0x5F),
                              edge: rgb(0x58, 0x78, 0x3A),
                              tuftOuter: rgb(0x58, 0x78, 0x3A), tuftInner: rgb(0x8C, 0xAA, 0x56))
        case .snow:
            return BiomeTones(light: rgb(0xEE, 0xF5, 0xFA), dark: rgb(0xE1, 0xEC, 0xF4),
                              edge: rgb(0xAE, 0xC4, 0xD4),
                              tuftOuter: rgb(0xC3, 0xD5, 0xE3), tuftInner: rgb(0xFF, 0xFF, 0xFF))
        case .desert:
            return BiomeTones(light: rgb(0xEB, 0xD7, 0xA2), dark: rgb(0xE0, 0xC9, 0x8F),
                              edge: rgb(0xC4, 0xA2, 0x66),
                              tuftOuter: rgb(0xC4, 0xA2, 0x66), tuftInner: rgb(0xE8, 0xD3, 0x9C))
        }
    }

    // Teams. An actor and the walls it builds are the same colour on purpose -
    // at a glance you should be able to tell whose base you are standing in.
    private static let teams: [SKColor] = [
        rgb(0x3E, 0xA2, 0x7F),   // 0 teal
        rgb(0xE0, 0x4B, 0x5C),   // 1 red
        rgb(0x4F, 0x92, 0xDC),   // 2 blue
        rgb(0x7B, 0x5B, 0xD6),   // 3 purple
        rgb(0xF2, 0x91, 0x3D),   // 4 orange
        rgb(0xE8, 0x6B, 0xB0),   // 5 pink
        rgb(0xF0, 0xC9, 0x4A),   // 6 yellow
        rgb(0x3A, 0xB8, 0xD2)    // 7 cyan - was a slate blue-grey that read as "nobody's"
    ]

    /// The same eight, turned up, for the scoreboards.
    ///
    /// Two sets on purpose. On the map a team colour covers whole walls, floors
    /// and bars, and at that size the softer set sits better on the grass. On a
    /// leaderboard it is a small swatch on a dark panel, and there it has to POP -
    /// the softer set looked flat and a little muddy at that size.
    ///
    /// Same order, same hues, so a team is recognisably the same colour in both.
    private static let vibrantTeams: [SKColor] = [
        rgb(0x27, 0xC4, 0x7F),   // 0 green
        rgb(0xFF, 0x3B, 0x4E),   // 1 red
        rgb(0x3E, 0x7C, 0xFF),   // 2 blue
        rgb(0x9B, 0x5C, 0xFF),   // 3 purple
        rgb(0xFF, 0x8A, 0x1F),   // 4 orange
        rgb(0xFF, 0x5F, 0xC4),   // 5 pink
        rgb(0xFF, 0xD2, 0x1F),   // 6 yellow
        rgb(0x2F, 0xD4, 0xF0)    // 7 cyan
    ]

    static func vibrantColour(for team: TeamID) -> SKColor {
        vibrantTeams[team.raw % vibrantTeams.count]
    }

    static func colour(for team: TeamID) -> SKColor {
        teams[team.raw % teams.count]
    }

    /// The flare at the centre of a blast.
    static let blast = SKColor(red: 0xFF / 255.0, green: 0xE9 / 255.0,
                               blue: 0x9C / 255.0, alpha: 0.95)

    /// Confetti. The team colours brightened, plus the HUD's own colours.
    ///
    /// Not `teams` verbatim: those are picked to sit calmly on grass all match, and
    /// the darker ones (slate, purple) vanish against it at confetti size. An
    /// explosion lasts half a second and has to read instantly, so these are the
    /// same hues pushed up in value.
    static let confetti: [SKColor] = [
        rgb(0x3E, 0xE0, 0xA8),   // teal
        rgb(0xFF, 0x5B, 0x6E),   // red
        rgb(0x5A, 0xB4, 0xFF),   // blue
        rgb(0xA9, 0x7B, 0xFF),   // purple
        rgb(0xFF, 0xA6, 0x3D),   // orange
        rgb(0xFF, 0x8A, 0xD0),   // pink
        rgb(0xFF, 0xE0, 0x4A),   // yellow
        rgb(0x6E, 0xF0, 0x6E),   // green
        rgb(0xFF, 0x51, 0x7B),   // health pink
        rgb(0xB3, 0xF0, 0xFA),   // bullet blue
        rgb(0xFF, 0xC4, 0x63),   // helmet yellow
        rgb(0xFF, 0xFF, 0xFF)
    ]

    // Projectiles - the pale blue from the mockup, deliberately not team coloured
    // so shots stay readable against eight different team colours.
    static let projectile        = rgb(0xB3, 0xF0, 0xFA)
    static let projectileOutline = SKColor.black

    // HUD. Panel and track alphas solved from the mockup: the panel is this dark
    // olive at 70% over the ground, the track a further 35% of black on top.
    static let hudPanel  = SKColor(red: 0x3B / 255.0, green: 0x46 / 255.0,
                                   blue: 0x27 / 255.0, alpha: 0.70)
    static let hudTrack  = SKColor(white: 0.0, alpha: 0.35)
    static let healthBar = rgb(0xFF, 0x51, 0x7B)

    // Health bars over people: green above 60%, yellow above 30%, red below.
    static func healthColour(at fraction: Double) -> SKColor {
        switch healthBand(at: fraction) {
        case 2: return rgb(0x3F, 0xD1, 0x6A)
        case 1: return rgb(0xF5, 0xC5, 0x42)
        default: return placementBlocked
        }
    }

    // The band a fraction falls in, so a bar repaints only when the band changes.
    static func healthBand(at fraction: Double) -> Int {
        if fraction > 0.6 { return 2 }
        if fraction > 0.3 { return 1 }
        return 0
    }
    /// Hotbar slots are plain black at 42% in the reference, not the HUD's olive -
    /// the ground shows through them far more.
    static let hotbarSlot = SKColor(white: 0.0, alpha: 0.42)
    /// The stack-count badge reuses the health pink.
    static let countBadge = rgb(0xFF, 0x51, 0x7B)
    static let ammoBar   = rgb(0x3E, 0xA1, 0x80)

    // Loot rarity: grey, green, blue, purple, gold, in that order and no other.
    //
    // The convention rather than an invention. Those five have meant the same thing
    // in every game with loot in it for fifteen years, and a player who has seen a
    // purple item knows it beats a green one without being told.
    //
    // There were six, and the two that went were the warm ones. Orange and red are
    // the hues this map cannot hold - the grass is warm green, the tokens are gold,
    // a blast is pink-white - so a warm pool under an item landed in the middle of
    // colours it half matched and read as an effect rather than as a rating. The
    // ladder is shorter for it and says more.
    //
    // Every one of these is pitched to survive a pale yellow-green lawn, which is
    // not where these colours are usually asked to work. Measured against the floor
    // tile: green 1.9, blue 1.9, purple 2.6. The greens and blues are lifted well
    // off their conventional values because a green that reads on a black inventory
    // screen is invisible on grass.
    private static let rarities: [SKColor] = [
        // Pale steel, and deliberately the quietest thing on the map. It barely
        // separates from the grass, which is the correct amount of attention for a
        // rung that means "you will find another one in a minute".
        rgb(0xA3, 0xAD, 0xB8),   // common

        // An emerald rather than the lime the artwork wears. A lime pool sat within
        // a hair of the floor tile on every measure and vanished under the item it
        // was meant to be advertising; pulling the hue cool and the value down puts
        // it at 1.9 against the grass while still reading as the green everybody
        // expects on the second rung.
        rgb(0x2B, 0xDE, 0x6A),   // epic
        rgb(0x2C, 0xA6, 0xFF),   // legendary
        rgb(0xC2, 0x58, 0xFF),   // mythical

        // Gold, and the weakest hue here against this particular map - a yellow
        // pool on yellow-green grass is the one fight a colour cannot win. That is
        // exactly why the top rung is also the rung that SPARKLES: Cosmic is found
        // by its twinkle and confirmed by its colour, rather than the other way
        // round. Pulled deeper than the token gold for the same reason, and kept as
        // its own value so the two can drift apart without either being dragged.
        rgb(0xFF, 0xBE, 0x1A)    // cosmic
    ]

    static func colour(of rarity: Rarity) -> SKColor {
        rarities[min(rarity.rawValue, rarities.count - 1)]
    }

    /// Stink gas. A sickly yellow-green rather than a clean one, because the map
    /// is already made of clean greens - a cloud in the same family as the grass
    /// would read as terrain, and this has to read as something you do not walk
    /// into.
    /// A pale spring green, lighter than the grass rather than more saturated
    /// than it.
    ///
    /// The first attempt was a sickly yellow-green picked to contrast with the
    /// map - which is the obvious way to make a hazard stand out and the wrong one
    /// here. At the opacity a cloud needs, a saturated colour reads as a hole
    /// punched in the level; a lighter version of what is already underneath reads
    /// as something lying ON the level, which is what it is.
    ///
    /// It does not need an outline either. An edge was doing the job the fill was
    /// too thin to do, and now that the fill is nearly solid the silhouette draws
    /// itself.
    static let gas = rgb(0xB4, 0xE3, 0x92)

    /// Money: a loose golden token, a machine paying out, the fountain of a
    /// jackpot.
    ///
    /// The same gold as the top of the rarity ladder and kept as its own name on
    /// purpose. They are the same colour for a reason a player already understands
    /// - gold is the best thing here - but they are different CLAIMS, and one of
    /// them is allowed to change without dragging the other with it. Cosmic gear is
    /// the only rarity that wears this, and asking for the rarity by name in the
    /// arcade code was how that guarantee would have quietly stopped being true.
    static let treasure = rgb(0xFF, 0xD6, 0x3A)

    // MARK: - Power-ups

    /// The rainbow a power-up wears, as a ring of hues.
    ///
    /// There were four perks and four colours, and the colour was doing real work:
    /// it told you across a map which of the four the person charging at you had
    /// drunk. With one perk there is nothing left to tell apart, so the colour is
    /// free to do the other job a colour can do - say how big a deal this is.
    ///
    /// Nothing else in this game cycles. Rarity is a colour, a team is a colour,
    /// damage is red and money is gold, and every one of them holds still. A thing
    /// that will not settle on a colour at all is therefore instantly legible as
    /// not-of-that-system, which is exactly what the only item that does four
    /// things at once should look like.
    ///
    /// Eight hues, solved for the most colour that will sit behind a white spark.
    ///
    /// The constraint used to be the LAWN. These were drawn as pigment straight
    /// onto pale yellow-green, so every hue had to clear a contrast ratio against
    /// the floor tile, which put a floor under how dark any of them could be and
    /// took the colour out of blue and violet to get there. A first version went
    /// further still and flattened perceived lightness to a tenth of a point - a
    /// rainbow at 0.59 mean chroma, which is a rainbow of dusty pastels, and for
    /// the one item in the game that does everything, dull is the worst thing it
    /// could read as. A band of L* 53 to 67 got that back to 0.83.
    ///
    /// The rainbow no longer touches the grass. Every particle is now a white
    /// sparkle with one of these behind it, so what a hue has to survive is the
    /// WHITE in front of it, not the green underneath - a different and much
    /// kinder question. The floor moves from "1.7 against the floor tile" to "2.3
    /// against white", which lets blue and violet drop where they wanted to be all
    /// along: blue gains a third of its chroma back, violet a fifth, and the mean
    /// goes 0.83 to 0.89.
    ///
    /// The other half of the ask was contrast, and that was a SPACING problem
    /// rather than a saturation one. Red at 354 degrees and orange at 18 were 24
    /// apart, a difference of 18 dE - close enough that two consecutive puffs of
    /// the trail read as one colour twice. Opening the warm end (orange to 28,
    /// gold to 52) takes the closest neighbouring pair to 37 dE, which doubles the
    /// worst step in the ring without moving a single hue far enough to stop being
    /// the colour it is called.
    ///
    /// Lightness swings 28 points now rather than 13. That would once have been a
    /// throb, and the whole reason the band existed was to avoid one - but the
    /// thing that would have throbbed was the overlay worn by the player, which is
    /// gone. Nothing wears a whole cycle on one object any more: an item walks the
    /// ring over six seconds, and each puff of the trail is one fixed colour that
    /// never changes after it is born.
    static let spectrum: [SKColor] = [
        rgb(0xFF, 0x00, 0x22),   // red
        rgb(0xFF, 0x77, 0x00),   // orange
        rgb(0xC4, 0xAA, 0x00),   // gold
        rgb(0x27, 0xC4, 0x00),   // green
        rgb(0x06, 0xBC, 0xC2),   // cyan
        rgb(0x00, 0x4C, 0xFF),   // blue
        rgb(0xAA, 0x00, 0xFF),   // violet
        rgb(0xFF, 0x0A, 0xB6)    // magenta
    ]

    /// One hue off the ring, counted round rather than clamped.
    ///
    /// Takes any integer, including a negative one, so callers can offset a second
    /// stream of particles by a fixed number of steps, or count a beat DOWNWARDS,
    /// without ever having to think about the length of the ring.
    ///
    /// Named apart from the array on purpose. `spectrum` and `spectrum(at:)` are
    /// legal side by side and the compiler can usually tell them apart, but a bare
    /// `RenderPalette.spectrum` in a `let` with no contextual type is then an
    /// unapplied method reference as readily as it is an array - a coin-flip
    /// diagnostic in a file nobody should have to think that hard about.
    static func hue(at step: Int) -> SKColor {
        let count = spectrum.count
        return spectrum[((step % count) + count) % count]
    }

    /// The pair of hues a perk's particles vary between at one instant.
    ///
    /// Three apart on an eight-hue ring, which is most of the way to opposite. The
    /// two-mote aura throws one of each, so at any moment the trail carries a
    /// contrast rather than a shade - and because both walk forward together, the
    /// contrast itself travels round the rainbow.
    static func perkColours(at step: Int) -> (bright: SKColor, deep: SKColor) {
        (hue(at: step), hue(at: step + 3))
    }

    /// What each power-up is, in colour.
    ///
    /// The disco ball refuses to settle on one and walks the whole ring - see
    /// perkColours - which is the claim that it is all of them at once. A single
    /// holds still on its own, which is the same claim in reverse, and each is
    /// taken from the ring rather than invented so the two read as one family.
    ///
    /// Red for hitting harder, cyan for moving faster, violet for healing. The
    /// first two are associations this game has already taught elsewhere - damage
    /// is red - and each is a neighbouring pair off the ring, so a trail carries a
    /// shade rather than a flat wash.
    ///
    /// REGENERATION WAS GREEN, on the reasoning that the heal motes are green and
    /// nothing new should have to be learned. That was the right call when this
    /// only had to tint a few glints; it is the wrong one now that it also colours
    /// a standing pool of light under a person, which has a different job - saying
    /// WHICH perk somebody is running, from across the map.
    ///
    /// And green is the one colour this map eats. The floor is a pale yellow-green
    /// lawn, and the rarity notes above carry the measurements: green 1.9 against
    /// the floor, blue 1.9, purple 2.6. Violet is the most legible thing on the
    /// ring here, which is worth more to an aura than the association was - the
    /// green motes still rise off somebody being healed and still say healing.
    ///
    /// Violet and magenta rather than violet twice, matching the other two. Magenta
    /// sits close to the health pink, which for a healing perk is the right
    /// accident to have.
    /// Strength's second colour: the spectrum's red, darker.
    static let strengthDeep = rgb(0xB8, 0x00, 0x18)

    static func colours(for perk: Perk, at step: Int) -> (bright: SKColor, deep: SKColor) {
        switch perk {
        case .overdrive:    return perkColours(at: step)
        // Red and a deeper red, rather than red and orange: the orange was what
        // made it read as orange from across the map.
        case .strength:     return (hue(at: 0), strengthDeep)
        case .speed:        return (hue(at: 4), hue(at: 5))
        case .regeneration: return (hue(at: 6), hue(at: 7))
        // Gold and orange: a warm yellow, kept clear of strength's red.
        case .resistance:   return (hue(at: 2), hue(at: 1))
        }
    }

    /// The near-white middle of a SPARKLE, which is a glint rather than a colour.
    ///
    /// The one thing about a perk that does NOT change with which perk it is: every
    /// enchanted item twinkles the same way, because the sparkles say "this is a
    /// power-up" while the tint under them says which one.
    static let perkSpark = rgb(0xFF, 0xF2, 0xE4)

    /// A base closing. A warm near-white, so the lap of light round a finished
    /// wall reads as the wall being lit rather than as another coloured effect on a
    /// map that already has plenty - and so it cannot be mistaken for a rarity, a
    /// team, a power-up or money, which is every other colour in this file.
    static let sealLight = rgb(0xFF, 0xF3, 0xD2)

    /// The colour of yes, and the colour of no, for anything you press.
    ///
    /// One pair, used by the sell button, the shop's price pills and the buy
    /// outlines alike - so "you can do this" looks the same everywhere it is said,
    /// which is the only way a colour ever comes to mean anything.
    static let sellButton = rgb(0x3F, 0xB9, 0x50)

    /// The plate under an offer the game is making you.
    ///
    /// A darker relative of the yes-green above, chosen because the quick-buy
    /// prompt used to be filled with hudPanel - the exact colour of the health
    /// panel it sits under. It was not that players were ignoring it; it was
    /// wearing the uniform of the furniture and reading as more of the same. White
    /// text clears 4.3 to 1 on this, which is comfortable at that size.
    static let offerPlate = rgb(0x2E, 0x8B, 0x47)

    /// The number thrown up when something sells.
    ///
    /// Much brighter than the sell button it comes from, and they are different on
    /// purpose: a button is a surface with a word on it and wants a green you can
    /// read black text against, while this is a small number on grass for three
    /// quarters of a second. Payouts elsewhere in this game are gold and they pop -
    /// this had to earn the same attention in a colour that already means money
    /// coming in.
    static let payout = rgb(0x3D, 0xF5, 0x74)

    /// The pill it sits on, so a bright green number survives pale green grass.
    ///
    /// A dark plate rather than an outline drawn out of offset copies of the text,
    /// which is what this replaced and which read as the number being printed
    /// twice. It is the same device the count badge and the shop's price pill use,
    /// so a payout belongs to the bar it comes out of.
    static let payoutPill = SKColor(red: 0.04, green: 0.14, blue: 0.07, alpha: 0.88)
    static let affordable = rgb(0x4C, 0xC9, 0x5E)

    /// A price you cannot pay yet: grey, not red.
    ///
    /// Two reds were tried on this button and both were wrong, in the end for the
    /// same reason rather than for their hues. Red is an ERROR - it is what this
    /// game says when you try to build on ground you cannot build on - and not
    /// having saved up thirteen tokens yet is not a mistake anybody has made. It is
    /// simply a thing that has not happened. Four cards side by side with two of
    /// them shouting in red also read as a shop that was half broken.
    ///
    /// Grey says the true thing quietly, leaves green as the only colour on the
    /// panel that means anything, and is what every shop in every game does. The
    /// refusal is still red - shake a card you actually pressed and cannot buy, and
    /// it flashes red - because that IS a moment, and it is over in half a second.
    /// Deliberately DARKER than the card it sits on rather than lighter.
    ///
    /// A lighter grey was tried and looked worse, and it is worth saying why the
    /// argument for it did not survive contact. The theory was that lifting the
    /// button above its card would make the pair read as one button lit and one
    /// not; what it actually did was give a price you cannot pay the same visual
    /// weight as one you can, so the row stopped sorting itself at a glance. Dark
    /// reads as the unlit version of the green - the same button with nothing
    /// behind it - which is exactly what it is.
    ///
    /// Still clear of the plate's own brightness in the other direction, which is
    /// the one rule here that does not bend: a grey at the plate's value dissolves
    /// into the card and stops being a button at all.
    static let unaffordable = SKColor(red: 0.24, green: 0.27, blue: 0.32, alpha: 1)

    /// The same two, a few shades down, for the lip under a button.
    ///
    /// A button in this game is a solid colour with a darker edge along the bottom
    /// of it, which is the one thing that makes a flat shape look like something
    /// you can press. It replaced a black outline, and the difference is what an
    /// outline SAYS: black around a shape is how this game draws objects in the
    /// world - the token, the crates, the figures - so a black-ringed capsule read
    /// as a thing lying on the grass rather than a control on a panel.
    static let affordableDeep = rgb(0x2C, 0x8B, 0x3F)
    static let unaffordableDeep = SKColor(red: 0.14, green: 0.16, blue: 0.20, alpha: 1)

    // Placement preview. Green while a footprint would take, red while it would
    // not - the only two colours nobody has to be taught.
    static let placementValid   = rgb(0x6E, 0xF0, 0x6E)
    static let placementBlocked = rgb(0xFF, 0x4B, 0x54)

    // On-screen controls
    static let controlBackground = SKColor(white: 0.0, alpha: 0.18)
    static let controlForeground = SKColor(white: 0.0, alpha: 0.30)

    private static func rgb(_ r: Int, _ g: Int, _ b: Int) -> SKColor {
        SKColor(red: CGFloat(r) / 255.0,
                green: CGFloat(g) / 255.0,
                blue: CGFloat(b) / 255.0,
                alpha: 1.0)
    }
}
