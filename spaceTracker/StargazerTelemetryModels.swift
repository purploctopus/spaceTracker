//
//  StargazerTelemetryModels.swift
//  spaceTracker
//
//  Created by Ben Clary on 8/14/26.
//  MAKE AN APP COLIN LOVES AND USES AND SUPPORTS SARA'S FREEDOM!
//https://api.visibleplanets.dev/v3/?latitude=\(latitude)&longitude=\(longitude)&showCoords=true
//        let urlString = "https://api.visibleplanets.dev/v3/?latitude=\(latitude)&longitude=\(longitude)&date=\(cleanEncodedTime)&showCoords=true"


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
struct APIPlanetItem: Identifiable, Equatable {
    var id: String { name }
    let name: String
    let constellation: String
    var altitude: Double
    var azimuth: Double
    let nakedEyeObject: Bool
    var classification: String // "PLANET" or "STAR"
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
// 🚀 NATIVE CELESTIAL POSITIONING & ORBITAL MECHANICAL ENGINE
// ==============================================================================
class StargazerViewModel: ObservableObject {
    @Published var stargazerState = StargazerState()
    
    private var internalStarsDatabase: [LocalStarItem] = []
    private var isDatabaseLoaded: Bool = false
    
    /// Asynchronously parses your local stars.json file inside an isolated background thread
    func preloadLocalStarCatalog() async {
        guard !isDatabaseLoaded else { return }
        
        guard let fileURL = Bundle.main.url(forResource: "stars", withExtension: "json") else {
            print("❌ [CATALOG ERROR]: Could not locate 'stars.json' inside the app bundle workspace.")
            return
        }
        
        do {
            let rawData = try Data(contentsOf: fileURL)
            let decodedStars = try JSONDecoder().decode([LocalStarItem].self, from: rawData)
            self.internalStarsDatabase = decodedStars
            self.isDatabaseLoaded = true
            print("🚀 [FILE TRACE SUCCESS]: Cached \(decodedStars.count) stars natively in memory.")
        } catch {
            print("❌ [FILE SYSTEM FAULT]: Failed parsing local catalog records: \(error)")
        }
    }
    
    /// Computes real-time orbital tracks for both planets and stars completely offline
    func calculateStargazingTelemetry(latitude: Double, longitude: Double) async {
        // Generate moon lookahead calendar frames dynamically
        var dynamicWeekForecast: [StargazeForecastDay] = []
        let calendar = Calendar.current
        let dayDateFormatter = DateFormatter()
        dayDateFormatter.dateFormat = "EEE MMM d"
        dayDateFormatter.locale = Locale(identifier: "en_US")
        
        for dayOffset in 0..<7 {
            if let calculatedDate = calendar.date(byAdding: .day, value: dayOffset, to: Date()) {
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
        
        // ==============================================================================
        // 📐 MASTER CALENDAR & SIDEREAL SCALE MATH
        // ==============================================================================
        let now = Date()
        let timeInterval = now.timeIntervalSince1970
        let julianDate = (timeInterval / 86400.0) + 2440587.5
        let d = julianDate - 2451543.5 // Days past the primary calendar orbital epoch
        let julianCenturies = (julianDate - 2451545.0) / 36525.0
        
        // Compute Local Sidereal Time (LST) to align your local view plane axis
        var gmstDegrees = 280.46061837 + (360.98564736629 * (julianDate - 2451545.0)) + (0.000387933 * julianCenturies * julianCenturies)
        gmstDegrees = gmstDegrees.truncatingRemainder(dividingBy: 360.0)
        if gmstDegrees < 0 { gmstDegrees += 360.0 }
        let dynamicLocalSiderealTime = ((gmstDegrees + longitude).truncatingRemainder(dividingBy: 360.0)) / 15.0
        
        var localizedOutputCatalog: [APIPlanetItem] = []
        
        // ==============================================================================
        // 🪐 THE KEPLERIAN PLANETARY COORDINATE SOLVER ENGINE
        // ==============================================================================
        let planetaryOrbits: [(name: String, con: String, N: Double, i: Double, w: Double, a: Double, e: Double, M_base: Double, M_period: Double)] = [
            ("MERCURY", "VIRGO", 48.3316, 7.0047, 29.1241, 0.3871, 0.2056, 168.6562, 4.0923344),
            ("VENUS", "VIRGO", 76.6799, 3.3946, 54.8910, 0.7233, 0.0068, 64.1250, 1.6021301), // Calibrated 2026 Epoch
            ("MARS", "SAGITTARIUS", 49.5574, 1.8497, 286.5016, 1.5237, 0.0934, 18.6021, 0.5240207),
            ("JUPITER", "ARIES", 100.4542, 1.3030, 273.8777, 5.2026, 0.0483, 19.8950, 0.0830853),
            ("SATURN", "AQUARIUS", 113.6655, 2.4886, 339.3939, 9.5547, 0.0560, 316.9670, 0.0334442),
            ("EARTH", "SUN-REF", 0.0, 0.0, 102.9404, 1.0000, 0.0167, 356.0210, 0.9856003)  // Calibrated 2026 Epoch
        ]

        
        let earth = planetaryOrbits.last!
        let eM = (earth.M_base + earth.M_period * d).truncatingRemainder(dividingBy: 360.0) * .pi / 180.0
        let ex = earth.a * (cos(eM) - earth.e)
        let ey = earth.a * (sin(eM) * sqrt(1.0 - earth.e * earth.e))
        let cosW = cos(earth.w * .pi / 180.0)
        let sinW = sin(earth.w * .pi / 180.0)
        let earthX = ex * cosW - ey * sinW
        let earthY = ex * sinW + ey * cosW
        
        for planet in planetaryOrbits.dropLast() {
            let pM = (planet.M_base + planet.M_period * d).truncatingRemainder(dividingBy: 360.0) * .pi / 180.0
            let px = planet.a * (cos(pM) - planet.e)
            let py = planet.a * (sin(pM) * sqrt(1.0 - planet.e * planet.e))
            
            let pCosW = cos(planet.w * .pi / 180.0)
            let pSinW = sin(planet.w * .pi / 180.0)
            let sunX = px * pCosW - py * pSinW
            let sunY = px * pSinW + py * pCosW
            
            let geoX = sunX - earthX
            let geoY = sunY - earthY
            
            var planetRA = atan2(geoY, geoX) * (180.0 / .pi) / 15.0
            if planetRA < 0 { planetRA += 24.0 }
            let distance = sqrt(geoX*geoX + geoY*geoY)
            let planetDec = atan2(0.1, distance) * (180.0 / .pi)
            
            let targetHA = (dynamicLocalSiderealTime - planetRA) * 15.0
            let latRad = latitude * .pi / 180.0
            let decRad = planetDec * .pi / 180.0
            let haRad = targetHA * .pi / 180.0
            
            let sinAlt = sin(latRad) * sin(decRad) + cos(latRad) * cos(decRad) * cos(haRad)
            let finalAltitude = asin(max(-1.0, min(1.0, sinAlt))) * (180.0 / .pi)
            
            let cosAz = (sin(decRad) - sin(latRad) * sinAlt) / (cos(latRad) * cos(asin(sinAlt)))
            var finalAzimuth = acos(max(-1.0, min(1.0, cosAz))) * (180.0 / .pi)
            if sin(haRad) > 0 { finalAzimuth = 360.0 - finalAzimuth }
            
            // ==============================================================================
            // 📝 UNRESTRICTED CELESTIAL LOGGER (FRONT GATE IS SECURED)
            // ==============================================================================
            if planet.name == "VENUS" {
                print("🌟 [DEBUG VENUS CALIBRATION TRACE] 🌟")
                print("⏰ System Local Sidereal Time (LST): \(String(format: "%.4fh", dynamicLocalSiderealTime))")
                print("📐 Space Coordinates ──> RA: \(String(format: "%.4fh", planetRA)) | Dec: \(String(format: "%.4f°", planetDec))")
                print("Compass Horizon ──> AZ: \(String(format: "%.2f°", finalAzimuth)) | ALT: \(String(format: "%.2f°", finalAltitude))")
                print("--------------------------------------------------")
            }
            
            if finalAltitude < -10.0 { continue }
            
            localizedOutputCatalog.append(APIPlanetItem(
                name: planet.name,
                constellation: planet.con,
                altitude: finalAltitude,
                azimuth: finalAzimuth,
                nakedEyeObject: true,
                classification: "PLANET"
            ))
        }
        
        // ==============================================================================
        // ✨ ASYNC BACKGROUND STAR INGESTION ENGINES
        // ==============================================================================
        await preloadLocalStarCatalog()
        
        for star in internalStarsDatabase {
            let distanceDelta = abs(dynamicLocalSiderealTime - star.ra)
            let normalizedDelta = min(distanceDelta, 24.0 - distanceDelta)
            if normalizedDelta > 6.0 { continue }
            
            let calculatedHourAngle = (dynamicLocalSiderealTime - star.ra) * 15.0
            let latRadians = latitude * .pi / 180.0
            let decRadians = star.dec * .pi / 180.0
            let haRadians = calculatedHourAngle * .pi / 180.0
            
            let absoluteSinAltitude = sin(latRadians) * sin(decRadians) + cos(latRadians) * cos(decRadians) * cos(haRadians)
            let finalAltitudeAngle = asin(max(-1.0, min(1.0, absoluteSinAltitude))) * (180.0 / .pi)
            
            if finalAltitudeAngle < 5.0 { continue }
            
            let absoluteCosAzimuth = (sin(decRadians) - sin(latRadians) * absoluteSinAltitude) / (cos(latRadians) * cos(asin(absoluteSinAltitude)))
            var finalAzimuthHeading = acos(max(-1.0, min(1.0, absoluteCosAzimuth))) * (180.0 / .pi)
            if sin(haRadians) > 0 { finalAzimuthHeading = 360.0 - finalAzimuthHeading }
            
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
            self.stargazerState.forecastWeek = dynamicWeekForecast
            self.stargazerState.liveVisibleTargets = sortedResult
            self.stargazerState.isDataLoaded = true
            print("🚀 [LOCAL MATRIX ENGINE]: Calculated \(sortedResult.count) real-time items natively.")
        }
    }
}

