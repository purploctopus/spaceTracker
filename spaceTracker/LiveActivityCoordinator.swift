//
//  LiveActivityCoordinator.swift
//  spaceTracker
//
//  Created by Claude on 9/9/26.
//
//  Bridges the app's already-fetched launch/pass data (the same arrays NotificationManager
//  gets, from ContentView's existing refresh pipeline -- no separate fetch of its own) into
//  the widget extension:
//    1. Publishes a "what's next" snapshot into the shared App Group container for the plain
//       Home/Lock Screen widget (FEAT-04), and nudges WidgetKit to reload it.
//    2. Starts/updates/ends a Live Activity when a launch or pass enters its final window
//       (FEAT-05).
//
//  Honest limitation, worth knowing up front: there's no push server behind this, so a
//  Live Activity can only start, update its phase, or end while the app itself actually runs
//  this sync (foreground refresh, or a background refresh if one fires). The countdown
//  number inside an already-running Activity keeps ticking live on-device regardless --
//  that's SwiftUI's Text(timerInterval:) rendering locally, not something this code drives --
//  but a phase flip (e.g. COUNTDOWN -> LIFTOFF the moment T-0 passes) only updates the next
//  time the app happens to run this. Good enough for a hobbyist app; a real push-based setup
//  would need a server component this app doesn't have.

import Foundation
import ActivityKit
import WidgetKit

@MainActor
final class LiveActivityCoordinator {
    static let shared = LiveActivityCoordinator()
    private init() {}

    // Deliberately tighter than SpaceLaunch.isWebcastLiveRightNow's -30min/+2h window
    // elsewhere in the app -- that one is "is there a stream worth linking," this one is
    // "does this deserve the Lock Screen / Dynamic Island right now."
    private let launchActivityLeadSeconds: TimeInterval = 15 * 60   // starts at T-15:00
    private let launchActivityTrailSeconds: TimeInterval = 5 * 60   // ends 5 min after T-0
    private let passActivityLeadSeconds: TimeInterval = 2 * 60      // starts 2 min before AOS

    func sync(launches: [SpaceLaunch], satellites: [SatellitePass]) {
        let now = Date()
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let isoFormatterNoFraction = ISO8601DateFormatter()
        func parseISO(_ string: String) -> Date? {
            isoFormatter.date(from: string) ?? isoFormatterNoFraction.date(from: string)
        }

        let nextLaunch: (SpaceLaunch, Date)? = launches
            .compactMap { launch -> (SpaceLaunch, Date)? in
                guard let net = launch.net, let date = parseISO(net) else { return nil }
                return (launch, date)
            }
            .filter { $0.1 > now }
            .min { $0.1 < $1.1 }

        let nextPass: (SatellitePass, Date)? = satellites
            .compactMap { sat -> (SatellitePass, Date)? in
                guard let date = parseISO(sat.utcTimeISO) else { return nil }
                return (sat, date)
            }
            .filter { $0.1 > now }
            .min { $0.1 < $1.1 }

        publishWidgetSnapshot(nextLaunch: nextLaunch, nextPass: nextPass)

        Task {
            await syncLiveActivity(nextLaunch: nextLaunch, nextPass: nextPass, now: now)
        }
    }

    // MARK: - Widget snapshot (FEAT-04)

    private func publishWidgetSnapshot(nextLaunch: (SpaceLaunch, Date)?, nextPass: (SatellitePass, Date)?) {
        // Note: written as if-let chains rather than switching on (nextLaunch, nextPass) --
        // each is Optional<(Model, Date)>, so a `.some(launch, launchDate)` pattern there
        // reads as ".some" taking two associated values instead of one tuple value, which
        // doesn't compile ("Enum case 'some' has one associated value that is a tuple of 2
        // elements"). This reads the same and avoids that pitfall entirely.
        let candidateEvent: UpcomingSpaceEvent?
        if let (launch, launchDate) = nextLaunch, let (pass, passDate) = nextPass {
            candidateEvent = launchDate <= passDate
                ? makeEvent(fromLaunch: launch, date: launchDate)
                : makeEvent(fromPass: pass, date: passDate)
        } else if let (launch, launchDate) = nextLaunch {
            candidateEvent = makeEvent(fromLaunch: launch, date: launchDate)
        } else if let (pass, passDate) = nextPass {
            candidateEvent = makeEvent(fromPass: pass, date: passDate)
        } else {
            candidateEvent = nil
        }

        guard candidateEvent != SharedSpaceStore.loadNextEvent() else { return }
        SharedSpaceStore.publish(candidateEvent)
        WidgetCenter.shared.reloadTimelines(ofKind: "spaceTrackerWidgets")
    }

    private func makeEvent(fromLaunch launch: SpaceLaunch, date: Date) -> UpcomingSpaceEvent {
        UpcomingSpaceEvent(
            kind: .launch,
            title: launch.name,
            subtitle: launch.launch_service_provider?.name ?? "UPCOMING LAUNCH",
            date: date,
            identifier: "launch-\(launch.id)"
        )
    }

    private func makeEvent(fromPass pass: SatellitePass, date: Date) -> UpcomingSpaceEvent {
        UpcomingSpaceEvent(
            kind: .satellitePass,
            title: pass.name,
            subtitle: "VISIBLE PASS · LOOK \(pass.travelDirection.uppercased())",
            date: date,
            identifier: "pass-\(pass.id_swiftui)"
        )
    }

    // MARK: - Live Activity (FEAT-05)

    private func syncLiveActivity(nextLaunch: (SpaceLaunch, Date)?, nextPass: (SatellitePass, Date)?, now: Date) async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        if let (launch, launchDate) = nextLaunch {
            let windowStart = launchDate.addingTimeInterval(-launchActivityLeadSeconds)
            let windowEnd = launchDate.addingTimeInterval(launchActivityTrailSeconds)
            if now >= windowStart && now <= windowEnd {
                let phase = now < launchDate ? "COUNTDOWN" : "LIFTOFF"
                await startOrUpdateActivity(
                    title: launch.name,
                    subtitle: launch.launch_service_provider?.name ?? "LAUNCH",
                    kindLabel: "LAUNCH",
                    targetDate: launchDate,
                    phaseLabel: phase,
                    staleDate: windowEnd
                )
                return
            }
        }

        if let (pass, passDate) = nextPass {
            let passEnd = passDate.addingTimeInterval(Double(pass.durationMinutes) * 60)
            let windowStart = passDate.addingTimeInterval(-passActivityLeadSeconds)
            if now >= windowStart && now <= passEnd {
                let phase = now < passDate ? "INCOMING" : "OVERHEAD"
                await startOrUpdateActivity(
                    title: pass.name,
                    subtitle: "LOOK \(pass.travelDirection.uppercased())",
                    kindLabel: "PASS",
                    targetDate: now < passDate ? passDate : passEnd,
                    phaseLabel: phase,
                    staleDate: passEnd
                )
                return
            }
        }

        // Neither a launch nor a pass is currently inside its window -- end anything left running.
        for activity in Activity<SpaceTrackerLiveActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }

    private func startOrUpdateActivity(title: String, subtitle: String, kindLabel: String, targetDate: Date, phaseLabel: String, staleDate: Date) async {
        let state = SpaceTrackerLiveActivityAttributes.ContentState(phaseLabel: phaseLabel, targetDate: targetDate)
        let content = ActivityContent(state: state, staleDate: staleDate)

        // Already tracking this exact event? Just refresh its phase/target (e.g. COUNTDOWN
        // flipping to LIFTOFF between sync calls) rather than restarting the Activity.
        if let existing = Activity<SpaceTrackerLiveActivityAttributes>.activities.first(where: { $0.attributes.eventTitle == title }) {
            await existing.update(content)
            return
        }

        // Tracking a different event (e.g. a launch activity still up when a pass starts) --
        // only one gets the Lock Screen / Dynamic Island at a time, so end the old one first.
        for activity in Activity<SpaceTrackerLiveActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }

        let attributes = SpaceTrackerLiveActivityAttributes(
            eventTitle: title,
            eventSubtitle: subtitle,
            kindLabel: kindLabel,
            eventDate: targetDate
        )

        do {
            _ = try Activity<SpaceTrackerLiveActivityAttributes>.request(attributes: attributes, content: content, pushType: nil)
        } catch {
            print("❌ [LIVE ACTIVITY]: Failed to start for \(title): \(error.localizedDescription)")
        }
    }
}
