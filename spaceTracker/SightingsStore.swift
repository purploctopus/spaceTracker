//
//  SightingsStore.swift
//  spaceTracker
//
//  FEAT-32: personal sightings log + index. Stored locally (UserDefaults), no backend.
//  "I saw it" on a satellite pass, planet/Moon row, or meteor shower card (and "WATCHED" on
//  a launch card) adds a sighting; the index counts sightings per object, and a weekly
//  streak counts consecutive weeks with at least one sighting (weeks, not days, so a
//  cloudy night doesn't break it).

import Foundation
import Combine

enum SightingCategory: String, Codable {
    case planet, satellite, meteorShower, launch
}

struct Sighting: Codable, Identifiable {
    let id: UUID
    let category: SightingCategory
    /// The index entry this counts toward ("JUPITER", "ISS", "Perseids", a launch provider).
    let indexKey: String
    /// What was actually seen, for the log ("ISS (ZARYA)", a launch's mission name).
    let displayName: String
    /// One per real-world event, so the same pass/night/launch can't be logged twice.
    let eventKey: String
    let date: Date
}

/// One row in a dynamic index section (other satellites, launch companies).
struct SightingTally: Identifiable {
    let name: String
    let count: Int
    var id: String { name }
}

struct SatelliteIndexEntry {
    let name: String
    let fragments: [String]
}

final class SightingsStore: ObservableObject {
    /// Shared singleton, same pattern as FavoritesStore -- the cards that log sightings are
    /// built from several places with no environment-object plumbing.
    static let shared = SightingsStore()

    @Published private(set) var sightings: [Sighting] {
        didSet { save() }
    }

    private static let storageKey = "sightings_log_v1"

    // MARK: - Index lists (what there is to "collect")

    static let planetIndex = ["MOON", "MERCURY", "VENUS", "MARS", "JUPITER", "SATURN"]

    /// The well-known satellites to chase -- same name fragments as
    /// SatellitePass.originalCuratedNameFragments. Anything else logged goes under
    /// "other satellites spotted".
    static let satelliteIndex: [SatelliteIndexEntry] = [
        SatelliteIndexEntry(name: "ISS", fragments: ["ISS"]),
        SatelliteIndexEntry(name: "TIANGONG", fragments: ["TIANGONG", "TIANHE", "CSS"]),
        SatelliteIndexEntry(name: "SHENZHOU", fragments: ["SHENZHOU"]),
        SatelliteIndexEntry(name: "HUBBLE", fragments: ["HUBBLE"]),
        SatelliteIndexEntry(name: "STARLINK", fragments: ["STARLINK"]),
        SatelliteIndexEntry(name: "X-37B", fragments: ["X37-B", "X-37B"]),
        SatelliteIndexEntry(name: "ENVISAT", fragments: ["ENVISAT"]),
        SatelliteIndexEntry(name: "AQUA", fragments: ["AQUA"]),
        SatelliteIndexEntry(name: "TERRA", fragments: ["TERRA"])
    ]

    static var meteorShowerIndex: [String] {
        MeteorShowerViewModel.annualMasterDatabase.map { $0.name }
    }

    private init() {
        if let data = UserDefaults.standard.data(forKey: Self.storageKey),
           let decoded = try? JSONDecoder().decode([Sighting].self, from: data) {
            sightings = decoded
        } else {
            sightings = []
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(sightings) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }

    // MARK: - Logging

    func isLogged(eventKey: String) -> Bool {
        sightings.contains { $0.eventKey == eventKey }
    }

    /// Logs the sighting, or removes it if this exact event was already logged (undo).
    func toggle(category: SightingCategory, indexKey: String, displayName: String, eventKey: String) {
        if let existing = sightings.firstIndex(where: { $0.eventKey == eventKey }) {
            sightings.remove(at: existing)
        } else {
            sightings.append(Sighting(id: UUID(), category: category, indexKey: indexKey,
                                      displayName: displayName, eventKey: eventKey, date: Date()))
        }
    }

    func delete(_ sighting: Sighting) {
        sightings.removeAll { $0.id == sighting.id }
    }

    // MARK: - Counts

    func count(_ category: SightingCategory, _ indexKey: String) -> Int {
        sightings.filter { $0.category == category && $0.indexKey == indexKey }.count
    }

    var recentSightings: [Sighting] {
        sightings.sorted { $0.date > $1.date }
    }

    /// Satellites logged that aren't on the fixed index list.
    var otherSatellites: [SightingTally] {
        let fixed = Set(Self.satelliteIndex.map { $0.name })
        return grouped(sightings.filter { $0.category == .satellite && !fixed.contains($0.indexKey) })
    }

    var launchProviders: [SightingTally] {
        grouped(sightings.filter { $0.category == .launch })
    }

    private func grouped(_ items: [Sighting]) -> [SightingTally] {
        Dictionary(grouping: items, by: { $0.indexKey })
            .map { SightingTally(name: $0.key, count: $0.value.count) }
            .sorted { $0.count != $1.count ? $0.count > $1.count : $0.name < $1.name }
    }

    // MARK: - Weekly streak

    /// Consecutive weeks with at least one sighting. The current week only adds to the
    /// streak once something is logged in it, but doesn't break it until it's over.
    var weeklyStreak: Int {
        let calendar = Calendar.current
        let loggedWeeks = Set(sightings.compactMap { calendar.dateInterval(of: .weekOfYear, for: $0.date)?.start })
        guard var week = calendar.dateInterval(of: .weekOfYear, for: Date())?.start else { return 0 }
        if !loggedWeeks.contains(week) {
            guard let previous = calendar.date(byAdding: .weekOfYear, value: -1, to: week) else { return 0 }
            week = previous
        }
        var streak = 0
        while loggedWeeks.contains(week) {
            streak += 1
            guard let previous = calendar.date(byAdding: .weekOfYear, value: -1, to: week) else { break }
            week = previous
        }
        return streak
    }

    // MARK: - Shared helpers

    static func parseISO(_ string: String?) -> Date? {
        guard let string else { return nil }
        let withFraction = ISO8601DateFormatter()
        withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return withFraction.date(from: string) ?? ISO8601DateFormatter().date(from: string)
    }

    // MARK: Satellite passes -- loggable from the pass's start until 3 hours after it ends

    static func satelliteIndexKey(for satelliteName: String) -> String {
        let upper = satelliteName.uppercased()
        return satelliteIndex.first { entry in entry.fragments.contains { upper.contains($0) } }?.name ?? upper
    }

    static func passEventKey(_ pass: SatellitePass) -> String {
        "pass-\(pass.id_swiftui)"
    }

    static func canLogPass(_ pass: SatellitePass, now: Date = Date()) -> Bool {
        guard let start = pass.startDate, let end = pass.endDate else { return false }
        return now >= start && now <= end.addingTimeInterval(3 * 60 * 60)
    }

    func togglePass(_ pass: SatellitePass) {
        toggle(category: .satellite,
               indexKey: Self.satelliteIndexKey(for: pass.name),
               displayName: pass.name.uppercased(),
               eventKey: Self.passEventKey(pass))
    }

    // MARK: Planets & Moon -- one log per object per night (a night runs noon to noon)

    static func normalizedBodyName(_ name: String) -> String {
        name.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func planetEventKey(name: String, now: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let night = formatter.string(from: now.addingTimeInterval(-12 * 60 * 60))
        return "planet-\(normalizedBodyName(name))-\(night)"
    }

    func togglePlanet(name: String) {
        let key = Self.normalizedBodyName(name)
        toggle(category: .planet, indexKey: key, displayName: key, eventKey: Self.planetEventKey(name: name))
    }

    // MARK: Meteor showers -- loggable from 2 nights before the peak to 2 nights after

    /// Event key if `now` falls inside the shower's window, else nil. Uses only the peak's
    /// month/day, so it still works when the outlook has already rolled the card forward
    /// to next year's date.
    static func meteorEventKey(name: String, peakDateStr: String, now: Date = Date()) -> String? {
        let parts = peakDateStr.split(separator: "-")
        guard parts.count == 3, let month = Int(parts[1]), let day = Int(parts[2]) else { return nil }
        let calendar = Calendar.current
        let thisYear = calendar.component(.year, from: now)
        for year in [thisYear - 1, thisYear, thisYear + 1] {
            guard let peak = calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12)),
                  let start = calendar.date(byAdding: .day, value: -2, to: peak),
                  let end = calendar.date(byAdding: .day, value: 3, to: peak) else { continue }
            if now >= start && now <= end {
                return "meteor-\(name)-\(year)"
            }
        }
        return nil
    }

    // MARK: Launches -- loggable from liftoff until 48 hours after (how long cards stay up)

    static func canLogLaunch(net: String?, now: Date = Date()) -> Bool {
        guard let liftoff = parseISO(net) else { return false }
        return now >= liftoff && now <= liftoff.addingTimeInterval(48 * 60 * 60)
    }
}
