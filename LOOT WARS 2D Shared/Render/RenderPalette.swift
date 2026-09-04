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

    // Terrain
    static let floorLight = rgb(0xC0, 0xDD, 0x7A)
    static let floorDark  = rgb(0xAF, 0xCC, 0x71)
    static let terrain    = rgb(0x6F, 0x8F, 0x4B)   // impassable scenery
    static let background = rgb(0x7E, 0x9A, 0x5C)   // only visible past the map edge

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
        rgb(0x4C, 0x6A, 0x8A)    // 7 slate
    ]

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
    /// Hotbar slots are plain black at 42% in the reference, not the HUD's olive -
    /// the ground shows through them far more.
    static let hotbarSlot = SKColor(white: 0.0, alpha: 0.42)
    /// The stack-count badge reuses the health pink.
    static let countBadge = rgb(0xFF, 0x51, 0x7B)
    static let ammoBar   = rgb(0x3E, 0xA1, 0x80)

    // Loot rarity. The convention rather than an invention - grey, green, blue,
    // purple, orange, gold have meant the same thing in every game with loot in it
    // for fifteen years, and a player who has seen a purple item knows it beats a
    // green one without being told.
    //
    // Pitched bright enough to read at hotbar size against a dark slot AND on grass
    // as a glow under a dropped item, which is why the greens and blues are lifted
    // off their usual values: the map is already green, and a green that works on
    // black is invisible on a lawn.
    private static let rarities: [SKColor] = [
        rgb(0xC2, 0xC9, 0xCE),   // common - pale steel
        // Muted on purpose. A saturated green is the brightest thing on a map made
        // of grass and reads as "look at this", which is the opposite of what the
        // second rung is for - uncommon should look like something you would pick
        // up and not think about again.
        rgb(0x8E, 0xC2, 0x76),   // uncommon - sage
        rgb(0x46, 0xB1, 0xFF),   // rare - blue
        rgb(0xB9, 0x6B, 0xFF),   // epic - light violet
        // Legendary was orange, and orange is the one hue this map cannot hold: the
        // grass is warm green, the tokens are gold and a blast is pink-white, so an
        // orange pool under an item sat in the middle of colours it half matched.
        // A deep violet has the ladder climbing INTO its own colour - epic is the
        // pale version of it - and it is the only strong shade the map has not
        // already spent.
        rgb(0x7A, 0x2B, 0xD1),   // legendary - deep violet
        rgb(0xFF, 0xD6, 0x3A)    // mythical - gold
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

    // MARK: - Power-ups

    /// The two shades a perk's particles vary between.
    ///
    /// Read off the ARTWORK, hue for hue: the regeneration bottle is violet, the
    /// speed one is sky blue, strength is a hot pink and resistance is amber. That
    /// is the whole rule, and it is the only rule that works - a player learns what
    /// a colour means by looking at the thing they picked up, so a trail that did
    /// not match its own bottle would be teaching them something false about a
    /// fight they can see from across the map.
    ///
    /// Two shades a STEP apart rather than a light one against a dark one. A wide
    /// spread puts the dark half down into the grass and turns any colour muddy,
    /// which is how the first violet ended up looking like poison; a step apart
    /// shimmers instead.
    ///
    /// Deliberately not the rarity colours. Rarity says how lucky you were to find
    /// a thing; this says which power is running - and both are on screen at once,
    /// so they must never be the same language.
    static func colours(of perk: Perk) -> (bright: SKColor, deep: SKColor) {
        switch perk {
        case .regeneration: return (rgb(0xC7, 0x8B, 0xFF), rgb(0xA2, 0x53, 0xF5))
        case .speed:        return (rgb(0x96, 0xD8, 0xFF), rgb(0x4F, 0xB0, 0xF5))
        case .strength:     return (rgb(0xFF, 0x7F, 0xAE), rgb(0xF5, 0x3C, 0x7E))
        case .resistance:   return (rgb(0xFF, 0xC0, 0x8A), rgb(0xF5, 0x8A, 0x3C))
        }
    }

    /// The near-white middle of a SPARKLE, which is a glint rather than a colour.
    ///
    /// The one thing about a perk that does NOT change with which perk it is: every
    /// enchanted item twinkles the same way, because the sparkles say "this is a
    /// power-up" while the tint under them says which one.
    static let perkSpark = rgb(0xFF, 0xF2, 0xE4)

    /// The colour of yes, and the colour of no, for anything you press.
    ///
    /// One pair, used by the sell button, the shop's price pills and the buy
    /// outlines alike - so "you can do this" looks the same everywhere it is said,
    /// which is the only way a colour ever comes to mean anything.
    static let sellButton = rgb(0x3F, 0xB9, 0x50)

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
