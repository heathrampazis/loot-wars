//
//  PlayerNames.swift
//  Loot Wars
//
//  What everybody in a match is called: the name the player picked in Settings,
//  and a name for each bot drawn from the list below.
//
//  A name is part of the actor - see Actor.name - so the world, not the screen,
//  says who is who. Bot names are drawn with the world's own generator when the
//  match is made, so a seed replays with the same names.
//

enum PlayerNames {

    /// What the player is called until they choose a name.
    static let defaultName = "You"

    /// The longest name allowed, so it fits over a head and on the leaderboard.
    static let maxLength = 12

    /// The names a bot can be given: short arcade code names - Tron, Flame,
    /// Laser - the kind a player types on a cabinet's high score table. Every one
    /// starts with a capital. Never fewer than seven - every bot needs its own -
    /// and none longer than maxLength.
    static let bots: [String] = [
        "Tron", "Flame", "Laser", "Skirmish", "Blaze", "Volt", "Pulse", "Neon", "Flux",
        "Nova", "Zap", "Bolt", "Ion", "Photon", "Vector", "Glitch", "Spark", "Ember",
        "Inferno", "Comet", "Cipher", "Turbo", "Rocket", "Static", "Arc", "Rift", "Blitz",
        "Surge", "Plasma", "Nitro", "Echo", "Raptor", "Viper", "Cobalt", "Titan", "Onyx",
        "Orbit", "Zenith", "Havoc", "Striker", "Fury", "Storm", "Frost", "Shadow",
        "Phantom", "Ghost", "Spectre", "Raider", "Ranger", "Jet", "Dash", "Ace", "Hex",
        "Byte", "Pixel", "Torque", "Gamma", "Omega", "Nexus", "Quasar", "Saber", "Talon",
        "Vortex", "Apex", "Halo", "Cinder", "Radar", "Rogue", "Siren", "Sonic"
    ]

    /// Whether a character may go in a name: letters, numbers, a space and a
    /// little punctuation.
    static func allows(_ character: Character) -> Bool {
        character.isLetter || character.isNumber || " _-.".contains(character)
    }

    /// A name as typed, made fit to show: trimmed, single-spaced, letters,
    /// numbers and a little punctuation only, and no longer than maxLength.
    /// Capitals are left exactly as typed. Nothing left means the default.
    static func clean(_ raw: String) -> String {
        let allowed = raw.filter(allows)
        let words = allowed.split(separator: " ", omittingEmptySubsequences: true)
        let joined = words.joined(separator: " ")
        let trimmed = String(joined.prefix(maxLength)).trimmingCharactersInSpace()
        return trimmed.isEmpty ? defaultName : trimmed
    }
}

private extension String {
    /// Core does not import Foundation, so trimming is done by hand.
    func trimmingCharactersInSpace() -> String {
        var text = Substring(self)
        while text.first == " " { text = text.dropFirst() }
        while text.last == " " { text = text.dropLast() }
        return String(text)
    }
}
