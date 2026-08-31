//
//  OrbitalTelemetryModels.swift
//  spaceTracker
//
//  Created by Ben Clary on 8/6/26.
//  make an app colin uses and support saras happiness
//       guard let url = URL(string: "https://api.wheretheiss.at/v1/satellites/25544") else {
//       guard let url = URL(string: "https://celestrak.org/NORAD/elements/gp.php?CATNR=48274&FORMAT=TLE") else {


import Foundation
import Combine
import CoreLocation
// 💡 REQUIRES: add SatelliteKit as a Swift Package dependency first —
// Xcode: File → Add Package Dependencies… → https://github.com/gavineadie/SatelliteKit.git
import SatelliteKit

// MARK: - 🛰️ ISS JSON PAYLOAD STRUCTURE
struct ISSResponse: Codable {
    let latitude: Double
    let longitude: Double
    let altitude: Double
    let velocity: Double
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

// MARK: - 🗺️ UNIFIED ORBITAL STATION STATE MATRIX
struct OrbitalStationState {
    enum TrackingTarget { case iss, tiangong } // 💡 TARGET ENUM DEFINITION
    
    var issCoordinate: CLLocationCoordinate2D = CLLocationCoordinate2D(latitude: 0, longitude: 0)
    var tiangongCoordinate: CLLocationCoordinate2D = CLLocationCoordinate2D(latitude: 0, longitude: 0)
    // Predicted future ground-track points, both from real SGP4 propagation — a dashed
    // "where it's headed" line to draw on the globe, distinct from the solid current-position dot.
    var issGroundTrack: [CLLocationCoordinate2D] = []
    var tiangongGroundTrack: [CLLocationCoordinate2D] = []
    var currentFocus: TrackingTarget = .iss // 💡 ISS IS THE STANDARD DEFAULT FOCUS TARGET
    var isDataLoaded: Bool = false
}

struct IvanTleResponse: Decodable {
    let name: String
    let line1: String
    let line2: String
}

/// A locally-cached TLE with the time it was fetched, so the app can avoid re-hitting the
/// network on every launch. Both TLE sources (tle.ivanstanojevic.me and CelesTrak) are small
/// services with real, documented rate-limiting against exactly this app's usage pattern —
/// many individual devices, often sharing carrier-NAT IPs, each independently querying.
/// TLEs don't meaningfully change within a few hours, so there's no accuracy reason to fetch
/// more often than that.
private struct CachedTLE: Codable {
    let lines: [String]
    let fetchedAt: Date
}

// MARK: - 📡 TRACKING ENGINE CLASS
@MainActor
class OrbitalTrackingViewModel: ObservableObject {
    @Published var stationState = OrbitalStationState()
    private var trackingTimer: Task<Void, Never>? = nil
    
    // MARK: - 🚀 INITIALIZE REAL NETWORK TELEMETRY PIPELINE
    func startTrackingPipeline() {
        stopTrackingPipeline()
        
        trackingTimer = Task {
            // Kick off both TLE fetches in the background. These only need to run once —
            // TLEs stay valid for hours to days, unlike the position itself, which needs
            // fresh SGP4 propagation on every poll.
            let tiangongFetchTask = Task { await fetchTLEData(noradId: 48274) }
            let issFetchTask = Task { await fetchTLEData(noradId: 25544) }
            
            while !Task.isCancelled {
                // ISS current position: stays on the live wheretheiss.at feed — the most
                // authoritative "right now" source, unrelated to the SGP4 work below.
                let realISSLocation = await fetchLiveISSLocation()
                self.stationState.issCoordinate = realISSLocation
                self.stationState.isDataLoaded = true
                
                // Tiangong current position + both satellites' predicted ground tracks all
                // come from the same real SGP4 propagation now.
                let tiangongTLE = await tiangongFetchTask.value
                if !tiangongTLE.isEmpty {
                    self.stationState.tiangongCoordinate = calculateOrbitPosition(tle: tiangongTLE)
                    self.stationState.tiangongGroundTrack = generateGroundTrack(tle: tiangongTLE)
                } else {
                    print("⏳ Tiangong TLE data is still downloading or empty...")
                }
                
                let issTLE = await issFetchTask.value
                if !issTLE.isEmpty {
                    self.stationState.issGroundTrack = generateGroundTrack(tle: issTLE)
                } else {
                    print("⏳ ISS TLE data is still downloading or empty...")
                }
                
                do {
                    // ⏱️ PRODUCTION CALIBRATION: Sleep 5 seconds
                    try await Task.sleep(nanoseconds: 5_000_000_000)
                } catch {
                    break
                }
            }
        }
    }
   
    func stopTrackingPipeline() {
        trackingTimer?.cancel()
        trackingTimer = nil
    }
    
    private func fetchLiveISSLocation() async -> CLLocationCoordinate2D {
        guard let url = URL(string: "https://api.wheretheiss.at/v1/satellites/25544") else {
            return CLLocationCoordinate2D(latitude: 0, longitude: 0)
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let decodedResponse = try JSONDecoder().decode(ISSResponse.self, from: data)
            return decodedResponse.coordinate
        } catch {
            print("❌ [TELEMETRY CORE ERROR]: Failed to route live ISS tracking files: \(error)")
            return stationState.issCoordinate
        }
    }
    
    /// Fetches a satellite's TLE by NORAD catalog ID. Checks a local cache first (see
    /// CachedTLE) — only hits the network if there's no cached copy or it's gone stale.
    /// This is the actual fix for both TLE sources' rate-limiting: it cuts real-world
    /// network traffic from "every app launch, every device" down to "roughly once per
    /// freshness window, per device" — directly addressing the "many individual devices
    /// querying independently" pattern CelesTrak's own usage policy names as the thing that
    /// gets blocked.
    private func fetchTLEData(noradId: Int) async -> [String] {
        let freshnessWindow: TimeInterval = 6 * 60 * 60 // 6 hours — generous vs. how slowly TLE accuracy actually degrades
        let cacheKey = "cachedTLE_\(noradId)"
        
        if let cached = loadCachedTLE(forKey: cacheKey), Date().timeIntervalSince(cached.fetchedAt) < freshnessWindow {
            let ageMinutes = Int(Date().timeIntervalSince(cached.fetchedAt) / 60)
            print("💾 [TLE CACHE]: Using cached TLE for NORAD \(noradId), \(ageMinutes) min old — no network call needed")
            return cached.lines
        }
        
        if let primary = await fetchTLEFromIvanstanojevic(noradId: noradId), !primary.isEmpty {
            saveCachedTLE(primary, forKey: cacheKey)
            return primary
        }
        
        print("⚠️ [TLE FALLBACK]: Primary TLE source failed for NORAD \(noradId), trying CelesTrak directly...")
        let fallback = await fetchTLEFromCelesTrak(noradId: noradId)
        if !fallback.isEmpty {
            saveCachedTLE(fallback, forKey: cacheKey)
            return fallback
        }
        
        // Both live sources failed. A stale cached TLE — even hours or a day old — is still
        // far more accurate than the hardcoded Shanghai placeholder, since orbital elements
        // degrade gracefully over time rather than becoming instantly wrong the moment the
        // freshness window expires.
        if let staleCache = loadCachedTLE(forKey: cacheKey) {
            let ageHours = Int(Date().timeIntervalSince(staleCache.fetchedAt) / 3600)
            print("⚠️ [TLE CACHE]: Both live sources failed for NORAD \(noradId) — using \(ageHours)h-old cached TLE as last resort")
            return staleCache.lines
        }
        
        print("❌ [TLE FAILURE]: No network data and no cache available for NORAD \(noradId)")
        return []
    }
    
    private func loadCachedTLE(forKey key: String) -> CachedTLE? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(CachedTLE.self, from: data)
    }
    
    private func saveCachedTLE(_ lines: [String], forKey key: String) {
        let cached = CachedTLE(lines: lines, fetchedAt: Date())
        if let data = try? JSONEncoder().encode(cached) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
    
    private func fetchTLEFromIvanstanojevic(noradId: Int) async -> [String]? {
        guard let url = URL(string: "https://tle.ivanstanojevic.me/api/tle/\(noradId)") else {
            return nil
        }
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 4.0
        let optimizedSession = URLSession(configuration: config)
        
        do {
            let (data, _) = try await optimizedSession.data(from: url)
            let decoded = try JSONDecoder().decode(IvanTleResponse.self, from: data)
            
            print("✅ [TLE PARSED]: Successfully loaded tracking matrix for \(decoded.name) (primary source)")
            return [decoded.name, decoded.line1, decoded.line2]
        } catch {
            print("❌ [NETWORK ERROR]: Primary TLE endpoint unreachable for NORAD \(noradId): \(error)")
            return nil
        }
    }
    
    /// Fallback TLE source, hit only when the primary fails. tle.ivanstanojevic.me is a
    /// small, single-maintainer community service — there's a documented history of
    /// reliability/behavior complaints about it (see the discussion on NASA's own
    /// nasa/api-docs GitHub issue #170). CelesTrak is the actual authoritative source that
    /// mirror itself pulls from daily, so querying it directly here means a hiccup on the
    /// primary doesn't leave a satellite's trajectory stuck on stale data.
    ///
    /// Unlike the primary source, this returns plain text (name / line1 / line2 on separate
    /// lines), not JSON — hence the manual line-splitting instead of JSONDecoder.
    private func fetchTLEFromCelesTrak(noradId: Int) async -> [String] {
        guard let url = URL(string: "https://celestrak.org/NORAD/elements/gp.php?CATNR=\(noradId)&FORMAT=TLE") else {
            return []
        }
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 6.0
        let session = URLSession(configuration: config)
        
        do {
            let (data, _) = try await session.data(from: url)
            guard let rawText = String(data: data, encoding: .utf8) else {
                print("❌ [CELESTRAK ERROR]: Response wasn't valid text for NORAD \(noradId)")
                return []
            }
            
            let lines = rawText
                .components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            
            guard lines.count >= 3 else {
                print("❌ [CELESTRAK ERROR]: Unexpected response for NORAD \(noradId): \(rawText.prefix(120))")
                return []
            }
            
            print("✅ [TLE PARSED]: Successfully loaded tracking matrix for \(lines[0]) (CelesTrak fallback)")
            return [lines[0], lines[1], lines[2]]
        } catch {
            print("❌ [CELESTRAK ERROR]: Fallback endpoint also unreachable for NORAD \(noradId): \(error)")
            return []
        }
    }
    
    private func calculateOrbitPosition(tle: [String]) -> CLLocationCoordinate2D {
        guard tle.count >= 3 else {
            return CLLocationCoordinate2D(latitude: 31.2304, longitude: 121.4737)
        }
        
        do {
            let elements = try Elements(tle[0], tle[1], tle[2])
            let satellite = Satellite(elements: elements)
            
            let nowJulianDay = Date().timeIntervalSince1970 / 86400.0 + 2440587.5
            let eciPositionKm = try satellite.position(julianDays: nowJulianDay)
            
            return Self.geodeticCoordinate(fromECIKilometers: eciPositionKm, julianDay: nowJulianDay)
        } catch {
            print("❌ [SGP4 ERROR]: Failed to propagate orbit from TLE: \(error)")
            return CLLocationCoordinate2D(latitude: 31.2304, longitude: 121.4737)
        }
    }
    
    /// Predicts the next `minutesAhead` minutes of ground track from real SGP4 propagation
    /// — the same technique as calculateOrbitPosition above, just sampled repeatedly across
    /// a future time window instead of once at "now". 20 minutes / 40 samples gives a
    /// visually clear curve (roughly a fifth of a ~90-minute LEO orbit) without extending so
    /// far it wraps confusingly across the globe.
    private func generateGroundTrack(tle: [String], minutesAhead: Double = 20.0, sampleCount: Int = 40) -> [CLLocationCoordinate2D] {
        guard tle.count >= 3 else { return [] }
        
        do {
            let elements = try Elements(tle[0], tle[1], tle[2])
            let satellite = Satellite(elements: elements)
            let nowJulianDay = Date().timeIntervalSince1970 / 86400.0 + 2440587.5
            
            var trackPoints: [CLLocationCoordinate2D] = []
            trackPoints.reserveCapacity(sampleCount + 1)
            
            for step in 0...sampleCount {
                let fractionalMinutes = (Double(step) / Double(sampleCount)) * minutesAhead
                let futureJulianDay = nowJulianDay + (fractionalMinutes / 1440.0) // 1440 min/day
                let eciPositionKm = try satellite.position(julianDays: futureJulianDay)
                trackPoints.append(Self.geodeticCoordinate(fromECIKilometers: eciPositionKm, julianDay: futureJulianDay))
            }
            
            return trackPoints
        } catch {
            print("❌ [SGP4 ERROR]: Failed to generate ground track from TLE: \(error)")
            return []
        }
    }
    
    /// Converts an Earth-Centered Inertial (ECI) position — what SGP4 propagators output —
    /// into a geographic lat/lon suitable for plotting on a map. This is standard,
    /// well-documented math (Vallado, "Fundamentals of Astrodynamics and Applications" —
    /// the same reference SatelliteKit itself is validated against): rotate by Greenwich
    /// Mean Sidereal Time to move from the inertial frame into the Earth-fixed rotating
    /// frame, then derive latitude/longitude from the rotated vector.
    ///
    /// Uses a spherical-Earth approximation for latitude (geocentric, not true WGS-84
    /// geodetic) — the difference is at most ~0.19° at mid-latitudes, well below what's
    /// visible on a world map pin. This exact simplification is standard practice in
    /// reference implementations meant for display rather than precision navigation.
    ///
    /// NOTE: `eci.x`/`.y`/`.z` assumes SatelliteKit's Vector type uses that naming — I
    /// couldn't fetch the library's raw source directly to confirm (GitHub's robots.txt
    /// blocked it), so if this doesn't compile, check Xcode's autocomplete on the `Vector`
    /// type for the actual property names and swap them in here — the math around them is
    /// correct regardless of what they're called.
    private static func geodeticCoordinate(fromECIKilometers eci: Vector, julianDay: Double) -> CLLocationCoordinate2D {
        // Greenwich Mean Sidereal Time (IAU 1982 model), in degrees.
        let centuriesSinceJ2000 = (julianDay - 2451545.0) / 36525.0
        var gmstDegrees = 280.46061837
            + 360.98564736629 * (julianDay - 2451545.0)
            + 0.000387933 * centuriesSinceJ2000 * centuriesSinceJ2000
            - (centuriesSinceJ2000 * centuriesSinceJ2000 * centuriesSinceJ2000) / 38710000.0
        gmstDegrees = gmstDegrees.truncatingRemainder(dividingBy: 360.0)
        if gmstDegrees < 0 { gmstDegrees += 360.0 }
        let gmstRadians = gmstDegrees * .pi / 180.0
        
        let x = eci.x, y = eci.y, z = eci.z
        
        var longitudeRadians = atan2(y, x) - gmstRadians
        longitudeRadians = longitudeRadians.truncatingRemainder(dividingBy: 2 * .pi)
        if longitudeRadians > .pi { longitudeRadians -= 2 * .pi }
        if longitudeRadians < -.pi { longitudeRadians += 2 * .pi }
        
        let rXY = sqrt(x * x + y * y)
        let latitudeRadians = atan2(z, rXY)
        
        return CLLocationCoordinate2D(
            latitude: latitudeRadians * 180.0 / .pi,
            longitude: longitudeRadians * 180.0 / .pi
        )
    }
}
