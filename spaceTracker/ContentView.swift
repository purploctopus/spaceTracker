//
//  ContentView.swift
//  spaceTracker
//
//  Created by Ben Clary on 6/17/26.
//  MAKE AN APP COLIN LOVES

import SwiftUI

struct ContentView: View {
    // 📡 Global Data Engine Hooks
    @StateObject private var viewModel = LaunchViewModel()
    @StateObject private var satViewModel = SatelliteViewModel()
    @State private var manualCitySearch: String = ""
    @StateObject private var rockViewModel = SpaceRocksViewModel()
    
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
                // Core SpaceX Dark Void Backdrop
                Color(red: 0.05, green: 0.05, blue: 0.05)
                    .ignoresSafeArea()
                
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
                                // Maps flights sequentially down your viewport grid
                                ForEach(upcomingManifest) { launch in
                                    NavigationLink(destination: MissionSingleDetailView(launch: launch)) {
                                        VStack(alignment: .leading, spacing: 8) {
                                            HStack {
                                                Text(launch.name.uppercased())
                                                    .font(.system(.headline, design: .monospaced))
                                                    .fontWeight(.bold)
                                                    .foregroundColor(.white)
                                                Spacer()
                                                Image(systemName: "chevron.right")
                                                    .font(.caption)
                                                    .foregroundColor(.gray)
                                            }
                                            Text(launch.launch_service_provider?.name?.uppercased() ?? "GLOBAL RANGE")
                                                .font(.system(.caption, design: .monospaced))
                                                .foregroundColor(.blue)
                                            
                                            // 💡 THE DATE INJECTION ROW: Clearly separates the upcoming schedule days
                                            Text(launch.localLaunchTimeDisplay)
                                                .font(.system(.caption2, design: .monospaced))
                                                .foregroundColor(.yellow)
                                            
                                            Divider()
                                                .background(Color.white.opacity(0.1))
                                        }
                                        .padding(.horizontal)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                        }
                        // 🛰️ 2. VISIBLE OVERHEAD SATELLITES WATCH MODULE (NEXT 48 HOURS)
                        VStack(alignment: .leading, spacing: 16) {
                            Text("OVERHEAD VISUAL TRACKS (48H)")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.secondary)
                                .tracking(2)
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
                                    
                                    // 💡 THE MANUAL OVERRIDE: Tap this to break the loop instantly if it hangs
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
                                            satViewModel.searchAndSelectCity(query: manualCitySearch)
                                        }) {
                                            Image(systemName: "magnifyingglass.circle.fill")
                                                .font(.title)
                                                .foregroundColor(.cyan)
                                        }
                                    }
                                    .padding(.horizontal)
                                }
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
                                            SatelliteCardView(sat: sat)
                                        }
                                    }
                                    .padding(.horizontal)
                                }
                            }
                        }
                        
                        // 3. MASTER ACCESS CHANNEL ROADWAY LINK
                        VStack(alignment: .leading, spacing: 12) {
                            Divider()
                                .background(Color.white.opacity(0.15))
                                .padding(.horizontal)
                                .padding(.bottom, 10)
                            
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
                        // 🛰️ 3. NASA NEAR-EARTH ASTEROID INTERCEPT RADAR STREAM (7-DAY MANIFEST)
                        VStack(alignment: .leading, spacing: 16) {
                            Text("NEAR-EARTH OBJECTS RADAR (7-DAY)")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.secondary)
                                .tracking(2)
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
                    } // Closes the outermost VStack inside ScrollView
                    .padding(.top, 24)
                } // Closes ScrollView
            } // Closes ZStack
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 16) {
                        // Left Flank
                        Image("logo_trans")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: ((UIApplication.shared.connectedScenes.first as? UIWindowScene)?.screen.bounds.width ?? 800) * 0.08)
                            .foregroundColor(.init(red: 0.4, green: 0.8, blue: 0.9))
                        
                        Text("COMMAND OPERATIONS")
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        // Right Flank
                        Image("logo_trans")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: ((UIApplication.shared.connectedScenes.first as? UIWindowScene)?.screen.bounds.width ?? 800) * 0.08)
                            .foregroundColor(.init(red: 0.4, green: 0.8, blue: 0.9))
                    }
                    .font(.system(.body, design: .monospaced))
                    .tracking(2)
                }
            }
            .task {
                await viewModel.fetchLaunches()
                satViewModel.requestPasses()
                await rockViewModel.fetchAsteroidRadar() 
            }
        } // Closes NavigationView
        .navigationViewStyle(.stack)
        .preferredColorScheme(.dark)
    } // Closes var body: some View
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
