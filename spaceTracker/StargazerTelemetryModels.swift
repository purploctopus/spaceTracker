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
    
    private var internalStarsDatabase: [LocalStarItem] = []
    private var isDatabaseLoaded: Bool = false
    
    /// Asynchronously parses your local stars.json file inside an isolated background execution thread
    func preloadLocalStarCatalog() async {
        guard !isDatabaseLoaded else { return }
        
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
            
            var combinedDisplayCatalog = apiResponse.data.map { item -> APIPlanetItem in
                var planetItem = item
                planetItem.classification = "PLANET"
                return planetItem
            }
            
            // ==============================================================================
            // 📐 THE PRECISION REAL TIME SIDEREAL TIME ALIGNMENT ENGINE
            // ==============================================================================
            let now = Date()
            
            // 2. Compute Julian Days since standard J2000 epoch epoch parameters
            let timeInterval = now.timeIntervalSince1970
            let julianDate = (timeInterval / 86400.0) + 2440587.5
            let julianCenturiesSinceJ2000 = (julianDate - 2451545.0) / 36525.0
            
            // 3. Compute Greenwich Mean Sidereal Time (GMST) formula in degrees
            var gmstDegrees = 280.46061837 + (360.98564736629 * (julianDate - 2451545.0)) +
                             (0.000387933 * julianCenturiesSinceJ2000 * julianCenturiesSinceJ2000) -
                             (julianCenturiesSinceJ2000 * julianCenturiesSinceJ2000 * julianCenturiesSinceJ2000 / 38710000.0)
            
            gmstDegrees = gmstDegrees.truncatingRemainder(dividingBy: 360.0)
            if gmstDegrees < 0 { gmstDegrees += 360.0 }
            
            // 4. Transform to true Local Sidereal Time (LST) incorporating your dynamic longitude coordinate!
            let localSiderealDegrees = (gmstDegrees + longitude).truncatingRemainder(dividingBy: 360.0)
            let dynamicLocalSiderealTime = localSiderealDegrees / 15.0 // Convert circle degrees back into decimal sky hours
            
            print("⚙️ [PRECISION POSITIONING]: Local Sidereal Time is calculated at: \(String(format: "%.4fh", dynamicLocalSiderealTime))")
            
            // Look at only a subset of stars passing over your active hemisphere grid lines
            for star in internalStarsDatabase {
                let distanceDelta = abs(dynamicLocalSiderealTime - star.ra)
                let normalizedDelta = min(distanceDelta, 24.0 - distanceDelta)
                
                if normalizedDelta > 6.0 {
                    continue // Skip completely hidden background elements immediately
                }
                
                let calculatedHourAngle = (dynamicLocalSiderealTime - star.ra) * 15.0 // Convert hour to circle degrees
                let latRadians = latitude * .pi / 180.0
                let decRadians = star.dec * .pi / 180.0
                let haRadians = calculatedHourAngle * .pi / 180.0
                
                let absoluteSinAltitude = sin(latRadians) * sin(decRadians) + cos(latRadians) * cos(decRadians) * cos(haRadians)
                let finalAltitudeAngle = asin(max(-1.0, min(1.0, absoluteSinAltitude))) * (180.0 / .pi)
                
                if finalAltitudeAngle < 5.0 {
                    continue
                }
                
                let absoluteCosAzimuth = (sin(decRadians) - sin(latRadians) * absoluteSinAltitude) / (cos(latRadians) * cos(asin(absoluteSinAltitude)))
                var finalAzimuthHeading = acos(max(-1.0, min(1.0, absoluteCosAzimuth))) * (180.0 / .pi)
                if sin(haRadians) > 0 {
                    finalAzimuthHeading = 360.0 - finalAzimuthHeading
                }
                
                combinedDisplayCatalog.append(APIPlanetItem(
                    name: star.name,
                    constellation: star.constellation,
                    altitude: finalAltitudeAngle,
                    azimuth: finalAzimuthHeading,
                    nakedEyeObject: star.mag <= 4.0,
                    classification: "STAR"
                ))
            }
            
            let sortedResult = combinedDisplayCatalog.sorted { $0.altitude > $1.altitude }
            
            DispatchQueue.main.async {
                self.objectWillChange.send()
                self.stargazerState.forecastWeek = dynamicWeekForecast
                self.stargazerState.liveVisibleTargets = sortedResult
                self.stargazerState.isDataLoaded = true
                print("🌐 [ALIGNMENT PIPELINE COMPLETE]: Local Star map positions are perfectly synchronized to calendar vectors.")
            }
        } catch {
            print("❌ [ASTRONOMY ENGINE ERROR]: Ingestion pipeline track aborted: \(error)")
        }
    }
}
