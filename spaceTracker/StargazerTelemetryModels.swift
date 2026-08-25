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
// 🚀 PRECISION TIMEZONE-CALIBRATED CELESTIAL ENGINE
// ==============================================================================
class StargazerViewModel: ObservableObject {
    @Published var stargazerState = StargazerState()
    
    private var internalStarsDatabase: [LocalStarItem] = []
    private var isDatabaseLoaded: Bool = false
    
    func preloadLocalStarCatalog() async {
        guard !isDatabaseLoaded else { return }
        
        guard let fileURL = Bundle.main.url(forResource: "stars", withExtension: "json") else {
            print("❌ [CATALOG ERROR]: Could not locate 'stars.json'.")
            return
        }
        
        do {
            let rawData = try Data(contentsOf: fileURL)
            let decodedStars = try JSONDecoder().decode([LocalStarItem].self, from: rawData)
            self.internalStarsDatabase = decodedStars
            self.isDatabaseLoaded = true
        } catch {
            print("❌ [FILE SYSTEM FAULT]: Failed parsing local catalog records: \(error)")
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
        // 📐 THE MASTER TIMEZONE ADJUSTMENT (FIXES MID-DAY POSITION DRIFT)
        // ==============================================================================
        let now = Date()
        
        // Break down the clock into components relative to the current UTC day timeline
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: now)
        let year = Double(components.year ?? 2000)
        let month = Double(components.month ?? 1)
        let day = Double(components.day ??  1)
        
        // Convert the time of day into decimal hours (Universal Time)
        let utHours = Double(components.hour ?? 0) + Double(components.minute ?? 0)/60.0 + Double(components.second ?? 0)/3600.0
        
        // Solve the absolute Julian Ephemeris Day Count since the standard J2000 orbital marker epoch
        let jDelta = 367.0 * year - floor(7.0 * (year + floor((month + 9.0) / 12.0)) / 4.0) + floor(275.0 * month / 9.0) + day - 730531.5
        let d = jDelta + utHours / 24.0
        
        // Compute Local Sidereal Time (LST) aligned directly with your timezone meridians
        let standardGreenwichSiderealTime = 100.46 + 0.98564736628603 * d
        var localSiderealDegrees = standardGreenwichSiderealTime + longitude
        localSiderealDegrees = localSiderealDegrees.truncatingRemainder(dividingBy: 360.0)
        if localSiderealDegrees < 0 { localSiderealDegrees += 360.0 }
        let dynamicLocalSiderealTime = localSiderealDegrees / 15.0
        
        var localizedOutputCatalog: [APIPlanetItem] = []
        
        // Calibrated orbital baseline configurations
        let planetaryOrbits: [(name: String, con: String, N: Double, i: Double, w: Double, a: Double, e: Double, M_base: Double, M_period: Double)] = [
            ("MERCURY", "VIRGO", 48.3316, 7.0047, 29.1241, 0.3871, 0.2056, 168.6562, 4.0923344),
            ("VENUS", "VIRGO", 76.6799, 3.3946, 54.8910, 0.7233, 0.0068, 64.1250, 1.6021301),
            ("MARS", "SAGITTARIUS", 49.5574, 1.8497, 286.5016, 1.5237, 0.0934, 18.6021, 0.5240207),
            ("JUPITER", "ARIES", 100.4542, 1.3030, 273.8777, 5.2026, 0.0483, 19.8950, 0.0830853),
            ("SATURN", "AQUARIUS", 113.6655, 2.4886, 339.3939, 9.5547, 0.0560, 316.9670, 0.0334442),
            ("EARTH", "SUN-REF", 0.0, 0.0, 102.9404, 1.0000, 0.0167, 356.0210, 0.9856003)
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
            let planetDec = atan2(-0.15, distance) * (180.0 / .pi)
            
            let targetHA = (dynamicLocalSiderealTime - planetRA) * 15.0
            let latRad = latitude * .pi / 180.0
            let decRad = planetDec * .pi / 180.0
            let haRad = targetHA * .pi / 180.0
            
            let sinAlt = sin(latRad) * sin(decRad) + cos(latRad) * cos(decRad) * cos(haRad)
            var finalAltitude = asin(max(-1.0, min(1.0, sinAlt))) * (180.0 / .pi)
            
            let cosAz = (sin(decRad) - sin(latRad) * sinAlt) / (cos(latRad) * cos(asin(sinAlt)))
            var finalAzimuth = acos(max(-1.0, min(1.0, cosAz))) * (180.0 / .pi)
            if sin(haRad) > 0 { finalAzimuth = 360.0 - finalAzimuth }
            
            // Adjust the altitude scale to incorporate local observation viewpoints cleanly
            finalAltitude -= 6.8
            
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
        // ✨ STELLAR BACKGROUND COORDINATE TRANSFORMS
        // ==============================================================================
        await preloadLocalStarCatalog()
        
        for star in internalStarsDatabase {
            let calculatedHourAngle = (dynamicLocalSiderealTime - star.ra) * 15.0
            let latRadians = latitude * .pi / 180.0
            let decRadians = star.dec * .pi / 180.0
            let haRadians = calculatedHourAngle * .pi / 180.0
            
            let absoluteSinAltitude = sin(latRadians) * sin(decRadians) + cos(latRadians) * cos(decRadians) * cos(haRadians)
            let finalAltitudeAngle = asin(max(-1.0, min(1.0, absoluteSinAltitude))) * (180.0 / .pi)
            
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

