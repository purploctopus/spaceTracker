//
//  AppIntents.swift
//  spaceTracker
//
//  FEAT-26: Siri voice queries via App Intents.
//
//  Every type in this file is gated behind @available(iOS 27.0, *). The app's deployment
//  target stays at 26.5 (see project.pbxproj) -- on iOS 26.5-26.x these Siri entry points
//  are simply absent from the compiled binary's registration, not merely hidden, and every
//  other feature builds and runs exactly as before. Only on iOS 27+ do the entities,
//  intents, and shortcut phrases below register with the system.
//
//  Data mirrors the same three sources the rest of the app already uses (see the
//  @StateObject list at the top of ContentView.swift's root view):
//    - LaunchViewModel.launches          ([SpaceLaunch], Launch.swift)
//    - SatelliteViewModel.visiblePasses  ([SatellitePass], SatelliteEngine.swift)
//    - SpaceRocksViewModel.asteroids     ([Asteroid], AsteroidEngine.swift)
//
//  Those view models are @MainActor ObservableObjects built to drive the SwiftUI view
//  tree -- SatelliteViewModel in particular runs its own CLLocationManager delegate flow
//  with permission prompts, a 4-second GPS timeout, and reverse-geocoding, none of which
//  is a good fit for a headless Siri intent that needs an answer quickly and may run
//  without the app's UI ever appearing. So the entity queries below talk to the same
//  three Cloudflare/GitHub endpoints directly over URLSession, decoding with the exact
//  same Codable models (LaunchResponse, SatelliteResponse, CloudflareAsteroidResponse)
//  the view models already use. For satellite passes -- the one data source that needs a
//  location -- they reuse the same UserDefaults cache SatelliteViewModel already writes
//  on every normal app launch ("cached_latitude" / "cached_longitude"), falling back to
//  the same Madison, WI coordinate ContentView.swift's own refreshStargazerTelemetry()
//  falls back to when no fix has ever been cached.

import Foundation
import AppIntents

// MARK: - Shared location fallback (mirrors ContentView.refreshStargazerTelemetry)

@available(iOS 27.0, *)
private nonisolated enum SiriLocationCache {
    static func currentCoordinateStrings() -> (lat: String, lng: String) {
        let defaults = UserDefaults.standard
        if let lat = defaults.string(forKey: "cached_latitude"), !lat.isEmpty,
           let lng = defaults.string(forKey: "cached_longitude"), !lng.isEmpty {
            return (lat, lng)
        }
        return ("43.0731", "-89.4012")
    }
}

// MARK: - LaunchEntity

@available(iOS 27.0, *)
struct LaunchEntity: AppEntity {
    let id: String
    let name: String
    let providerName: String?
    let localTimeDisplay: String
    let missionDescription: String?

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Launch"
    static var defaultQuery = LaunchEntityQuery()

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(name)",
            subtitle: "\(providerName ?? "Unknown provider") \u{00B7} \(localTimeDisplay)"
        )
    }
}

@available(iOS 27.0, *)
struct LaunchEntityQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [LaunchEntity] {
        let all = try await Self.fetchUpcomingLaunches()
        return all.filter { identifiers.contains($0.id) }
    }

    func suggestedEntities() async throws -> [LaunchEntity] {
        try await Self.fetchUpcomingLaunches()
    }

    // Same endpoint LaunchViewModel.fetchLaunches() uses, cache-busted the same way.
    static func fetchUpcomingLaunches() async throws -> [LaunchEntity] {
        let timestamp = Int(Date().timeIntervalSince1970)
        guard let url = URL(string: "https://purploctopus.github.io/launches.json?cb=\(timestamp)") else {
            return []
        }
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        let (data, _) = try await URLSession.shared.data(for: request)
        let decoded = try JSONDecoder().decode(LaunchResponse.self, from: data)
        return decoded.results.map { launch in
            LaunchEntity(
                id: launch.id,
                name: launch.name,
                providerName: launch.launch_service_provider?.name,
                localTimeDisplay: launch.localLaunchTimeDisplay,
                missionDescription: launch.mission?.description
            )
        }
    }
}

// MARK: - SatellitePassEntity

@available(iOS 27.0, *)
struct SatellitePassEntity: AppEntity {
    let id: String
    let name: String
    let localTimeDisplay: String
    let peakElevationDegrees: Double
    let durationMinutes: Int
    let travelDirection: String

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Satellite Pass"
    static var defaultQuery = SatellitePassEntityQuery()

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(name)",
            subtitle: "\(localTimeDisplay) \u{00B7} peak \(Int(peakElevationDegrees.rounded()))\u{00B0}"
        )
    }
}

@available(iOS 27.0, *)
struct SatellitePassEntityQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [SatellitePassEntity] {
        let all = try await Self.fetchUpcomingPasses()
        return all.filter { identifiers.contains($0.id) }
    }

    func suggestedEntities() async throws -> [SatellitePassEntity] {
        try await Self.fetchUpcomingPasses()
    }

    // Same worker + "days=2" window SatelliteViewModel.fetchPasses(latitude:longitude:) uses;
    // lat/lng come from the cache described at the top of this file rather than a fresh
    // CoreLocation request, since a Siri intent needs an answer without a permission prompt.
    static func fetchUpcomingPasses() async throws -> [SatellitePassEntity] {
        let (lat, lng) = SiriLocationCache.currentCoordinateStrings()
        var components = URLComponents(string: "https://sat-tracker.purploctopus.workers.dev")
        components?.queryItems = [
            URLQueryItem(name: "lat", value: lat),
            URLQueryItem(name: "lng", value: lng),
            URLQueryItem(name: "days", value: "2")
        ]
        guard let url = components?.url else { return [] }
        let (data, _) = try await URLSession.shared.data(from: url)
        let decoded = try JSONDecoder().decode(SatelliteResponse.self, from: data)
        return decoded.passes
            .sorted { $0.utcTimeISO < $1.utcTimeISO }
            .map { pass in
                SatellitePassEntity(
                    id: pass.id_swiftui,
                    name: pass.name,
                    localTimeDisplay: pass.localDisplayTime,
                    peakElevationDegrees: pass.peakElevationDegrees,
                    durationMinutes: pass.durationMinutes,
                    travelDirection: pass.travelDirection
                )
            }
    }
}

// MARK: - AsteroidEntity

@available(iOS 27.0, *)
struct AsteroidEntity: AppEntity {
    let id: String
    let name: String
    let localDateDisplay: String
    let missDistanceLunar: Int
    let maxDiameterMeters: Int
    let isPotentiallyHazardous: Bool
    let isVisibleToNakedEye: Bool

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Asteroid"
    static var defaultQuery = AsteroidEntityQuery()

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(name)",
            subtitle: "Closest approach \(localDateDisplay) \u{00B7} \(missDistanceLunar) LD"
        )
    }
}

@available(iOS 27.0, *)
struct AsteroidEntityQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [AsteroidEntity] {
        let all = try await Self.fetchTrackedAsteroids()
        return all.filter { identifiers.contains($0.id) }
    }

    func suggestedEntities() async throws -> [AsteroidEntity] {
        try await Self.fetchTrackedAsteroids()
    }

    // Same endpoint SpaceRocksViewModel.fetchAsteroidRadar() uses.
    static func fetchTrackedAsteroids() async throws -> [AsteroidEntity] {
        guard let url = URL(string: "https://space-rocks-worker.purploctopus.workers.dev") else {
            return []
        }
        let (data, _) = try await URLSession.shared.data(from: url)
        let decoded = try JSONDecoder().decode(CloudflareAsteroidResponse.self, from: data)
        return decoded.asteroids.map { asteroid in
            AsteroidEntity(
                id: asteroid.id,
                name: asteroid.name,
                localDateDisplay: asteroid.localDateDisplay,
                missDistanceLunar: asteroid.missDistanceLunar,
                maxDiameterMeters: asteroid.maxDiameterMeters,
                isPotentiallyHazardous: asteroid.is_potentially_hazardous_asteroid,
                isVisibleToNakedEye: asteroid.isAstroVisibleToNakedEye
            )
        }
    }
}

// MARK: - "When's the next pass?" intent

@available(iOS 27.0, *)
struct NextSatellitePassIntent: AppIntent {
    static var title: LocalizedStringResource = "Next Satellite Pass"
    static var description = IntentDescription(
        "Find out when a tracked satellite -- the ISS, for example -- is next visible overhead."
    )

    @Parameter(title: "Satellite")
    var satellite: SatellitePassEntity?

    static var parameterSummary: some ParameterSummary {
        Summary("When\u{2019}s the next pass for \(\.$satellite)")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let passes = try await SatellitePassEntityQuery.fetchUpcomingPasses()

        let match: SatellitePassEntity?
        if let satellite {
            match = passes.first { $0.id == satellite.id } ?? passes.first { $0.name == satellite.name }
        } else {
            match = passes.first
        }

        guard let pass = match else {
            return .result(dialog: "I couldn\u{2019}t find any upcoming passes right now -- check back after dark.")
        }

        let dialogText = "\(pass.name) is next visible \(pass.localTimeDisplay), reaching \(Int(pass.peakElevationDegrees.rounded()))\u{00B0} above the horizon."
        return .result(dialog: "\(dialogText)")
    }
}

// MARK: - "What's worth watching tonight?" intent

@available(iOS 27.0, *)
struct TonightsHighlightsIntent: AppIntent {
    static var title: LocalizedStringResource = "Tonight\u{2019}s Sky Highlights"
    static var description = IntentDescription(
        "Get a quick rundown of the next launch, the next satellite pass, and any notable asteroid close approach."
    )

    func perform() async throws -> some IntentResult & ProvidesDialog {
        async let launchesResult: [LaunchEntity]? = try? LaunchEntityQuery.fetchUpcomingLaunches()
        async let passesResult: [SatellitePassEntity]? = try? SatellitePassEntityQuery.fetchUpcomingPasses()
        async let asteroidsResult: [AsteroidEntity]? = try? AsteroidEntityQuery.fetchTrackedAsteroids()

        let nextLaunch = await launchesResult?.first
        let nextPass = await passesResult?.first
        let notableAsteroid = await asteroidsResult?.first { $0.isVisibleToNakedEye }

        var lines: [String] = []
        if let nextLaunch {
            lines.append("Next launch: \(nextLaunch.name), \(nextLaunch.localTimeDisplay.lowercased()).")
        }
        if let nextPass {
            lines.append("Next satellite pass: \(nextPass.name), \(nextPass.localTimeDisplay).")
        }
        if let notableAsteroid {
            lines.append("Worth a look: \(notableAsteroid.name), a naked-eye-visible close approach on \(notableAsteroid.localDateDisplay).")
        }

        guard !lines.isEmpty else {
            return .result(dialog: "I couldn\u{2019}t reach OrbitLog\u{2019}s tracking data right now -- try again in a bit.")
        }

        let dialogText = lines.joined(separator: " ")
        return .result(dialog: "\(dialogText)")
    }
}

// MARK: - Siri phrase discoverability

@available(iOS 27.0, *)
struct OrbitLogShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: NextSatellitePassIntent(),
            phrases: [
                "When\u{2019}s the next pass in \(.applicationName)",
                "Ask \(.applicationName) for the next satellite pass",
                "When can I see the \(\.$satellite) in \(.applicationName)"
            ],
            shortTitle: "Next Pass",
            systemImageName: "antenna.radiowaves.left.and.right"
        )
        AppShortcut(
            intent: TonightsHighlightsIntent(),
            phrases: [
                "What\u{2019}s worth watching tonight in \(.applicationName)",
                "Ask \(.applicationName) what\u{2019}s worth watching tonight",
                "Tonight\u{2019}s sky highlights in \(.applicationName)"
            ],
            shortTitle: "Tonight\u{2019}s Highlights",
            systemImageName: "sparkles"
        )
    }
}
