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
    
    private let weatherService = WeatherService.shared
    
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
            
            // Pulls the precise hourly forecast block natively from the iOS database
            let weatherData = try await weatherService.weather(for: location, including: .hourly)
            
            // Match the precise hour of the satellite pass crossing event frame
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
}
