//
//  LiveSkyViewfinderOverlay.swift
//  spaceTracker
//
//  Created by Ben Clary on 8/14/26.
//  MAKE AN APP COLIN LOVES AND SUPPORTS SARA'S FREEDOM

import SwiftUI

struct TargetLockMatch: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let constellation: String
    let altitude: Int
    let azimuth: Int
}

struct LiveSkyViewfinderOverlay: View {
    let visiblePlanetsCatalog: [APIPlanetItem]
    @Environment(\.dismiss) private var dismiss
    
    @StateObject private var motionEngine = SkyMotionManager()
    
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            
            ViewfinderBackgroundGridLines()
                .stroke(Color.cyan.opacity(0.1), lineWidth: 1)
                .ignoresSafeArea()
            
            // ==============================================================================
            // SPATIAL OBSERVATION SKY CANVAS
            // ==============================================================================
            GeometryReader { proxy in
                let centerPoint = CGPoint(x: proxy.size.width / 2, y: proxy.size.height / 2)
                
                // 💡 THE VISIBLE CONSTELLATION MAP FIELD PLOTTER:
                // Draws dots and labels floating around dynamically based on phone orientation!
                ForEach(motionEngine.currentlyVisibleInViewport) { object in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(object.classification == "PLANET" ? Color.cyan : Color.white)
                                // Planets get a bold footprint, dim stars drop to micro points
                                .frame(width: object.classification == "PLANET" ? 6 : 4,
                                       height: object.classification == "PLANET" ? 6 : 4)
                            
                            Text(object.name.uppercased())
                                .font(.system(.caption2, design: .monospaced))
                                .fontWeight(.bold)
                                .foregroundColor(object.isPrimaryLock ? .green : (object.classification == "PLANET" ? .cyan : .secondary))
                        }
                    }
                    // Moves the dot to its exact real-time offset position relative to screen center
                    .position(x: centerPoint.x + object.screenX, y: centerPoint.y + object.screenY)
                }
            }
            .ignoresSafeArea()
            
            // ==============================================================================
            // MAIN HUD OVERLAY LAYER GATES
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
                        .stroke(motionEngine.currentLockedTarget != nil ? Color.green.opacity(0.4) : Color.cyan.opacity(0.2), lineWidth: 1)
                        .frame(width: 240, height: 240)
                    
                    Circle()
                        .stroke(motionEngine.currentLockedTarget != nil ? Color.green : Color.cyan, lineWidth: 2)
                        .frame(width: 140, height: 140)
                    
                    Rectangle()
                        .fill(motionEngine.currentLockedTarget != nil ? Color.green : Color.cyan)
                        .frame(width: 30, height: 1)
                    Rectangle()
                        .fill(motionEngine.currentLockedTarget != nil ? Color.green : Color.cyan)
                        .frame(width: 1, height: 30)
                    
                    if let lockedTarget = motionEngine.currentLockedTarget {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.green, lineWidth: 2)
                                .frame(width: 180, height: 180)
                            
                            VStack(alignment: .center, spacing: 2) {
                                Text("🎯 TARGET ACQUIRED")
                                    .font(.system(.caption2, design: .monospaced))
                                    .fontWeight(.bold)
                                    .foregroundColor(.green)
                                
                                Text(lockedTarget.name)
                                    .font(.system(.headline, design: .monospaced))
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                
                                Text("CONSTELLATION: \(lockedTarget.constellation)")
                                    .font(.system(.caption2, design: .monospaced))
                                    .foregroundColor(.secondary)
                            }
                            .padding(8)
                            .background(Color.black.opacity(0.75))
                            .cornerRadius(6)
                            .offset(y: 130)
                        }
                    }
                }
                
                Spacer()
                
                // Bottom Live Heading Direction Dashboard Footers
                HStack(spacing: 40) {
                    VStack(spacing: 2) {
                        Text("HEADING COMPASS")
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundColor(.secondary)
                        Text("\(Int(motionEngine.azimuthHeading))° \(getCompassLabel(motionEngine.azimuthHeading))")
                            .font(.system(.headline, design: .monospaced))
                            .foregroundColor(.primary)
                    }
                    
                    VStack(spacing: 2) {
                        Text("TILT PITCH ANGLE")
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundColor(.secondary)
                        Text("\(Int(motionEngine.altitudeTilt))°")
                            .font(.system(.headline, design: .monospaced))
                            .foregroundColor(.primary)
                    }
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
    
    private func getCompassLabel(_ angle: Double) -> String {
        let sectors = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
        let index = Int((angle + 22.5).truncatingRemainder(dividingBy: 360.0) / 45.0)
        return sectors[max(0, min(index, 7))]
    }
}

// ==============================================================================
// 📐 VIEW LAYER GRAPHIC DETAIL LINING STRUCT
// ==============================================================================
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
