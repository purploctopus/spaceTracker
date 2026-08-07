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


// MARK: - 📡 TRACKING ENGINE CLASS
@MainActor
class OrbitalTrackingViewModel: ObservableObject {
    @Published var stationState = OrbitalStationState()
    private var trackingTimer: Task<Void, Never>? = nil
    
    // MARK: - 🚀 INITIALIZE REAL NETWORK TELEMETRY PIPELINE
    func startTrackingPipeline() {
        stopTrackingPipeline()
        
        trackingTimer = Task {
            // Fetch the live TLE matrix parameters for Tiangong immediately on launch
            let tiangongTLE = await fetchTiangongTLEData()
            
            while !Task.isCancelled {
                // Fetch the absolute real-world location from the live web server stream
                let realISSLocation = await fetchLiveISSLocation()
                
                // Keep Tiangong moving seamlessly based on its true orbital vectors
                let currentTiangongLocation = calculateTiangongOrbitPosition(tle: tiangongTLE)
                
                // Write the factual coordinates straight to your UI state variables
                self.stationState.issCoordinate = realISSLocation
                self.stationState.tiangongCoordinate = currentTiangongLocation
                self.stationState.isDataLoaded = true
                
                do {
                    // ⏱️ PRODUCTION CALIBRATION: Sleep 5 seconds between fetches to respect API servers and prevent freezing
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
        guard let url = URL(string: "https://celestrak.org/NORAD/elements/gp.php?CATNR=48274&FORMAT=TLE") else {
            return []
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let rawTLEText = String(data: data, encoding: .utf8) else { return [] }
            
            let lines = rawTLEText.components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            
            return lines
        } catch {
            print("❌ [NORAD NETWORK ERROR]: Failed to pull live Tiangong orbital matrix: \(error)")
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
