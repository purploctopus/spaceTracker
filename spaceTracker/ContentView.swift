//
//  ContentView.swift
//  spaceTracker
//
//  Created by Ben Clary on 6/17/26.
//  MAKE AN APP COLIN LOVES

import SwiftUI
import CoreLocation
import MapKit

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



    @StateObject private var adEngine = AdMobEngine()
    @State private var showAdPromptOverlay = false
    @State private var adInterceptActionLabel = ""
    @State private var pendingAdCompletionAction: (() -> Void)? = nil
    
    @StateObject private var connectivityMonitor = SystemConnectivityMonitor()


    // 💡 THE COMPILER GATEKEEPER: Standalone modular components prevents type-check freeze loops
    private var stargazingConditionsHeaderBar: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("LOCAL ATMOSPHERIC RECON")
                .font(.system(.caption2, design: .monospaced))
                .foregroundColor(.secondary)
                .tracking(2)
            
            HStack(spacing: 16) {
                // Cloud Cover Readout Block
                HStack(spacing: 6) {
                    Image(systemName: "cloud.fill")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text("\(weatherViewModel.cloudCoverPercent)% CLOUDS")
                        .font(.system(.caption, design: .monospaced))
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
                
                // Humidity Readout Block
                HStack(spacing: 6) {
                    Image(systemName: "humidity.fill")
                        .font(.caption)
                        .foregroundColor(.cyan)
                    Text("\(weatherViewModel.humidityPercent)% HUMIDITY")
                        .font(.system(.caption, design: .monospaced))
                        .fontWeight(.bold)
                        .foregroundColor(.cyan)
                }
                
                Spacer()
                
                // Operational Sky Status Pill Tag
                Text(weatherViewModel.observationRating.replacingOccurrences(of: " // ", with: ": "))
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(weatherViewModel.cloudCoverPercent > 50 ? .orange : .green)
                
                // 💡 FIXED: Positions the mandatory WeatherKit elements directly to the right of the status pill
                HStack(spacing: 6) {
                    HStack(spacing: 2) {
                        Image(systemName: "apple.logo")
                            .font(.system(size: 9))
                        Text("Weather")
                            .font(.system(size: 9, weight: .semibold))
                    }
                    .foregroundColor(.secondary)
                    
                    Link("Data Sources", destination: URL(string: "https://weatherkit.apple.com/legal-attribution.html")!)
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(.blue)
                }
                .padding(.leading, 4) // Tiny buffer to separate it cleanly from the status pill border
            }
            .padding(12)
            .background(Color.white.opacity(0.04))
            .cornerRadius(4)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
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
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.secondary)
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
                                    if adEngine.isPremiumUnlocked {
                                        selectedMeteorShower = shower
                                    } else {
                                        adInterceptActionLabel = shower.name
                                        pendingAdCompletionAction = { selectedMeteorShower = shower }
                                        showAdPromptOverlay = true
                                    }
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
            Text("NEAR-EARTH OBJECTS RADAR (7-DAY)")
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.secondary)
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
                            // 💡 FIXED: Wrapped inside your active ad monetization firewall gate!
                            .onTapGesture {
                                if adEngine.isPremiumUnlocked {
                                    // 🟢 Premium Active: Skip ad layer and open sheet instantly
                                    selectedAsteroidTarget = asteroid
                                } else {
                                    // 🛑 Ad Gate Active: Cache action parameters and fire intercept overlay
                                    adInterceptActionLabel = asteroid.name
                                    pendingAdCompletionAction = { selectedAsteroidTarget = asteroid }
                                    showAdPromptOverlay = true
                                }
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
            Text("ACTIVE ORBITAL CREW RECON (\(crewViewModel.totalHumansInOrbit) ACTIVE)")
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.secondary)
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
                                // 💡 FIXED: Wrapped inside the active ad monetization firewall gate
                                .onTapGesture {
                                    if adEngine.isPremiumUnlocked {
                                        selectedSpacecraftCrewName = "International Space Station"
                                    } else {
                                        adInterceptActionLabel = "International Space Station Crew"
                                        pendingAdCompletionAction = { selectedSpacecraftCrewName = "International Space Station" }
                                        showAdPromptOverlay = true
                                    }
                                }
                        }
                        
                        if !crewViewModel.tiangongCrew.isEmpty {
                            SpacecraftRosterCardView(craftName: "Tiangong Space Station", crewList: crewViewModel.tiangongCrew)
                                // 💡 FIXED: Wrapped inside the active ad monetization firewall gate
                                .onTapGesture {
                                    if adEngine.isPremiumUnlocked {
                                        selectedSpacecraftCrewName = "Tiangong Space Station"
                                    } else {
                                        adInterceptActionLabel = "Tiangong Space Station Crew"
                                        pendingAdCompletionAction = { selectedSpacecraftCrewName = "Tiangong Space Station" }
                                        showAdPromptOverlay = true
                                    }
                                }
                        }
                        
                        if !crewViewModel.otherCrew.isEmpty {
                            SpacecraftRosterCardView(craftName: "Experimental Transits", crewList: crewViewModel.otherCrew)
                                // 💡 FIXED: Wrapped inside the active ad monetization firewall gate
                                .onTapGesture {
                                    if adEngine.isPremiumUnlocked {
                                        selectedSpacecraftCrewName = "Experimental Transits"
                                    } else {
                                        adInterceptActionLabel = "Experimental Transit Crew"
                                        pendingAdCompletionAction = { selectedSpacecraftCrewName = "Experimental Transits" }
                                        showAdPromptOverlay = true
                                    }
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
            Divider()
                .background(Color.white.opacity(0.1))
            Text("OVERHEAD VISUAL TRACKS (48H)")
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.secondary)
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
                                    // 💡 INTERCEPT GATEKEEPER: Checks if the user has already unlocked access for today
                                    if adEngine.isPremiumUnlocked {
                                        selectedSatellitePass = sat
                                    } else {
                                        adInterceptActionLabel = sat.name
                                        pendingAdCompletionAction = { selectedSatellitePass = sat }
                                        showAdPromptOverlay = true
                                    }
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
            Image("launch_logo")
                .resizable()
                .renderingMode(.template)
                .aspectRatio(contentMode: .fit)
                .frame(width: sizeClass == .regular ? 38 : 28, height: sizeClass == .regular ? 38 : 28)
                .foregroundColor(.init(red: 0.4, green: 0.8, blue: 0.9))
                .padding(sizeClass == .regular ? 10 : 8)
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
        .padding(.top, sizeClass == .regular ? 16 : 10)
    }

    private var upcoming7DayMissionsChannelBlock: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("UPCOMING 7-DAY MISSIONS")
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.secondary)
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
                                    if adEngine.isPremiumUnlocked {
                                        selectedSpaceLaunch = launch
                                    } else {
                                        adInterceptActionLabel = launch.name
                                        pendingAdCompletionAction = { selectedSpaceLaunch = launch }
                                        showAdPromptOverlay = true
                                    }
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
        NavigationView {
            ZStack {
                TacticalAmbientBackdropView(apodViewModel: apodViewModel, showInfoSheet: $showAPODDetails)
                
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 32) {
                        stargazingConditionsHeaderBar
                        // 🛰️ 1. UPCOMING 7-DAY MISSIONS MANIFEST CHANNEL
                        upcoming7DayMissionsChannelBlock
                            .toolbar {
                                ToolbarItem(placement: .principal) {
                                    principalToolbarHeaderTitleStack(sizeClass: horizontalSizeClass)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading) // ✅ FIXED: Clamps the block layout width
                        
                        // 3. MASTER ACCESS CHANNEL ROADWAY LINK
                        VStack(alignment: .leading, spacing: 12) {
                            Divider()
                                .background(Color.white.opacity(0.15))
                                .padding(.horizontal)
                                .padding(.bottom, 10)
                            
                            // 💡 THE DIRECT REIFIED CHECK:
                            if adEngine.isPremiumUnlocked {
                                // YES OK -> Just wrap the card in a standard, direct NavigationLink push
                                NavigationLink(destination: ProviderIndexView(launches: viewModel.launches)) {
                                    MasterAccessChannelRowView(launches: viewModel.launches)
                                }
                                .buttonStyle(PlainButtonStyle())
                                
                            } else {
                                // NO -> Freeze navigation and show your standard ad prompt overlay grid
                                Button(action: {
                                    adInterceptActionLabel = "Global Orbital Providers Directory"
                                    pendingAdCompletionAction = { } // Clears out on video close
                                    showAdPromptOverlay = true
                                }) {
                                    MasterAccessChannelRowView(launches: viewModel.launches)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        // 🛰️ 2. VISIBLE OVERHEAD SATELLITES WATCH MODULE (NEXT 48 HOURS)
                        visibleSatellitesChannelBlock
                            .frame(maxWidth: .infinity, alignment: .leading) // ✅ FIXED: Binds the tracking system module bounds safely
                        
                        // 🛰️ 3. NASA NEAR-EARTH ASTEROID INTERCEPT RADAR STREAM (7-DAY MANIFEST)
                        nasaAsteroidRadarChannelBlock
                            .frame(maxWidth: .infinity, alignment: .leading) // ✅ FIXED: Seals asteroid section horizontal container
                        
                        // 🛰️ 4. ANNUAL METEOR SHOWER LOOKAHEAD MANIFEST CHANNEL
                        annualMeteorShowerChannelBlock
                            .frame(maxWidth: .infinity, alignment: .leading) // ✅ FIXED: Seals meteor section horizontal container
                        
                        // 🛰️ 5. LIVE HUMANS IN SPACE ROSTER CHANNEL BLOCK
                        liveHumansInSpaceChannelBlock
                    } // Closes the outermost VStack inside ScrollView
                    .padding(.top, 24)
                    .padding(.bottom, 60)
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

                // 💡 INJECTED PRE-PRESENTATION GATEWAY OVERLAY MESH
                if showAdPromptOverlay {
                    AdPromptOverlayView(
                        adEngine: adEngine,
                        actionLabel: adInterceptActionLabel,
                        onTriggerAd: {
                            // Extract active key controller windows to handle full screen Google rendering
                            if let rootVC = UIApplication.shared.connectedScenes
                                .compactMap({ $0 as? UIWindowScene })
                                .flatMap({ $0.windows })
                                .first(where: { $0.isKeyWindow })?.rootViewController {
                                
                                adEngine.showAd(from: rootVC) {
                                    // Ad completed! Fire the pending state change and tear down the prompt
                                    showAdPromptOverlay = false
                                    pendingAdCompletionAction?()
                                }
                            }
                        },
                        onDismiss: {
                            showAdPromptOverlay = false
                            pendingAdCompletionAction = nil
                        }
                    )
                    .transition(.opacity.animation(.easeInOut))
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
                let hardwareLat = CLLocationManager().location?.coordinate.latitude ?? 43.0731
                let hardwareLng = CLLocationManager().location?.coordinate.longitude ?? -89.4012
                meteorViewModel.generateOutlook(userLatitude: hardwareLat)
                
                // 💡 INJECTED PRE-FETCH INTO STEP 3: Pulls current weather data using a clean ISO8601 date string
                let currentISOString = ISO8601DateFormatter().string(from: Date())
                await weatherViewModel.fetchStargazingWeather(lat: hardwareLat, lng: hardwareLng, targetISO8601Date: currentISOString)
                
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
        } // Closes NavigationView
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
    }

 // Closes var body: some View
    // 💡 THE UNTANGLED GEOCODING INTERCEPT METHOD: Handles universal vector mapping
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
                        
                        // 4. Dispatch the exact clean coordinates down to your satellite engine network pipeline
                        let latStr = String(format: "%.4f", coordinate.latitude)
                        let lngStr = String(format: "%.4f", coordinate.longitude)
                        satViewModel.selectCityCoordinates(lat: latStr, lng: lngStr)
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

