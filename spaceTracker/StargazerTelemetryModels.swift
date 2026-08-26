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
}

struct CloudPlanetPacket: Codable {
    let name: String
    let ra: Double
    let dec: Double
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
// 🚀 DYNAMIC LIVE VIEWPORT TELEMETRY MODULE ENGINE (NORTH-COMPASS CALIBRATED)
// ==============================================================================
class StargazerViewModel: ObservableObject {
    @Published var stargazerState = StargazerState()
    
    private var internalStarsDatabase: [LocalStarItem] = []
    private var isDatabaseLoaded: Bool = false
    
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
    
    private func fetchLivePlanetaryCoordinates() async -> [CloudPlanetPacket] {
        guard let url = URL(string: ephemerisCloudURLString) else { return [] }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            return try JSONDecoder().decode([CloudPlanetPacket].self, from: data)
        } catch {
            print("❌ [CONNECTION FAULT]: Failed fetching live ephemeris from cloud repo: \(error)")
            return []
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
        
        // ==============================================================================
        // 📐 Precise Civil-To-Astronomical UTC Clock Realignment
        // ==============================================================================
        let now = Date()
        var gmtCalendar = Calendar.current
        gmtCalendar.timeZone = TimeZone(abbreviation: "UTC")!
        
        let components = gmtCalendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: now)
        var Y = Double(components.year ?? 2026)
        var M = Double(components.month ?? 8)
        let D = Double(components.day ?? 26)
        
        if M <= 2 {
            Y -= 1
            M += 12
        }
        
        let UT = Double(components.hour ?? 0) + Double(components.minute ?? 0)/60.0 + Double(components.second ?? 0)/3600.0
        
        let A = floor(Y / 100.0)
        let B = 2.0 - A + floor(A / 4.0)
        let julianDate = floor(365.25 * (Y + 4716.0)) + floor(30.6001 * (M + 1.0)) + D + ((UT - 12.0) / 24.0) + B - 1524.5
        
        let d = julianDate - 2451543.5
        let T = d / 36525.0
        
        var gmstDegrees = 280.46061837 + 360.98564736629 * d + 0.000387933 * T * T
        gmstDegrees = gmstDegrees.truncatingRemainder(dividingBy: 360.0)
        if gmstDegrees < 0 { gmstDegrees += 360.0 }
        
        let pureLongitudeDegrees = longitude < 0 ? (360.0 + longitude) : longitude
        var localSiderealDegrees = gmstDegrees + pureLongitudeDegrees
        localSiderealDegrees = localSiderealDegrees.truncatingRemainder(dividingBy: 360.0)
        if localSiderealDegrees < 0 { localSiderealDegrees += 360.0 }
        let dynamicLocalSiderealTime = localSiderealDegrees / 15.0
        
        var localizedOutputCatalog: [APIPlanetItem] = []
        let cloudPlanets = await fetchLivePlanetaryCoordinates()
        
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("🕵️‍♂️ [MATH FORENSICS] RUNNING LOCAL HORIZON GEOMETRY TRANSFORMS")
        print("⏰ Precise Local Sidereal Time (LST): \(String(format: "%.4fh", dynamicLocalSiderealTime))")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        
        let latRad = latitude * .pi / 180.0
        
        for p in cloudPlanets {
            let targetHA = (dynamicLocalSiderealTime - p.ra) * 15.0
            let decRad = p.dec * .pi / 180.0
            let haRad = targetHA * .pi / 180.0
            
            // ==============================================================================
            // 📐 STANDARD CANONICAL MODERN HORIZONTAL TRANSFORMATION (NORTH-EAST BALANCED)
            // ==============================================================================
            // 💡 FIXED: Uses standard astronomical spherical trigonometry to compute
            // Altitude and North-based Azimuth directly, matching real compass screens natively!
            let sinAlt = sin(latRad) * sin(decRad) + cos(latRad) * cos(decRad) * cos(haRad)
            let finalAltitude = asin(max(-1.0, min(1.0, sinAlt))) * (180.0 / .pi)
            
            let yAz = sin(haRad)
            let xAz = cos(haRad) * sin(latRad) - tan(decRad) * cos(latRad)
            
            // atan2(y, x) solves the exact modern compass heading quadrant correctly
            var finalAzimuth = atan2(yAz, xAz) * (180.0 / .pi) + 180.0
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
                classification: "PLANET"
            ))
        }
        
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        
        // ==============================================================================
        // ✨ PERFECT STELLAR BACKGROUND TRANSFORMS
        // ==============================================================================
        await preloadLocalStarCatalog()
        for star in internalStarsDatabase {
            let calculatedHourAngle = (dynamicLocalSiderealTime - star.ra) * 15.0
            let decRadians = star.dec * .pi / 180.0
            let haRadians = calculatedHourAngle * .pi / 180.0
            
            let sinAltS = sin(latRad) * sin(decRadians) + cos(latRad) * cos(decRadians) * cos(haRadians)
            let finalAltitudeAngle = asin(max(-1.0, min(1.0, sinAltS))) * (180.0 / .pi)
            
            let yAzS = sin(haRadians)
            let xAzS = cos(haRadians) * sin(latRad) - tan(decRadians) * cos(latRad)
            
            var finalAzimuthHeading = atan2(yAzS, xAzS) * (180.0 / .pi) + 180.0
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

extension Double {
    init(cosHBytes decRadians: Double) { self = decRadians }
}
