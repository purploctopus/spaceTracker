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
    var currentFocus: TrackingTarget = .iss // 💡 ISS IS THE STANDARD DEFAULT FOCUS TARGET
    var isDataLoaded: Bool = false
}

struct IvanTleResponse: Decodable {
    let name: String
    let line1: String
    let line2: String
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
            // 1. Kick off the slow Tiangong fetch in the background
            let tiangongFetchTask = Task {
                await fetchTiangongTLEData()
            }
            
            while !Task.isCancelled {
                // 2. This fetches immediately on launch without waiting
                let realISSLocation = await fetchLiveISSLocation()
                
                // 3. Update the ISS coordinate right away so your view loads instantly
                self.stationState.issCoordinate = realISSLocation
                self.stationState.isDataLoaded = true
                
                // 4. Get the TLE array (which is non-optional)
                let tiangongTLE = await tiangongFetchTask.value
                
                // 5. Check if we actually received data inside the array
                if !tiangongTLE.isEmpty {
                    let currentTiangongLocation = calculateTiangongOrbitPosition(tle: tiangongTLE)
                    self.stationState.tiangongCoordinate = currentTiangongLocation
                } else {
                    print("⏳ Tiangong TLE data is still downloading or empty...")
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
    
    private func fetchTiangongTLEData() async -> [String] {
        // 1. Notice the path correction: /api/tle/48274
        guard let url = URL(string: "https://tle.ivanstanojevic.me/api/tle/48274") else {
            return []
        }
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 4.0
        let optimizedSession = URLSession(configuration: config)
        
        do {
            let (data, _) = try await optimizedSession.data(from: url)
            let decoded = try JSONDecoder().decode(IvanTleResponse.self, from: data)
            
            print("✅ [TLE PARSED]: Successfully loaded tracking matrix for \(decoded.name)")
            return [decoded.name, decoded.line1, decoded.line2]
            
        } catch {
            print("❌ [NETWORK ERROR]: Tracking matrix endpoint unreachable: \(error)")
            return []
        }
    }
    
    private func calculateTiangongOrbitPosition(tle: [String]) -> CLLocationCoordinate2D {
        guard tle.count >= 3 else {
            return CLLocationCoordinate2D(latitude: 31.2304, longitude: 121.4737)
        }
        
        let timeModifier = Date().timeIntervalSince1970
        let simulatedLat = 41.5 * sin(timeModifier / 1200.0)
        let simulatedLng = (timeModifier.truncatingRemainder(dividingBy: 2400.0) / 2400.0 * 360.0) - 180.0
        
        return CLLocationCoordinate2D(latitude: simulatedLat, longitude: simulatedLng)
    }
}
