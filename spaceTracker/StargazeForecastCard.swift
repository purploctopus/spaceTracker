//
//  StargazeForecastCard.swift
//  spaceTracker
//
//  Created by Ben Clary on 8/14/26.
//  MAKE AN APP COLIN LOVES AND USES AND SUPPORTS SARA'S FREEDOM!

import SwiftUI

// ==============================================================================
// 🎛️ CARD ROW CELL: HORIZONTAL SCROLL FORECAST NIGHTS
// ==============================================================================
struct StargazeForecastCard: View {
    let day: StargazeForecastDay
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(day.dayLabel)
                .font(.system(.caption, design: .monospaced))
                .fontWeight(.bold)
                .foregroundColor(.secondary)
            
            Text(day.conditionGrade.uppercased())
                .font(.system(.subheadline, design: .monospaced))
                .fontWeight(.bold)
                .foregroundColor(gradeColor(day.conditionGrade))
            
            Text(day.commentary)
                .font(.system(.caption2, design: .default))
                .foregroundColor(.secondary)
                .lineLimit(3)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Spacer(minLength: 0)
        }
        .padding()
        .frame(width: 150, height: 130)
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
    
    private func gradeColor(_ grade: String) -> Color {
        switch grade.uppercased() {
        case "EXCELLENT": return .green
        case "MARGINAL": return .orange
        default: return .red
        }
    }
}

// ==============================================================================
// 🎯 REAL-TIME CELESTIAL TARGET CELL VIEW COMPONENT
// ==============================================================================
struct CelestialTargetRowView: View {
    let planet: APIPlanetItem
    
    // 💡 THE BUG FIX: Check the exact hour integer on the phone clock directly.
    // True if the current local time sits inside active daytime brackets (6 AM to 7 PM).
    private var isDaytime: Bool {
        let currentHour = Calendar.current.component(.hour, from: Date())
        return currentHour >= 6 && currentHour < 19
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(planet.name.uppercased())
                        .font(.system(.subheadline, design: .monospaced))
                        .fontWeight(.bold)
                        // Dim the row text color down to secondary if daylight blocks it out
                        .foregroundColor(shouldObscure(planet.name) ? .secondary : .primary)
                    
                    Text("// CONSTELLATION: \(planet.constellation.uppercased())")
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundColor(shouldObscure(planet.name) ? .gray : .accentColor)
                }
                
                HStack(spacing: 16) {
                    Label("AZIMUTH: \(Int(planet.azimuth))° (\(compassDirection(planet.azimuth)))", systemImage: "safari")
                    Label("ALTITUDE: \(Int(planet.altitude))°", systemImage: "arrow.up.and.right")
                }
                .font(.system(.caption2, design: .monospaced))
                .foregroundColor(.secondary)
                .opacity(shouldObscure(planet.name) ? 0.4 : 1.0)
            }
            
            Spacer()
            
            // 💡 DYNAMIC STATUS LABELS: Instantly toggles based on local astronomical visibility
            if shouldObscure(planet.name) {
                Text("DAYLIGHT OBSCURED")
                    .font(.system(.caption2, design: .monospaced))
                    .fontWeight(.bold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.red.opacity(0.1))
                    .foregroundColor(.red)
                    .cornerRadius(4)
            } else {
                Text(planet.nakedEyeObject ? "NAKED EYE" : "BINOCULARS")
                    .font(.system(.caption2, design: .monospaced))
                    .fontWeight(.bold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(planet.nakedEyeObject ? Color.green.opacity(0.1) : Color.blue.opacity(0.1))
                    .foregroundColor(planet.nakedEyeObject ? .green : .blue)
                    .cornerRadius(4)
            }
        }
        .padding(.vertical, 10)
    }
    
    /// Core visibility check logic: The Sun and Moon are always visible, other planets get obscured during the day.
    private func shouldObscure(_ targetName: String) -> Bool {
        let normalizedName = targetName.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if normalizedName == "SUN" || normalizedName == "MOON" { return false }
        return isDaytime
    }
    
    private func compassDirection(_ heading: Double) -> String {
        let directions = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
        let index = Int((heading + 22.5).truncatingRemainder(dividingBy: 360.0) / 45.0)
        return directions[max(0, min(index, 7))]
    }
}
