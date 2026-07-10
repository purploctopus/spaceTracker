//
//  spaceRocksEngine.swift
//  spaceTracker
//
//  Created by Ben Clary on 6/22/26.
//  MAKE AN APP COLIN LOVES

import Foundation
import Combine
import SwiftUI

// MARK: - 1. DECODER MODELS
struct CloudflareAsteroidResponse: Decodable {
    let asteroids: [Asteroid]
}

struct Asteroid: Decodable, Identifiable {
    let id: String
    let name: String
    let is_potentially_hazardous_asteroid: Bool
    let estimated_diameter_max: Double
    let close_approach_date: String
    let miss_distance_lunar: String
    
    // 💡 FIXED: Configured to Optional (?) to ensure safe background cache parsing profiles [1.1]
    let ra_hours: Double?
    let dec_degrees: Double?
    
    var maxDiameterMeters: Int {
        return Int(estimated_diameter_max)
    }
    
    var missDistanceLunar: Int {
        if let doubleVal = Double(miss_distance_lunar) {
            return Int(doubleVal)
        }
        return 0
    }
    
    var localDateDisplay: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: close_approach_date) else { return close_approach_date }
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date).uppercased()
    }
    
    var isAstroVisibleToNakedEye: Bool {
        return estimatedVisualMagnitude <= 11.0
    }
    
    var estimatedVisualMagnitude: Double {
        let ld = max(Double(missDistanceLunar), 0.1)
        let diameter = max(estimated_diameter_max, 1.0)
        let H = 22.5 - 5.0 * log10(diameter / 100.0)
        let distanceAU = ld * 0.00257
        return H + 5.0 * log10(distanceAU * distanceAU)
    }

    // 💡 FIXED: Evaluates physical elevation against raw magnitude brightness thresholds dynamically! [1.13]
    func fetchLiveVisibilityDescriptor(lat: Double, lng: Double) -> (text: String, isVisibleNow: Bool, isTooDim: Bool) {
        let horizon = calculateLocalHorizonCoordinates(lat: lat, lng: lng)
        let magnitude = estimatedVisualMagnitude
        
        // 🚨 LEVEL 1 RADAR CONSTRAINT: Object is currently physically positioned below the horizon line
        guard horizon.altitude > 0 else {
            return ("BELOW HORIZON // TRANSITING INBOUND", false, magnitude > 11.0)
        }
        
        // 🚨 LEVEL 2 RADAR CONSTRAINT: Object is high overhead, but reflecting surfaces are too dim to track
        if magnitude > 11.0 {
            return ("TOO DIM // DEEP SPACE RECON ONLY", false, true)
        }
        
        // 🚨 LEVEL 3 RADAR CONSTRAINT: Object is crossing local coordinates and bright enough for backyard equipment [1.13]
        if magnitude <= 6.0 {
            return ("EYE ACQUISITION POSSIBLE", true, false)
        } else {
            return ("TELESCOPE RECON POSSIBLE", true, false)
        }
    }

    // 🎛️ CORE MATHEMATICAL DIRECTION VECTOR ALGORITHM
    func calculateLocalHorizonCoordinates(lat: Double, lng: Double) -> (altitude: Int, azimuth: Int, compassHeading: String) {
        // Safe failable unwrap guards shield background threads from missing JSON properties [1.1]
        guard let ra = ra_hours, let dec = dec_degrees else {
            return (-999, 0, "N/A")
        }
        
        let calendar = Calendar.current
        let hour = Double(calendar.component(.hour, from: Date()))
        let minute = Double(calendar.component(.minute, from: Date()))
        let decimalTime = hour + (minute / 60.0)
        
        let localSiderealTime = (18.697 + 24.0657 * decimalTime + lng / 15.0).truncatingRemainder(dividingBy: 24.0)
        var hourAngle = (localSiderealTime - ra) * 15.0 * (.pi / 180.0)
        if hourAngle < 0 { hourAngle += 2.0 * .pi }
        
        let latRad = lat * (.pi / 180.0)
        let decRad = dec * (.pi / 180.0)
        
        let sinAlt = sin(decRad) * sin(latRad) + cos(decRad) * cos(latRad) * cos(hourAngle)
        let altitudeDegrees = Int(asin(sinAlt) * (180.0 / .pi))
        
        let cosAz = (sin(decRad) - sinAlt * sin(latRad)) / (cos(asin(sinAlt)) * cos(latRad))
        var azimuthDegrees = Int(acos(max(-1.0, min(1.0, cosAz))) * (180.0 / .pi))
        
        if sin(hourAngle) > 0 {
            azimuthDegrees = 360 - azimuthDegrees
        }
        
        let direction: String
        switch azimuthDegrees {
        case 338...360, 0...22:   direction = "N"
        case 23...67:             direction = "NE"
        case 68...112:            direction = "E"
        case 113...157:           direction = "SE"
        case 158...202:           direction = "S"
        case 203...247:           direction = "SW"
        case 248...292:           direction = "W"
        default:                  direction = "NW"
        }
        
        return (altitudeDegrees, azimuthDegrees, direction)
    }
}

// MARK: - 2. THE DEDICATED VIEW MODEL
@MainActor
class SpaceRocksViewModel: ObservableObject {
    @Published var asteroids: [Asteroid] = []
    @Published var isLoading = false
    @Published var errorMessage: String? = nil
    
    // 💡 LOCKED: Pointed directly to your new independent asteroid cloud worker
    private let workerURLString = "https://space-rocks-worker.purploctopus.workers.dev"
    
    func fetchAsteroidRadar() async {
        isLoading = true
        errorMessage = nil
        
        guard let url = URL(string: workerURLString) else { return }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                self.errorMessage = "CLOUD SERVICE TIMEOUT"
                self.isLoading = false
                return
            }
            
            let decoded = try JSONDecoder().decode(CloudflareAsteroidResponse.self, from: data)
            self.asteroids = decoded.asteroids
            self.isLoading = false
        } catch let decodingError as DecodingError {
            // Unmasks key and schema faults instantly if payload properties change
            switch decodingError {
            case .typeMismatch(let type, _):
                self.errorMessage = "TYPE FAULT: \(type)"
            case .valueNotFound(let value, _):
                self.errorMessage = "VALUE MISSING: \(value)"
            case .keyNotFound(let key, _):
                self.errorMessage = "MISSING KEY: \(key.stringValue)"
            case .dataCorrupted(_):
                self.errorMessage = "PAYLOAD CORRUPTED"
            @unknown default:
                self.errorMessage = "DECODING CONFIG ERROR"
            }
            print("❌ NASA DECODER LOG: \(decodingError)")
            self.isLoading = false
        } catch {
            self.errorMessage = "NETWORK INTERCEPT FAULT"
            self.isLoading = false
        }
    }
}

// MARK: - 3. UI SUB-VIEW: ASTEROID RADAR MONITOR CELL CARD
struct AsteroidCardView: View {
    let asteroid: Asteroid
    let userLatitude: Double
    let userLongitude: Double
    
    // 💡 THE COMPILER SAVIOR: Move all complex lookup math completely out of the body view layout tree! [1.1]
    private var liveVisibility: (text: String, isVisibleNow: Bool, isTooDim: Bool) {
        asteroid.fetchLiveVisibilityDescriptor(lat: userLatitude, lng: userLongitude)
    }
    
    // Pre-calculate your directional horizon vector variables to keep code clean and lightweight [1.1]
    private var horizonVector: (altitude: Int, azimuth: Int, compassHeading: String) {
        asteroid.calculateLocalHorizonCoordinates(lat: userLatitude, lng: userLongitude)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Hazard Indicator Header Status Row
            HStack {
                Text(asteroid.name.uppercased())
                    .font(.system(.subheadline, design: .monospaced))
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Spacer()
                
                if asteroid.is_potentially_hazardous_asteroid {
                    Text("⚠️ HAZARD")
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                        .foregroundColor(.red)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.red.opacity(0.15))
                        .border(Color.red.opacity(0.4), width: 1)
                } else {
                    Text("SAFE")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(.green)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.green.opacity(0.1))
                }
            }
            
            Text("APPROACH: \(asteroid.localDateDisplay)")
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.yellow)
            
            // 💡 FIXED: Uses pre-calculated property streams to prevent type-checking bottlenecks instantly! [1.1]
            HStack(spacing: 4) {
                Circle()
                    .fill(liveVisibility.isVisibleNow ? Color.green : (liveVisibility.isTooDim ? Color.gray.opacity(0.5) : Color.orange))
                    .frame(width: 4, height: 4)
                
                // Renders the live truth directly onto the face of your scrolling dashboard cards [1.13]
                Text("SKY RECON: \(liveVisibility.text.uppercased())")
                    .font(.system(size: 7.5, weight: .bold, design: .monospaced))
                    .foregroundColor(liveVisibility.isVisibleNow ? .green : (liveVisibility.isTooDim ? .gray : .orange))
            }
            .padding(.top, -2)
            
            HStack(spacing: 12) {
                HStack(spacing: 3) {
                    Image(systemName: "arrow.down.forward.and.arrow.up.backward")
                        .font(.system(size: 10))
                    Text("MISS: \(asteroid.missDistanceLunar)LD")
                        .font(.system(size: 10, design: .monospaced))
                }
                
                HStack(spacing: 3) {
                    Image(systemName: "circle.circle")
                        .font(.system(size: 10))
                    Text("SIZE: \(asteroid.maxDiameterMeters)M")
                        .font(.system(size: 10, design: .monospaced))
                }
            }
            .foregroundColor(.gray)
            
            Divider()
                .background(Color.white.opacity(0.05))
                .padding(.vertical, 2)
            
            // Local Coordinates Pointing Display Lane
            HStack(spacing: 6) {
                Image(systemName: "safari")
                    .font(.system(size: 10))
                    .foregroundColor(.cyan)
                
                if horizonVector.altitude > 0 {
                    Text("SKY RECON // DIR: \(horizonVector.azimuth)° \(horizonVector.compassHeading) // ALT: \(horizonVector.altitude)° UP")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundColor(.cyan)
                } else {
                    Text("BELOW HORIZON // TRANSITS INBOUND SHORTLY")
                        .font(.system(size: 8, design: .monospaced))
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(14)
        .frame(width: 240, alignment: .leading)
        .background(Color.white.opacity(0.04))
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(asteroid.is_potentially_hazardous_asteroid ? Color.red.opacity(0.3) : Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}
