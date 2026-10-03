//
//  LegalText.swift
//  Loot Wars
//
//  The Privacy Policy and Terms of Use, shown in the game from Settings >
//  About. GENERATED alongside docs/privacy.html and docs/terms.html (the
//  copies for GitHub Pages and the App Store listing) - change both together.
//

enum LegalDocument {
    case privacy, terms

    static let updated = "Last updated 3 October 2026"

    var title: String {
        switch self {
        case .privacy: return "Privacy Policy"
        case .terms:   return "Terms of Use"
        }
    }

    var intro: String {
        switch self {
        case .privacy: return "Loot Wars (“we”, “us”) is a game for iPhone. This policy explains what information the game handles. The short version: we don't collect any personal information."
        case .terms:   return "These terms apply when you download or play Loot Wars (“the game”). By playing, you agree to them. If you don't agree, please don't use the game."
        }
    }

    var sections: [(heading: String, body: String)] {
        switch self {
        case .privacy:
            return [
                ("Information we collect",
                 "None. Loot Wars has no accounts, sign-in, ads, analytics or tracking, and it doesn't connect to the internet while you play. We don't collect, store or share your name, email address, location, contacts, device identifiers or any other personal information."),
                ("Information stored on your device",
                 "The game saves your settings (such as sound and control layout), your level and XP, and your best score on your device, so they're there the next time you play. This information stays on your device and is never sent to us. Deleting the game deletes it."),
                ("Crash reports from Apple",
                 "If you've chosen to share analytics with app developers in your iPhone's settings, Apple may send us anonymous crash and performance reports. These don't identify you. You can turn this off at any time in Settings > Privacy & Security > Analytics & Improvements."),
                ("Children",
                 "Loot Wars doesn't collect personal information from anyone, including children."),
                ("Third parties",
                 "We don't sell or share any information with third parties. The game contains no third-party advertising or analytics code."),
                ("Changes to this policy",
                 "If this policy changes, we'll update it here and change the date at the top."),
                ("Contact",
                 "Questions about privacy? Email us at mistydual@gmail.com.")
            ]
        case .terms:
            return [
                ("Using the game",
                 "We give you a personal, non-transferable licence to play Loot Wars on Apple devices you own or control, as allowed by the App Store's rules. Apple's Standard Licensed Application End User License Agreement also applies, and these terms add to it."),
                ("What you can't do",
                 "Don't copy, modify, sell or redistribute the game, or try to reverse engineer it, except where the law allows. Don't use the game in any way that breaks the law."),
                ("In-game items",
                 "Tokens, items, levels and other in-game content have no real-world value and can't be exchanged for money. Your progress is stored on your device and may be lost if you delete the game or change devices."),
                ("Ownership",
                 "The game, including its art, sound, code and name, belongs to us. These terms don't give you any ownership of it."),
                ("Changes",
                 "We may update, change or stop offering the game at any time. We may also update these terms; the date at the top shows when they last changed."),
                ("No warranty",
                 "The game is provided “as is”. To the extent the law allows, we don't promise it will be free of bugs or always available."),
                ("Australian Consumer Law",
                 "Nothing in these terms excludes, restricts or changes any rights you have under the Australian Consumer Law or any other law that can't be excluded. Where the law lets us limit our liability, it is limited to supplying the game again or paying the cost of doing so."),
                ("Limitation of liability",
                 "To the extent the law allows, we aren't liable for any indirect or consequential loss arising from your use of the game."),
                ("Governing law",
                 "These terms are governed by the laws of Australia, and you agree to the non-exclusive jurisdiction of the courts of Australia."),
                ("Contact",
                 "Questions about these terms? Email us at mistydual@gmail.com.")
            ]
        }
    }
}
