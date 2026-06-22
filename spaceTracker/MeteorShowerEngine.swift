//
//  MeteorShowerEngine.swift
//  spaceTracker
//
//  Created by Ben Clary on 6/22/26.
//

import Foundation
import SwiftUI
import Combine

// MARK: - 1. THE DATA MODELS
struct MeteorShower: Identifiable {
    let id = UUID()
    let name: String
    let peakDateStr: String // Format: YYYY-MM-DD
    let peakZHR: Int       // Zenithal Hourly Rate (approx flakes per hour)
    let parentComet: String
    let optimalLatitude: Double // Ideal celestial peak inclination center point
    
    var localPeakDisplay: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: peakDateStr) else { return peakDateStr }
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date).uppercased()
    }
}

// MARK: - 2. THE LOCALIZED LOOKAHEAD ENGINE
class MeteorShowerViewModel: ObservableObject {
    @Published var upcomingShowers: [MeteorShower] = []
    
    // Curated scientific baseline dataset of major stable annual meteor streams
    private let annualMasterDatabase: [MeteorShower] = [
        MeteorShower(name: "Quadrantids", peakDateStr: "2026-01-03", peakZHR: 120, parentComet: "Asteroid 2003 EH1", optimalLatitude: 45.0),
        MeteorShower(name: "Lyrids", peakDateStr: "2026-04-22", peakZHR: 18, parentComet: "Comet Thatcher", optimalLatitude: 34.0),
        MeteorShower(name: "Eta Aquariids", peakDateStr: "2026-05-06", peakZHR: 50, parentComet: "Halley's Comet", optimalLatitude: -15.0),
        MeteorShower(name: "Delta Aquariids", peakDateStr: "2026-07-30", peakZHR: 20, parentComet: "Comet 96P/Machholz", optimalLatitude: -15.0),
        MeteorShower(name: "Perseids", peakDateStr: "2026-08-12", peakZHR: 100, parentComet: "Comet Swift-Tuttle", optimalLatitude: 58.0),
        MeteorShower(name: "Orionids", peakDateStr: "2026-10-21", peakZHR: 20, parentComet: "Halley's Comet", optimalLatitude: 0.0),
        MeteorShower(name: "Leonids", peakDateStr: "2026-11-17", peakZHR: 15, parentComet: "Comet Tempel-Tuttle", optimalLatitude: 22.0),
        MeteorShower(name: "Geminids", peakDateStr: "2026-12-14", peakZHR: 120, parentComet: "Asteroid 3200 Phaethon", optimalLatitude: 33.0),
        MeteorShower(name: "Ursids", peakDateStr: "2026-12-23", peakZHR: 10, parentComet: "Comet 8P/Tuttle", optimalLatitude: 76.0)
    ]
    
    func generateOutlook(userLatitude: Double) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        let now = Date()
        
        // Filter out dates that have already passed, shifting matching targets forward into the rolling calendar year outlook
        let adjustedShowers = annualMasterDatabase.map { shower -> MeteorShower in
            guard let peakDate = formatter.date(from: shower.peakDateStr) else { return shower }
            
            if peakDate < now {
                // If it passed this year, slide it smoothly into the next annual tracking bracket
                let components = shower.peakDateStr.split(separator: "-")
                if let currentYear = Int(components[0]) {
                    let nextYearStr = "\(currentYear + 1)-\(components[1])-\(components[2])"
                    return MeteorShower(name: shower.name, peakDateStr: nextYearStr, peakZHR: shower.peakZHR, parentComet: shower.parentComet, optimalLatitude: shower.optimalLatitude)
                }
            }
            return shower
        }
        
        // Sort everything linearly out sequentially over the next 12 months
        self.upcomingShowers = adjustedShowers.sorted { a, b in
            let dateA = formatter.date(from: a.peakDateStr) ?? Date.distantFuture
            let dateB = formatter.date(from: b.peakDateStr) ?? Date.distantFuture
            return dateA < dateB
        }
    }
    
    // 💡 LOCAL COMPASS COUPLING: Dynamically verify observation conditions based on coordinate vectors
    func checkObservingRating(shower: MeteorShower, userLatitude: Double) -> (text: String, isPoor: Bool) {
        let variance = abs(userLatitude - shower.optimalLatitude)
        
        if variance > 55 {
            return ("SUB-HORIZON / POOR", true)
        } else if variance > 30 {
            return ("LOW HORIZON / FAIR", false)
        } else {
            return ("EXCELLENT OUTLOOK", false)
        }
    }
}

// MARK: - 3. UI VIEW: METEOR SHOWER CELL CARD
struct MeteorShowerCardView: View {
    let shower: MeteorShower
    let userLatitude: Double
    let ratingEngine = MeteorShowerViewModel()
    
    var body: some View {
        let rating = ratingEngine.checkObservingRating(shower: shower, userLatitude: userLatitude)
        
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(shower.name.uppercased())
                    .font(.system(.subheadline, design: .monospaced))
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .lineLimit(1)
                Spacer()
                
                Text("\(shower.peakZHR) ZHR")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.cyan)
            }
            
            Text("PEAK: \(shower.localPeakDisplay)")
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.yellow)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("PARENT: \(shower.parentComet.uppercased())")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.gray)
                
                // Localized Status Flag text injection row
                Text("RADAR: \(rating.text)")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(rating.isPoor ? .orange : .green)
            }
        }
        .padding(14)
        .frame(width: 230, alignment: .leading)
        .background(Color.white.opacity(0.04))
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(rating.isPoor ? Color.orange.opacity(0.15) : Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}
// MARK: - 4. THE METEOR SHOWER STREAM PROFILE SHEET
struct MeteorShowerDetailSheet: View {
    let shower: MeteorShower
    let userLatitude: Double
    @Environment(\.dismiss) var dismiss
    
    // Curated field intelligence regarding observation constraints
    private var streamIntel: (bestTime: String, moonInterference: String, summary: String) {
        let name = shower.name.uppercased()
        if name.contains("PERSEIDS") {
            return ("22:00 PM TO 04:30 AM", "LOW OVERLAP // MODERATE RISK", "THE PERSEIDS ARE THE REIGNING HIGH-DENSITY VISUAL LIGHT SHOW OF THE SUMMER SKY. GENERATES BRIGHT FIREBALL EXTRACTIONS WITH ENHANCED TRAILING DEBRIS TRAILS.")
        } else if name.contains("GEMINIDS") {
            return ("21:00 PM TO 05:00 AM", "HIGH GLIDERS // LOW IMPACT", "THE GEMINIDS ARE UNIQUE COMING FROM AN ASTEROID RATHER THAN A COMET. RENDER HIGHLY MULTI-COLORED METEOR BURSTS THAT FLICKER AT SLOWER SKY TRAJECTORY SPEEDS.")
        } else if name.contains("QUADRANTIDS") {
            return ("02:00 AM TO BREAK OF DAWN", "INTENSE BURST // WINDOW IS SHORTER THAN 6 HOURS", "THE QUADRANTIDS HAVE A SHARP, HIGH-VOLUME MAXIMUM TRAJECTORY BLIP WINDOW. DEMANDS AN OPEN SKY VIEW FACING NORTHERN SKY ARC ANGLES.")
        } else if name.contains("ETA AQUARIIDS") || name.contains("DELTA AQUARIIDS") {
            return ("03:00 AM TO SUNRISE COLD LINE", "SOUTHERN INCIDENCE // MODERATE DEPTH", "BEST OBSERVED FROM SOUTHERN TRACKS OR LOW NORTHERN VECTOR QUADRANTS. STREAMING FRAGMENTS LEAVE STABLE IONIZED TRAILING DRIFT SMOKE CELLS IN THE UPPER RECON SPHERE.")
        } else if name.contains("LYRIDS") {
            return ("23:00 PM TO 04:00 AM", "VARIABLE LOGS // PERSISTENT FLAKES", "ONE OF THE OLDEST RECORDED STREAMS IN THE ARCHIVES. CAN SPORADICALLY SURGE WITH RADIANT BLOCKS UP TO 100 METEORS PER HOUR IF THE MAIN FILAMENT INTERCEPTS THE EARTH.")
        } else if name.contains("LEONIDS") {
            return ("03:00 AM UNTIL DAWN SYNC", "FAST STRIKES // HIGH VELOCITY", "THE LEONID FRAGMENTS INTERCEPT EARTH AT RECORD TRAJECTORY VELOCITIES OF 71 KM/S. HISTORICALLY TRIGGER METEOR STORMS EVERY 33 YEARS IN THE CYCLICAL RANGE.")
        }
        return ("00:00 AM TO 04:00 AM LOCAL", "MONITOR LOCAL SKY CLEARANCE", "ANNUAL COMETARY DUST DEBRIS INTERCEPT COMPONENT. OPTIMAL OBSERVATION TRACKING IN DARK RURAL RADIAL FIELDS AWAY FROM URBAN LIGHT ARTIFACT BLOCKS.")
    }
    
    var body: some View {
        ZStack {
            Color(red: 0.04, green: 0.04, blue: 0.04).ignoresSafeArea()
            
            VStack(alignment: .leading, spacing: 24) {
                // Header Control Panel Block Node
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(shower.name.uppercased())
                            .font(.system(.title2, design: .monospaced))
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        Text("STREAM CLASS: ANNUAL COMETARY FILAMENT")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.cyan)
                    }
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.gray)
                    }
                }
                .padding(.bottom, 8)
                
                // Tactical Operational Status Metrics Table
                VStack(spacing: 0) {
                    telemetryRow(label: "PEAK TRACK TIMELINE", value: shower.localPeakDisplay)
                    telemetryRow(label: "ZENITH HOURLY DEPTH", value: "\(shower.peakZHR) PARTICLES/H")
                    telemetryRow(label: "OPTIMAL SPECTRAL TIME", value: streamIntel.bestTime)
                    telemetryRow(label: "MOON ILLUMINATION RISK", value: streamIntel.moonInterference)
                    telemetryRow(label: "COMET PROGENITOR CELL", value: shower.parentComet)
                }
                .border(Color.white.opacity(0.1), width: 1)
                
                // Mission Observation Narrative
                VStack(alignment: .leading, spacing: 8) {
                    Text("STREAM INTELLIGENCE FIELD REPORT //")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.yellow)
                    Text(streamIntel.summary)
                        .font(.system(.subheadline, design: .monospaced))
                        .foregroundColor(.gray)
                        .lineSpacing(4)
                }
                
                Spacer()
            }
            .padding(24)
        }
        .preferredColorScheme(.dark)
    }
    
    private func telemetryRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.secondary)
            Spacer()
            Text(value.uppercased())
                .font(.system(.caption, design: .monospaced))
                .fontWeight(.bold)
                .foregroundColor(.white)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .background(Color.white.opacity(0.01))
        .overlay(Rectangle().stroke(Color.white.opacity(0.04), lineWidth: 0.5))
    }
}
