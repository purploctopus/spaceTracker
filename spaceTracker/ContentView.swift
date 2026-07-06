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
    
    var body: some View {
        NavigationView {
            ZStack {
                TacticalAmbientBackdropView(apodViewModel: apodViewModel, showInfoSheet: $showAPODDetails)
                
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 32) {
                        
                        // 1. WEEKLY MANIFEST SECTION BLOCK
                        VStack(alignment: .leading, spacing: 16) {
                            Text("UPCOMING 7-DAY MISSIONS")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.secondary)
                                .tracking(2)
                                .padding(.horizontal)
                            
                            if viewModel.isLoading {
                                ProgressView("POLLING LOGS...")
                                    .font(.system(.caption, design: .monospaced))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 20)
                            } else if upcomingManifest.isEmpty {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("NO TARGET OPERATIONS THIS WEEK")
                                        .font(.system(.subheadline, design: .monospaced))
                                        .fontWeight(.bold)
                                        .foregroundColor(.orange)
                                    Text("STANDBY STATUS ACTIVE")
                                        .font(.system(.caption2, design: .monospaced))
                                        .foregroundColor(.gray)
                                }
                                .padding(16)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.white.opacity(0.02))
                                .cornerRadius(4)
                                .padding(.horizontal)
                            } else {
                                // ✅ FIXED: Replaced your old vertical loop with the smooth horizontal scroll view
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 12) {
                                        ForEach(upcomingManifest) { launch in
                                            LaunchCardView(launch: launch)
                                                .onTapGesture {
                                                    selectedSpaceLaunch = launch
                                                }
                                        }
                                    }
                                    .padding(.horizontal)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading) // ✅ FIXED: Clamps the block layout width
                        
                        // 3. MASTER ACCESS CHANNEL ROADWAY LINK
                        VStack(alignment: .leading, spacing: 12) {
                            NavigationLink(destination: ProviderIndexView(launches: viewModel.launches)) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("ALL ORBITAL PROVIDERS")
                                            .font(.system(.headline, design: .monospaced))
                                            .fontWeight(.bold)
                                            .foregroundColor(.white)
                                            .tracking(1)
                                        Text("VIEW MANIFEST DATA BY FIRM")
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
                            .buttonStyle(PlainButtonStyle())
                        }
                        .frame(maxWidth: .infinity, alignment: .leading) // ✅ FIXED: Binds the layout matrix block width safely
                        
                        // 🛰️ 2. VISIBLE OVERHEAD SATELLITES WATCH MODULE (NEXT 48 HOURS)
                        VStack(alignment: .leading, spacing: 16) {
                            Divider()
                                .background(Color.white.opacity(0.1))
                            Text("OVERHEAD VISUAL TRACKS (48H)")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.secondary)
                                .tracking(2)
                                .frame(maxWidth: .infinity, alignment: .leading) // ✅ FIXED: Keeps header baseline aligned left
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
                                .frame(maxWidth: .infinity, alignment: .leading) // ✅ FIXED: Prevents loading block width leakage
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
                                            // 💡 CLEAN ACTION TRIGGER: Dispatches to helper function below
                                            executeUniversalCitySearch()
                                        }) {
                                            Image(systemName: "magnifyingglass.circle.fill")
                                                .font(.title)
                                                .foregroundColor(.cyan)
                                        }
                                    }
                                    .padding(.horizontal)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading) // ✅ FIXED: Prevents input layout stretch blocks
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
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 12) {
                                        ForEach(satViewModel.visiblePasses, id: \.id_swiftui) { sat in
                                            // UPDATED: Now passing the location name dynamically down into the card matrix layout
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
                        .frame(maxWidth: .infinity, alignment: .leading) // ✅ FIXED: Binds the tracking system module bounds safely
                        
                        // 🛰️ 3. NASA NEAR-EARTH ASTEROID INTERCEPT RADAR STREAM (7-DAY MANIFEST)
                        VStack(alignment: .leading, spacing: 16) {
                            Text("NEAR-EARTH OBJECTS RADAR (7-DAY)")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.secondary)
                                .tracking(2)
                                .frame(maxWidth: .infinity, alignment: .leading) // ✅ FIXED: Keeps header baseline aligned left
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
                                .frame(maxWidth: .infinity, alignment: .center) // ✅ FIXED: Clamps progress bar bounds
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
                                            AsteroidCardView(asteroid: asteroid)
                                        }
                                    }
                                    .padding(.horizontal)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading) // ✅ FIXED: Seals asteroid section horizontal container
                        
                        // 🛰️ 4. ANNUAL METEOR SHOWER LOOKAHEAD MANIFEST CHANNEL
                        VStack(alignment: .leading, spacing: 16) {
                            Text("ANNUAL METEOR SHOWER OUTLOOK")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.secondary)
                                .tracking(2)
                                .frame(maxWidth: .infinity, alignment: .leading) // ✅ FIXED: Keeps header baseline aligned left
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
                                            // 💡 INJECTED TAP TRIGGER: Captures shower data reference token on touch tap
                                                .onTapGesture {
                                                    selectedMeteorShower = shower
                                                }
                                        }
                                    }
                                    .padding(.horizontal)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading) // ✅ FIXED: Seals meteor section horizontal container
                        // 🛰️ 5. LIVE HUMANS IN SPACE ROSTER CHANNEL BLOCK
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
                                        }
                                        
                                        if !crewViewModel.tiangongCrew.isEmpty {
                                            SpacecraftRosterCardView(craftName: "Tiangong Space Station", crewList: crewViewModel.tiangongCrew)
                                        }
                                        
                                        if !crewViewModel.otherCrew.isEmpty {
                                            SpacecraftRosterCardView(craftName: "Experimental Transits", crewList: crewViewModel.otherCrew)
                                        }
                                    }
                                    .fixedSize(horizontal: false, vertical: true)
                                    .padding(.horizontal)
                                }
                            }
                        }

                    } // Closes the outermost VStack inside ScrollView
                    .padding(.top, 24)
                    .padding(.bottom, 60)
                } // Closes ScrollView
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(.hidden, for: .navigationBar)
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        HStack(spacing: horizontalSizeClass == .regular ? 16 : 10) {
                            Image("earthBlueSLS")
                              //  .renderingMode(.template)
                                .resizable()
                                .scaledToFit()
                                .frame(width: toolbarLogoSize, height: toolbarLogoSize)
                                .foregroundColor(.init(red: 0.4, green: 0.8, blue: 0.9))
                            
                            Text("DAILY COMMAND")
                                .font(.system(horizontalSizeClass == .regular ? .body : .subheadline, design: .monospaced))
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .tracking(2)
                            
                            Image("logo_transparent")
                            //    .renderingMode(.template)
                                .resizable()
                                .scaledToFit()
                                .frame(width: toolbarLogoSize, height: toolbarLogoSize)
                                .foregroundColor(.init(red: 0.4, green: 0.8, blue: 0.9))
                        }
                    }
                }
                
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
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
                            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.white.opacity(0.1), lineWidth: 0.5))
                        }
                        .padding(16)
                    }
                }
                .opacity(apodViewModel.isLoaded ? 1.0 : 0.0)

            } // Closes ZStack
            .onAppear {
                let navigationBarAppearance = UINavigationBarAppearance()
                navigationBarAppearance.configureWithTransparentBackground()
                UINavigationBar.appearance().standardAppearance = navigationBarAppearance
                UINavigationBar.appearance().compactAppearance = navigationBarAppearance
                UINavigationBar.appearance().scrollEdgeAppearance = navigationBarAppearance
            }
            // 💡 KEEP YOUR EXACT 4-STEP PIPELINE COMPLETELY UNTOUCHED:
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
                meteorViewModel.generateOutlook(userLatitude: hardwareLat)
                
                // 4. THE ALERT INTEGRATION: Compile today's targets and arm the 08:00 AM local alarm block
                notificationEngine.scheduleDailyBriefing(
                    launches: viewModel.launches,
                    satellites: satViewModel.visiblePasses,
                    meteorShowers: meteorViewModel.upcomingShowers
                )
            }
            // 💡 ADD THIS INDEPENDENT LANE IMMEDIATELY UNDERNEATH:
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
        .sheet(item: $selectedSatellitePass) { pass in
            SatelliteDetailSheet(
                sat: pass,
                location: satViewModel.locationName,
                userHeading: satViewModel.currentHeading
            )
            .presentationSizing(.page)
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
                if let coordinate = response.mapItems.first?.location.coordinate {
                    await MainActor.run {
                        // 1. Commit coordinates to your local universal state parameters instantly
                        self.universalLatitude = coordinate.latitude
                        self.universalLongitude = coordinate.longitude
                        
                        // 2. Force meteor view model to dynamically calculate the new horizon ratings
                        meteorViewModel.generateOutlook(userLatitude: coordinate.latitude)
                        
                        // 3. Dispatch the exact clean coordinates down to your satellite engine network pipeline
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
