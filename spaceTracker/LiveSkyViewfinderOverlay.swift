//
//  LiveSkyViewfinderOverlay.swift
//  spaceTracker
//
//  Created by Ben Clary on 8/14/26.
//  MAKE AN APP COLIN LOVES AND SUPPORTS SARA'S FREEDOM

import SwiftUI

// ==============================================================================
// 📐 VIEW LAYER GRAPHIC DETAIL GRID VECTOR BLUEPRINT (SCOPE FIXED)
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

// ==============================================================================
// 🪐 LIVE SKY VIEWFINDER HUD INTERFACE OVERLAY
// ==============================================================================
struct LiveSkyViewfinderOverlay: View {
    let visiblePlanetsCatalog: [APIPlanetItem]
    @Environment(\.dismiss) private var dismiss
    
    @StateObject private var motionEngine = SkyMotionManager()
    
    @State private var projectedScreenPlots: [ScreenProjectedObject] = []
    @State private var currentCrosshairTarget: TargetLockMatch? = nil
    
    // Smoothly hides the screen for 1.5 seconds while sensors find true North!
    @State private var isStabilizingEngine = true
    
    var body: some View {
        ZStack {
            // 1. Core AR Engine Canvas
            SkyViewportARViewContainer(
                celestialCatalog: visiblePlanetsCatalog,
                projectedScreenPlots: $projectedScreenPlots,
                currentCrosshairTarget: $currentCrosshairTarget
            )
            .ignoresSafeArea()
            
            // 2. Uncluttered Major Target Text Label Overlay Layer
            GeometryReader { proxy in
                ZStack {
                    ForEach(projectedScreenPlots) { object in
                        Text(object.name.uppercased())
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(object.classification == "PLANET" ? .cyan : .yellow)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.black.opacity(0.6))
                            .cornerRadius(3)
                            .position(x: object.x, y: object.y)
                    }
                }
            }
            .ignoresSafeArea()
            
            // 💡 Clean Reticle Crosshair Line Geometry Grid (Scope Fully Restored!)
            ViewfinderBackgroundGridLines()
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                .ignoresSafeArea()
            
            // Main HUD Controller Layer Deck
            VStack(spacing: 0) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("SYSTEM: LIVE SKY VECTOR PORT")
                            .font(.system(.caption, design: .monospaced))
                            .fontWeight(.bold)
                            .foregroundColor(.cyan)
                        Text("TARGET MODE: AUTOMATIC RAYCAST LOCK-ON")
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
                .background(Color.black.opacity(0.4))
                
                Spacer()
                
                ZStack {
                    Circle()
                        .stroke(motionEngine.isPointingBelowHorizon ? Color.red : (currentCrosshairTarget != nil ? Color.green : Color.cyan.opacity(0.2)), lineWidth: 1)
                        .frame(width: 200, height: 240)
                    
                    Circle()
                        .stroke(motionEngine.isPointingBelowHorizon ? Color.red : (currentCrosshairTarget != nil ? Color.green : Color.cyan), lineWidth: 1.5)
                        .frame(width: 100, height: 100)
                    
                    Rectangle()
                        .fill(currentCrosshairTarget != nil ? Color.green : Color.cyan)
                        .frame(width: 20, height: 1)
                    Rectangle()
                        .fill(currentCrosshairTarget != nil ? Color.green : Color.cyan)
                        .frame(width: 1, height: 20)
                    
                    if motionEngine.isPointingBelowHorizon {
                        VStack(spacing: 4) {
                            Image(systemName: "arrow.up.circle")
                                .font(.title)
                            Text("LOOK UP")
                                .font(.system(.caption, design: .monospaced))
                                .fontWeight(.bold)
                        }
                        .foregroundColor(.red)
                        .padding(8)
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(4)
                    }
                    
                    if let lockedTarget = currentCrosshairTarget {
                        ZStack {
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color.green, lineWidth: 1.5)
                                .frame(width: 140, height: 140)
                            
                            VStack(spacing: 2) {
                                Text("🎯 TARGET LOCKED")
                                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                                    .foregroundColor(.green)
                                
                                Text(lockedTarget.name)
                                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                                    .foregroundColor(.white)
                                    .multilineTextAlignment(.center)
                                    .fixedSize(horizontal: false, vertical: true)
                                
                                Text("CON: \(lockedTarget.constellation)")
                                    .font(.system(size: 8, design: .monospaced))
                                    .foregroundColor(.gray)
                                
                                Text("ALT: \(lockedTarget.altitude)° / AZ: \(lockedTarget.azimuth)°")
                                    .font(.system(size: 8, design: .monospaced))
                                    .foregroundColor(.cyan)
                            }
                            .padding(8)
                            .background(Color.black.opacity(0.85))
                            .cornerRadius(4)
                            .offset(y: 115)
                        }
                    }
                }
                
                Spacer()
                
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
            
            // The stabilization veil hides jitter frames during initial sensor calibration
            if isStabilizingEngine {
                Color.black
                    .ignoresSafeArea()
                    .overlay(
                        VStack(spacing: 12) {
                            ProgressView()
                                .tint(.cyan)
                            Text("LOCKING SPATIAL SKY TELEMETRY MATRIX...")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(.cyan)
                        }
                    )
            }
        }
        .onAppear {
            motionEngine.engageSensorStreaming(with: visiblePlanetsCatalog)
            
            // Allow ARKit exactly 1.5 seconds to find true geographic North before dissolving the veil
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation(.easeInOut(duration: 0.5)) {
                    isStabilizingEngine = false
                }
            }
        }
        .onDisappear {
            motionEngine.disengageSensorStreaming()
        }
        .navigationBarHidden(true)
    }
}
