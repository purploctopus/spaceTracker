//
//  LiveSkyViewfinderOverlay.swift
//  spaceTracker
//
//  Created by Ben Clary on 8/14/26.
//  MAKE AN APP COLIN LOVES AND SUPPORTS SARA'S FREEDOM

import SwiftUI

// ==============================================================================
// 🪐 LIVE SKY VIEWFINDER OVERLAY LAYOUT
// ==============================================================================
struct LiveSkyViewfinderOverlay: View {
    let visiblePlanetsCatalog: [APIPlanetItem]
    @Environment(\.dismiss) private var dismiss
    
    @StateObject private var motionEngine = SkyMotionManager()
    
    var body: some View {
        ZStack {
            // Displays your 2,500 calibrated stars and planets smoothly in true 3D AR space
            SkyViewportARView(celestialCatalog: visiblePlanetsCatalog)
                .ignoresSafeArea()
            
            ViewfinderBackgroundGridLines()
                .stroke(Color.cyan.opacity(0.1), lineWidth: 1)
                .ignoresSafeArea()
            
            // ==============================================================================
            // MAIN HUD OVERLAY CONTROLS
            // ==============================================================================
            VStack(spacing: 0) {
                // Top Operational Telemetry Bar Header Grid
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("SYSTEM: LIVE SKY VECTOR PORT")
                            .font(.system(.caption, design: .monospaced))
                            .fontWeight(.bold)
                            .foregroundColor(.cyan)
                        Text("COORDINATE SYSTEM: AR SPATIAL DOME")
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
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
                
                Spacer()
                
                // Center Targeting Sight Reticle Rings
                ZStack {
                    Circle()
                        .stroke(motionEngine.isPointingBelowHorizon ? Color.red.opacity(0.3) : Color.cyan.opacity(0.2), lineWidth: 1)
                        .frame(width: 240, height: 240)
                    
                    Circle()
                        .stroke(motionEngine.isPointingBelowHorizon ? Color.red : Color.cyan, lineWidth: 2)
                        .frame(width: 140, height: 140)
                    
                    if motionEngine.isPointingBelowHorizon {
                        VStack(spacing: 6) {
                            Image(systemName: "arrow.up.circle")
                                .font(.title)
                            Text("LOOK UP")
                                .font(.system(.headline, design: .monospaced))
                                .fontWeight(.bold)
                            Text("You are pointing below the horizon. Tilt your device up to view the sky.")
                                .font(.system(.caption, design: .default))
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .foregroundColor(.red)
                        .padding()
                        .frame(width: 240)
                        .background(Color.black.opacity(0.75))
                        .cornerRadius(8)
                    } else {
                        Rectangle()
                            .fill(Color.cyan)
                            .frame(width: 30, height: 1)
                        Rectangle()
                            .fill(Color.cyan)
                            .frame(width: 1, height: 30)
                    }
                }
                
                Spacer()
                
                // Bottom Live Heading Direction Dashboard Footer Rows
                HStack {
                    Spacer()
                    VStack(spacing: 2) {
                        Text("VIEWPORT TILT PITCH")
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundColor(.secondary)
                        Text("\(Int(motionEngine.altitudeTilt))°")
                            .font(.system(.headline, design: .monospaced))
                            .foregroundColor(.primary)
                    }
                    Spacer()
                }
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            motionEngine.engageSensorStreaming(with: visiblePlanetsCatalog)
        }
        .onDisappear {
            motionEngine.disengageSensorStreaming()
        }
        .navigationBarHidden(true)
    }
}

struct ViewfinderBackgroundGridLines: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let midX = rect.midX
        let midY = rect.midY
        path.move(to: CGPoint(x: midX, y: rect.minY))
        path.addLine(to: CGPoint(x: midX, y: rect.maxY))
        path.move(to: CGPoint(x: rect.minX, y: midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: midY))
        return path
    }
}
