//
//  ContentView.swift
//  spaceTracker
//
//  Created by Ben Clary on 6/17/26.
//  MAKE AN APP COLIN LOVES

import SwiftUI
import CoreLocation
import MapKit
import Combine

// ==============================================================================
// 📍 DEVICE LOCATION PROVIDER — a single, correctly-authorized location source
// ==============================================================================
/// Wraps CLLocationManager the way it actually needs to be used: request authorization if
/// undetermined, then request a fix and *wait* for the delegate callback before returning.
///
/// This replaces the pattern of `CLLocationManager().location` read immediately after
/// construction — a fresh manager has no authorization and hasn't been given any time to
/// acquire a fix, so that property is essentially always nil on a cold instance. That
/// silent nil is why the fallback coordinate (Madison, WI) has been used almost every time
/// this app has run, regardless of the user's real location.
///
/// Concurrent callers are de-duplicated: if two `.task` blocks both call `currentLocation()`
/// around launch (as this file's do), they share one underlying request instead of each
/// standing up their own CLLocationManager continuation — doing that naively would leak the
/// first caller's continuation and trigger a runtime "continuation misuse" fault.
@MainActor
final class DeviceLocationProvider: NSObject, ObservableObject, CLLocationManagerDelegate {
    // Declared explicitly rather than relying on ObservableObject's synthesized
    // objectWillChange — that synthesis is unreliable for NSObject-subclassing types
    // (needed here for CLLocationManagerDelegate), which is what triggered "does not
    // conform to protocol 'ObservableObject'" despite conforming to it correctly.
    // Nothing here needs to actually .send() through it — this class has no @Published
    // state driving UI, it's purely an async location-fetch helper — it just needs to
    // exist to satisfy @StateObject's requirement.
    let objectWillChange = ObservableObjectPublisher()

    private let manager = CLLocationManager()
    private var cachedLocation: CLLocationCoordinate2D?
    private var inFlightTask: Task<CLLocationCoordinate2D?, Never>?

    private var authorizationContinuation: CheckedContinuation<Bool, Never>?
    private var locationContinuation: CheckedContinuation<CLLocationCoordinate2D?, Never>?

    override init() {
        super.init()
        manager.delegate = self
    }

    /// Returns the device's current coordinate. Requests "when in use" authorization first
    /// if that hasn't been decided yet. Returns nil if permission is denied/restricted, or
    /// if CoreLocation genuinely couldn't produce a fix — callers must supply their own
    /// fallback for that case, this never invents one.
    func currentLocation() async -> CLLocationCoordinate2D? {
        if let cachedLocation { return cachedLocation }
        if let inFlightTask { return await inFlightTask.value }

        let task = Task<CLLocationCoordinate2D?, Never> { [weak self] in
            await self?.resolveLocation()
        }
        inFlightTask = task
        let result = await task.value
        inFlightTask = nil
        cachedLocation = result
        return result
    }

    private func resolveLocation() async -> CLLocationCoordinate2D? {
        switch manager.authorizationStatus {
        case .notDetermined:
            let granted = await requestAuthorization()
            guard granted else { return nil }
        case .denied, .restricted:
            return nil
        default:
            break
        }
        return await requestFix()
    }

    private func requestAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            self.authorizationContinuation = continuation
            manager.requestWhenInUseAuthorization()
        }
    }

    private func requestFix() async -> CLLocationCoordinate2D? {
        await withCheckedContinuation { continuation in
            self.locationContinuation = continuation
            manager.requestLocation()
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            guard status != .notDetermined, let continuation = self.authorizationContinuation else { return }
            self.authorizationContinuation = nil
            continuation.resume(returning: status == .authorizedWhenInUse || status == .authorizedAlways)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            self.locationContinuation?.resume(returning: locations.last?.coordinate)
            self.locationContinuation = nil
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            self.locationContinuation?.resume(returning: nil)
            self.locationContinuation = nil
        }
    }
}

struct ContentView: View {
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @StateObject private var viewModel = LaunchViewModel()
    @StateObject private var satViewModel = SatelliteViewModel()
    @State private var manualCitySearch: String = ""
    @StateObject private var rockViewModel = SpaceRocksViewModel()
    @State private var universalLatitude: Double = 43.0731
    @State private var universalLongitude: Double = -89.4012
    @State private var selectedSatellitePass: SatellitePass? = nil
    @StateObject private var meteorViewModel = MeteorShowerViewModel()
    @State private var selectedMeteorShower: MeteorShower? = nil
    @State private var selectedSpaceLaunch: SpaceLaunch? = nil
    @StateObject private var apodViewModel = APODViewModel()
    @State private var showAPODDetails = false
    @State private var stableAPODTitle: String = ""
    @State private var stableAPODExplanation: String = ""
    @StateObject private var notificationEngine = NotificationManager()
    @StateObject private var crewViewModel = AstronautViewModel()
    @State private var selectedSpacecraftCrewName: String? = nil
    @StateObject private var weatherViewModel = StargazingWeatherViewModel()
    @State private var selectedAgencyFilter: String = "ALL OPERATIONS"
    @State private var selectedAsteroidTarget: Asteroid? = nil
    @State private var showLiveVideoTelemetrySheet = false
    @State private var activeLiveStreamURL: String = ""
    @State private var streamingLaunchName: String = ""
    @State private var streamingLaunchNetDate: String? = nil
    // 💡 REMOVED: globalTapCount / tapCount tap-gating and the per-action pending-completion
    // plumbing that went with it. All content is unconditionally accessible now — ads are
    // ambient (shown on app transitions, frequency-capped) rather than blocking specific
    // taps. See spaceTrackerApp.swift for the transition trigger.
    @EnvironmentObject var adEngine: AdMobEngine
    @State private var showAdPromptOverlay = false
    @State private var showConditionsExplainer = false
    @StateObject private var newsViewModel = SpaceNewsViewModel()
    @State private var selectedArticle: SpaceNewsArticle? = nil
    @StateObject private var stargazerViewModel = StargazerViewModel()
    @State private var showLiveViewfinderOverlay: Bool = false
    
    @StateObject private var connectivityMonitor = SystemConnectivityMonitor()
    @StateObject private var locationProvider = DeviceLocationProvider()


    // 💡 RESPONSIVE ATMOSPHERIC CELL MATRIX: Stacks vertically on iPhone, aligns horizontally on iPad
    private var stargazingConditionsHeaderBar: some View {
        let shortTermAlert = weatherViewModel.kpIndex >= 5.0 ? "STORM ACTIVE" : weatherViewModel.kpIndex >= 4.0 ? "MODERATE WATCH" : "QUIET"
        
        return Button(action: { showConditionsExplainer = true }) {
            VStack(alignment: .leading, spacing: 6) {
                Text("LOCAL ATMOSPHERIC DATA // TAP FOR FIELD BRIEFING ❯")
                    .font(.system(.caption, design: .monospaced).weight(.bold))
                    .foregroundColor(.cyan)
                    .tracking(1)
                
                VStack(alignment: .leading, spacing: 12) {
                    if horizontalSizeClass == .compact {
                        // 📱 IPHONE MATRIX: Stacks neatly into 3 distinct, uncluttered layout rows
                        
                        // ROW 1: Ground-Level Weather Readouts
                        HStack(spacing: 20) {
                            HStack(spacing: 6) {
                                Image(systemName: "cloud.fill")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                Text("\(weatherViewModel.cloudCoverPercent)% CLOUDS")
                                    .fontWeight(.bold)
                            }
                            
                            HStack(spacing: 6) {
                                Image(systemName: "humidity.fill")
                                    .font(.caption)
                                    .foregroundColor(.cyan)
                                Text("\(weatherViewModel.humidityPercent)% HUMIDITY")
                                    .fontWeight(.bold)
                                    .foregroundColor(.cyan)
                            }
                            Spacer()
                        }
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.white)
                        
                        // ROW 2: Geomagnetic Solar Tracking Readouts
                        HStack(spacing: 6) {
                            Text("KP: \(String(format: "%.1f", weatherViewModel.kpIndex))")
                                .fontWeight(.bold)
                            Text("• 3-DAY WATCH: \(shortTermAlert)")
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.white)
                        
                        // ROW 3: Mandatory Legal Attribution Footer (Aligned cleanly to the right edge)
                        HStack {
                            Spacer()
                            HStack(spacing: 4) {
                                Image(systemName: "apple.logo")
                                    .font(.system(size: 9))
                                Text("Weather")
                                    .font(.system(size: 9, weight: .semibold))
                                
                                Link("Data", destination: URL(string: "https://weather-data.apple.com/legal-attribution.html")!)
                                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                                    .foregroundColor(.blue)
                                    .underline()
                            }
                            .foregroundColor(.secondary)
                        }
                        
                    } else {
                        // 🖥️ IPAD PAD LAYOUT: Retains your original single horizontal instruments string line row
                        HStack(spacing: 16) {
                            HStack(spacing: 6) {
                                Image(systemName: "cloud.fill")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                Text("\(weatherViewModel.cloudCoverPercent)% CLOUDS")
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                            }
                            
                            HStack(spacing: 6) {
                                Image(systemName: "humidity.fill")
                                    .font(.caption)
                                    .foregroundColor(.cyan)
                                Text("\(weatherViewModel.humidityPercent)% HUMIDITY")
                                    .fontWeight(.bold)
                                    .foregroundColor(.cyan)
                            }
                            
                            Spacer()
                            
                            HStack(spacing: 6) {
                                Text("KP: \(String(format: "%.1f", weatherViewModel.kpIndex))")
                                    .fontWeight(.bold)
                                Text("• 3-DAY WATCH: \(shortTermAlert)")
                                    .foregroundColor(.secondary)
                            }
                            
                            HStack(spacing: 4) {
                                Image(systemName: "apple.logo")
                                    .font(.system(size: 9))
                                Text("Weather")
                                    .font(.system(size: 9, weight: .semibold))
                                
                                Link("Data", destination: URL(string: "https://apple.com")!)
                                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                                    .foregroundColor(.blue)
                                    .underline()
                            }
                            .foregroundColor(.secondary)
                        }
                        .font(.system(.caption, design: .monospaced))
                    }
                }
                .padding(12)
                .background(Color.white.opacity(0.04))
                .cornerRadius(4)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
            }
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.horizontal)
        .padding(.bottom, 8)
    }
    
    // ==============================================================================
    // 🪐 STARGAZER OBSERVATION SYSTEM DASHBOARD CHANNEL BLOCK
    // ==============================================================================
    private var stargazerDashboardChannelBlock: some View {
        VStack(alignment: .leading, spacing: 20) {
            
            // 🗺️ 1. TOP TELEMETRY METRIC GLANCE SUMMARY CARD
            VStack(alignment: .leading, spacing: 12) {
                Text("SKY OBSERVATION RADAR SUMMARY")
                    .font(.system(.caption, design: .monospaced))
                    .fontWeight(.bold)
                    .foregroundColor(.secondary)
                
                // 💡 UPDATED: Completely cleaned up with zero filler words or text clutter!
                Button(action: {
                    showLiveViewfinderOverlay = true
                }) {
                    ZStack(alignment: .bottomLeading) {
                        // 🌌 DEEP SPACE GRAPHIC BANNER: Pulls from your new asset image file
                        Image("night_sky_banner")
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 120)
                            .background(Color(.systemGray6))
                            .clipped()
                        
                        // Dark tactical gradient mask to make your white text lines pop cleanly
                        LinearGradient(
                            colors: [Color.black.opacity(0.85), Color.black.opacity(0.1)],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                        
                        // Simple, punchy, high-utility titles
                        HStack(alignment: .bottom) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("OPEN LIVE INTERACTIVE SKY MAP")
                                    .font(.system(.caption2, design: .monospaced))
                                    .fontWeight(.bold)
                                    .foregroundColor(.cyan)
                                
                                Text("POINT DEVICE TO FIND PLANETS")
                                    .font(.system(.subheadline, design: .default))
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                            }
                            
                            Spacer()
                            
                            // Reticle scope graphic icon anchor
                            Image(systemName: "scope")
                                .font(.title2)
                                .foregroundColor(.cyan)
                        }
                        .padding()
                    }
                    .cornerRadius(12)
                    .shadow(color: Color.black.opacity(0.2), radius: 6, x: 0, y: 3)
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.bottom, 8)
                
                HStack(spacing: 16) {
                    // Glowing circular rating index badge
                    ZStack {
                        Circle()
                            .stroke(Color.cyan.opacity(0.2), lineWidth: 4)
                        Circle()
                            .trim(from: 0, to: CGFloat(weatherViewModel.observationIndex) / 100.0)
                            .stroke(Color.cyan, lineWidth: 4)
                            .rotationEffect(.degrees(-90))
                        
                        VStack(spacing: 2) {
                            Text("\(weatherViewModel.observationIndex)%")
                                .font(.system(.subheadline, design: .monospaced))
                                .fontWeight(.bold)
                            Text(weatherViewModel.observationQualityLabel)
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundColor(observationQualityColor(weatherViewModel.observationQualityLabel))
                        }
                    }
                    .frame(width: 70, height: 70)
                    
                    // Vertical Text Telemetry Lines Data List
                    VStack(alignment: .leading, spacing: 4) {
                        Text("MOON ILLUMINATION: \(Int(weatherViewModel.moonIlluminationEstimate * 100))%")
                        Text("MOON PHASE: \(weatherViewModel.moonPhaseDescription)")
                        Text("MOONSET TIME: \(weatherViewModel.moonsetTimeString)")
                        Text("TRUE DARK WINDOW: \(stargazerViewModel.stargazerState.trueDarkWindow)")
                    }
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundColor(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 3)
            }
            
            Divider().background(Color.cyan)
            
            // 📅 2. HORIZONTAL SCROLL TIMELINE WEEK FORECAST
            VStack(alignment: .leading, spacing: 8) {
                Text("7-DAY SKY OBSERVATION LOOKAHEAD")
                    .font(.system(.caption, design: .monospaced))
                    .fontWeight(.bold)
                    .foregroundColor(.secondary)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(stargazerViewModel.stargazerState.forecastWeek) { day in
                            StargazeForecastCard(day: day)
                        }
                    }
                }
            }
            
            Divider().background(Color.cyan)
            
            // 🎯 3. VERTICAL LIVE TARGETS MATRIX RADAR LIST ROWS
            VStack(alignment: .leading, spacing: 4) {
                Text("PLANETS & MOON CURRENTLY OVERHEAD")
                    .font(.system(.caption, design: .monospaced))
                    .fontWeight(.bold)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 4)
                
                VStack(spacing: 0) {
                    // 💡 THE PERFOMANCE FIX: Filter to ONLY render "PLANET"/"MOON" classifications on the main dashboard tab!
                    ForEach(stargazerViewModel.stargazerState.liveVisibleTargets.filter { $0.classification == "PLANET" || $0.classification == "MOON" }) { planet in
                        CelestialTargetRowView(planet: planet)
                        
                        if planet.id != stargazerViewModel.stargazerState.liveVisibleTargets.filter({ $0.classification == "PLANET" || $0.classification == "MOON" }).last?.id {
                            Divider()
                        }
                    }
                }
                .padding(.horizontal)
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 3)
            }
        }
    }
    
    // 💡 THE DYNAMIC BRIEFING ENGINE: Translates our physical scenario grid into plain-English field intelligence
    private var dynamicMissionBriefingText: String {
        let clouds = weatherViewModel.cloudCoverPercent
        let kp = weatherViewModel.kpIndex
        
        // Define exact weather threshold brackets
        let isOvercast = clouds > 70
        let isPartlyCloudy = clouds > 30 && clouds <= 70
        let isClear = clouds <= 30
        
        // Define exact solar alert threshold brackets
        let isExtremeStorm = kp >= 7.0
        let isMinorStorm = kp >= 5.0 && kp < 7.0
        
        // --- 1. THE OVERCAST BRACKET: Thick clouds block 100% of light ---
        if isOvercast {
            if isExtremeStorm || isMinorStorm {
                return "VISUAL BLOCKED: A solar storm is active right now (KP \(String(format: "%.1f", kp))), but heavy cloud cover (\(clouds)%) completely blocks your view. You will not see anything until the weather layer breaks."
            } else {
                return "TERMINAL BLOCKED: Total cloud cover (\(clouds)%) is blocking the sky, and solar activity is completely quiet. Conditions are poor for all forms of visual astronomy."
            }
        }
        
        // --- 2. THE PARTLY CLOUDY BRACKET: Fragmented sky windows ---
        if isPartlyCloudy {
            if isExtremeStorm {
                return "PARTIAL SIGHTING: An extreme solar storm is active (KP \(String(format: "%.1f", kp))). Passing cloud gaps (\(clouds)% cover) may allow you to catch bright aurora pillars if you scan clear patches of the sky."
            } else if isMinorStorm {
                return "HIGH FRICTION: Minor solar activity detected (KP \(String(format: "%.1f", kp))), but scattered clouds (\(clouds)%) make observation difficult. Horizon glow will be tough to distinguish from light pollution."
            } else {
                return "STANDBY: Skies are partially broken, but solar activity is quiet. You can try tracking brighter satellite crossings through the clear gaps, but there is no aurora risk."
            }
        }
        
        // --- 3. THE CLEAR SKIES BRACKET: Crisp, unobstructed viewports ---
        if isClear {
            if isExtremeStorm {
                return "MAXIMUM ALERT: Perfect tracking window. Local skies are beautifully clear and an extreme solar storm is peaking (KP \(String(format: "%.1f", kp))). Step outside immediately—vivid auroras are highly likely overhead."
            } else if isMinorStorm {
                return "ACTIVE OUTLOOK: Clear skies provide great viewing parameters. A minor solar storm is active (KP \(String(format: "%.1f", kp))). Look toward your northern horizon for visible light glows."
            } else {
                return "PRIME SATELLITE WINDOW: The solar shield is quiet (KP \(String(format: "%.1f", kp))), meaning zero aurora chance. However, because your skies are completely clear, you have the absolute perfect, light-pollution-free window to track satellite crossings, rocket launches, and space stations!"
            }
        }
        
        return "STANDBY // POLLING METRIC DATA..."
    }

    private var toolbarLogoSize: CGFloat {
        // ✅ RESPONSIVE FRACTION: Scales dynamically by measuring the typographic base font profile line height
        let bodyFontMetric = UIFont.preferredFont(forTextStyle: .body).lineHeight
        
        if horizontalSizeClass == .regular {
            // Amplified scaling factor proportional to large-screen layout metrics
            return bodyFontMetric * 4
        } else {
            // Streamlined scaling factor proportional to mobile phone screen layouts
            return bodyFontMetric * 3
        }
    }

    // 💡 THE 7-DAY MANIFEST ENGINE: Calculates tracking windows for the next 7 days
    private var upcomingManifest: [SpaceLaunch] {
        viewModel.launches.filter { launch in
            guard let netString = launch.net else { return false }
            
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            
            var launchDate = formatter.date(from: netString)
            if launchDate == nil {
                let backup = ISO8601DateFormatter()
                launchDate = backup.date(from: netString)
            }
            
            guard let validDate = launchDate else { return false }
            
            // Core structural boundary conditions
            let now = Date()
            guard let sevenDaysFromNow = Calendar.current.date(byAdding: .day, value: 7, to: now) else { return false }
            
            // Capture any target operations scheduled between right now and next week
            return validDate >= now && validDate <= sevenDaysFromNow
        }
    }
    
    // MARK: - STANDALONE COMPONENT: CLEAN PROVIDER LINK ROW
    struct MasterAccessChannelRowView: View {
        let launches: [SpaceLaunch]
        
        var body: some View {
            // 💡 FIXED: Completely removed the hardcoded NavigationLink container to stop it from hijacking touches!
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("ALL ORBITAL PROVIDERS")
                        .font(.system(.headline, design: .monospaced))
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .tracking(1)
                    
                    Text("VIEW MANIFEST DATA BY PROVIDER")
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundColor(.gray)
                }
                Spacer()
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .font(.title2)
                    .foregroundColor(.white)
            }
            .padding(16)
            .background(Color.white.opacity(0.05))
            .cornerRadius(6)
            .padding(.horizontal)
        }
    }
    // Extracted button logic to stop Xcode from freezing
    private var nasaApodButton: some View {
        Button(action: { showAPODDetails = true }) {
            HStack(spacing: 4) {
                Image(systemName: "info.circle")
                Text("NASA APOD")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
            }
            .foregroundColor(.white.opacity(0.35))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.black.opacity(0.4))
            .cornerRadius(4)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
            )
        }
        .padding(16)
    }
    // Extracts meteor layout math to permanently unblock the compiler
    private var annualMeteorShowerChannelBlock: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("ANNUAL METEOR SHOWER OUTLOOK")
                .font(.system(.caption, design: .monospaced).weight(.bold))
                .foregroundColor(.cyan)
                .tracking(2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
            
            if meteorViewModel.upcomingShowers.isEmpty {
                Text("STANDBY LOGS LOADING...")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.gray)
                    .padding(.horizontal)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(meteorViewModel.upcomingShowers) { shower in
                            MeteorShowerCardView(shower: shower, userLatitude: universalLatitude)
                                .onTapGesture {
                                    selectedMeteorShower = shower
                                }
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }
    
    // Isolates the asteroid calculations to fully stabilize the compiler
    private var nasaAsteroidRadarChannelBlock: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("NEAR-EARTH ASTEROIDS (7-DAY)")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(.cyan)
                .tracking(2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
            
            if rockViewModel.isLoading {
                HStack {
                    Spacer()
                    ProgressView("SCANNING JPL DEEP SPACE NETWORK...")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.gray)
                    Spacer()
                }
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .center)
            } else if let error = rockViewModel.errorMessage {
                Text(error)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.red)
                    .padding(.horizontal)
            } else if rockViewModel.asteroids.isEmpty {
                Text("RADAR RANGE CLEAR")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.green)
                    .padding(.horizontal)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(rockViewModel.asteroids) { asteroid in
                            AsteroidCardView(
                                asteroid: asteroid,
                                userLatitude: universalLatitude,
                                userLongitude: universalLongitude
                            )
                            .onTapGesture {
                                selectedAsteroidTarget = asteroid
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                // The Actionable Detailed Telemetry Flyout Sheet
                .sheet(item: $selectedAsteroidTarget) { targetAsteroid in
                    AsteroidDetailView(
                        asteroid: targetAsteroid,
                        userLatitude: universalLatitude,
                        userLongitude: universalLongitude
                    )
                }
            }
        }
    }
    
    // Isolates human crew rendering to guarantee swift compiling
    private var liveHumansInSpaceChannelBlock: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("CURRENT HUMANS IN SPACE (\(crewViewModel.totalHumansInOrbit) ACTIVE)")
                .font(.system(.caption, design: .monospaced).weight(.bold))
                .foregroundColor(.cyan)
                .tracking(2)
                .padding(.horizontal)
            
            if crewViewModel.isLoading {
                Text("SYNCHRONIZING OPEN MANIFEST...")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.gray)
                    .padding(.horizontal)
            } else if let error = crewViewModel.errorMessage {
                Text(error)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.red)
                    .padding(.horizontal)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        if !crewViewModel.issCrew.isEmpty {
                            SpacecraftRosterCardView(craftName: "International Space Station", crewList: crewViewModel.issCrew)
                                .onTapGesture {
                                    selectedSpacecraftCrewName = "International Space Station"
                                }
                        }
                        
                        if !crewViewModel.tiangongCrew.isEmpty {
                            SpacecraftRosterCardView(craftName: "Tiangong Space Station", crewList: crewViewModel.tiangongCrew)
                                .onTapGesture {
                                    selectedSpacecraftCrewName = "Tiangong Space Station"
                                }
                        }
                        
                        if !crewViewModel.otherCrew.isEmpty {
                            SpacecraftRosterCardView(craftName: "Experimental Transits", crewList: crewViewModel.otherCrew)
                            .onTapGesture {
                                selectedSpacecraftCrewName = "Experimental Transits"
                            }
                        }
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal)
                }
            }
        }
    }
    
    // Extracted the location entry box to fix the layout freeze
    private var universalLocationSearchBox: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(satViewModel.errorMessage ?? "ENTER LOCATION MANUALLY")
                .font(.system(.caption2, design: .monospaced))
                .foregroundColor(satViewModel.errorMessage != nil ? .red : .orange)
                .padding(.horizontal)
            
            HStack(spacing: 12) {
                TextField("ENTER CITY NAME (EG. MADISON)", text: $manualCitySearch)
                    .font(.system(.subheadline, design: .monospaced))
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.characters)
                    .padding(12)
                    .background(Color.white.opacity(0.04))
                    .cornerRadius(4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
                
                Button(action: {
                    executeUniversalCitySearch()
                }) {
                    Image(systemName: "magnifyingglass.circle.fill")
                        .font(.title)
                        .foregroundColor(.cyan)
                }
            }
            .padding(.horizontal)
        }
    }

    // Safely unloads complex view logic from the main layout tree
    private var visibleSatellitesChannelBlock: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("UPCOMING SATELLITE PASSES")
                .font(.system(.caption, design: .monospaced).weight(.bold))
                .foregroundColor(.cyan)
                .tracking(2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
            
            if satViewModel.isTracking {
                VStack(spacing: 12) {
                    HStack {
                        Spacer()
                        ProgressView("COMPUTING SKY FOOTPRINT...")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.gray)
                        Spacer()
                    }
                    
                    Button(action: {
                        satViewModel.isTracking = false
                        satViewModel.requiresManualSelection = true
                    }) {
                        Text("CHOOSE CITY MANUALLY ❯")
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundColor(.cyan)
                            .underline()
                    }
                }
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
            } else if satViewModel.requiresManualSelection || !(satViewModel.errorMessage?.isEmpty ?? true) {
                // THE SEARCH CONSOLE: Universal Geocoding Lookup Box Layout
                VStack(alignment: .leading, spacing: 12) {
                    Text(satViewModel.errorMessage ?? "ENTER LOCATION MANUALLY")
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundColor(satViewModel.errorMessage != nil ? .red : .orange)
                        .padding(.horizontal)
                    
                    HStack(spacing: 12) {
                        TextField("ENTER CITY NAME (EG. MADISON)", text: $manualCitySearch)
                            .font(.system(.subheadline, design: .monospaced))
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.characters)
                            .padding(12)
                            .background(Color.white.opacity(0.04))
                            .cornerRadius(4)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                            )
                        
                        Button(action: {
                            executeUniversalCitySearch()
                        }) {
                            Image(systemName: "magnifyingglass.circle.fill")
                                .font(.title)
                                .foregroundColor(.cyan)
                        }
                    }
                    .padding(.horizontal)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else if satViewModel.visiblePasses.isEmpty {
                Button(action: { satViewModel.requestPasses() }) {
                    HStack {
                        Text("INITIALIZE BACKYARD RADAR")
                            .font(.system(.subheadline, design: .monospaced))
                            .fontWeight(.bold)
                            .foregroundColor(.cyan)
                        Spacer()
                        Image(systemName: "antenna.radiowaves.left.and.right")
                            .foregroundColor(.cyan)
                    }
                    .padding(16)
                    .background(Color.white.opacity(0.03))
                    .border(Color.cyan.opacity(0.3), width: 1)
                    .padding(.horizontal)
                }
            } else {
                // 💡 FIXED: Completely cleaned up and type-safe layout points exclusively to your satellite array dataset
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(satViewModel.visiblePasses, id: \.id_swiftui) { (sat: SatellitePass) in
                            SatelliteCardView(sat: sat, location: satViewModel.locationName)
                                .onTapGesture {
                                    selectedSatellitePass = sat
                                }
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }
    
    // Accepts the size class as a parameter to maximize layout readability
    private func principalToolbarHeaderTitleStack(sizeClass: UserInterfaceSizeClass?) -> some View {
        HStack(alignment: .center, spacing: sizeClass == .regular ? 24 : 14) {
            
            // 🚀 LEFT LOGO APERTURE
            Image("logo_transparent")
                .resizable()
                .renderingMode(.template)
                .aspectRatio(contentMode: .fit)
                .frame(width: sizeClass == .regular ? 48 : 38, height: sizeClass == .regular ? 48 : 38)
                .foregroundColor(.init(red: 0.4, green: 0.8, blue: 0.9))
                .padding(sizeClass == .regular ? 6 : 4)
                .background(Color.init(red: 0.4, green: 0.8, blue: 0.9).opacity(0.05))
                .cornerRadius(4)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.init(red: 0.4, green: 0.8, blue: 0.9).opacity(0.2), lineWidth: 1)
                )
            
            // 🚀 CENTRAL CALL SIGN WITH LIVE HARDWARE SYSTEM STATUS BEACON
            VStack(alignment: .center, spacing: 4) {
                Text("DAILY COMMAND")
                    .font(.system(size: sizeClass == .regular ? 24 : 18, weight: .black, design: .monospaced))
                    .foregroundColor(.white)
                    .tracking(sizeClass == .regular ? 6 : 3)
                
                HStack(spacing: 5) {
                    Circle()
                        .fill(connectivityMonitor.isSystemOnline ? Color.green : Color.red)
                        .frame(width: 6, height: 6)
                        .shadow(color: connectivityMonitor.isSystemOnline ? Color.green.opacity(0.5) : Color.red.opacity(0.5), radius: 3)
                    
                    Text(connectivityMonitor.isSystemOnline ? "ORBITLOG LINK OPERATIONAL" : "ORBITLOG DISCONNECTED")
                        .font(.system(size: sizeClass == .regular ? 9 : 8, weight: .bold, design: .monospaced))
                        .foregroundColor(connectivityMonitor.isSystemOnline ? .gray : .red)
                        .tracking(1.5)
                }
            }
            .frame(maxWidth: .infinity)
            
            // 🚀 RIGHT DATA DESCRIPTOR MATRIX: Left-justified grid configuration
            if sizeClass == .regular {
                // 💡 FIXED: Changed text stack alignment to .leading to force left justification
                VStack(alignment: .leading, spacing: 2) {
                    let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
                    Text("SYS.VER // \(appVersion)")
                    
                    if universalLatitude == 0.0 && universalLongitude == 0.0 {
                        Text("RADAR//POL-PND")
                    } else {
                        let latStr = String(format: "%.2f°%@", abs(universalLatitude), universalLatitude >= 0 ? "N" : "S")
                        let lngStr = String(format: "%.2f°%@", abs(universalLongitude), universalLongitude >= 0 ? "E" : "W")
                        
                        // Left-justified string matrix mapping layout rows
                        Text("RADAR // \(latStr) : \(lngStr) // \(satViewModel.countryISOCode)")
                    }
                }
                .font(.system(size: sizeClass == .regular ? 9 : 8, weight: .semibold, design: .monospaced))
                .foregroundColor(.gray)
                .opacity(0.65)
                .frame(width: 170, alignment: .leading) // 💡 FIXED: Changed alignment boundary frame to .leading
            } else {
                Spacer()
                    .frame(width: 24)
            }

        }
        .padding(.horizontal, sizeClass == .regular ? 20 : 14)
        .padding(.vertical, sizeClass == .regular ? 18 : 14)
        .background(Color.black.opacity(0.25))
        .overlay(
            VStack {
                Divider().background(Color.white.opacity(0.12))
                Spacer()
                Divider().background(Color.white.opacity(0.12))
            }
        )
        .padding(.horizontal)
        .padding(.top, sizeClass == .regular ? 26 : 20)
    }
    
    // ==============================================================================
    // 📰 6. SPACEFLIGHT NEWS CHANNEL BLOCK (PAGINATED INFINITE SCROLL)
    // ==============================================================================
    private var spaceflightNewsChannelBlock: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header Label Ticker
            Text("LATEST SPACE NEWS")
                .font(.system(.caption, design: .monospaced).weight(.bold))
                .foregroundColor(.cyan)
                .tracking(2)
                .padding(.vertical, 8)
            
            if newsViewModel.newsState.isNewsLoaded {
                // 💡 THE LAZY LAYER FIX: Swapped VStack for LazyVStack to recycle
                // device image memory automatically as the user scrolls!
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(newsViewModel.newsState.topStories.enumerated()), id: \.element.id) { index, article in
                        Button(action: {
                               
                                // Open up the details summary sheet natively
                                selectedArticle = article
                        }) {
                            VStack(spacing: 0) {
                                SpaceNewsCardView(article: article)
                                
                                // Clean layout separation line partitions between article rows
                                if article.id != newsViewModel.newsState.topStories.last?.id {
                                    Divider()
                                        .padding(.leading, 92) // Clean offset boundary next to thumbnails
                                }
                            }
                        }
                        .buttonStyle(PlainButtonStyle()) // Eliminates the default SwiftUI button cell tap flash
                        // 💡 THE SCROLL TRIGGER FIX: Evaluates the item index against the array count!
                        // This prevents the trigger from firing early on boot setup passes.
                        .onAppear {
                            let totalItems = newsViewModel.newsState.topStories.count
                            if totalItems > 0 && article.id == newsViewModel.newsState.topStories[totalItems - 1].id {
                                Task {
                                    print("🏁 [TRUE SCROLL BOTTOM]: Fetching next page data segment frame...")
                                    await newsViewModel.fetchNextPagePayload()
                                }
                            }
                        }
                        
                        // 💡 Native ad card, woven in every 7 articles — styled to match
                        // SpaceNewsCardView so it reads as part of the feed rather than an
                        // interruption. Renders nothing until an ad actually loads.
                        if (index + 1) % 7 == 0 && !adEngine.isPremiumUnlocked {
                            VStack(spacing: 0) {
                                NativeNewsAdCard(adUnitID: adEngine.newsNativeAdUnitID)
                                if article.id != newsViewModel.newsState.topStories.last?.id {
                                    Divider()
                                        .padding(.leading, 92)
                                }
                            }
                        }
                    }
                    
                    // 🔄 SPINNER FOOTER TRAY: Displays a tiny loading ring at the bottom while page 2-10 loads
                    if newsViewModel.newsState.isFetchingNextPage {
                        HStack {
                            Spacer()
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("LOADING MORE STORIES...")
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundColor(.secondary)
                                .padding(.leading, 4)
                            Spacer()
                        }
                        .padding(.vertical, 16)
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 3)
            } else {
                // Inline loading tray if network synchronization state checks are lagging on boot
                HStack {
                    Spacer()
                    ProgressView()
                        .padding(.trailing, 8)
                    Text("SYNCHRONIZING NEWS FEEDS...")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.vertical, 32)
                .background(Color(.systemBackground))
                .cornerRadius(12)
            }
        }
    }

    private var upcoming7DayMissionsChannelBlock: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("UPCOMING 7-DAY LAUNCHES")
                .font(.system(.caption, design: .monospaced).weight(.bold))
                .foregroundColor(.cyan)
                .tracking(2)
                .padding(.horizontal)
            
            // MARK: - 🚀 ORBITAL PROVIDER DYNAMIC PARSER
            let dynamicProvidersList: [String] = {
                let extractedNames = upcomingManifest.compactMap { launch in
                    launch.launch_service_provider?.name ?? "UNKNOWN PROVIDER"
                }
                let uniqueSet = Set(extractedNames)
                return ["ALL OPERATIONS"] + uniqueSet.sorted()
            }()
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(dynamicProvidersList, id: \.self) { filterName in
                        Button(action: { selectedAgencyFilter = filterName }) {
                            Text(filterName.uppercased())
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(selectedAgencyFilter == filterName ? .black : .gray)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(selectedAgencyFilter == filterName ? Color.cyan : Color.white.opacity(0.04))
                                .cornerRadius(4)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4)
                                        .stroke(selectedAgencyFilter == filterName ? Color.cyan : Color.white.opacity(0.08), lineWidth: 1)
                                )
                        }
                    }
                }
                .padding(.horizontal)
            }
            .padding(.bottom, 4)
            
            if viewModel.isLoading {
                ProgressView("POLLING LOGS...")
                    .font(.system(.caption, design: .monospaced))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            } else {
                // MARK: - 🔎 ZERO-MISS FILTER MATCHING
                let filteredManifest = upcomingManifest.filter { launch in
                    if selectedAgencyFilter == "ALL OPERATIONS" { return true }
                    let providerName = launch.launch_service_provider?.name ?? "UNKNOWN PROVIDER"
                    return providerName == selectedAgencyFilter
                }
                
                if filteredManifest.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("NO ACTIVE LAUNCH VECTORS FOUND")
                            .font(.system(.subheadline, design: .monospaced))
                            .fontWeight(.bold)
                            .foregroundColor(.orange)
                        Text("STANDBY STATUS ACTIVE FOR SECTOR")
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundColor(.gray)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white.opacity(0.02))
                    .cornerRadius(4)
                    .padding(.horizontal)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(filteredManifest) { launch in
                                LaunchCardView(
                                    launch: launch,
                                    onWatchTap: { embeddedURL in
                                        activeLiveStreamURL = embeddedURL
                                        streamingLaunchName = launch.name
                                        streamingLaunchNetDate = launch.net
                                        showLiveVideoTelemetrySheet = true
                                    }
                                )
                                .onTapGesture {
                                    selectedSpaceLaunch = launch
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
        }
    }

    var body: some View {
        TabView {
            NavigationView {
                ZStack {
                    TacticalAmbientBackdropView(apodViewModel: apodViewModel, showInfoSheet: $showAPODDetails)
                    
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 8) { // 💡 Tight 8pt default spacing keeps titles clipped closely to their true cards below
                            stargazingConditionsHeaderBar
                                .padding(.top, 16) // 💡 Clears the frame constraints of the absolutely positioned Daily Command header box
                            Divider()
                                .background(Color.cyan)
                            
                            // 💡 StarGaze entry point, also on the default landing tab — not a
                            // duplicate dashboard, just the same single launch card used on
                            // the Star Gazer tab, reusing the same trigger
                            // (showLiveViewfinderOverlay) and the same asset/design. The
                            // flagship feature of this release shouldn't be a tab-swipe away
                            // from the screen most users land on first.
                            Button(action: {
                                showLiveViewfinderOverlay = true
                            }) {
                                ZStack(alignment: .bottomLeading) {
                                    Image("night_sky_banner")
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(height: 120)
                                        .background(Color(.systemGray6))
                                        .clipped()
                                    
                                    LinearGradient(
                                        colors: [Color.black.opacity(0.85), Color.black.opacity(0.1)],
                                        startPoint: .bottom,
                                        endPoint: .top
                                    )
                                    
                                    HStack(alignment: .bottom) {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("OPEN LIVE INTERACTIVE SKY MAP")
                                                .font(.system(.caption2, design: .monospaced))
                                                .fontWeight(.bold)
                                                .foregroundColor(.cyan)
                                            
                                            Text("POINT DEVICE TO FIND PLANETS")
                                                .font(.system(.subheadline, design: .default))
                                                .fontWeight(.bold)
                                                .foregroundColor(.white)
                                        }
                                        
                                        Spacer()
                                        
                                        Image(systemName: "scope")
                                            .font(.title2)
                                            .foregroundColor(.cyan)
                                    }
                                    .padding()
                                }
                                .cornerRadius(12)
                                .shadow(color: Color.black.opacity(0.2), radius: 6, x: 0, y: 3)
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            // 🛰️ 1. UPCOMING 7-DAY MISSIONS MANIFEST CHANNEL (Includes your company filter buttons and horizontal cards)
                            upcoming7DayMissionsChannelBlock
                                .toolbar {
                                    ToolbarItem(placement: .principal) {
                                        principalToolbarHeaderTitleStack(sizeClass: horizontalSizeClass)
                                    }
                                    // 💡 Persistent, low-key entry point into the voluntary
                                    // "Go Ad-Free" sheet — nothing forces this open, it's
                                    // just always reachable for whoever goes looking for it.
                                    // 💡 Keys off hasPermanentAdFree specifically, not the
                                    // combined isPremiumUnlocked — this icon should stay
                                    // visible through an active temporary ad-free window
                                    // (there's still a reason to tap it: buying permanently),
                                    // only disappearing once ads are actually gone for good.
                                    if !adEngine.hasPermanentAdFree {
                                        ToolbarItem(placement: .navigationBarTrailing) {
                                            Button(action: { showAdPromptOverlay = true }) {
                                                Image(systemName: "tv.slash")
                                                    .font(.system(size: 14, weight: .semibold))
                                                    .foregroundColor(.cyan)
                                            }
                                        }
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            // 3. MASTER ACCESS CHANNEL ROADWAY LINK (Pulls tight under the launch tracks thanks to parent spacing: 8)
                            VStack(alignment: .leading, spacing: 2) {
                                NavigationLink(destination: ProviderIndexView(launches: viewModel.launches)) {
                                    MasterAccessChannelRowView(launches: viewModel.launches)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            Divider()
                                .background(Color.cyan)
                            
                            // 🛰️ 2. VISIBLE OVERHEAD SATELLITES WATCH MODULE (NEXT 48 HOURS)
                            visibleSatellitesChannelBlock
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.top, 24)
                            Divider()
                                .background(Color.cyan)
                            // 🛰️ 3. NASA NEAR-EARTH ASTEROID INTERCEPT RADAR STREAM (7-DAY MANIFEST)
                            nasaAsteroidRadarChannelBlock
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.top, 24) // 💡 Pushes the title text down away from the satellite cards above it so it matches its cards
                            Divider()
                                .background(Color.cyan)
                            // 🛰️ 4. ANNUAL METEOR SHOWER LOOKAHEAD MANIFEST CHANNEL
                            annualMeteorShowerChannelBlock
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.top, 24) // 💡 Separates the meteor timelines from the asteroid radar matrix above it
                            Divider()
                                .background(Color.cyan)
                            // THE 3D ORBITAL INTERCEPT RADAR MAP CONTAINER
                            SpaceStationRadarChannelView()
                                .padding(.top, 24)
                            // 🛰️ 5. LIVE HUMANS IN SPACE ROSTER CHANNEL BLOCK
                            liveHumansInSpaceChannelBlock
                                .padding(.top, 24)
                            Divider()
                                .background(Color.cyan)
                        } // Closes the outermost VStack inside ScrollView
                        .padding(.top, 24)
                        .padding(.bottom, 60) // Safe scrolling buffer space so the lower content clears the hardware device bezels cleanly
                    } // Closes ScrollView
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbarBackground(.hidden, for: .navigationBar)
                    
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            nasaApodButton
                        }
                    }
                    .opacity(apodViewModel.isLoaded ? 1.0 : 0.0)
                    
                    // 💡 Voluntary "Go Ad-Free" sheet — reached via the persistent entry point
                    // (see the header button below), never as a forced interrupt.
                    if showAdPromptOverlay {
                        AdPromptOverlayView(
                            adEngine: adEngine,
                            actionLabel: "Ad-Free Access",
                            onTriggerAd: {
                                adEngine.showAdFromKeyWindow {
                                    showAdPromptOverlay = false
                                }
                            },
                            onDismiss: {
                                showAdPromptOverlay = false
                            }
                        )
                        .transition(.opacity.animation(.easeInOut))
                    }
                    // 💡 THE CONDITIONS BRIEFING POPUP: Dimmed backdrop with a clean, centralized terminal box
                    if showConditionsExplainer {
                        ZStack {
                            Color.black.opacity(0.85)
                                .ignoresSafeArea()
                                .onTapGesture { showConditionsExplainer = false } // Dismiss when background is tapped
                            
                            VStack(alignment: .leading, spacing: 20) {
                                // Header Row
                                HStack {
                                    Text("FIELD BRIEFING: WEATHER STATUS")
                                        .font(.system(.subheadline, design: .monospaced))
                                        .fontWeight(.bold)
                                        .foregroundColor(.cyan)
                                    Spacer()
                                    Button(action: { showConditionsExplainer = false }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.title2)
                                            .foregroundColor(.gray)
                                    }
                                }
                                
                                Divider()
                                    .background(Color.white.opacity(0.15))
                                
                                // Human-Readable Telemetry Breakdown
                                VStack(alignment: .leading, spacing: 14) {
                                    // 💡 THE COMPLIANT TARGET INSIGHT ROW: Renders our exact dynamic string matrix text flawlessly
                                    Text(dynamicMissionBriefingText)
                                        .fontWeight(.bold)
                                        .foregroundColor(weatherViewModel.cloudCoverPercent <= 30 ? .green : (weatherViewModel.cloudCoverPercent > 70 ? .orange : .yellow))
                                    Text("• CLOUDS & HUMIDITY: This dictates your visual visibility vector. Low cloud cover (< 30%) and low humidity mean crisp, high-clarity viewing conditions through your local atmospheric path.")
                                    
                                    Text("• KP-INDEX: This tracks geomagnetic solar storms in the upper atmosphere on a scale of 0 to 9. High scores (5+) trigger aurora displays.")
                                    
                                }
                                .font(.system(.footnote, design: .monospaced))
                                .foregroundColor(.secondary)
                                .lineSpacing(4)
                            }
                            .padding(24)
                            .background(Color(red: 0.06, green: 0.06, blue: 0.06))
                            .border(Color.white.opacity(0.1), width: 1)
                            .cornerRadius(6)
                            .padding(.horizontal, horizontalSizeClass == .regular ? 140 : 24)
                        }
                        .transition(.opacity.animation(.easeInOut(duration: 0.2)))
                    }
                    
                    
                } // Closes ZStack
                .onAppear {
                    let navigationBarAppearance = UINavigationBarAppearance()
                    navigationBarAppearance.configureWithTransparentBackground()
                    UINavigationBar.appearance().standardAppearance = navigationBarAppearance
                    UINavigationBar.appearance().compactAppearance = navigationBarAppearance
                    UINavigationBar.appearance().scrollEdgeAppearance = navigationBarAppearance
                }
                .task {
                    // 1. Request local device alert permissions immediately on workspace load
                    notificationEngine.requestPermission()
                    
                    // 2. Fire down all background API web asset streams
                    await viewModel.fetchLaunches()
                    satViewModel.requestPasses()
                    await rockViewModel.fetchAsteroidRadar()
                    await apodViewModel.fetchDailyBackdrop()
                    
                    // 3. Process dynamic hardware location parameters for meteor streams
                    let resolvedCoordinate = await locationProvider.currentLocation()
                    let hardwareLat = resolvedCoordinate?.latitude ?? 43.0731
                    let hardwareLng = resolvedCoordinate?.longitude ?? -89.4012
                    if resolvedCoordinate == nil {
                        print("⚠️ [LOCATION]: No authorized fix available — using fallback coordinate (Madison, WI).")
                    }
                    meteorViewModel.generateOutlook(userLatitude: hardwareLat)
                    
                    // 💡 INJECTED PRE-FETCH INTO STEP 3: Pulls current weather data using a clean ISO8601 date string
                    let currentISOString = ISO8601DateFormatter().string(from: Date())
                    await weatherViewModel.fetchStargazingWeather(lat: hardwareLat, lng: hardwareLng, targetISO8601Date: currentISOString)
                    await weatherViewModel.fetchGeomagneticRadar()
                    await weatherViewModel.fetchMoonData(lat: hardwareLat, lng: hardwareLng)
                    
                    // Both cloud/humidity (fetchStargazingWeather) and moon brightness
                    // (fetchMoonData) are in now, so the composite score can be computed.
                    weatherViewModel.updateObservationIndex()
                    
                    // Real 7-day outlook, replacing the old fixed "EXCELLENT" stub.
                    stargazerViewModel.stargazerState.forecastWeek = await weatherViewModel.fetchWeekAheadOutlook(lat: hardwareLat, lng: hardwareLng)
                    
                    // 4. THE ALERT INTEGRATION: Compile today's targets and arm the 08:00 AM local alarm block
                    notificationEngine.scheduleDailyBriefing(
                        launches: viewModel.launches,
                        satellites: satViewModel.visiblePasses,
                        meteorShowers: meteorViewModel.upcomingShowers
                    )
                }
                .task {
                    print("🚀 [CONTENT VIEW]: Initiating parallel astronaut fetch...")
                    await crewViewModel.fetchAstronautRoster()
                }
            }// Closes NavigationView
            .navigationViewStyle(.stack)
            .preferredColorScheme(.dark)
            .sheet(isPresented: $showAPODDetails) {
                APODCreditDetailSheet(title: apodViewModel.photoTitle, explanation: apodViewModel.photoExplanation)
            }
            .sheet(item: $selectedMeteorShower) { shower in
                MeteorShowerDetailSheet(shower: shower, userLatitude: universalLatitude)
            }
            .sheet(item: $selectedSpaceLaunch) { launch in
                NavigationStack {
                    MissionSingleDetailView(launch: launch)
                }
                .preferredColorScheme(.dark)
            }
            // Astronaut crew profile manifest sheet container
            .sheet(item: Binding(
                get: { selectedSpacecraftCrewName != nil ? CrewSheetIdentifiable(name: selectedSpacecraftCrewName!) : nil },
                set: { selectedSpacecraftCrewName = $0?.name }
            )) { wrapper in
                // 💡 COMPUTES AUTOMATIC CROSS-REFERENCE TELEMETRY ON OPEN
                let targetedCrew = wrapper.name.contains("International") ? crewViewModel.issCrew : crewViewModel.tiangongCrew
                SpacecraftDetailSheet(craftName: wrapper.name, crewList: targetedCrew, passes: satViewModel.visiblePasses)
            }
            // 💡 FIXED: Uses exact parameter matching and safely unwraps the heading Double value
            .sheet(item: $selectedSatellitePass) { pass in
                SatelliteDetailSheet(
                    sat: pass,
                    weatherEngine: weatherViewModel,
                    location: satViewModel.locationName,
                    userHeading: satViewModel.currentHeading
                )
            }
            .sheet(isPresented: $showLiveVideoTelemetrySheet) {
                LaunchLiveStreamPlayerView(
                    //            streamURLString: "https://www.youtube.com/watch?v=awQzjn72bI0",
                    streamURLString: activeLiveStreamURL,
                    launchName: streamingLaunchName,
                    launchNetDateString: streamingLaunchNetDate
                )
            }
            .sheet(item: $selectedArticle) { article in
                SpaceNewsDetailSheet(article: article)
            }
            .task {
                await newsViewModel.loadLatestSpaceNews()
            }
            
            // ==============================================================================
            // CHANNEL TAB 1: HOME COMMAND
            // ==============================================================================
            // (Your untouched home command views sit inside this frame slot)
            .tabItem {
                Label("Home Command", systemImage: "house")
            }
            
            // ==============================================================================
            // CHANNEL TAB 2: STAR GAZERS TELEMETRY CARD TRAY DECK
            // ==============================================================================
            VStack(spacing: 0) {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 8) {
                        stargazerDashboardChannelBlock
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 24)
                    }
                    .padding(.horizontal)
                    .padding(.top, 24)
                    .padding(.bottom, 60)
                }
                .task {
                    print("📡 [ASTRONOMY UPDATE]: Ingesting live hardware GPS telemetry...")
                    
                    let resolvedCoordinate = await locationProvider.currentLocation()
                    let hardwareLat = resolvedCoordinate?.latitude ?? 43.0731
                    let hardwareLng = resolvedCoordinate?.longitude ?? -89.4012
                    if resolvedCoordinate == nil {
                        print("⚠️ [LOCATION]: No authorized fix available — using fallback coordinate (Madison, WI).")
                    }
                    
                    // Clean, true parameter inputs with absolutely zero made-up variables!
                    await stargazerViewModel.calculateStargazingTelemetry(
                        latitude: hardwareLat,
                        longitude: hardwareLng
                    )
                }
            }
            .tabItem {
                Label("Star Gazers", systemImage: "moon.stars")
            }

            // ==============================================================================
            // CHANNEL TAB 3: SPACE NEWS
            // ==============================================================================
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 8) {
                    spaceflightNewsChannelBlock
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 24)
                }
                .padding(.top, 24)
                .padding(.bottom, 60)
            }
            .tabItem {
                Label("Space News", systemImage: "newspaper")
            }
        }
        // 🪐 FULL SCREEN LENS VIEWFINDER MODAL POPUP LAYER COVERAGE
        .fullScreenCover(isPresented: $showLiveViewfinderOverlay) {
            // 💡 THE TRUE DATA FEED: Passes your real live downloaded planets list array down into the finder lookups!
            LiveSkyViewfinderOverlay(
                visiblePlanetsCatalog: stargazerViewModel.stargazerState.liveVisibleTargets,
                moonBrightnessPenalty: weatherViewModel.moonBrightnessPenalty
            )
        }
    }

 // Closes var body: some View
    // 💡 THE UNTANGLED GEOCODING INTERCEPT METHOD: Handles universal vector mapping
    /// Maps the quality label back to a display color. Kept here rather than in the view
    /// model since color choice is a UI concern — the view model only owns the score/label.
    private func observationQualityColor(_ label: String) -> Color {
        switch label {
        case "OPTIMAL": return .green
        case "GOOD": return .cyan
        case "FAIR": return .yellow
        default: return .orange
        }
    }

    private func executeUniversalCitySearch() {
        guard !manualCitySearch.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        
        satViewModel.isTracking = true
        satViewModel.errorMessage = nil
        
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = manualCitySearch
        request.resultTypes = .address
        
        let search = MKLocalSearch(request: request)
        
        Task {
            do {
                let response = try await search.start()
                
                // 💡 FIXED: Changing this to .placemark.coordinate satisfies modern MapKit standards and clears compilation errors instantly
                if let coordinate = response.mapItems.first?.placemark.coordinate {
                    await MainActor.run {
                        // 1. Commit coordinates to your local universal state parameters instantly
                        self.universalLatitude = coordinate.latitude
                        self.universalLongitude = coordinate.longitude
                        
                        // 2. Force meteor view model to dynamically calculate the new horizon ratings
                        meteorViewModel.generateOutlook(userLatitude: coordinate.latitude)
                        
                        // 3. Clear out any previous weather parameters so it refreshes cleanly for the new city
                        weatherViewModel.cloudCoverPercent = 0
                        weatherViewModel.humidityPercent = 0
                        weatherViewModel.observationRating = "POLLING COMPASS DATA..."
                        weatherViewModel.moonPhaseDescription = "CALCULATING..."
                        weatherViewModel.moonriseTimeString = "--:--"
                        weatherViewModel.moonsetTimeString = "--:--"
                        weatherViewModel.observationIndex = 0
                        weatherViewModel.observationQualityLabel = "CALCULATING..."
                        stargazerViewModel.stargazerState.isDataLoaded = false
                        
                        // 4. Dispatch the exact clean coordinates down to your satellite engine network pipeline
                        let latStr = String(format: "%.4f", coordinate.latitude)
                        let lngStr = String(format: "%.4f", coordinate.longitude)
                        satViewModel.selectCityCoordinates(lat: latStr, lng: lngStr)
                    }
                    
                    // 5. Actually re-fetch everything location-dependent for the new coordinates.
                    // Previously this only reset fields to loading placeholders and stopped —
                    // nothing ever re-populated them, so switching cities silently left every
                    // stargazing/weather/moon value stuck showing the OLD city's data (or a
                    // permanent "CALCULATING..." if the old data hadn't loaded yet either).
                    let currentISOString = ISO8601DateFormatter().string(from: Date())
                    await stargazerViewModel.calculateStargazingTelemetry(latitude: coordinate.latitude, longitude: coordinate.longitude)
                    await weatherViewModel.fetchStargazingWeather(lat: coordinate.latitude, lng: coordinate.longitude, targetISO8601Date: currentISOString)
                    await weatherViewModel.fetchMoonData(lat: coordinate.latitude, lng: coordinate.longitude)
                    weatherViewModel.updateObservationIndex()
                    let newOutlook = await weatherViewModel.fetchWeekAheadOutlook(lat: coordinate.latitude, lng: coordinate.longitude)
                    await MainActor.run {
                        stargazerViewModel.stargazerState.forecastWeek = newOutlook
                    }
                } else {
                    await MainActor.run {
                        satViewModel.errorMessage = "CITY NOT FOUND"
                        satViewModel.isTracking = false
                    }
                }
            } catch {
                await MainActor.run {
                    satViewModel.errorMessage = "SEARCH FAILED"
                    satViewModel.isTracking = false
                }
            }
        }
    }
}

// MARK: - SUB-VIEW: ALPHABETICAL CORPORATE FIRM DIRECTORY INDEX
struct ProviderIndexView: View {
    let launches: [SpaceLaunch]
    
    private var groupedProviders: [String: [SpaceLaunch]] {
        Dictionary(grouping: launches) { launch in
            launch.launch_service_provider?.name ?? "UNKNOWN PROVIDER"
        }
    }
    
    private var sortedProviderNames: [String] {
        groupedProviders.keys.sorted()
    }
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                ForEach(sortedProviderNames, id: \.self) { companyName in
                    let matches = groupedProviders[companyName] ?? []
                    
                    NavigationLink(destination: CompanyDetailView(companyName: companyName, launches: matches)) {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(companyName.uppercased())
                                    .font(.system(.headline, design: .monospaced))
                                    .fontWeight(.bold)
                                    .tracking(1)
                                    .foregroundColor(.white)
                                Spacer()
                                Text("\(matches.count) LAUNCHES")
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundColor(.secondary)
                            }
                            Divider()
                                .padding(.top, 10)
                        }
                        .padding(.horizontal)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.top, 20)
        }
        .navigationTitle("ORBITAL PROVIDERS")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct CrewSheetIdentifiable: Identifiable {
    var id: String { name }
    let name: String
}

struct IdentifiableStream: Identifiable {
    let id = UUID()
    let url: String
}
