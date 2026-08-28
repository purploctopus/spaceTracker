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
    
    // 🌙 MOON DATA — sourced from WeatherKit's daily forecast, same service/entitlement
    // already used for cloud cover above, rather than a separate SwiftAA calculation.
    @Published var moonPhaseDescription: String = "CALCULATING..."
    @Published var moonriseTimeString: String = "--:--"
    @Published var moonsetTimeString: String = "--:--"
    /// WeatherKit only exposes an 8-bucket MoonPhase, not a continuous illuminated
    /// percentage — this is a representative estimate derived from that bucket (see
    /// illuminationEstimate(for:) below), not a precise measurement.
    @Published var moonIlluminationEstimate: Double = 0.0
    /// How many magnitudes of naked-eye reach tonight's moonlight costs you, feeding the
    /// visibility badge in LiveSkyViewfinderOverlay. Unlike the previous SwiftAA version,
    /// this can't smoothly taper by the moon's actual altitude in the sky — WeatherKit
    /// doesn't expose live moon position, only rise/set times — so it's a simpler
    /// above/below-horizon gate instead. See fetchMoonData below for the reasoning.
    @Published var moonBrightnessPenalty: Double = 0.0
    
    // 🎯 OBSERVATION QUALITY — a real composite score now, computed from the cloud cover,
    // humidity, and moon brightness data already above. Moved here (was a hardcoded stub in
    // StargazerState) since its inputs all live in this view model.
    @Published var observationIndex: Int = 0
    @Published var observationQualityLabel: String = "CALCULATING..."
    
    private let weatherService = WeatherService.shared
    
    /// Maps WeatherKit's 8-bucket MoonPhase to a representative illuminated-fraction
    /// estimate. Exact at the four named syzygy points (new/quarter/full/quarter); the
    /// crescent/gibbous buckets use their midpoint as a reasonable stand-in since WeatherKit
    /// doesn't give a continuous value.
    private func illuminationEstimate(for phase: MoonPhase) -> Double {
        switch phase {
        case .new: return 0.0
        case .waxingCrescent, .waningCrescent: return 0.25
        case .firstQuarter, .lastQuarter: return 0.5
        case .waxingGibbous, .waningGibbous: return 0.75
        case .full: return 1.0
        @unknown default: return 0.5
        }
    }
    
    /// Fetches today's moon phase, moonrise, and moonset from WeatherKit's daily forecast,
    /// and derives the same brightness-penalty concept the visibility badge already expects.
    func fetchMoonData(lat: Double, lng: Double) async {
        let location = CLLocation(latitude: lat, longitude: lng)
        
        do {
            print("📡 [WEATHERKIT]: Requesting daily forecast for moon data...")
            let dailyForecast = try await weatherService.weather(for: location, including: .daily)
            
            guard let today = dailyForecast.first(where: { Calendar.current.isDateInToday($0.date) }) ?? dailyForecast.first else {
                print("❌ [WEATHERKIT MOON]: No daily forecast entry available.")
                return
            }
            
            let phase = today.moon.phase
            self.moonPhaseDescription = phase.description.uppercased()
            
            let timeFormatter = DateFormatter()
            timeFormatter.timeStyle = .short
            
            let moonrise = today.moon.moonrise
            let moonset = today.moon.moonset
            
            self.moonriseTimeString = moonrise.map { timeFormatter.string(from: $0) } ?? "DOES NOT RISE TODAY"
            self.moonsetTimeString = moonset.map { timeFormatter.string(from: $0) } ?? "DOES NOT SET TODAY"
            
            let illumination = illuminationEstimate(for: phase)
            self.moonIlluminationEstimate = illumination
            
            // Determine whether the moon is up right now from today's rise/set pair. The
            // ordering matters: if moonrise comes before moonset, the moon is up strictly
            // between them (the common case). If moonset comes first, that means the moon
            // was already up from a rise yesterday, sets at that time, then rises again
            // later the same day — so it's up everywhere EXCEPT between those two times.
            let now = Date()
            let moonIsUp: Bool
            switch (moonrise, moonset) {
            case let (.some(rise), .some(set)) where rise < set:
                moonIsUp = (now >= rise && now <= set)
            case let (.some(rise), .some(set)) where set < rise:
                moonIsUp = (now <= set || now >= rise)
            default:
                // Missing one or both events for today — can't determine precisely.
                // Default to applying the penalty, which is the more conservative choice
                // for a visibility badge (better to under-promise than over-promise).
                moonIsUp = true
            }
            
            self.moonBrightnessPenalty = moonIsUp ? (3.5 * illumination) : 0.0
            
            print("✅ [WEATHERKIT MOON]: \(phase.description), illumination ≈\(Int(illumination * 100))%, rise \(self.moonriseTimeString), set \(self.moonsetTimeString), penalty -\(String(format: "%.1f", self.moonBrightnessPenalty)) mag")
        } catch {
            print("❌ [WEATHERKIT MOON ERROR]: \(error.localizedDescription)")
        }
    }
    
    // ==============================================================================
    // 🎯 OBSERVATION QUALITY SCORE — replaces the old hardcoded 85%/"OPTIMAL" stub
    // ==============================================================================
    /// Combines cloud cover, humidity, and tonight's moon brightness penalty into a single
    /// 0–100 "how good is stargazing right now" score. Weights are a reasonable rule of
    /// thumb, not a rigorously derived formula: clouds are the dominant, near-binary
    /// blocker (a heavily overcast sky ends the conversation regardless of anything else),
    /// humidity only matters once it's high enough to suggest haze/dew, and moonlight is a
    /// real but comparatively gentler factor.
    private func computeObservationIndex(cloudCoverPercent: Int, humidityPercent: Int, moonBrightnessPenalty: Double, moonIlluminationEstimate: Double) -> Int {
        var score = 100.0
        score -= Double(cloudCoverPercent) * 0.6
        score -= Double(max(0, humidityPercent - 70)) * 1.0
        // Horizon-gated term: real impact from moonBrightnessPenalty when the moon is
        // actually up right now (see fetchMoonData's moonIsUp logic).
        score -= moonBrightnessPenalty * 8.0
        // Flat, ungated dampener: nudges the score down based purely on how full the moon
        // is tonight, independent of the above/below-horizon gate. This is the deliberately
        // invented part — not a physical model, just "a big bright moon should visibly cost
        // you something even if the precise up/down timing is a little off" — so the score
        // doesn't swing wildly on gate precision alone.
        score -= moonIlluminationEstimate * 20.0
        return min(max(Int(score.rounded()), 0), 100)
    }
    
    private func qualityLabel(forScore score: Int) -> String {
        switch score {
        case 80...100: return "OPTIMAL"
        case 55..<80: return "GOOD"
        case 30..<55: return "FAIR"
        default: return "POOR"
        }
    }
    
    /// Recomputes the observation score from this view model's own already-published
    /// cloud/humidity/moon values. Call after fetchStargazingWeather and fetchMoonData have
    /// both completed — the score needs both.
    func updateObservationIndex() {
        let score = computeObservationIndex(
            cloudCoverPercent: cloudCoverPercent,
            humidityPercent: humidityPercent,
            moonBrightnessPenalty: moonBrightnessPenalty,
            moonIlluminationEstimate: moonIlluminationEstimate
        )
        self.observationIndex = score
        self.observationQualityLabel = qualityLabel(forScore: score)
    }
    
    // ==============================================================================
    // 📅 7-DAY OUTLOOK — replaces the hardcoded "EXCELLENT" / "MOONLIGHT: MINIMAL" stub
    // ==============================================================================
    /// Builds a real 7-day outlook from WeatherKit's daily forecast: DayWeather doesn't
    /// expose a numeric cloud-cover percentage (that's an hourly/current-only field), so
    /// `condition` — a real WeatherCondition enum — stands in as the daily sky-clarity
    /// signal instead of pulling and averaging 7 days of hourly data. Moonlight commentary
    /// uses that day's actual moon phase, not a fixed guess.
    func fetchWeekAheadOutlook(lat: Double, lng: Double) async -> [StargazeForecastDay] {
        let location = CLLocation(latitude: lat, longitude: lng)
        
        let dayLabelFormatter = DateFormatter()
        dayLabelFormatter.dateFormat = "EEE MMM d"
        dayLabelFormatter.locale = Locale(identifier: "en_US")
        
        do {
            print("📡 [WEATHERKIT]: Requesting 7-day outlook...")
            let dailyForecast = try await weatherService.weather(for: location, including: .daily)
            
            let outlook = dailyForecast.prefix(7).map { day -> StargazeForecastDay in
                let dayLabel = dayLabelFormatter.string(from: day.date).uppercased()
                let illumination = illuminationEstimate(for: day.moon.phase)
                let grade = combinedNightGrade(condition: day.condition, moonIllumination: illumination)
                let commentary = "MOONLIGHT: \(Int(illumination * 100))% (\(day.moon.phase.description.uppercased()))"
                return StargazeForecastDay(dayLabel: dayLabel, conditionGrade: grade, commentary: commentary)
            }
            
            print("✅ [WEATHERKIT]: 7-day outlook built (\(outlook.count) days).")
            return Array(outlook)
        } catch {
            print("❌ [WEATHERKIT WEEK OUTLOOK ERROR]: \(error.localizedDescription)")
            return []
        }
    }
    
    /// Combines that day's sky condition with its moon illumination into a single grade —
    /// unlike a first pass at this that graded purely on cloud condition and let moonlight
    /// sit unused in the commentary text, which could show "EXCELLENT" right next to
    /// "MOONLIGHT: 100% (FULL MOON)". More moonlight should make a night worse for
    /// stargazing, same direction as the live observation score, not be ignored.
    ///
    /// This is a simplified version of that same idea, not identical to it: unlike the live
    /// score, this can't know whether the moon will actually be above the horizon during
    /// the dark hours of a *future* night, so it scales purely by illumination percentage as
    /// a reasonable approximation rather than a precise per-night prediction.
    private func combinedNightGrade(condition: WeatherCondition, moonIllumination: Double) -> String {
        let baseScore: Double
        switch condition {
        case .clear, .mostlyClear: baseScore = 100
        case .partlyCloudy: baseScore = 75
        case .mostlyCloudy: baseScore = 50
        default: baseScore = 20
        }
        
        let moonPenalty = moonIllumination * 30.0
        let score = baseScore - moonPenalty
        
        switch score {
        case 80...: return "EXCELLENT"
        case 55..<80: return "GOOD"
        case 30..<55: return "FAIR"
        default: return "POOR"
        }
    }
    
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
