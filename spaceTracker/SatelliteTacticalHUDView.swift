//
//  SatelliteTacticalHUDView.swift
//  spaceTracker
//
//  Created by Ben Clary on 6/24/26.
//  make an app colin loves

import SwiftUI

struct SatelliteTacticalHUDView: View {
    let pass: SatellitePass
    let userHeading: Double
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack {
            // Absolute black void background canvas plate
            Color.black.ignoresSafeArea()
            
            // Background Tactical Grid Texture Accents
            GeometryReader { geo in
                Path { p in
                    // Fine crosshair alignment marks stretching to the edges of the display glass
                    p.move(to: CGPoint(x: geo.size.width / 2, y: 0))
                    p.addLine(to: CGPoint(x: geo.size.width / 2, y: geo.size.height))
                    p.move(to: CGPoint(x: 0, y: geo.size.height / 2))
                    p.addLine(to: CGPoint(x: geo.size.width, y: geo.size.height / 2))
                }
                .stroke(Color.cyan.opacity(0.03), lineWidth: 1)
            }
            .ignoresSafeArea()
            
            // MAIN COMPONENT STACK
            VStack {
                // Top Telemetry Header Status Bar
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("TARGET LOCK // \(pass.name.uppercased())")
                            .font(.system(.headline, design: .monospaced))
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        Text("NORAD ID: #\(pass.id) • MAX ELEVATION: \(Int(pass.peakElevationDegrees))°")
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundColor(.cyan)
                    }
                    
                    Spacer()
                    
                    // High-Tech Close Button Matrix
                    Button(action: { dismiss() }) {
                        HStack(spacing: 6) {
                            Text("CLOSE HUD")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                            Image(systemName: "scope")
                                .font(.caption)
                        }
                        .foregroundColor(.black)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.cyan)
                        .cornerRadius(4)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                
                Spacer()
                
                // THE HERO CORE: Maximize the Radar circle scale bounds across the canvas space
                CompassRadarView(pass: pass, userHeading: userHeading)
                    .scaleEffect(1.15) // Slightly boost vector assets resolution scale
                    .frame(maxWidth: 550, maxHeight: 550) // Cap upper bounds layout safety for wide iPads
                    .padding(24)
                
                Spacer()
                
                // Bottom Real-Time Flight Vector Sub-Display Readout panel
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("ORBITAL VECTOR TRACK")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(.gray)
                        Text(pass.travelDirection.uppercased())
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.yellow)
                            .fontWeight(.bold)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("WINDOW TIME REMAINING")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(.gray)
                        Text("\(pass.durationMinutes) MINUTES ACTIVE")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.green) // Match your custom theme color color token
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
            }
        }
        .preferredColorScheme(.dark)
    }
}
