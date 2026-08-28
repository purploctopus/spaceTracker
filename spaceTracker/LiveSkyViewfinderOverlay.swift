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
/// Carries the reticle ring's actual on-screen center up to the root view, so both the
/// guided-tracking needle (here) and the crosshair lock detection (inside
/// SkyViewportARViewContainer's Coordinator) target the exact same point instead of two
/// independently-guessed constants.
private struct ReticleCenterPreferenceKey: PreferenceKey {
    static var defaultValue: CGPoint = .zero
    static func reduce(value: inout CGPoint, nextValue: () -> CGPoint) {
        value = nextValue()
    }
}

private let arRootCoordinateSpace = "arRootSpace"

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

struct LiveSkyViewfinderOverlay: View {
    let visiblePlanetsCatalog: [APIPlanetItem]
    @Environment(\.dismiss) private var dismiss
    
    @StateObject private var motionEngine = SkyMotionManager()
    
    @State private var projectedScreenPlots: [ScreenProjectedObject] = []
    @State private var currentCrosshairTarget: TargetLockMatch? = nil
    
    @State private var isStabilizingEngine = true
    @State private var selectedProfile: CelestialProfile? = nil
    
    // NAVIGATION ACTIVE STATE TRACKERS
    @State private var isMenuDrawerOpen = false
    @State private var activeNavigationTarget: String? = nil
    
    // Real, measured center of the reticle ring. Starts as a rough screen-center guess so
    // the first frame (before GeometryReader reports back) isn't at (0,0); gets overwritten
    // with the true value the instant the reticle lays out.
    @State private var reticleCenter = CGPoint(
        x: UIScreen.main.bounds.width / 2,
        y: UIScreen.main.bounds.height / 2
    )
    
    var body: some View {
        ZStack {
            // 1. Core AR Engine Canvas (100% Intact)
            SkyViewportARViewContainer(
                celestialCatalog: visiblePlanetsCatalog,
                projectedScreenPlots: $projectedScreenPlots,
                currentCrosshairTarget: $currentCrosshairTarget,
                reticleCenter: reticleCenter
            )
            .ignoresSafeArea()
            
            // 2. Floating Target Text Labels (Direct Tap-Safe Links)
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
                        }) {
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
                            .padding(.horizontal, 6)
                            .padding(.vertical, 4)
                            .background(Color.black.opacity(0.65))
                            .cornerRadius(4)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .position(x: object.x, y: object.y)
                    }
                }
            }
            .ignoresSafeArea()
            
            // Reticle Grid Line Geometry
            ViewfinderBackgroundGridLines()
                .stroke(Color.white.opacity(0.04), lineWidth: 1)
                .ignoresSafeArea()
            
            // 3. Main HUD Interface Controller Deck Layout
            VStack(spacing: 0) {
                // Top Monospaced Status Header Panel
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("SYSTEM: LIVE SKY VECTOR PORT")
                            .font(.system(.caption, design: .monospaced))
                            .fontWeight(.bold)
                            .foregroundColor(.cyan)
                        Text(activeNavigationTarget != nil ? "TARGET MODE: GUIDED TRACKING ACTIVE [\(activeNavigationTarget!)]" : "TARGET MODE: FREE-LOOK SCAN")
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundColor(activeNavigationTarget != nil ? .green : .secondary)
                    }
                    
                    Spacer()
                    
                    Button(action: { dismiss() }) {
                        Text("DISENGAGE")
                            .font(.system(.caption, design: .monospaced))
                            .fontWeight(.bold)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.red.opacity(0.1))
                            .foregroundColor(.red)
                            .cornerRadius(4)
                    }
                }
                .padding()
                .background(Color.black.opacity(0.4))
                
                Spacer()

                // ==============================================================================
                // 🎯 BULLETPROOF 2D SCREEN-SPACE INTERSECTOR NEEDLE ENGINE
                // ==============================================================================
                ZStack {
                    Circle()
                        .stroke(Color.cyan.opacity(0.2), lineWidth: 1)
                        .frame(width: 200, height: 240)
                    
                    Circle()
                        .stroke(Color.cyan, lineWidth: 1.5)
                        .frame(width: 100, height: 100)
                    
                    Rectangle().fill(Color.cyan).frame(width: 20, height: 1)
                    Rectangle().fill(Color.cyan).frame(width: 1, height: 20)
                    
                    // Reads the active, updating screen projection plots to calculate a
                    // direct visual direction needle, targeting the reticle's *measured*
                    // center (see reticleCenter / ReticleCenterPreferenceKey below) — the
                    // same point the AR lock detection targets, instead of a separately
                    // guessed constant.
                    if let targetName = activeNavigationTarget,
                       let screenPlot = projectedScreenPlots.first(where: { $0.name.uppercased() == targetName }) {
                        
                        let deltaX = screenPlot.x - reticleCenter.x
                        let deltaY = screenPlot.y - reticleCenter.y
                        
                        let distanceToTarget = sqrt(pow(deltaX, 2) + pow(deltaY, 2))
                        
                        // Keeps needle active until the text card touches your 100px reticle ring
                        if distanceToTarget > 45.0 {
                            // Standard screen-space bearing angle calculation (Inverted Y coordinate rule)
                            let angleRadians = atan2(deltaX, -deltaY)
                            let angleDegrees = angleRadians * (180.0 / .pi)
                            
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.green)
                                .offset(y: -50) // Anchors cleanly on the perimeter ring
                                .rotationEffect(.degrees(angleDegrees)) // Rotates smoothly to match the visual plot!
                        }
                    }
                }
                .background(
                    GeometryReader { reticleProxy in
                        Color.clear.preference(
                            key: ReticleCenterPreferenceKey.self,
                            value: CGPoint(
                                x: reticleProxy.frame(in: .named(arRootCoordinateSpace)).midX,
                                y: reticleProxy.frame(in: .named(arRootCoordinateSpace)).midY
                            )
                        )
                    }
                )


                Spacer()
                
                // Bottom Viewport Tilt Pitch Readout
                HStack {
                    Spacer()
                    VStack(spacing: 2) {
                        Text("VIEWPORT TILT PITCH")
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundColor(.secondary)
                        Text("\(Int(motionEngine.currentAltitude))°")
                            .font(.system(.headline, design: .monospaced))
                            .foregroundColor(.primary)
                    }
                    Spacer()
                }
                .padding(.bottom, 40)
            }
            
            // ==============================================================================
            // ☰ THE SLIDE-OVER NAVIGATION SELECTION DRAWER (ANCHORED AT Z-ROOT)
            // ==============================================================================
            if isMenuDrawerOpen {
                Color.black.opacity(0.5)
                    .ignoresSafeArea()
                    .onTapGesture { isMenuDrawerOpen = false }
                
                HStack {
                    Spacer()
                    
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("✦ SELECT VECTOR TARGET")
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundColor(.cyan)
                            Spacer()
                            Button(action: { isMenuDrawerOpen = false }) {
                                Image(systemName: "xmark.square.fill")
                                    .foregroundColor(.gray)
                                    .font(.title3)
                            }
                        }
                        .padding(.bottom, 10)
                        
                        ScrollView(.vertical, showsIndicators: false) {
                            VStack(spacing: 8) {
                                ForEach(CelestialDatabaseRegistry.interactiveTargetsList, id: \.self) { targetID in
                                    let profile = CelestialDatabaseRegistry.profiles[targetID]!
                                    let isCurrentlySelected = activeNavigationTarget == targetID
                                    
                                    Button(action: {
                                        if isCurrentlySelected {
                                            activeNavigationTarget = nil
                                        } else {
                                            activeNavigationTarget = targetID
                                        }
                                        isMenuDrawerOpen = false
                                    }) {
                                        HStack {
                                            Text(profile.name.uppercased())
                                                .font(.system(size: 13, weight: .bold, design: .monospaced))
                                            Spacer()
                                            if isCurrentlySelected {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .foregroundColor(.green)
                                            }
                                        }
                                        .padding(12)
                                        .background(isCurrentlySelected ? Color.green.opacity(0.15) : Color.white.opacity(0.04))
                                        .foregroundColor(isCurrentlySelected ? .green : .white)
                                        .cornerRadius(6)
                                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(isCurrentlySelected ? Color.green.opacity(0.4) : Color.clear, lineWidth: 1))
                                    }
                                }
                            }
                        }
                    }
                    .padding(20)
                    .frame(width: 260)
                    .background(Color(red: 0.05, green: 0.05, blue: 0.07))
                    .overlay(Rectangle().stroke(Color.gray.opacity(0.15), lineWidth: 1))
                    .ignoresSafeArea()
                    .transition(.move(edge: .trailing))
                }
            }
            
            // ☰ FLOATING NATIVE HAMBURGER INTERACTION BUTTON — anchored bottom-right, the
            // primary entry point for tracking a specific star/planet via the target drawer.
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button(action: { isMenuDrawerOpen.toggle() }) {
                        Image(systemName: "line.3.horizontal")
                            .font(.system(size: 16, weight: .bold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(isMenuDrawerOpen ? Color.cyan.opacity(0.2) : Color.black.opacity(0.6))
                            .foregroundColor(isMenuDrawerOpen ? .cyan : .white)
                            .cornerRadius(6)
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.cyan.opacity(0.3), lineWidth: 1))
                    }
                }
                .padding(.trailing, 20)
                .padding(.bottom, 100) // clears the tilt-pitch readout beneath it
            }
            .ignoresSafeArea(.container, edges: .bottom)

            // Stabilization Veil
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
        .coordinateSpace(name: arRootCoordinateSpace)
        .onPreferenceChange(ReticleCenterPreferenceKey.self) { measuredCenter in
            guard measuredCenter != .zero else { return }
            self.reticleCenter = measuredCenter
        }
        .navigationBarHidden(true)
        .sheet(item: $selectedProfile) { profile in
            CelestialDetailSheet(profile: profile)
        }
    }
}
