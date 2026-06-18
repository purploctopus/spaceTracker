//
//  SatelliteViewModel.swift
//  spaceTracker
//
//  Created by Ben Clary on 6/18/26.
//  MAKE AN APP COLIN LOVES

import Foundation
import Combine
import CoreLocation
import SwiftUI
import MapKit

// MARK: - 1. THE DATA MODELS
struct SatelliteResponse: Codable {
    let total_visible_passes: Int
    let passes: [SatellitePass]
}

struct SatellitePass: Codable, Identifiable {
    // 💡 THE ID FIX: Divert SwiftUI from using the raw NORAD number as the primary identity key
    let id: String
    let name: String
    let utcTimeISO: String
    let peakElevationDegrees: Double
    let durationMinutes: Int
    
    // Conforms to Identifiable uniquely by attaching the exact timestamp matrix
    var id_swiftui: String {
        return "\(id)-\(utcTimeISO)"
    }
    
    var localDisplayTime: String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = formatter.date(from: utcTimeISO) else { return "STANDBY" }
        
        let outputFormatter = DateFormatter()
        outputFormatter.dateFormat = "h:mm a (MMM d)"
        return outputFormatter.string(from: date)
    }
}

// MARK: - 2. THE PIPELINE RADAR VIEW MODEL
class SatelliteViewModel: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var visiblePasses: [SatellitePass] = []
    @Published var isTracking: Bool = false
    @Published var errorMessage: String? = nil
    @Published var requiresManualSelection: Bool = false // 💡 Triggers the manual UI picker
    
    private let locationManager = CLLocationManager()
    
    // 💡 KEEPING YOUR URL: Your exact production endpoint string
    private let workerURLString = "https://sat-tracker.purploctopus.workers.dev"
    
    // 💡 THE DE-DUPLICATION CACHE: Tracks previous position parameters to block duplicate calls
    private var lastQueriedLocationVector: String = ""
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyThreeKilometers
    }
    
    func requestPasses() {
        isTracking = true
        errorMessage = nil
        requiresManualSelection = false
        
        let status = locationManager.authorizationStatus
        
        if status == .denied || status == .restricted {
            isTracking = false
            requiresManualSelection = true
            return
        }
        
        if status == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
        } else {
            locationManager.requestLocation()
            
            // Safety timeout: If simulator/hardware takes more than 4 seconds, show city selection options
            DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) { [weak self] in
                guard let self = self, self.isTracking && self.visiblePasses.isEmpty else { return }
                self.isTracking = false
                self.requiresManualSelection = true
            }
        }
    }
    
    // Manual entry gateway method for your city selection button taps
    func selectCityCoordinates(lat: String, lng: String) {
        // Clear coordinate cache on manual choice to force override the system lock
        lastQueriedLocationVector = ""
        isTracking = true
        requiresManualSelection = false
        errorMessage = nil
        
        Task {
            await fetchPasses(latitude: lat, longitude: lng)
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.first else {
            self.requiresManualSelection = true
            return
        }
        
        let lat = String(format: "%.4f", location.coordinate.latitude)
        let lng = String(format: "%.4f", location.coordinate.longitude)
        
        Task {
            await fetchPasses(latitude: lat, longitude: lng)
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        if visiblePasses.isEmpty {
            self.isTracking = false
            self.requiresManualSelection = true
        }
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            manager.requestLocation()
        } else if status == .denied || status == .restricted {
            self.requiresManualSelection = true
        }
    }
    
    @MainActor
    private func fetchPasses(latitude: String, longitude: String) async {
        let locationKey = "\(latitude),\(longitude)"
        
        // 💡 THE SMART REPETITION GUARD: If these exact coordinates are already loading or loaded, stop instantly!
        guard locationKey != lastQueriedLocationVector else { return }
        
        lastQueriedLocationVector = locationKey
        isTracking = true
        errorMessage = nil
        
        // Form the URL string accurately mapping parameters
        guard let url = URL(string: "\(workerURLString)?lat=\(latitude)&lng=\(longitude)&days=2") else { return }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                self.errorMessage = "UPSTREAM SYNC FAIL"
                self.isTracking = false
                self.lastQueriedLocationVector = "" // Reset on error so user can re-try
                return
            }
            
            let decoded = try JSONDecoder().decode(SatelliteResponse.self, from: data)
            
            // Commit the unique tracking cards directly to the main thread timeline
            self.visiblePasses = decoded.passes
            self.isTracking = false
        } catch {
            self.errorMessage = "DECODING ENGINE FAULT"
            self.isTracking = false
            self.lastQueriedLocationVector = ""
        }
    }
    
    func searchAndSelectCity(query: String) {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        
        DispatchQueue.main.async {
            self.lastQueriedLocationVector = ""
            self.isTracking = true
            self.errorMessage = nil
        }
        
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.resultTypes = .address
        
        let search = MKLocalSearch(request: request)
        
        Task {
            do {
                let response = try await search.start()
                
                if let coordinate = response.mapItems.first?.location.coordinate {
                    let lat = String(format: "%.4f", coordinate.latitude)
                    let lng = String(format: "%.4f", coordinate.longitude)
                    
                    await MainActor.run {
                        self.selectCityCoordinates(lat: lat, lng: lng)
                    }
                } else {
                    await MainActor.run {
                        self.errorMessage = "CITY NOT FOUND"
                        self.isTracking = false
                    }
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "SEARCH FAILED"
                    self.isTracking = false
                }
            }
        }
    }
}

// MARK: - 3. THE ISOLATED SUB-VIEW COMPONENT
struct SatelliteCardView: View {
    let sat: SatellitePass
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(sat.name.uppercased())
                .font(.system(.subheadline, design: .monospaced))
                .fontWeight(.bold)
                .foregroundColor(.white)
                .lineLimit(1)
            
            Text(sat.localDisplayTime.uppercased())
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.yellow)
            
            HStack(spacing: 4) {
                Image(systemName: "scope")
                    .font(.caption2)
                Text("HEIGHT: \(Int(sat.peakElevationDegrees))°")
                    .font(.system(size: 10, design: .monospaced))
                
                Spacer()
                
                Image(systemName: "clock")
                    .font(.caption2)
                Text("\(sat.durationMinutes) MIN")
                    .font(.system(size: 10, design: .monospaced))
            }
            .foregroundColor(.gray)
        }
        .padding(14)
        .frame(width: 220, alignment: .leading)
        .background(Color.white.opacity(0.04))
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}
