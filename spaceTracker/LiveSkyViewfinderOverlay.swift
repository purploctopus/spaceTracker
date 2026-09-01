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

// ==============================================================================
// 🔭 VISIBILITY TIER HELPERS (magnitude vs. tonight's moonlight-adjusted sky)
// ==============================================================================
// NOTE: this used to key off a Bortle-class light-pollution lookup. That was removed —
// real light-pollution datasets either aren't legally reusable in a monetized app without
// the data owner's explicit permission, or (per the leading atlas's own author, who
// published a direct comparison against real observer Bortle ratings) don't reliably
// convert into a Bortle number in the first place. Moonlight is the one major sky-brightness
// factor that's both physically well-understood and fully computable offline from data we
// already have a legitimate right to use (see moonSkyBrightnessPenalty in
// StargazerTelemetryModels.swift). This intentionally does NOT model light pollution — the
// disclaimer surfaced in TargetInfoReadout below exists specifically so that isn't mistaken
// for a complete picture, especially for anyone under a city sky on a moonless night.

/// A fixed "typical clear, reasonably dark sky" starting point — not location-specific,
/// since this badge no longer attempts to model any particular observer's real light
/// pollution. Tonight's moon penalty is subtracted from this baseline.
private let assumedBaselineLimitingMagnitude = 6.5

private struct VisibilityTier {
    let label: String
    let color: Color
}

/// Buckets an object's magnitude against tonight's moonlight-adjusted naked-eye limit into a
/// rough "what do I need to see this" tier. The magnitude gaps used here (≈4.5 mag of reach
/// for typical 7x50 binoculars, ≈9 mag total for a modest amateur telescope) are standard
/// approximations, not derived from any specific instrument — treat them as a helpful nudge,
/// not a guarantee.
private func visibilityTier(magnitude: Double, limitingMagnitude: Double) -> VisibilityTier {
    let margin = limitingMagnitude - magnitude // positive = brighter than what the eye can see
    switch margin {
    case 1.5...:
        return VisibilityTier(label: "NAKED EYE", color: .green)
    case 0..<1.5:
        return VisibilityTier(label: "NAKED EYE — MARGINAL", color: .yellow)
    case -4.5..<0:
        return VisibilityTier(label: "BINOCULARS RECOMMENDED", color: .orange)
    case -9.0 ..< -4.5:
        return VisibilityTier(label: "SMALL TELESCOPE", color: .red)
    default:
        return VisibilityTier(label: "ADVANCED SCOPE NEEDED", color: .purple)
    }
}

/// Formats an AU distance alongside an approximate mileage, since "142 million miles" reads
/// more concretely than "1.53 AU" for most people glancing at a live overlay. Branches on
/// scale because the Moon (~0.0026 AU, ~239,000 mi) would otherwise round to a misleading
/// "≈0M mi" under the million-miles formatting built for planetary distances.
private func formattedDistance(auValue: Double) -> String {
    let milesPerAU = 92_955_807.3
    let miles = auValue * milesPerAU
    if miles < 1_000_000 {
        return String(format: "%.4f AU  (≈%.0f mi)", auValue, miles)
    } else {
        return String(format: "%.2f AU  (≈%.0fM mi)", auValue, miles / 1_000_000.0)
    }
}

// ==============================================================================
// 🎯 LIVE TARGET INFO READOUT — what's currently under the crosshair
// ==============================================================================
private struct TargetInfoReadout: View {
    let target: TargetLockMatch
    let moonBrightnessPenalty: Double
    
    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                Text(target.name)
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundColor(.cyan)
                Text(target.constellation)
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            
            HStack(spacing: 12) {
                Text("ALT \(String(format: "%.1f°", target.altitude))")
                Text("AZ \(String(format: "%.1f°", target.azimuth))")
                if let magnitude = target.magnitude {
                    Text("MAG \(String(format: "%.1f", magnitude))")
                }
            }
            .font(.system(size: 10, weight: .medium, design: .monospaced))
            .foregroundColor(.white.opacity(0.85))
            
            if let distanceAU = target.distanceAU {
                Text(formattedDistance(auValue: distanceAU))
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.65))
            }
            
            if let magnitude = target.magnitude {
                let effectiveLimitingMagnitude = assumedBaselineLimitingMagnitude - moonBrightnessPenalty
                let tier = visibilityTier(magnitude: magnitude, limitingMagnitude: effectiveLimitingMagnitude)
                Text(tier.label)
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(tier.color.opacity(0.18))
                    .foregroundColor(tier.color)
                    .cornerRadius(4)
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(tier.color.opacity(0.5), lineWidth: 1))
                
                // Keeps this from being read as a complete "can I see this" verdict — it's
                // moonlight only. A moonless sky in a bright city will still show NAKED EYE
                // here even though the real sky is far too bright to actually see it.
                Text("Moonlight-only estimate — doesn't account for local light pollution")
                    .font(.system(size: 7.5, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.4))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 160)
            }
        }
        .padding(10)
        .background(Color.black.opacity(0.7))
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.cyan.opacity(0.3), lineWidth: 1))
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

struct LiveSkyViewfinderOverlay: View {
    let visiblePlanetsCatalog: [APIPlanetItem]
    /// Drives the naked-eye/binoculars/scope visibility badge in the target readout. Pass
    /// `stargazerState.moonBrightnessPenalty` in from the call site — unlike the Bortle
    /// value this replaced, this is real, computed from the Moon's actual current
    /// illumination and altitude (see moonSkyBrightnessPenalty in
    /// StargazerTelemetryModels.swift), not a stub.
    var moonBrightnessPenalty: Double = 0.0
    @Environment(\.dismiss) private var dismiss
    
    @StateObject private var motionEngine = SkyMotionManager()
    
    @State private var projectedScreenPlots: [ScreenProjectedObject] = []
    @State private var currentCrosshairTarget: TargetLockMatch? = nil
    
    @State private var isStabilizingEngine = true
    @State private var selectedProfile: CelestialProfile? = nil
    
    // NAVIGATION ACTIVE STATE TRACKERS
    @State private var isMenuDrawerOpen = false
    @State private var activeNavigationTarget: String? = nil
    
    // First-run how-to-use overlay, replayable via the "?" icon in the header.
    @State private var showHowToUseOverlay = false
    
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
                        let isMoon = object.classification == "MOON"
                        let moonlightColor = Color(red: 0.96, green: 0.96, blue: 0.82)
                        
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
                                        .foregroundColor(isMoon ? moonlightColor : (isPlanet ? .cyan : CelestialDatabaseRegistry.electricBlue))
                                }
                                
                                Text(object.name.uppercased())
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .foregroundColor(isMoon ? moonlightColor : (isPlanet ? .cyan : (hasProfileInfo ? CelestialDatabaseRegistry.electricBlue : .yellow)))
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 4)
                            .background(Color.black.opacity(0.65))
                            .cornerRadius(4)
                        }
                        .buttonStyle(PlainButtonStyle())
                        // The rendered chip (small icon + small text, tight padding) is well
                        // under Apple's 44x44pt minimum tappable target — this expands the
                        // actual hit area to that minimum without touching how it looks.
                        // .contentShape(Rectangle()) is required here: without it, SwiftUI
                        // only counts the small drawn content as tappable even after the
                        // frame grows, since Button's default hit-testing follows the content
                        // shape, not the frame.
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
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
                    
                    // Replays the how-to-use overlay on demand — same small, low-key visual
                    // treatment as the "go ad-free" icon in ContentView's toolbar.
                    Button(action: { showHowToUseOverlay = true }) {
                        Image(systemName: "questionmark.circle")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.cyan)
                    }
                    .padding(.trailing, 4)
                    
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
                VStack(spacing: 14) {
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
                    
                    // Whatever's actually under the crosshair right now — independent of
                    // activeNavigationTarget above, which only concerns the guided-tracking
                    // needle for a manually selected target.
                    if let lockedTarget = currentCrosshairTarget {
                        TargetInfoReadout(target: lockedTarget, moonBrightnessPenalty: moonBrightnessPenalty)
                            .transition(.opacity)
                    }
                }
                .animation(.easeInOut(duration: 0.2), value: currentCrosshairTarget)

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
            
            // First-run (or replayed via the "?" icon) how-to-use overlay. Tap anywhere to
            // dismiss — no buttons to hunt for, nothing to read past a glance.
            if showHowToUseOverlay {
                Color.black.opacity(0.85)
                    .ignoresSafeArea()
                    .overlay(
                        VStack(spacing: 20) {
                            Image(systemName: "sparkles")
                                .font(.largeTitle)
                                .foregroundColor(.cyan)
                            
                            Text("HOW TO USE STARGAZE")
                                .font(.system(.headline, design: .monospaced))
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .tracking(1)
                            
                            VStack(alignment: .leading, spacing: 16) {
                                howToUseLine(icon: "camera.viewfinder", text: "Point your phone at the sky.")
                                howToUseLine(icon: "hand.tap", text: "Tap any (i) you see for details.")
                                howToUseLine(icon: "line.3.horizontal", text: "Tap ☰ to track a specific target.")
                            }
                            .padding(.horizontal, 32)
                            
                            Text("TAP ANYWHERE TO DISMISS")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundColor(.secondary)
                                .padding(.top, 8)
                        }
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showHowToUseOverlay = false
                        }
                    }
                    .transition(.opacity)
            }
        }
        .onAppear {
            motionEngine.engageSensorStreaming(with: visiblePlanetsCatalog)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation(.easeInOut(duration: 0.5)) {
                    isStabilizingEngine = false
                }
                // Shown once, right after the stabilization veil clears — showing it
                // simultaneously with the veil would read as two overlapping loading
                // states; this way it appears the moment the live view is actually visible.
                if !UserDefaults.standard.bool(forKey: "hasSeenStarGazeHowToUse") {
                    showHowToUseOverlay = true
                    UserDefaults.standard.set(true, forKey: "hasSeenStarGazeHowToUse")
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
    
    @ViewBuilder
    private func howToUseLine(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.cyan)
                .frame(width: 24)
            Text(text)
                .font(.system(.subheadline, design: .monospaced))
                .foregroundColor(.white)
        }
    }
}
