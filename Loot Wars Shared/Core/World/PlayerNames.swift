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
        guard !trimmed.isEmpty, !isOffensive(trimmed) else { return defaultName }
        return trimmed
    }

    // MARK: - Names that are not allowed

    /// Whether a name is rude, a slur, or otherwise not something to see over
    /// somebody's head.
    ///
    /// Sees through the usual dodges: capitals, numbers standing in for letters
    /// (A55, N1), dots and underscores between the letters (f_u_c_k), and a
    /// letter held down (fuuuck). Short words that turn up inside ordinary ones -
    /// the "ass" in Bass and Glass, the "rape" in Grape - only count as a word on
    /// their own: a whole name, or one part of a name like BigAss.
    ///
    /// A list, so never perfect - but it stops the obvious, and the lists below
    /// are where anything missed gets added.
    static func isOffensive(_ name: String) -> Bool {
        let parts = words(in: name)
        let whole = runs(of: parts.joined())
        if blockedAnywhere.contains(where: { contains(whole, $0) }) { return true }
        for part in parts {
            let letters = runs(of: part)
            if blockedWords.contains(where: { matches(letters, $0) }) { return true }
        }
        return false
    }

    /// Blocked wherever they appear in a name.
    ///
    /// Stored in ROT13 so the words themselves are not sitting in the source in
    /// plain sight; decoded once, the first time a name is checked.
    private static let blockedAnywhere: [Runs] = [
        "shpx", "shx", "fuvg", "phag", "ovgpu", "onfgneq", "juber", "fyhg", "qvpx",
        "chffl", "cravf", "intvan", "avttre", "avttn", "snttbg", "sntbg", "snt",
        "ergneq", "anmv", "uvgyre", "xvxr", "puvax", "jrgonpx", "genaal", "gjng",
        "jnax", "wvmm", "cbea", "obbo", "cvff", "obyybpx", "ohttre", "zbgures",
        "nffubyr", "nefrubyr", "qvyqb", "betnfz", "frzra", "oybjwbo", "unaqwbo",
        "evzwbo", "zvys", "zbyrfg", "vaprfg", "uragnv", "phpx", "xvyylbhefrys",
        "ornare"
    ].map { PlayerNames.runs(of: PlayerNames.rot13($0)) }

    /// Blocked only as a whole word - see isOffensive. ROT13, like the above.
    private static let blockedWords: [Runs] = [
        "nff", "nefr", "nany", "nahf", "phz", "frk", "gvg", "gvgf", "pbpx", "encr",
        "encvfg", "fcvp", "tbbx", "qlxr", "pbba", "ubzb", "crqb", "cnrqb", "vfvf",
        "xxx", "xlf", "cnxv", "arteb", "abapr", "ubr"
    ].map { PlayerNames.runs(of: PlayerNames.rot13($0)) }

    /// A word as runs of the same letter: "fuuck" is f, u twice, c, k.
    private typealias Runs = [(letter: Character, count: Int)]

    private static func runs(of text: String) -> Runs {
        var result: Runs = []
        for character in text {
            if let last = result.last, last.letter == character {
                result[result.count - 1].count += 1
            } else {
                result.append((character, 1))
            }
        }
        return result
    }

    /// Whether the word appears somewhere in the text, each letter there at
    /// least as many times in a row as the word has it - so a held-down letter
    /// still matches, but Bob does not match a word with a double o in it.
    private static func contains(_ text: Runs, _ word: Runs) -> Bool {
        guard !word.isEmpty, text.count >= word.count else { return false }
        for start in 0...(text.count - word.count) {
            var found = true
            for (offset, run) in word.enumerated() {
                let here = text[start + offset]
                if here.letter != run.letter || here.count < run.count {
                    found = false
                    break
                }
            }
            if found { return true }
        }
        return false
    }

    /// The same, but the whole of the text has to be the word.
    private static func matches(_ text: Runs, _ word: Runs) -> Bool {
        text.count == word.count && contains(text, word)
    }

    /// The parts of a name, lower case, numbers read as the letters they stand
    /// in for, everything else dropped. Split at spaces and punctuation, and
    /// where a capital follows a small letter - so BigAss is "big" and "ass".
    private static func words(in name: String) -> [String] {
        let lookalikes: [Character: Character] = [
            "0": "o", "1": "i", "3": "e", "4": "a", "5": "s", "7": "t", "8": "b", "9": "g"
        ]
        var parts: [String] = []
        var current = ""
        var previous: Character?

        for character in name {
            if " _-.".contains(character) {
                if !current.isEmpty { parts.append(current) }
                current = ""
                previous = nil
                continue
            }
            if let previous, previous.isLowercase, character.isUppercase, !current.isEmpty {
                parts.append(current)
                current = ""
            }
            current.append(character)
            previous = character
        }
        if !current.isEmpty { parts.append(current) }

        return parts.compactMap { part in
            let letters = part.lowercased().compactMap { character -> Character? in
                let read = lookalikes[character] ?? character
                return ("a"..."z").contains(read) ? read : nil
            }
            return letters.isEmpty ? nil : String(letters)
        }
    }

    private static func rot13(_ text: String) -> String {
        String(text.unicodeScalars.map { scalar -> Character in
            switch scalar.value {
            case 97...122: return Character(UnicodeScalar((scalar.value - 97 + 13) % 26 + 97)!)
            default: return Character(scalar)
            }
        })
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
