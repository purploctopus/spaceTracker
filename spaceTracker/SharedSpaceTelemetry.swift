//
//  SharedSpaceTelemetry.swift
//  spaceTracker
//
//  Created by Claude on 9/9/26.
//
//  Shared between the main app and the spaceTrackerWidgetsExtension target -- this file's
//  Target Membership needs both checked in Xcode's File Inspector, since it's the standard
//  way to share types between an app and a widget/Live Activity extension (they're separate
//  compiled processes; the extension can't import the app, and there's no shared framework
//  target here). Everything below is intentionally dependency-free (Foundation/ActivityKit
//  only) so it compiles cleanly in both.

import Foundation
import ActivityKit

// MARK: - "What's next" snapshot, shared via the App Group for the Home/Lock Screen widget

/// A single upcoming launch or satellite pass, whichever is soonest. Published by the main
/// app (LiveActivityCoordinator) every time it refreshes launch/pass data, and read by the
/// widget extension's TimelineProvider. Intentionally just enough to render a card -- this
/// is a display snapshot, not the full SpaceLaunch/SatellitePass models (which live only in
/// the main app target and pull in dependencies the widget doesn't need).
struct UpcomingSpaceEvent: Codable, Equatable {
    enum Kind: String, Codable {
        case launch
        case satellitePass

        var displayLabel: String {
            switch self {
            case .launch: return "LAUNCH"
            case .satellitePass: return "PASS"
            }
        }

        var systemImageName: String {
            switch self {
            case .launch: return "flame.fill"
            case .satellitePass: return "antenna.radiowaves.left.and.right"
            }
        }
    }

    let kind: Kind
    let title: String       // rocket/mission name, or satellite name
    let subtitle: String    // launch provider, or "LOOK <direction>"
    let date: Date          // T-0, or pass start (AOS)
    let identifier: String  // stable id (mirrors NotificationManager's "launch-"/"pass-" scheme)
}

/// Thin read/write wrapper around the shared App Group's UserDefaults suite. This is the
/// only channel the widget extension has into the main app's data -- the two run as separate
/// processes and can't call each other directly.
enum SharedSpaceStore {
    static let appGroupID = "group.PurplOctopus.spaceTracker"
    private static let nextEventKey = "widget_next_upcoming_event_v1"

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }

    /// Called by the main app whenever it has a fresh "what's next" answer. `nil` clears the
    /// widget back to its empty state (e.g. no more launches or passes on the horizon at all).
    static func publish(_ event: UpcomingSpaceEvent?) {
        guard let defaults = defaults else { return }
        guard let event = event else {
            defaults.removeObject(forKey: nextEventKey)
            return
        }
        if let data = try? JSONEncoder().encode(event) {
            defaults.set(data, forKey: nextEventKey)
        }
    }

    static func loadNextEvent() -> UpcomingSpaceEvent? {
        guard let defaults = defaults, let data = defaults.data(forKey: nextEventKey) else { return nil }
        return try? JSONDecoder().decode(UpcomingSpaceEvent.self, from: data)
    }
}

// MARK: - Live Activity attributes

/// Must be the literal same compiled type in both the app process (which calls
/// Activity<SpaceTrackerLiveActivityAttributes>.request/.update/.end) and the widget
/// extension process (which renders it via ActivityConfiguration(for:)) -- that's the actual
/// technical reason this file needs dual target membership, not just convenience.
nonisolated struct SpaceTrackerLiveActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        /// "COUNTDOWN" / "LIFTOFF" for a launch, "INCOMING" / "OVERHEAD" for a pass. The
        /// Live Activity UI uses this (not a raw date comparison) to decide whether to show
        /// a live-ticking countdown or a static status word.
        var phaseLabel: String
        /// Countdown target while phaseLabel is COUNTDOWN/INCOMING (T-0 or pass AOS); once
        /// the phase flips to LIFTOFF/OVERHEAD this is no longer in the future and the UI
        /// switches to showing phaseLabel as plain text instead of a broken countdown.
        var targetDate: Date
    }

    var eventTitle: String
    var eventSubtitle: String
    var kindLabel: String   // "LAUNCH" or "PASS"
    var eventDate: Date
}
