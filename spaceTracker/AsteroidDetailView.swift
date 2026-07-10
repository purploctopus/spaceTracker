//
//  AsteroidDetailView.swift
//  spaceTracker
//
//  Created by Ben Clary on 7/10/26.
//

import SwiftUI

import SwiftUI

// MARK: - 🗺️ UNIFIED INTERACTIVE POPUP DETAIL WINDOW
struct AsteroidDetailView: View {
    let asteroid: Asteroid
    let userLatitude: Double
    let userLongitude: Double
    @Environment(\.dismiss) var dismiss
    
    // 💡 SHIELD 1: Isolated horizon math expression satisfies the type-checker [1.1]
    private var horizon: (altitude: Int, azimuth: Int, compassHeading: String) {
        asteroid.calculateLocalHorizonCoordinates(lat: userLatitude, lng: userLongitude)
    }
    
    // 💡 SHIELD 2: Pre-calculated visibility status removes compilation timeouts forever! [1.1]
    private var visibilityStatus: (text: String, isVisibleNow: Bool, isTooDim: Bool) {
        asteroid.fetchLiveVisibilityDescriptor(lat: userLatitude, lng: userLongitude)
    }
    
    var body: some View {
        ZStack {
            // Dark Slate Backing Plate
            Color(red: 0.04, green: 0.04, blue: 0.04)
                .ignoresSafeArea()
            
            VStack(alignment: .leading, spacing: 24) {
                // Header Control Panel Block Node
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(asteroid.name.uppercased())
                            .font(.system(.title2, design: .monospaced))
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        Text("OBJECT CLASSIFICATION: NEAR-EARTH ASTEROID (NEO)")
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
                
                // HERO RADAR COMPASS LAYER: Shows the user exactly where in the sky to look
                HStack {
                    Spacer()
                    ZStack {
                        // Outer Radar Rings
                        Circle()
                            .stroke(Color.white.opacity(0.05), lineWidth: 1)
                            .frame(width: 160, height: 160)
                        
                        Circle()
                            .stroke(Color.cyan.opacity(0.12), lineWidth: 1)
                            .frame(width: 110, height: 110)
                        
                        // Crosshair Calibration Lines
                        Rectangle()
                            .fill(Color.white.opacity(0.05))
                            .frame(width: 180, height: 1)
                        Rectangle()
                            .fill(Color.white.opacity(0.05))
                            .frame(width: 1, height: 180)
                        
                        // Cardinal Position Reference Stamps
                        Text("N").font(.system(size: 8, design: .monospaced)).foregroundColor(.gray).offset(y: -90)
                        Text("S").font(.system(size: 8, design: .monospaced)).foregroundColor(.gray).offset(y: 90)
                        Text("E").font(.system(size: 8, design: .monospaced)).foregroundColor(.gray).offset(x: 90)
                        Text("W").font(.system(size: 8, design: .monospaced)).foregroundColor(.gray).offset(x: -90)
                        
                        // LIVE TARGET TRACKING INDICATOR DOT
                        if horizon.altitude > 0 {
                            Circle()
                                .fill(asteroid.is_potentially_hazardous_asteroid ? Color.red : Color.cyan)
                                .frame(width: 8, height: 8)
                                .shadow(color: asteroid.is_potentially_hazardous_asteroid ? Color.red : Color.cyan, radius: 4)
                                .offset(y: -55)
                                .rotationEffect(.degrees(Double(horizon.azimuth)))
                        }
                    }
                    Spacer()
                }
                .padding(.vertical, 10)
                
                // Tactical Operational Status Metrics Table
                VStack(spacing: 0) {
                    telemetryRow(label: "CLOSE APPROACH TIMELINE", value: asteroid.localDateDisplay)
                    telemetryRow(label: "THREAT RECON INDEX", value: asteroid.is_potentially_hazardous_asteroid ? "⚠️ HIGH POTENTIAL HAZARD" : "SAFE / CLEAR TRAJECTORY", valueColor: asteroid.is_potentially_hazardous_asteroid ? .red : .green)
                    telemetryRow(label: "MISS DISTANCE EXPONENT", value: "\(asteroid.missDistanceLunar) LUNAR DISTANCES (LD)")
                    telemetryRow(label: "BOULDER CORE FOOTPRINT", value: "≈ \(asteroid.maxDiameterMeters) METERS MAX DIAMETER")
                    
                    // 💡 FIXED: Uses pre-calculated property streams to prevent nesting bottlenecks [1.1]
                    if horizon.altitude > 0 {
                        telemetryRow(label: "COMPASS ACQUISITION BEARING", value: "\(horizon.azimuth)° BEARING (\(horizon.compassHeading))", valueColor: .cyan)
                        telemetryRow(label: "SKY ELEVATION ANGLE", value: "\(horizon.altitude)° VERTICAL UP", valueColor: .cyan)
                        telemetryRow(label: "BACKYARD VISIBILITY STATUS", value: visibilityStatus.text.uppercased(), valueColor: visibilityStatus.isVisibleNow ? .green : .gray)
                    } else {
                        telemetryRow(label: "RADAR TRACKING VECTOR", value: "BELOW HORIZON (UNAVAILABLE FOR VISUAL SCAN)", valueColor: .red)
                    }
                }
                .border(Color.white.opacity(0.1), width: 1)
                
                // Dynamic Spectral Intel Field Report
                VStack(alignment: .leading, spacing: 8) {
                    Text("DYNAMIC SPECTRAL INTEL REPORT //")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.yellow)
                    
                    Text(asteroid.is_potentially_hazardous_asteroid ?
                         "UPSTREAM MONITOR DATA SHIELDS SHOW AN EXTENDED RADAR MASS RETICLE WITH AN ORBIT VECTOR THAT CROSSES KEY INTERCEPT PLANES. PERMANENT WATCH SEQUENCE LOCKED IN SYSTEM CHANNELS." :
                         "TRAJECTORY COMPUTATIONS DEMONSTRATE COLD INERTIAL PASS SPEEDS FREE OF GRAVITATIONAL INTERFERENCE FIELDS. RADAR LANE IS CLEAR FOR UNRESTRICTED TRACKING LOOPS.")
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
    
    // MATRIX ELEMENT BUILDER
    private func telemetryRow(label: String, value: String, valueColor: Color = .white) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(.gray)
            Spacer()
            Text(value)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(valueColor)
        }
        .padding(12)
        .background(Color.white.opacity(0.01))
        .overlay(
            Rectangle()
                .stroke(Color.white.opacity(0.04), lineWidth: 1)
        )
    }
}


// MARK: - COMPACT MATRIX ROW REUSABLE UTILITY
struct TelemetryRow: View {
    let label: String
    let value: String
    var valueColor: Color = .white
    
    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(.gray)
            Spacer()
            Text(value)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundColor(valueColor)
        }
        .padding(8)
        .background(Color.white.opacity(0.01))
        .overlay(Rectangle().stroke(Color.white.opacity(0.04), lineWidth: 1))
    }
}
