//
//  StargazerTelemetryModels.swift
//  spaceTracker
//
//  Created by Ben Clary on 8/14/26.
//  MAKE AN APP COLIN LOVES AND USES AND SUPPORTS SARA'S FREEDOM!
//https://api.visibleplanets.dev/v3/?latitude=\(latitude)&longitude=\(longitude)&showCoords=true

import Foundation
import Combine

// MARK: - 📥 LOCAL CATALOG STAR DECODER MODEL
struct LocalStarItem: Codable, Identifiable {
    var id: String { name }
    let name: String
    let constellation: String
    let ra: Double  // Decimal hour right ascension (0.0 to 24.0)
    let dec: Double // Decimal degree declination (-90.0 to +90.0)
    let mag: Double // Visual brightness magnitude scale
}

// MARK: - 🌐 UNIFIED DISPLAY POSITION STRUCT
struct APIPlanetItem: Codable, Identifiable, Equatable {
    var id: String { name }
    let name: String
    let constellation: String
    var altitude: Double
    var azimuth: Double
    let nakedEyeObject: Bool
    var classification: String = "PLANET" // Set to "PLANET" or "STAR" dynamically
    
    private enum CodingKeys: String, CodingKey {
        case name
        case constellation
        case altitude
        case azimuth
        case nakedEyeObject
    }
}

struct PlanetAPIResponse: Codable {
    let data: [APIPlanetItem]
}

struct StargazeForecastDay: Identifiable, Equatable {
    let id = UUID()
    let dayLabel: String
    let conditionGrade: String
    let commentary: String
}

// MARK: - 🎯 GLOBAL STATE MACHINE ARCHITECTURE
class StargazerState: ObservableObject {
    @Published var observationIndex: Int = 85
    @Published var bortleClass: String = "CLASS 4 (RURAL-SUBURBAN)"
    @Published var moonPhase: String = "WAXING CRESCENT"
    @Published var moonSetTime: String = "10:14 PM"
    @Published var trueDarkWindow: String = "09:34 PM - 04:15 AM"
    
    @Published var liveVisibleTargets: [APIPlanetItem] = []
    @Published var forecastWeek: [StargazeForecastDay] = []
    @Published var isDataLoaded: Bool = false
}

// ==============================================================================
// 🚀 MAIN STARGAZER CONTEXT VIEW MODEL
// ==============================================================================
class StargazerViewModel: ObservableObject {
    @Published var stargazerState = StargazerState()
    
    // 💡 THE RAM CACHE: Holds your full 9,000 star database file cleanly in the background
    private var internalStarsDatabase: [LocalStarItem] = []
    private var isDatabaseLoaded: Bool = false
    
    /// Asynchronously parses your local stars.json file inside an isolated background execution thread
    func preloadLocalStarCatalog() async {
        guard !isDatabaseLoaded else { return } // Skip re-reading disk if already loaded
        
        // Find the absolute system bundle file reference token path inside the app container
        guard let fileURL = Bundle.main.url(forResource: "stars", withExtension: "json") else {
            print("❌ [CATALOG ERROR]: Could not locate 'stars.json' inside the app bundle workspace.")
            return
        }
        
        do {
            print("📦 [FILE TRACKER]: Opening disk channel stream to read star table indices...")
            let rawData = try Data(contentsOf: fileURL)
            let decodedStars = try JSONDecoder().decode([LocalStarItem].self, from: rawData)
            
            self.internalStarsDatabase = decodedStars
            self.isDatabaseLoaded = true
            print("🚀 [FILE TRACE SUCCESS]: Cached \(decodedStars.count) naked-eye stars safely in background memory.")
        } catch {
            print("❌ [FILE SYSTEM FAULT]: Failed parsing local catalog records: \(error)")
        }
    }
    
    /// Pulls live planets via network session and combines them with calculated positions of your local stars database file
    func calculateStargazingTelemetry(latitude: Double, longitude: Double) async {
        // Ensure our offline star list is fully initialized inside RAM memory arrays first
        await preloadLocalStarCatalog()
        
        let urlString = "https://api.visibleplanets.dev/v3/?latitude=\(latitude)&longitude=\(longitude)&showCoords=true"
        guard let url = URL(string: urlString) else { return }
        
        // Generate moon lookahead calendar frames dynamically
        var dynamicWeekForecast: [StargazeForecastDay] = []
        let currentCalendar = Calendar.current
        let dayDateFormatter = DateFormatter()
        dayDateFormatter.dateFormat = "EEE MMM d"
        dayDateFormatter.locale = Locale(identifier: "en_US")
        
        for dayOffset in 0..<7 {
            if let calculatedDate = currentCalendar.date(byAdding: .day, value: dayOffset, to: Date()) {
                let dayLabelText = dayDateFormatter.string(from: calculatedDate).uppercased()
                let calculatedIllumination = min(100.0, 12.0 + (Double(dayOffset) * 7.0))
                let percentString = String(format: "%.0f%%", calculatedIllumination)
                
                let skyGrade = calculatedIllumination > 50.0 ? "POOR" : (calculatedIllumination > 25.0 ? "MARGINAL" : "EXCELLENT")
                
                dynamicWeekForecast.append(StargazeForecastDay(
                    dayLabel: dayLabelText,
                    conditionGrade: skyGrade,
                    commentary: "MOONLIGHT: \(percentString)"
                ))
            }
        }
        
        do {
            print("🌐 [ASTRONOMY WORKER]: Fetching live planetary orbit positions...")
            let (data, _) = try await URLSession.shared.data(from: url)
            let apiResponse = try JSONDecoder().decode(PlanetAPIResponse.self, from: data)
            
            // Map incoming network results cleanly as planets
            var combinedDisplayCatalog = apiResponse.data.map { item -> APIPlanetItem in
                var planetItem = item
                planetItem.classification = "PLANET"
                return planetItem
            }
            
            // ==============================================================================
            // 📐 THE REAL TIME GEOMETRIC PROJECTION PASS (OPTIMIZED)
            // ==============================================================================
            let deviceDate = Date()
            let deviceCalendar = Calendar.current
            let systemHour = Double(deviceCalendar.component(.hour, from: deviceDate))
            
            // Approximate localized sidereal tracking hour reference based on current device clock vectors
            let dynamicLocalSiderealTime = (systemHour + 6.0).truncatingRemainder(dividingBy: 24.0)
            
            print("⚙️ [OPTIMIZATION ENGINE]: Transforming coordinates for local observation windows...")
            
            // Look at only a subset of stars passing over your active hemisphere grid lines
            for star in internalStarsDatabase {
                // Stage 1 Range Filter Box: Throw away stars on the completely opposite face of the planet
                let distanceDelta = abs(dynamicLocalSiderealTime - star.ra)
                let normalizedDelta = min(distanceDelta, 24.0 - distanceDelta)
                
                if normalizedDelta > 6.0 {
                    continue // Skip completely hidden background elements immediately
                }
                
                // Stage 2 Geometry: Map standard spherical trigonometry positions based on your latitude parameters
                let calculatedHourAngle = (dynamicLocalSiderealTime - star.ra) * 15.0 // Convert hour to circle degrees
                let latRadians = latitude * .pi / 180.0
                let decRadians = star.dec * .pi / 180.0
                let haRadians = calculatedHourAngle * .pi / 180.0
                
                // Solve for true altitude angle above your horizon curves
                let absoluteSinAltitude = sin(latRadians) * sin(decRadians) + cos(latRadians) * cos(decRadians) * cos(haRadians)
                let finalAltitudeAngle = asin(max(-1.0, min(1.0, absoluteSinAltitude))) * (180.0 / .pi)
                
                // Filter items sitting below the ground line out of our display queues completely
                if finalAltitudeAngle < 5.0 {
                    continue
                }
                
                // Solve for true azimuth compass heading degree
                let absoluteCosAzimuth = (sin(decRadians) - sin(latRadians) * absoluteSinAltitude) / (cos(latRadians) * cos(asin(absoluteSinAltitude)))
                var finalAzimuthHeading = acos(max(-1.0, min(1.0, absoluteCosAzimuth))) * (180.0 / .pi)
                if sin(haRadians) > 0 {
                    finalAzimuthHeading = 360.0 - finalAzimuthHeading
                }
                
                // Wrap cleanly as a unified item and push directly to the presentation storage list arrays
                combinedDisplayCatalog.append(APIPlanetItem(
                    name: star.name,
                    constellation: star.constellation,
                    altitude: finalAltitudeAngle,
                    azimuth: finalAzimuthHeading,
                    nakedEyeObject: star.mag <= 4.0,
                    classification: "STAR"
                ))
            }
            
            // Prioritize listing objects passing near peak vertical visibility views
            let sortedResult = combinedDisplayCatalog.sorted { $0.altitude > $1.altitude }
            
            DispatchQueue.main.async {
                self.objectWillChange.send()
                self.stargazerState.forecastWeek = dynamicWeekForecast
                self.stargazerState.liveVisibleTargets = sortedResult
                self.stargazerState.isDataLoaded = true
                print("🌐 [COMPUTATION LOG COMPLETE]: Merged active planets with \(sortedResult.count - apiResponse.data.count) passing stars.")
            }
        } catch {
            print("❌ [ASTRONOMY ENGINE ERROR]: Ingestion pipeline track aborted: \(error)")
        }
    }
}
