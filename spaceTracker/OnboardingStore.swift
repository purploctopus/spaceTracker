//
//  OnboardingStore.swift
//  spaceTracker
//
//  First-launch welcome card + one-time tab tips. New installs get the welcome card (and
//  the location-based startup load waits for its SHOW ME button, so location is asked with
//  context). Existing users who update only get the tab tips. Settings > Help can replay
//  the tips.

import Foundation
import Combine

enum AppTab: String, CaseIterable {
    case home, starGazers, earthWatch, news

    var tipText: String {
        switch self {
        case .home:
            return "HOME COMMAND: upcoming launches, satellite passes over you, asteroids and meteor showers. Pull down to refresh."
        case .starGazers:
            return "STAR GAZERS: tonight's sky and what's up now. Spot something? Tap I SAW IT to log it and build your weekly streak."
        case .earthWatch:
            return "EARTH WATCH: today's real photo of Earth from space, plus the space stations live."
        case .news:
            return "SPACE NEWS: the latest spaceflight headlines."
        }
    }
}

final class OnboardingStore: ObservableObject {
    static let shared = OnboardingStore()

    /// Whether the welcome sheet is up.
    @Published var showWelcome: Bool
    /// False only on a brand-new install until the welcome card's SHOW ME (or skip):
    /// Home Command's location-based startup load waits on this.
    @Published var allowStartupLoad: Bool
    @Published private var seenTips: Set<String>

    private enum Keys {
        static let installChecked = "onboarding_installChecked"
        static let welcomeDone = "onboarding_welcomeDone"
        static let seenTips = "onboarding_seenTips"
    }

    private init() {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: Keys.installChecked) == nil {
            defaults.set(true, forKey: Keys.installChecked)
            // timesRan is bumped on the first app activation, which happens after this runs
            // (spaceTrackerApp touches this store in its init), so 0 here means a brand-new
            // install. Anyone updating from an older version has already run the app.
            let isNewInstall = defaults.integer(forKey: "timesRan") == 0
            defaults.set(!isNewInstall, forKey: Keys.welcomeDone)
        }
        let welcomeDone = defaults.bool(forKey: Keys.welcomeDone)
        showWelcome = !welcomeDone
        allowStartupLoad = welcomeDone
        seenTips = Set(defaults.stringArray(forKey: Keys.seenTips) ?? [])
    }

    /// Called when the welcome sheet goes away, however it was closed.
    func finishWelcome() {
        showWelcome = false
        allowStartupLoad = true
        UserDefaults.standard.set(true, forKey: Keys.welcomeDone)
    }

    func shouldShowTip(_ tab: AppTab) -> Bool {
        !showWelcome && !seenTips.contains(tab.rawValue)
    }

    func dismissTip(_ tab: AppTab) {
        seenTips.insert(tab.rawValue)
        UserDefaults.standard.set(Array(seenTips), forKey: Keys.seenTips)
    }

    /// Settings > Help: show every tab's tip again on its next visit.
    func replayTips() {
        seenTips = []
        UserDefaults.standard.set([String](), forKey: Keys.seenTips)
    }
}
