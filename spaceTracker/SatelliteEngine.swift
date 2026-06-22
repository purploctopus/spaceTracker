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
    let id: String
    let name: String
    let utcTimeISO: String
    let peakElevationDegrees: Double
    let durationMinutes: Int
    
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

// MARK: - 2. THE DEBUG-READY RADAR VIEW MODEL
class SatelliteViewModel: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var visiblePasses: [SatellitePass] = []
    @Published var isTracking: Bool = false
    @Published var errorMessage: String? = nil
    @Published var requiresManualSelection: Bool = false
    
    private let locationManager = CLLocationManager()
    private let workerURLString = "https://sat-tracker.purploctopus.workers.dev"
    private var lastQueriedLocationVector: String = ""
    
    override init() {
        super.init()
        print("🤖 [RADAR ENGINE]: Initializing core class framework...")
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyThreeKilometers
    }
    
    func requestPasses() {
        print("🤖 [RADAR ENGINE]: requestPasses() triggered by parent view.")
        isTracking = true
        errorMessage = nil
        requiresManualSelection = false
        
        let status = locationManager.authorizationStatus
        print("🤖 [RADAR ENGINE]: Current system authorization status code: \(status.rawValue)")
        
        if status == .denied || status == .restricted {
            print("❌ [RADAR ENGINE]: Access denied by user system security controls.")
            isTracking = false
            requiresManualSelection = true
            return
        }
        
        if status == .notDetermined {
            print("🤖 [RADAR ENGINE]: Permission undetermined. Triggering native Apple dialog...")
            locationManager.requestWhenInUseAuthorization()
        } else {
            print("🤖 [RADAR ENGINE]: Permission authorized. Initializing core background GPS chip update stream...")
            locationManager.startUpdatingLocation()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) { [weak self] in
                guard let self = self else { return }
                if self.isTracking && self.visiblePasses.isEmpty {
                    print("⚠️ [RADAR ENGINE]: 4-second safety boundary reached with zero coordinates captured. Switching to manual selector UI.")
                    self.locationManager.stopUpdatingLocation()
                    self.isTracking = false
                    self.requiresManualSelection = true
                }
            }
        }
    }
    
    func selectCityCoordinates(lat: String, lng: String) {
        print("🤖 [RADAR ENGINE]: Manual coordinates received vector: \(lat), \(lng)")
        lastQueriedLocationVector = ""
        isTracking = true
        requiresManualSelection = false
        errorMessage = nil
        
        Task {
            await fetchPasses(latitude: lat, longitude: lng)
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        print("✅ [RADAR ENGINE]: Hardware callback received! Found \(locations.count) valid locations in vector stack.")
        guard let location = locations.last else {
            print("⚠️ [RADAR ENGINE]: Location array was empty inside completion delegate.")
            return
        }
        
        manager.stopUpdatingLocation()
        
        let lat = String(format: "%.4f", location.coordinate.latitude)
        let lng = String(format: "%.4f", location.coordinate.longitude)
        print("🤖 [RADAR ENGINE]: Extracted coordinates: Lat \(lat), Lng \(lng)")
        
        Task { @MainActor in
            await fetchPasses(latitude: lat, longitude: lng)
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("❌ [RADAR ENGINE]: CoreLocation Hardware Error stream: \(error.localizedDescription)")
        manager.stopUpdatingLocation()
        Task { @MainActor in
            if self.visiblePasses.isEmpty {
                self.isTracking = false
                self.requiresManualSelection = true
                self.errorMessage = "HARDWARE TIMEOUT: \(error.localizedDescription)"
            }
        }
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        print("🤖 [RADAR ENGINE]: System Authorization changed dynamically to status code: \(status.rawValue)")
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            print("🤖 [RADAR ENGINE]: Authorization granted. Activating hardware scan cycle...")
            isTracking = true
            manager.startUpdatingLocation()
        } else if status == .denied || status == .restricted {
            print("❌ [RADAR ENGINE]: Authorization explicitly refused on user prompt.")
            self.requiresManualSelection = true
        }
    }
    
    @MainActor
    private func fetchPasses(latitude: String, longitude: String) async {
        let locationKey = "\(latitude),\(longitude)"
        guard locationKey != lastQueriedLocationVector else {
            print("🤖 [RADAR ENGINE]: Target vector matches existing footprint. Aborting double query stream fetch.")
            return
        }
        
        lastQueriedLocationVector = locationKey
        isTracking = true
        errorMessage = nil
        
        let urlString = "\(workerURLString)?lat=\(latitude)&lng=\(longitude)&days=2"
        print("📡 [RADAR ENGINE]: Initiating background fetch path to: \(urlString)")
        
        guard let url = URL(string: urlString) else {
            print("❌ [RADAR ENGINE]: Malformed endpoint URL parsing construction.")
            return
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ [RADAR ENGINE]: Upstream server response was not an HTTP transmission matrix.")
                return
            }
            
            print("📡 [RADAR ENGINE]: Cloudflare Gateway handshake complete. Response HTTP Code: \(httpResponse.statusCode)")
            
            guard httpResponse.statusCode == 200 else {
                self.errorMessage = "UPSTREAM SYNC FAIL"
                self.isTracking = false
                self.lastQueriedLocationVector = ""
                return
            }
            
            let decoded = try JSONDecoder().decode(SatelliteResponse.self, from: data)
            print("✅ [RADAR ENGINE]: Successful pipeline synchronization. Loaded \(decoded.passes.count) visual pass records.")
            self.visiblePasses = decoded.passes
            self.isTracking = false
        } catch {
            print("❌ [RADAR ENGINE]: Data processing conversion exception thrown: \(error)")
            self.errorMessage = "DECODING ENGINE FAULT"
            self.isTracking = false
            self.lastQueriedLocationVector = ""
        }
    }
    
    func searchAndSelectCity(query: String) {
        print("🤖 [RADAR ENGINE]: Processing manual string text geocode search query: '\(query)'")
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
                    print("✅ [RADAR ENGINE]: Manual string lookup successful: \(lat), \(lng)")
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
                print("❌ [RADAR ENGINE]: MapKit geocoding search block context failed: \(error)")
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

// MARK: - 4. THE DETAILED MISSIONS PROFILE SHEET
struct SatelliteDetailSheet: View {
    let sat: SatellitePass
    @Environment(\.dismiss) var dismiss
    
    // Curated telemetry database for your 11 high-visibility targets
    private var missionProfile: (country: String, launched: String, type: String, summary: String) {
        let name = sat.name.uppercased()
        if name.contains("ISS") {
            return ("MULTINATIONAL", "1998-11-20", "HABITATION LAB", "THE INTERNATIONAL SPACE STATION SERVES AS A PERMANENT ORBITAL BASE FOR ASTROPHYSICS, BIOLOGY, AND MICROGRAVITY LABORATORY RESEARCH.")
        } else if name.contains("CSS") || name.contains("TIANHE") || name.contains("TIANGONG") || name.contains("SHENZHOU") {
            return ("CHINA", "2021-04-29", "HABITATION LAB", "THE TIANGONG CORE MODULE SERVES AS THE FOUNDATION FOR EXPANDED LONG-DURATION CHINESE ACADEMIC ORBITAL FLIGHTS.")
        } else if name.contains("HUBBLE") {
            return ("UNITED STATES (NASA)", "1990-04-24", "SPACE TELESCOPE", "THE DEEP SPACE OBSERVATORY TRACKS OPTICAL, ULTRAVIOLET, AND INFRARED SPECTRAL COSMIC TRAJECTORIES.")
        } else if name.contains("STARLINK") {
            return ("UNITED STATES (SPACEX)", "COMMERCIAL", "TELECOM CONSTELLATION", "LOW-EARTH ORBIT BROADBAND TRANSMISSION SATELLITE DESIGNED FOR GLOBAL HIGH-SPEED INTERNET LINK ROUTING.")
        } else if name.contains("X37-B") {
            return ("UNITED STATES (USAF)", "CLASSIFIED", "EXPERIMENTAL SPACEPLANE", "AUTONOMOUS REUSABLE MILITARY ROBOTIC VEHICLE CONDUCTING LONG-DURATION ORBITAL TECHNOLOGICAL FLIGHT TESTS.")
        } else if name.contains("ENVISAT") {
            return ("EUROPEAN UNION (ESA)", "2002-03-01", "ENVIRONMENTAL RADAR", "MASSIVE ACTIVE INFRASTRUCTURE ELEMENT DEDICATED TO RADAR ATMOSPHERIC AND EARTH FOOTPRINT TRACKING INTERCEPTS.")
        } else if name.contains("AQUA") {
            return ("UNITED STATES (NASA)", "2002-05-04", "EARTH OBSERVATION", "MULTINATIONAL RECONNAISSANCE PLATFORM STUDYING EARTH WATER CYCLES, PRECIPITATION, AND OCEAN EVAPORATION SIGNS.")
        } else if name.contains("TERRA") {
            return ("UNITED STATES (NASA)", "1999-12-18", "EARTH OBSERVATION", "PRIMARY FLAGSHIP SPECTRUM MONITOR ANALYZING THE GLOBAL SPREAD OF VEGETATION AND CLIMATE TRANSITIONS OVER HORIZONS.")
        }
        return ("INTERNATIONAL", "UNKNOWN", "ORBITAL PAYLOAD", "HIGH-VISIBILITY TARGET TRACKED IN REAL-TIME BY HORIZON COMPASS SURVEILLANCE RADAR RAILS.")
    }
    
    var body: some View {
        ZStack {
            Color(red: 0.04, green: 0.04, blue: 0.04).ignoresSafeArea()
            
            VStack(alignment: .leading, spacing: 24) {
                // Header Panel Control
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(sat.name.uppercased())
                            .font(.system(.title2, design: .monospaced))
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        Text("NORAD CATALOG ID: #\(sat.id)")
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundColor(.cyan)
                    }
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.gray)
                    }
                }
                .padding(.bottom, 8)
                
                // Telemetry Matrix Table
                VStack(spacing: 0) {
                    telemetryRow(label: "ORIGIN REALM", value: missionProfile.country)
                    telemetryRow(label: "LAUNCH TIMELINE", value: missionProfile.launched)
                    telemetryRow(label: "PLATFORM TYPE", value: missionProfile.type)
                    telemetryRow(label: "MAX ELEVATION", value: "\(Int(sat.peakElevationDegrees))° ANGLE")
                    telemetryRow(label: "WINDOW DURATION", value: "\(sat.durationMinutes) MINUTES")
                }
                .border(Color.white.opacity(0.1), width: 1)
                
                // Mission Narrative
                VStack(alignment: .leading, spacing: 8) {
                    Text("MISSION OBJECTIVES //")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.yellow)
                    Text(missionProfile.summary)
                        .font(.system(.subheadline, design: .monospaced))
                        .foregroundColor(.gray)
                        .lineSpacing(4)
                }
                
                Spacer()
            }
            .padding(24)
        }
        .preferredColorScheme(.dark)
    }
    
    private func telemetryRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.secondary)
            Spacer()
            Text(value.uppercased())
                .font(.system(.caption, design: .monospaced))
                .fontWeight(.bold)
                .foregroundColor(.white)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .background(Color.white.opacity(0.01))
        .overlay(Rectangle().stroke(Color.white.opacity(0.04), lineWidth: 0.5))
    }
}
