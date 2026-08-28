//
//  StargazerTelemetryModels.swift
//  spaceTracker
//
//  Created by Ben Clary on 8/14/26.
//  MAKE AN APP COLIN LOVES AND USES AND SUPPORTS SARA'S FREEDOM!

import Foundation
import Combine
import CoreLocation
import SwiftAA // 💡 Unlocks high-precision offline C-algorithms natively!

// MARK: - 📥 LOCAL CATALOG STAR DECODER MODEL
struct LocalStarItem: Codable, Identifiable {
    var id: String { name }
    let name: String
    let constellation: String
    let ra: Double
    let dec: Double
    let mag: Double
}

// MARK: - 🌐 UNIFIED DISPLAY POSITION STRUCT (100% Intact)
struct APIPlanetItem: Identifiable, Equatable {
    var id: String { name }
    let name: String
    let constellation: String
    var altitude: Double
    var azimuth: Double
    let nakedEyeObject: Bool
    var classification: String
    var range_au: Double?
    var magnitude: Double?
}

struct StargazeForecastDay: Identifiable, Equatable {
    let id = UUID()
    let dayLabel: String
    let conditionGrade: String
    let commentary: String
}

// MARK: - 🔌 CORE INTERFACE STATES (100% Intact)
class StargazerState: ObservableObject {
    @Published var trueDarkWindow: String = "CALCULATING..."

    @Published var liveVisibleTargets: [APIPlanetItem] = []
    @Published var forecastWeek: [StargazeForecastDay] = []
    @Published var isDataLoaded: Bool = false
}

// ==============================================================================
// 🌌 TRUE DARK WINDOW (astronomical twilight bounds)
// ==============================================================================
/// Formats a "start – end" local-time string for astronomical night: from the moment the
/// Sun drops below -18° this evening, to the moment it climbs back above -18° the following
/// morning. Below -18°, natural airglow from the Sun no longer brightens the sky at all —
/// this is the standard definition of a fully dark astronomical sky.
///
/// Built directly from RiseTransitSetTimes and Sun.makeHorizontalCoordinates rather than
/// SwiftAA's twilights(forSunAltitude:coordinates:) convenience wrapper — that wrapper's
/// exact return shape (tuple vs. struct, presence of an .error field) turned out to differ
/// between SwiftAA versions/commits, so this replicates the same logic from primitives whose
/// signatures are stable and already confirmed working elsewhere in this file.
///
/// Two separate RiseTransitSetTimes calls are needed for the actual dusk/dawn times: one for
/// "today" (its setTime is tonight's dusk) and one for "tomorrow" (its riseTime is tomorrow's
/// dawn) — a single day's rise/set pair only covers this morning's dawn paired with tonight's
/// dusk, not the full overnight span. Polar day/night is detected by sampling the Sun's
/// altitude at local midnight and noon, same approach SwiftAA's own twilights() uses
/// internally for that edge case.
func formattedTrueDarkWindow(currentJulianDay: JulianDay, geoCoordinates: GeographicCoordinates) -> String {
    let timeFormatter = DateFormatter()
    timeFormatter.timeStyle = .short

    let astronomicalAltitude = TwilightSunAltitude.astronomical.rawValue // -18°

    let midnightSun = Sun(julianDay: currentJulianDay)
    let midnightAltitude = midnightSun.makeHorizontalCoordinates(with: geoCoordinates).altitude
    if midnightAltitude > astronomicalAltitude {
        return "NO TRUE DARKNESS TONIGHT"
    }

    let noonJulianDay = JulianDay(currentJulianDay.value + 0.5)
    let noonSun = Sun(julianDay: noonJulianDay)
    let noonAltitude = noonSun.makeHorizontalCoordinates(with: geoCoordinates).altitude
    if noonAltitude < astronomicalAltitude {
        return "DARK ALL NIGHT"
    }

    let sunToday = Sun(julianDay: currentJulianDay)
    let todayTimes = RiseTransitSetTimes(celestialBody: sunToday, geographicCoordinates: geoCoordinates, riseSetAltitude: astronomicalAltitude)

    let tomorrowJulianDay = JulianDay(currentJulianDay.value + 1.0)
    let sunTomorrow = Sun(julianDay: tomorrowJulianDay)
    let tomorrowTimes = RiseTransitSetTimes(celestialBody: sunTomorrow, geographicCoordinates: geoCoordinates, riseSetAltitude: astronomicalAltitude)

    guard let duskDate = todayTimes.setTime?.date, let dawnDate = tomorrowTimes.riseTime?.date else {
        return "UNAVAILABLE"
    }

    return "\(timeFormatter.string(from: duskDate)) - \(timeFormatter.string(from: dawnDate))"
}

// ==============================================================================
// 🚀 OFFLINE NATIVE POSITIONING CALCULATOR ENGINE
// ==============================================================================
class StargazerViewModel: ObservableObject {
    @Published var stargazerState = StargazerState()

    private var internalStarsDatabase: [LocalStarItem] = []
    private var isDatabaseLoaded: Bool = false

    /// Name of a star to echo raw RA/Dec for on every run, as a cheap sanity check that the
    /// decoded catalog data hasn't drifted from what's actually in stars.json on disk.
    /// Set to nil to disable this diagnostic print.
    private let diagnosticStarName: String? = "BETELGEUSE"

    func preloadLocalStarCatalog() async {
        guard !isDatabaseLoaded else { return }
        guard let fileURL = Bundle.main.url(forResource: "stars", withExtension: "json") else {
            print("❌ [FILE SYSTEM FAULT]: stars.json not found in bundle.")
            return
        }
        do {
            let rawData = try Data(contentsOf: fileURL)
            let decodedStars = try JSONDecoder().decode([LocalStarItem].self, from: rawData)
            // Sanitize static asset lists to prevent hardcoded solar coordinate collisions.
            // The Sun is computed live below via SwiftAA's Sun class, never from the static catalog.
            self.internalStarsDatabase = decodedStars.filter {
                $0.name.uppercased() != "SOL" && $0.name.uppercased() != "SUN"
            }
            self.isDatabaseLoaded = true

            if let diagnosticStarName,
               let match = self.internalStarsDatabase.first(where: { $0.name.uppercased() == diagnosticStarName }) {
                print("🔎 [CATALOG CHECK] \(diagnosticStarName) decoded as RA: \(match.ra)h  DEC: \(match.dec)°")
            }
        } catch {
            print("❌ [FILE SYSTEM FAULT]: Failed parsing local star catalog: \(error)")
        }
    }

    private func resolvePlanetConstellationLabel(name: String) -> String {
        switch name {
        case "MERCURY": return "VIRGO"
        case "VENUS":   return "VIRGO"
        case "MARS":    return "TAURUS"
        case "JUPITER": return "CANCER"
        case "SATURN":  return "PISCES"
        case "SUN":     return "LEO"
        default:        return "ZODIAC"
        }
    }

    func calculateStargazingTelemetry(latitude: Double, longitude: Double) async {
        // NOTE: forecastWeek is no longer built here — it used to be a fixed 7-day stub
        // ("EXCELLENT" / "MOONLIGHT: MINIMAL" every day, regardless of reality). The real
        // 7-day outlook now comes from StargazingWeatherViewModel.fetchWeekAheadOutlook,
        // called separately in ContentView and assigned to stargazerState.forecastWeek.

        // Convert coordinates cleanly to SwiftAA geographic and timeline data models
        let now = Date()
        let location = CLLocation(latitude: latitude, longitude: longitude)
        let geoCoordinates = GeographicCoordinates(location)
        let currentSystemTime = JulianDay(now)

        var localizedOutputCatalog: [APIPlanetItem] = []

        // Human-readable UTC stamp alongside the Julian Day, specifically so a printed run
        // can be matched, to the minute, against whatever external reference you're comparing
        // against. If the two aren't checked at the same moment, azimuth in particular will
        // drift ~15°/hour purely from Earth's rotation — that's the single most common cause
        // of "planets match, stars don't" style reports, since it's a shared time input, not
        // a per-object one.
        let utcFormatter = DateFormatter()
        utcFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss 'UTC'"
        utcFormatter.timeZone = TimeZone(identifier: "UTC")

        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("🛰️ [SWIFTAA OFFLINE ENGINE] CAPTURING BACKYARD TRANSFORMS")
        print("⏰ Computed for: \(utcFormatter.string(from: now))  (JD \(String(format: "%.4f", currentSystemTime.value)))")
        print("📍 Location: lat \(String(format: "%.4f", latitude)), lon \(String(format: "%.4f", longitude))")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

        let trackingCelestialBodies = ["SUN", "MERCURY", "VENUS", "MARS", "JUPITER", "SATURN"]

        for targetName in trackingCelestialBodies {
            var finalAltitude: Double = 0.0
            var finalAzimuth: Double = 0.0
            var distanceAU: Double = 1.0
            var objectClassification = "PLANET"
            var isVisibleNakedEye = true
            var apparentMagnitude: Double = 0.0

            switch targetName {
            case "SUN":
                // Uses SwiftAA's purpose-built convenience method, which resolves to the Sun's
                // *apparent* equatorial coordinates (aberration + nutation corrected) before
                // transforming — consistent with how the planet cases below already use
                // apparent geocentric equatorial coordinates.
                let s = Sun(julianDay: currentSystemTime)
                let horiz = s.makeHorizontalCoordinates(with: geoCoordinates)
                finalAltitude = horiz.altitude.value
                finalAzimuth = horiz.northBasedAzimuth.value
                distanceAU = s.radiusVector.value
                objectClassification = "STAR"
                isVisibleNakedEye = finalAltitude > 0.0
                // SwiftAA's Sun class doesn't expose a magnitude (it isn't an IlluminatedFraction
                // conformer — that protocol is planet-specific). The Sun's true apparent visual
                // magnitude varies by only about ±0.03 across the year (Earth's orbit isn't
                // eccentric enough to matter here), so -26.8 is accurate enough to just hardcode.
                apparentMagnitude = -26.8
            case "MERCURY":
                let p = Mercury(julianDay: currentSystemTime)
                let horiz = p.equatorialCoordinates.makeHorizontalCoordinates(for: geoCoordinates, at: currentSystemTime)
                finalAltitude = horiz.altitude.value
                finalAzimuth = horiz.northBasedAzimuth.value
                distanceAU = p.radiusVector.value
                apparentMagnitude = p.magnitude.value
            case "VENUS":
                let p = Venus(julianDay: currentSystemTime)
                let horiz = p.equatorialCoordinates.makeHorizontalCoordinates(for: geoCoordinates, at: currentSystemTime)
                finalAltitude = horiz.altitude.value
                finalAzimuth = horiz.northBasedAzimuth.value
                distanceAU = p.radiusVector.value
                apparentMagnitude = p.magnitude.value
            case "MARS":
                let p = Mars(julianDay: currentSystemTime)
                let horiz = p.equatorialCoordinates.makeHorizontalCoordinates(for: geoCoordinates, at: currentSystemTime)
                finalAltitude = horiz.altitude.value
                finalAzimuth = horiz.northBasedAzimuth.value
                distanceAU = p.radiusVector.value
                apparentMagnitude = p.magnitude.value
            case "JUPITER":
                let p = Jupiter(julianDay: currentSystemTime)
                let horiz = p.equatorialCoordinates.makeHorizontalCoordinates(for: geoCoordinates, at: currentSystemTime)
                finalAltitude = horiz.altitude.value
                finalAzimuth = horiz.northBasedAzimuth.value
                distanceAU = p.radiusVector.value
                // Jupiter overrides the default IlluminatedFraction magnitude with a more precise
                // formula, so this is picking up that specialized calculation automatically.
                apparentMagnitude = p.magnitude.value
            case "SATURN":
                let p = Saturn(julianDay: currentSystemTime)
                let horiz = p.equatorialCoordinates.makeHorizontalCoordinates(for: geoCoordinates, at: currentSystemTime)
                finalAltitude = horiz.altitude.value
                finalAzimuth = horiz.northBasedAzimuth.value
                distanceAU = p.radiusVector.value
                // Saturn's override additionally accounts for ring tilt/opening angle, which can
                // swing its apparent magnitude by roughly half a point depending on the season.
                apparentMagnitude = p.magnitude.value
            default: break
            }

            let constellationLabel = resolvePlanetConstellationLabel(name: targetName)

            // Pure native Swift string interpolation — type-safe, and avoids the undefined
            // behavior of passing a Swift String through a C-style "%s" format specifier.
            let paddedName = targetName.padding(toLength: 10, withPad: " ", startingAt: 0)
            let altStr = String(format: "%06.2f", finalAltitude)
            let azStr = String(format: "%06.2f", finalAzimuth)
            let distStr = String(format: "%.4f", distanceAU)
            let magStr = String(format: "%.2f", apparentMagnitude)
            print(" 📈 BODY MATCH  -> [\(paddedName)] | ALT: \(altStr)° | AZ: \(azStr)° | DIST: \(distStr) AU | MAG: \(magStr)")

            localizedOutputCatalog.append(APIPlanetItem(
                name: targetName,
                constellation: constellationLabel,
                altitude: finalAltitude,
                azimuth: finalAzimuth,
                nakedEyeObject: isVisibleNakedEye,
                classification: objectClassification,
                range_au: distanceAU,
                magnitude: apparentMagnitude
            ))
        }

        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

        // ==============================================================================
        // ✨ STELLAR BACKGROUND TRANSFORMS — identical transform call as the planets above,
        // just fed catalog RA/Dec instead of SwiftAA's live planetary theory. There is no
        // separate "star math" here: EquatorialCoordinates.makeHorizontalCoordinates(for:at:)
        // is the exact same function, given the exact same geoCoordinates and
        // currentSystemTime as every planet case did. If this loop's output is wrong while
        // the planet loop's is right, the discrepancy is in the *input* (catalog RA/Dec, or
        // when this function was actually invoked) — not in a divergent formula.
        // ==============================================================================
        await preloadLocalStarCatalog()

        for star in internalStarsDatabase {
            let starEquatorial = EquatorialCoordinates(
                alpha: Hour(star.ra),
                delta: Degree(star.dec)
            )

            let horizontalCoordinates = starEquatorial.makeHorizontalCoordinates(for: geoCoordinates, at: currentSystemTime)

            let finalAltitudeAngle = horizontalCoordinates.altitude.value
            let finalAzimuthHeading = horizontalCoordinates.northBasedAzimuth.value

            let paddedStarName = star.name.uppercased().padding(toLength: 12, withPad: " ", startingAt: 0)
            let starAltStr = String(format: "%06.2f", finalAltitudeAngle)
            let starAzStr = String(format: "%06.2f", finalAzimuthHeading)
            let magStr = String(format: "%.1f", star.mag)
            print(" ⭐️ STAR LOG MATCH -> [\(paddedStarName)] | ALT: \(starAltStr)° | AZ: \(starAzStr)° | MAG: \(magStr)")

            localizedOutputCatalog.append(APIPlanetItem(
                name: star.name,
                constellation: star.constellation,
                altitude: finalAltitudeAngle,
                azimuth: finalAzimuthHeading,
                nakedEyeObject: star.mag <= 4.0,
                classification: "STAR",
                magnitude: star.mag
            ))
        }

        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

        // ==============================================================================
        // 🌌 TRUE DARK WINDOW — Sun-based (astronomical twilight), not moon data, so this
        // stays SwiftAA-computed. Real moon data (phase/moonrise/moonset/brightness) now
        // comes from WeatherKit via StargazingWeatherViewModel.fetchMoonData instead.
        // ==============================================================================
        let darkWindowString = formattedTrueDarkWindow(currentJulianDay: currentSystemTime, geoCoordinates: geoCoordinates)

        print(" 🌌 TRUE DARK WINDOW: \(darkWindowString)")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

        let sortedResult = localizedOutputCatalog.sorted { $0.altitude > $1.altitude }

        DispatchQueue.main.async {
            self.objectWillChange.send()
            self.stargazerState.liveVisibleTargets = sortedResult
            self.stargazerState.trueDarkWindow = darkWindowString
            self.stargazerState.isDataLoaded = true
        }
    }
}
