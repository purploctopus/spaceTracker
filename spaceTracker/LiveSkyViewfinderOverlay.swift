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

import SwiftUI

struct LiveSkyViewfinderOverlay: View {
    let visiblePlanetsCatalog: [APIPlanetItem]
    @Environment(\.dismiss) private var dismiss
    
    @StateObject private var motionEngine = SkyMotionManager()
    
    @State private var projectedScreenPlots: [ScreenProjectedObject] = []
    @State private var currentCrosshairTarget: TargetLockMatch? = nil
    
    // Smoothly hides the screen for 1.5 seconds while sensors find true North!
    @State private var isStabilizingEngine = true
    
    // 💡 THE SHEET PRESENTATION STATE:
    @State private var selectedProfile: CelestialProfile? = nil
    
    var body: some View {
        ZStack {
            // 1. Core AR Engine Canvas (100% Intact)
            SkyViewportARViewContainer(
                celestialCatalog: visiblePlanetsCatalog,
                projectedScreenPlots: $projectedScreenPlots,
                currentCrosshairTarget: $currentCrosshairTarget
            )
            .ignoresSafeArea()
            
            // 2. Uncluttered Major Target Text Label Overlay Layer (Upgraded with Native iOS Symbols)
            GeometryReader { proxy in
                ZStack {
                    ForEach(projectedScreenPlots) { object in
                        let profileMatch = CelestialDatabaseRegistry.profiles[object.name.uppercased()]
                        let hasProfileInfo = profileMatch != nil
                        let isPlanet = object.classification == "PLANET"
                        
                        Button(action: {
                            if var targetProfile = profileMatch {
                                if let liveTrack = visiblePlanetsCatalog.first(where: { $0.name.uppercased() == object.name.uppercased() }) {
                                    targetProfile.liveAltitude = liveTrack.altitude
                                    targetProfile.liveAzimuth = liveTrack.azimuth
                                    targetProfile.liveDistanceAU = liveTrack.range_au
                                }
                                self.selectedProfile = targetProfile
                            }
                        }){
                            HStack(spacing: 5) {
                                if hasProfileInfo {
                                    Image(systemName: "info.circle.fill")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(isPlanet ? .cyan : CelestialDatabaseRegistry.electricBlue)
                                }
                                
                                Text(object.name.uppercased())
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .foregroundColor(isPlanet ? .cyan : (hasProfileInfo ? CelestialDatabaseRegistry.electricBlue : .yellow))
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .background(Color.black.opacity(0.65))
                            .cornerRadius(4)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .position(x: object.x, y: object.y)
                    }
                }
            }
            .ignoresSafeArea()

            
            // Minimal Visual Reticle Crosshair Line Geometry (Scope Fully Restored!)
            ViewfinderBackgroundGridLines()
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                .ignoresSafeArea()
            
            // 3. Main HUD Status Bar (Top and Bottom Panels Only)
            VStack(spacing: 0) {
                // Top Monospaced Status Header Panel
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
                
                // 🎯 Clean Center Crosshairs System (Purely Visual Reference Rings)
                ZStack {
                    Circle()
                        .stroke(motionEngine.isPointingBelowHorizon ? Color.red : Color.cyan.opacity(0.2), lineWidth: 1)
                        .frame(width: 200, height: 240)
                    
                    Circle()
                        .stroke(motionEngine.isPointingBelowHorizon ? Color.red : Color.cyan, lineWidth: 1.5)
                        .frame(width: 100, height: 100)
                    
                    Rectangle()
                        .fill(Color.cyan)
                        .frame(width: 20, height: 1)
                    Rectangle()
                        .fill(Color.cyan)
                        .frame(width: 1, height: 20)
                }
                
                Spacer()
                
                // Bottom Viewport Tilt Pitch Readout
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
            
            // Stabilization Veil (Hides initial sensor calibration frames)
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
        .sheet(item: $selectedProfile) { profile in
            CelestialDetailSheet(profile: profile)
        }
    }
}
