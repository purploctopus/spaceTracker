//
//  LiveSkyViewfinderOverlay.swift
//  spaceTracker
//
//  Created by Ben Clary on 8/14/26.
//  MAKE AN APP COLIN LOVES AND SUPPORTS SARA'S FREEDOM

import SwiftUI

// ==============================================================================
// 🪐 FULL-SCREEN TELEMETRY VIEW: THE LIVE SKY POINTER VIEW-PORTS
// ==============================================================================
struct LiveSkyViewfinderOverlay: View {
    @Environment(\.dismiss) private var dismiss
    
    // Telemetry storage variables to receive gyroscope motion streaming values
    @State private var deviceAzimuthHeading: Double = 0.0
    @State private var deviceAltitudeTilt: Double = 0.0
    
    var body: some View {
        ZStack {
            // 💡 THE BACKGROUND: Dark ambient void to protect nighttime dark adaptation
            Color.black
                .ignoresSafeArea()
            
            // Sub-layer decorative tactical matrix grid lines
            ViewfinderBackgroundGridLines()
                .stroke(Color.cyan.opacity(0.1), lineWidth: 1)
                .ignoresSafeArea()
            
            // ==============================================================================
            // LAYER 1: MAIN RADAR HEADS-UP DISPLAY (HUD)
            // ==============================================================================
            VStack(spacing: 0) {
                // Top Operational Telemetry Bar Header Grid
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("SYSTEM: LIVE SKY VECTOR PORT")
                            .font(.system(.caption, design: .monospaced))
                            .fontWeight(.bold)
                            .foregroundColor(.cyan)
                        Text("COORDINATE SYSTEM: HORIZON LOCAL")
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // Direct interactive close command trigger button
                    Button(action: { dismiss() }) {
                        Text("DISENGAGE")
                            .font(.system(.caption, design: .monospaced))
                            .fontWeight(.bold)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.red.opacity(0.1))
                            .foregroundColor(.red)
                            .cornerRadius(4)
                    }
                }
                .padding()
                .background(Color(.systemGray6).opacity(0.1))
                
                // Active Target Crosshair Readout Center Block
                Spacer()
                
                ZStack {
                    // Center Targeting Sight Reticle Rings
                    Circle()
                        .stroke(Color.cyan.opacity(0.2), lineWidth: 1)
                        .frame(width: 240, height: 240)
                    
                    Circle()
                        .stroke(Color.cyan, lineWidth: 2)
                        .frame(width: 140, height: 140)
                    
                    // Precision crosshair hair segments
                    Rectangle()
                        .fill(Color.cyan)
                        .frame(width: 30, height: 1)
                    Rectangle()
                        .fill(Color.cyan)
                        .frame(width: 1, height: 30)
                    
                    // Dynamic live position tracking tag label floating right near crosshairs
                    VStack {
                        Text("AZ: \(Int(deviceAzimuthHeading))°")
                        Text("ALT: \(Int(deviceAltitudeTilt))°")
                    }
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundColor(.cyan)
                    .padding(6)
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(4)
                    .offset(x: 90, y: -60)
                }
                
                Spacer()
                
                // Bottom Live Heading Direction Dashboard Footers
                HStack(spacing: 40) {
                    VStack(spacing: 2) {
                        Text("HEADING COMPASS")
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundColor(.secondary)
                        Text("\(Int(deviceAzimuthHeading))° \(getCompassLabel(deviceAzimuthHeading))")
                            .font(.system(.headline, design: .monospaced))
                            .foregroundColor(.primary)
                    }
                    
                    VStack(spacing: 2) {
                        Text("TILT PITCH ANGLE")
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundColor(.secondary)
                        Text("\(Int(deviceAltitudeTilt))°")
                            .font(.system(.headline, design: .monospaced))
                            .foregroundColor(.primary)
                    }
                }
                .padding(.bottom, 40)
            }
        }
        .navigationBarHidden(true)
    }
    
    // Quick geometry converter translating compass degrees to layout labels
    private func getCompassLabel(_ angle: Double) -> String {
        let sectors = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
        let index = Int((angle + 22.5).truncatingRemainder(dividingBy: 360.0) / 45.0)
        return sectors[max(0, min(index, 7))]
    }
}

// MARK: - 🗺️ VIEW LAYER GRAPHIC DETAIL LINING STRUCT
struct ViewfinderBackgroundGridLines: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let midX = rect.midX
        let midY = rect.midY
        
        // Draw extended alignment tracking cross axis lines across the screen space
        path.move(to: CGPoint(x: midX, y: rect.minY))
        path.addLine(to: CGPoint(x: midX, y: rect.maxY))
        path.move(to: CGPoint(x: rect.minX, y: midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: midY))
        
        return path
    }
}
