//
//  NotificationManager.swift
//  spaceTracker
//
//  Created by Ben Clary on 6/25/26.
//  make an app colin loves

import Foundation
import UserNotifications
import Combine

class NotificationManager: ObservableObject {
    @Published var isAuthorized = false

    // MARK: - Per-type toggles & lead times
    // @Published + didSet keeps these in sync with UserDefaults with no separate save step.
    // FEAT-02's settings screen binds its toggles/steppers directly to these properties.
    @Published var launchAlertsEnabled: Bool {
        didSet { UserDefaults.standard.set(launchAlertsEnabled, forKey: Keys.launchAlertsEnabled) }
    }
    @Published var passAlertsEnabled: Bool {
        didSet { UserDefaults.standard.set(passAlertsEnabled, forKey: Keys.passAlertsEnabled) }
    }
    @Published var meteorAlertsEnabled: Bool {
        didSet { UserDefaults.standard.set(meteorAlertsEnabled, forKey: Keys.meteorAlertsEnabled) }
    }
    @Published var dailyBriefingEnabled: Bool {
        didSet { UserDefaults.standard.set(dailyBriefingEnabled, forKey: Keys.dailyBriefingEnabled) }
    }
    @Published var launchLeadMinutes: Int {
        didSet { UserDefaults.standard.set(launchLeadMinutes, forKey: Keys.launchLeadMinutes) }
    }
    @Published var passLeadMinutes: Int {
        didSet { UserDefaults.standard.set(passLeadMinutes, forKey: Keys.passLeadMinutes) }
    }

    // MARK: - Quiet hours
    // Best practice for local alerts: don't wake someone up for a launch or pass at 3 AM.
    // When enabled, any per-event alert whose fire time falls inside this window is simply
    // not scheduled (skipped, not delayed -- a "look up now" alert that fires hours late is
    // useless). The daily 8 AM briefing is unaffected; it never fires overnight anyway.
    @Published var quietHoursEnabled: Bool {
        didSet { UserDefaults.standard.set(quietHoursEnabled, forKey: Keys.quietHoursEnabled) }
    }
    @Published var quietHoursStartHour: Int {
        didSet { UserDefaults.standard.set(quietHoursStartHour, forKey: Keys.quietHoursStartHour) }
    }
    @Published var quietHoursEndHour: Int {
        didSet { UserDefaults.standard.set(quietHoursEndHour, forKey: Keys.quietHoursEndHour) }
    }

    private enum Keys {
        static let launchAlertsEnabled = "notif_launchAlertsEnabled"
        static let passAlertsEnabled = "notif_passAlertsEnabled"
        static let meteorAlertsEnabled = "notif_meteorAlertsEnabled"
        static let dailyBriefingEnabled = "notif_dailyBriefingEnabled"
        static let launchLeadMinutes = "notif_launchLeadMinutes"
        static let passLeadMinutes = "notif_passLeadMinutes"
        static let quietHoursEnabled = "notif_quietHoursEnabled"
        static let quietHoursStartHour = "notif_quietHoursStartHour"
        static let quietHoursEndHour = "notif_quietHoursEndHour"
    }

    // iOS caps an app at 64 pending local notifications system-wide, shared across every
    // category below plus the daily briefing. These per-run limits keep total scheduling
    // well under that ceiling even on a day with a busy launch manifest and pass list.
    private let maxLaunchAlerts = 12
    private let maxPassAlerts = 15
    private let maxMeteorAlerts = 10

    private static let identifierPrefixes = ["launch-", "pass-", "meteor-"]

    init() {
        let defaults = UserDefaults.standard
        self.launchAlertsEnabled = defaults.object(forKey: Keys.launchAlertsEnabled) as? Bool ?? true
        self.passAlertsEnabled = defaults.object(forKey: Keys.passAlertsEnabled) as? Bool ?? true
        self.meteorAlertsEnabled = defaults.object(forKey: Keys.meteorAlertsEnabled) as? Bool ?? true
        self.dailyBriefingEnabled = defaults.object(forKey: Keys.dailyBriefingEnabled) as? Bool ?? true
        self.launchLeadMinutes = defaults.object(forKey: Keys.launchLeadMinutes) as? Int ?? 15
        self.passLeadMinutes = defaults.object(forKey: Keys.passLeadMinutes) as? Int ?? 5
        // Default window: 10 PM-8 AM local time, on by default so new installs don't get
        // buzzed overnight without asking; easy to switch off entirely in Settings.
        self.quietHoursEnabled = defaults.object(forKey: Keys.quietHoursEnabled) as? Bool ?? true
        self.quietHoursStartHour = defaults.object(forKey: Keys.quietHoursStartHour) as? Int ?? 22
        self.quietHoursEndHour = defaults.object(forKey: Keys.quietHoursEndHour) as? Int ?? 8
    }

    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { success, error in
            DispatchQueue.main.async {
                self.isAuthorized = success
                if success {
                    print("✅ [NOTIFICATIONS]: System permission authorized by user.")
                } else {
                    print("❌ [NOTIFICATIONS]: System permission explicitly denied.")
                }
            }
        }
    }

    /// Re-checks the current system permission without prompting -- unlike
    /// requestPermission(), this never shows the native dialog, so it's safe to call every
    /// time SettingsView appears (e.g. after the user backgrounds the app to flip the
    /// switch in iOS Settings and comes back) without risking a surprise re-prompt.
    func refreshAuthorizationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.isAuthorized = settings.authorizationStatus == .authorized
            }
        }
    }

    func scheduleDailyBriefing(launches: [SpaceLaunch], satellites: [SatellitePass], meteorShowers: [MeteorShower]) {
        // 💡 FIX: this used to call removeAllPendingNotificationRequests(), which also wiped
        // every per-event alert scheduleEventAlerts() had just scheduled below, every single
        // time this ran. Now it only clears its own identifier.
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["daily-space-briefing"])
        guard dailyBriefingEnabled else { return }

        let content = UNMutableNotificationContent()
        content.title = "🚀 DAILY ORBITAL BRIEFING"
        content.sound = .default

        var bodyLines: [String] = []

        // 1. Filter Rocket Flights launching TODAY
        let todayLaunches = launches.filter { launch in
            guard let netString = launch.net else { return false }
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            guard let date = formatter.date(from: netString) else { return false }
            return Calendar.current.isDateInToday(date)
        }

        if !todayLaunches.isEmpty {
            bodyLines.append("• LAUNCHES: \(todayLaunches.count) FLIGHT(S) ACTIVE FOR PAD IGNITION.")
        } else {
            bodyLines.append("• LAUNCHES: NO PAD IGNITIONS SCHEDULED.")
        }

        // 2. Filter Satellite Passes overhead TODAY
        let todaySats = satellites.filter { sat in
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            guard let date = formatter.date(from: sat.utcTimeISO) else { return false }
            return Calendar.current.isDateInToday(date)
        }

        if !todaySats.isEmpty {
            bodyLines.append("• SATELLITES: \(todaySats.count) VISUAL TARGETS PASSING OVERHEAD.")
        } else {
            bodyLines.append("• SATELLITES: SKY TRACKS AREA CLEAR.")
        }

        // 3. Filter Meteor Shower Peaks occurring TODAY
        let todayShowers = meteorShowers.filter { shower in
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            guard let date = formatter.date(from: shower.peakDateStr) else { return false }
            return Calendar.current.isDateInToday(date)
        }

        if let showerToday = todayShowers.first {
            bodyLines.append("• METEORS: \(showerToday.name.uppercased()) STREAMS PEAK TONIGHT!")
        }

        content.body = bodyLines.joined(separator: "\n")

        // Clock Trigger: Configured to fire every single morning at 08:00 AM local device time
        var dateComponents = DateComponents()
        dateComponents.hour = 8
        dateComponents.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: "daily-space-briefing", content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ [NOTIFICATIONS]: Registration rejected: \(error.localizedDescription)")
            } else {
                print("✅ [NOTIFICATIONS]: Daily operations briefing locked for 08:00 AM local time.")
            }
        }
    }

    /// Schedules real per-event alerts — a launch about to go, a satellite pass about to
    /// start, a meteor shower peaking tonight — on top of the single daily digest above.
    /// Safe to call repeatedly as fresh data comes in: it clears its own previously-scheduled
    /// alerts first, so schedule slips and newly-added passes are picked up rather than piling
    /// up stale duplicates.
    func scheduleEventAlerts(launches: [SpaceLaunch], satellites: [SatellitePass], meteorShowers: [MeteorShower]) {
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { [weak self] pending in
            guard let self else { return }
            let staleIdentifiers = pending
                .map { $0.identifier }
                .filter { identifier in Self.identifierPrefixes.contains { identifier.hasPrefix($0) } }
            if !staleIdentifiers.isEmpty {
                center.removePendingNotificationRequests(withIdentifiers: staleIdentifiers)
            }

            let now = Date()
            let isoFormatter = ISO8601DateFormatter()
            isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let isoFormatterNoFraction = ISO8601DateFormatter()

            func parseISO(_ string: String) -> Date? {
                isoFormatter.date(from: string) ?? isoFormatterNoFraction.date(from: string)
            }

            // FEAT-06: once at least one provider is starred, scope launch alerts to just
            // those providers instead of every launch in the manifest. Empty favorites means
            // no one's opted in yet, so behavior is unchanged -- everything still alerts.
            let favoriteProviders = FavoritesStore.shared.favoriteProviders

            if self.launchAlertsEnabled {
                let upcoming = launches
                    .filter { launch in
                        guard !favoriteProviders.isEmpty else { return true }
                        guard let providerName = launch.launch_service_provider?.name else { return false }
                        return favoriteProviders.contains(providerName)
                    }
                    .compactMap { launch -> (SpaceLaunch, Date)? in
                        guard let netString = launch.net, let date = parseISO(netString) else { return nil }
                        return (launch, date)
                    }
                    .filter { $0.1.timeIntervalSince(now) > Double(self.launchLeadMinutes * 60) }
                    .sorted { $0.1 < $1.1 }
                    .prefix(self.maxLaunchAlerts)

                for (launch, netDate) in upcoming {
                    let fireDate = netDate.addingTimeInterval(-Double(self.launchLeadMinutes * 60))
                    guard !self.isWithinQuietHours(fireDate) else { continue }
                    let content = UNMutableNotificationContent()
                    content.title = "🚀 LAUNCH ALERT"
                    content.body = "\(launch.name) lifts off in \(self.launchLeadMinutes) minutes."
                    content.sound = .default
                    self.scheduleOneTime(identifier: "launch-\(launch.id)", content: content, fireDate: fireDate, center: center)
                }
            }

            // Same opt-in scoping for satellite passes, keyed on the satellite's stable id.
            // FEAT-25 follow-up (2026-09-15): the worker's whitelist is gone now, so
            // "satellites" here can be 100+ objects on a clear night instead of ~9. Favoriting
            // still scopes alerts to exactly what's favorited like before -- but the *default*,
            // before anyone's favorited anything, now falls back to just the originally curated
            // set (isOriginalCuratedTarget) instead of literally everything, so a user who's
            // never touched the favorites screen doesn't suddenly get flooded with alerts for
            // satellites they don't recognize.
            let favoriteSatellites = FavoritesStore.shared.favoriteSatellites

            if self.passAlertsEnabled {
                let upcoming = satellites
                    .filter { sat in
                        favoriteSatellites.isEmpty ? sat.isOriginalCuratedTarget : favoriteSatellites.contains(sat.id)
                    }
                    .compactMap { sat -> (SatellitePass, Date)? in
                        guard let date = parseISO(sat.utcTimeISO) else { return nil }
                        return (sat, date)
                    }
                    .filter { $0.1.timeIntervalSince(now) > Double(self.passLeadMinutes * 60) }
                    .sorted { $0.1 < $1.1 }
                    .prefix(self.maxPassAlerts)

                for (sat, passDate) in upcoming {
                    let fireDate = passDate.addingTimeInterval(-Double(self.passLeadMinutes * 60))
                    guard !self.isWithinQuietHours(fireDate) else { continue }
                    let content = UNMutableNotificationContent()
                    content.title = "🛰️ PASS ALERT"
                    content.body = "\(sat.name) is overhead in \(self.passLeadMinutes) minutes — look \(sat.travelDirection)."
                    content.sound = .default
                    self.scheduleOneTime(identifier: "pass-\(sat.id_swiftui)", content: content, fireDate: fireDate, center: center)
                }
            }

            if self.meteorAlertsEnabled {
                let dayFormatter = DateFormatter()
                dayFormatter.dateFormat = "yyyy-MM-dd"

                let upcoming = meteorShowers
                    .compactMap { shower -> (MeteorShower, Date)? in
                        guard let date = dayFormatter.date(from: shower.peakDateStr) else { return nil }
                        return (shower, date)
                    }
                    .filter { $0.1 >= Calendar.current.startOfDay(for: now) }
                    .sorted { $0.1 < $1.1 }
                    .prefix(self.maxMeteorAlerts)

                for (shower, peakDate) in upcoming {
                    // Fire at 8 PM local time on the peak date — meteor showers are named for
                    // a calendar night, not a precise timestamp, so there's no exact moment to
                    // count down to the way a launch or pass has one.
                    var fireComponents = Calendar.current.dateComponents([.year, .month, .day], from: peakDate)
                    fireComponents.hour = 20
                    fireComponents.minute = 0
                    guard let fireDate = Calendar.current.date(from: fireComponents), fireDate > now else { continue }
                    guard !self.isWithinQuietHours(fireDate) else { continue }

                    let content = UNMutableNotificationContent()
                    content.title = "☄️ METEOR SHOWER PEAK"
                    content.body = "\(shower.name) peaks tonight — best viewing after dark, away from city lights."
                    content.sound = .default
                    self.scheduleOneTime(identifier: "meteor-\(shower.name)-\(shower.peakDateStr)", content: content, fireDate: fireDate, center: center)
                }
            }
        }
    }

    /// Whether `date`'s local hour-of-day falls inside the configured quiet-hours window.
    /// The window can wrap past midnight (e.g. 22 -> 8), so this compares hour-of-day rather
    /// than a simple date range comparison.
    private func isWithinQuietHours(_ date: Date) -> Bool {
        guard quietHoursEnabled else { return false }
        guard quietHoursStartHour != quietHoursEndHour else { return true }
        let hour = Calendar.current.component(.hour, from: date)
        if quietHoursStartHour < quietHoursEndHour {
            return hour >= quietHoursStartHour && hour < quietHoursEndHour
        } else {
            return hour >= quietHoursStartHour || hour < quietHoursEndHour
        }
    }

    private func scheduleOneTime(identifier: String, content: UNMutableNotificationContent, fireDate: Date, center: UNUserNotificationCenter) {
        let interval = fireDate.timeIntervalSinceNow
        guard interval > 0 else { return }
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        center.add(request) { error in
            if let error = error {
                print("❌ [NOTIFICATIONS]: \(identifier) rejected: \(error.localizedDescription)")
            }
        }
    }
}
