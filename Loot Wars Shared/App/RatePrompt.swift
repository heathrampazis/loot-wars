//
//  RatePrompt.swift
//  Loot Wars
//
//  Asks for an App Store rating, at a good moment and not often.
//
//  The good moment is a podium finish: somebody who just came top 3 is about as
//  pleased with the game as they will ever be. Never on a first match - they
//  have barely seen it - so only from the third finished match on. And at most
//  once per app version, on top of Apple's own limit of three times a year,
//  which iOS enforces whatever we ask for.
//
//  iOS decides whether the box actually appears. Nothing here can tell, and
//  nothing should behave differently either way.
//

import StoreKit
import UIKit

enum RatePrompt {

    /// Finished matches before the first ask.
    static let fromMatch = 3

    /// Places that count as a good finish: 0 is first.
    static let podium = 3

    /// Whether a match that ended in this place should ask. Call AFTER the match
    /// has been counted in Prefs.matchesFinished.
    static func shouldAsk(afterPlace place: Int) -> Bool {
        guard place < podium,
              Prefs.matchesFinished >= fromMatch,
              let version = currentVersion else { return false }
        return Prefs.reviewAskedVersion != version
    }

    /// Asks, and remembers that it did for this version.
    static func ask(in scene: UIWindowScene?) {
        guard let scene, let version = currentVersion else { return }
        Prefs.reviewAskedVersion = version
        if #available(iOS 16.0, *) {
            AppStore.requestReview(in: scene)
        } else {
            SKStoreReviewController.requestReview(in: scene)
        }
    }

    private static var currentVersion: String? {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
    }
}
