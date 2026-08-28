//
//  StargazingWeatherViewModel.swift
//  spaceTracker
//
//  Created by Ben Clary on 7/7/26.
//  make an app Colin LOVES!

import Foundation
import SwiftUI
import CoreLocation
import WeatherKit
import Combine

@MainActor
class StargazingWeatherViewModel: ObservableObject {
    @Published var cloudCoverPercent: Int = 0
    @Published var humidityPercent: Int = 0
    @Published var observationRating: String = "POLLING COMPASS DATA..."
    @Published var isLoading = false
    
    // 💡 INJECTED GEOMAGNETIC AURORA VARIABLES
    @Published var kpIndex: Double = 0.0
    @Published var auroraStormActive: Bool = false
    @Published var geomagneticStatusText: String = "QUIET CONDITIONS"
    
    private let weatherService = WeatherService.shared
    
    // 💡 INJECTED SPACE WEATHER ENGINE: Pulls live global solar storm telemetry from NOAA
    func fetchGeomagneticRadar() async {
        guard let url = URL(string: "https://services.swpc.noaa.gov/json/planetary_k_index_1m.json") else { return }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            
            if let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
               let latestReading = jsonArray.last,
               let kpNumber = latestReading["kp_index"] as? NSNumber {
                
                let kpParsed = kpNumber.doubleValue
                self.kpIndex = kpParsed
                
                // Kp Scale: >= 5.0 is G1 (Minor Storm), >= 7.0 is G3 (Severe Storm)
                if kpParsed >= 7.0 {
                    self.auroraStormActive = true
                    self.geomagneticStatusText = "G3+ SEVERE STORM // AURORA ACTIVE"
                } else if kpParsed >= 5.0 {
                    self.auroraStormActive = true
                    self.geomagneticStatusText = "G1-G2 MINOR STORM // HORIZON GLOW"
                } else if kpParsed >= 4.0 {
                    self.auroraStormActive = false
                    self.geomagneticStatusText = "UNSETTLED GEOMAGNETIC SHIELD"
                } else {
                    self.auroraStormActive = false
                    self.geomagneticStatusText = "QUIET IONOSPHERE METRICS"
                }
                print("📡 [SPACE WEATHER]: Successfully processed Kp-Index: \(kpParsed)")
            } else {
                // This branch existing at all is the point: the previous version of this
                // parse silently failed here on every single call (kp_index comes back from
                // NOAA as a JSON number, not a String) with no log line anywhere — kpIndex
                // just quietly stayed at its 0.0 default forever. If this ever fires again,
                // it means NOAA changed the response shape; at least now it's visible.
                print("⚠️ [SPACE WEATHER]: Response didn't match expected shape — no Kp-index applied.")
            }
        } catch {
            print("❌ [SPACE WEATHER ERROR]: Failed to decode planetary K-index logs: \(error)")
        }
    }
    
    func fetchStargazingWeather(lat: Double, lng: Double, targetISO8601Date: String) async {
        isLoading = true
        
        let inputFormatter = ISO8601DateFormatter()
        inputFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        var parsedDate = inputFormatter.date(from: targetISO8601Date)
        
        if parsedDate == nil {
            let backup = ISO8601DateFormatter()
            parsedDate = backup.date(from: targetISO8601Date)
        }
        
        guard let validDate = parsedDate else {
            self.observationRating = "TIMING ALIGNMENT ERROR"
            self.isLoading = false
            return
        }
        
        let location = CLLocation(latitude: lat, longitude: lng)
        
        do {
            print("📡 [WEATHERKIT]: Dispatching secure telemetry request to Apple edge servers...")
            
            let weatherData = try await weatherService.weather(for: location, including: .hourly)
            
            if let matchedHour = weatherData.first(where: { hour in
                Calendar.current.isDate(hour.date, equalTo: validDate, toGranularity: .hour)
            }) {
                let clouds = Int(matchedHour.cloudCover * 100)
                let humidity = Int(matchedHour.humidity * 100)
                
                self.cloudCoverPercent = clouds
                self.humidityPercent = humidity
                
                if clouds > 70 {
                    self.observationRating = "❌ BLOCKED // HEAVY CLOUD COVER"
                } else if clouds > 30 {
                    self.observationRating = "⚠️ PARTIAL // SCATTERED OBSTRUCTIONS"
                } else if humidity > 85 {
                    self.observationRating = "⚠️ MISTY // HIGH DEW POINT BLOCKAGE"
                } else {
                    self.observationRating = "✨ EXCELLENT // NOMINAL CLEAR SKIES"
                }
                
                print("✅ [WEATHERKIT]: Successfully processed conditions: \(clouds)% clouds.")
            } else {
                self.observationRating = "FORECAST RANGE OUT OF BOUNDS"
            }
            
            self.isLoading = false
        } catch {
            print("❌ [WEATHERKIT CRASH LOG]: Entitlement verification error: \(error.localizedDescription)")
            self.observationRating = "WEATHER CAPABILITY ASSIGNMENT BUSY"
            self.isLoading = false
        }
    }
    
    // 💡 INJECT THIS INTO YOUR StargazingWeatherViewModel CLASS
    func calculateNextVisualPrediction(userLatitude: Double) -> (targetKp: Double, urgencyText: String, isPossibleNow: Bool) {
        let absLat = abs(userLatitude) // Handles northern and southern hemisphere limits
        let targetRequiredKp: Double
        
        // NOAA Geomagnetic Latitude to Kp Translation Matrix
        if absLat >= 65.0 { targetRequiredKp = 1.0 }       // Alaska, Northern Scandinavia
        else if absLat >= 60.0 { targetRequiredKp = 3.0 }  // Southern Canada, Scotland
        else if absLat >= 54.0 { targetRequiredKp = 5.0 }  // Northern US Border (WA, ND, MN, ME)
        else if absLat >= 50.0 { targetRequiredKp = 6.0 }  // Central US (OR, IL, NY) / Northern Europe
        else if absLat >= 44.0 { targetRequiredKp = 7.0 }  // Mid-US (CA, NE, PA, OH)
        else if absLat >= 38.0 { targetRequiredKp = 8.0 }  // Southern US (TX, FL) / Southern Europe
        else { targetRequiredKp = 9.0 }                    // Equatorial / Deep Space Boundary
        
        // Core Comparison Check
        if self.kpIndex >= targetRequiredKp {
            return (targetRequiredKp, "🚨 ACTIVE VISUAL DETECTED // LOOK UP NOW", true)
        } else {
            // Determine structural distance gap to predict the active threat profile
            let gap = targetRequiredKp - self.kpIndex
            if gap <= 1.5 {
                return (targetRequiredKp, "⚠️ GEOMAGNETIC UNREST // HIGH THREAT EVENT PENDING", false)
            } else {
                return (targetRequiredKp, "STANDBY // RECON ACCELERATION DEMANDS KP \(String(format: "%.0f", targetRequiredKp))+", false)
            }
        }
    }

}
