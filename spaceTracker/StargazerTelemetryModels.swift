//
//  StargazerTelemetryModels.swift
//  spaceTracker
//
//  Created by Ben Clary on 8/14/26.
//  MAKE AN APP COLIN LOVES AND USES AND SUPPORTS SARA'S FREEDOM!
//https://api.visibleplanets.dev/v3/?latitude=\(latitude)&longitude=\(longitude)&showCoords=true
//        let urlString = "https://api.visibleplanets.dev/v3/?latitude=\(latitude)&longitude=\(longitude)&date=\(cleanEncodedTime)&showCoords=true"
// private let ephemerisCloudURLString = "https://raw.githubusercontent.com/purploctopus/spaceTracker-Ephemeris-Engine/main/ephemeris.json"


import Foundation
import Combine

// MARK: - 📥 LOCAL CATALOG STAR DECODER MODEL
struct LocalStarItem: Codable, Identifiable {
    var id: String { name }
    let name: String
    let constellation: String
    let ra: Double
    let dec: Double
    let mag: Double
}

// MARK: - 🌐 UNIFIED DISPLAY POSITION STRUCT
struct APIPlanetItem: Identifiable, Equatable {
    var id: String { name }
    let name: String
    let constellation: String
    var altitude: Double
    var azimuth: Double
    let nakedEyeObject: Bool
    var classification: String
    var range_au: Double?
}

// MARK: - 🔌 CLOUD DATA DECODER RE-ARCHITECTURE
// Mirrors your new hourly GitHub payload layout contract perfectly!
struct CloudPlanetPacket: Codable {
    let name: String
    let ra: Double
    let dec: Double
    let range_au: Double
}

struct IntegratedCloudPayload: Codable {
    let gmst_hours: Double
    let planets: [CloudPlanetPacket]
}

struct StargazeForecastDay: Identifiable, Equatable {
    let id = UUID()
    let dayLabel: String
    let conditionGrade: String
    let commentary: String
}

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
// 🚀 DYNAMIC API-ANCHORED CELESTIAL POSITIONING CALCULATOR ENGINE
// ==============================================================================
class StargazerViewModel: ObservableObject {
    @Published var stargazerState = StargazerState()
    
    private var internalStarsDatabase: [LocalStarItem] = []
    private var isDatabaseLoaded: Bool = false
    
    // Your raw public usercontent data delivery link
    private let ephemerisCloudURLString = "https://raw.githubusercontent.com/purploctopus/spaceTracker-Ephemeris-Engine/main/ephemeris.json"
    
    func preloadLocalStarCatalog() async {
        guard !isDatabaseLoaded else { return }
        guard let fileURL = Bundle.main.url(forResource: "stars", withExtension: "json") else { return }
        do {
            let rawData = try Data(contentsOf: fileURL)
            let decodedStars = try JSONDecoder().decode([LocalStarItem].self, from: rawData)
            self.internalStarsDatabase = decodedStars
            self.isDatabaseLoaded = true
        } catch {
            print("❌ [FILE SYSTEM FAULT]: Failed parsing local star catalog: \(error)")
        }
    }
    
    private func fetchLiveCloudPayload() async -> IntegratedCloudPayload? {
        guard let url = URL(string: ephemerisCloudURLString) else { return nil }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            return try JSONDecoder().decode(IntegratedCloudPayload.self, from: data)
        } catch {
            print("❌ [CONNECTION FAULT]: Failed downlinking unified data payload: \(error)")
            return nil
        }
    }
    
    private func resolvePlanetConstellationLabel(name: String) -> String {
        switch name {
        case "MERCURY": return "VIRGO"
        case "VENUS":   return "VIRGO"
        case "MARS":    return "TAURUS"
        case "JUPITER": return "CANCER"
        case "SATURN":  return "PISCES"
        default:        return "ZODIAC"
        }
    }
    
    func calculateStargazingTelemetry(latitude: Double, longitude: Double) async {
        var dynamicWeekForecast: [StargazeForecastDay] = []
        let calendar = Calendar.current
        let dayDateFormatter = DateFormatter()
        dayDateFormatter.dateFormat = "EEE MMM d"
        dayDateFormatter.locale = Locale(identifier: "en_US")
        
        for dayOffset in 0..<7 {
            if let calculatedDate = calendar.date(byAdding: .day, value: dayOffset, to: Date()) {
                let dayLabelText = dayDateFormatter.string(from: calculatedDate).uppercased()
                dynamicWeekForecast.append(StargazeForecastDay(
                    dayLabel: dayLabelText,
                    conditionGrade: "EXCELLENT",
                    commentary: "MOONLIGHT: MINIMAL"
                ))
            }
        }
        
        // 📡 DOWNLINK ENGINE FETCH PASS
        guard let cloudPayload = await fetchLiveCloudPayload() else { return }
        
        // ==============================================================================
        // 📐 THE GLOBAL-TO-LOCAL SIDEODEREAL CLOCK ASSIGNMENT
        // ==============================================================================
        // 💡 FIXED: We bypass all local clock loops completely. We read Greenwich time directly
        // from your JSON file and add your raw longitude to convert it to your backyard natively!
        let longitudeHours = longitude / 15.0
        var dynamicLocalSiderealTime = cloudPayload.gmst_hours + longitudeHours
        
        // Keep the hours safely inside standard 24-hour clock boundaries
        dynamicLocalSiderealTime = dynamicLocalSiderealTime.truncatingRemainder(dividingBy: 24.0)
        if dynamicLocalSiderealTime < 0 { dynamicLocalSiderealTime += 24.0 }
        
        var localizedOutputCatalog: [APIPlanetItem] = []
        
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("🕵️‍♂️ [MATH FORENSICS] RUNNING LOCAL HORIZON GEOMETRY TRANSFORMS")
        print("⏰ Precise Local Sidereal Time (LST): \(String(format: "%.4fh", dynamicLocalSiderealTime))")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        
        let latRad = latitude * .pi / 180.0
        
        for p in cloudPayload.planets {
            var targetHA = (dynamicLocalSiderealTime - p.ra) * 15.0
            targetHA = targetHA.truncatingRemainder(dividingBy: 360.0)
            if targetHA < 0 { targetHA += 360.0 }
            
            let decRad = p.dec * .pi / 180.0
            let haRad = targetHA * .pi / 180.0
            
            // Standard Meeus Spherical Trigonometry Conversions
            let sinAlt = sin(latRad) * sin(decRad) + cos(latRad) * cos(decRad) * cos(haRad)
            let finalAltitude = asin(max(-1.0, min(1.0, sinAlt))) * (180.0 / .pi)
            
            let yAz = -sin(haRad) * cos(decRad)
            let xAz = sin(decRad) - sin(latRad) * sin(max(-1.0, min(1.0, sinAlt)))
            
            var finalAzimuth = atan2(yAz, xAz) * (180.0 / .pi)
            finalAzimuth = finalAzimuth.truncatingRemainder(dividingBy: 360.0)
            if finalAzimuth < 0 { finalAzimuth += 360.0 }
            
            let constellationLabel = resolvePlanetConstellationLabel(name: p.name)
            
            print("📈 TRACK MATCH: \(p.name)")
            print("   ├─> Downlinked Coords: RA: \(p.ra)h | Dec: \(p.dec)°")
            print("   └─> Local Look Angle : ALT: \(String(format: "%.2f°", finalAltitude)) | AZ: \(String(format: "%.2f°", finalAzimuth))")
            
            localizedOutputCatalog.append(APIPlanetItem(
                name: p.name,
                constellation: constellationLabel,
                altitude: finalAltitude,
                azimuth: finalAzimuth,
                nakedEyeObject: true,
                classification: "PLANET",
                range_au: p.range_au
            ))
        }
        
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        
        // ==============================================================================
        // ✨ PERFECT STELLAR BACKGROUND TRANSFORMS
        // ==============================================================================
        await preloadLocalStarCatalog()
        for star in internalStarsDatabase {
            var calculatedHourAngle = (dynamicLocalSiderealTime - star.ra) * 15.0
            calculatedHourAngle = calculatedHourAngle.truncatingRemainder(dividingBy: 360.0)
            if calculatedHourAngle < 0 { calculatedHourAngle += 360.0 }
            
            let decRadians = star.dec * .pi / 180.0
            let haRadians = calculatedHourAngle * .pi / 180.0
            
            let sinAltS = sin(latRad) * sin(decRadians) + cos(latRad) * cos(decRadians) * cos(haRadians)
            let finalAltitudeAngle = asin(max(-1.0, min(1.0, sinAltS))) * (180.0 / .pi)
            
            let yAzS = -sin(haRadians) * cos(decRadians)
            let xAzS = sin(decRadians) - sin(latRad) * sin(max(-1.0, min(1.0, sinAltS)))
            
            var finalAzimuthHeading = atan2(yAzS, xAzS) * (180.0 / .pi)
            finalAzimuthHeading = finalAzimuthHeading.truncatingRemainder(dividingBy: 360.0)
            if finalAzimuthHeading < 0 { finalAzimuthHeading += 360.0 }
            
            localizedOutputCatalog.append(APIPlanetItem(
                name: star.name,
                constellation: star.constellation,
                altitude: finalAltitudeAngle,
                azimuth: finalAzimuthHeading,
                nakedEyeObject: star.mag <= 4.0,
                classification: "STAR"
            ))
        }
        
        let sortedResult = localizedOutputCatalog.sorted { $0.altitude > $1.altitude }
        DispatchQueue.main.async {
            self.objectWillChange.send()
            self.stargazerState.liveVisibleTargets = sortedResult
            self.stargazerState.isDataLoaded = true
        }
    }
}
