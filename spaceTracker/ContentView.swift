//
//  ContentView.swift
//  spaceTracker
//
//  Created by Ben Clary on 6/17/26.
//  MAKE AN APP COLIN LOVES

import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = LaunchViewModel()
    
    // Filter out launches taking place TODAY based on current device calendar
    private var todaysLaunches: [SpaceLaunch] {
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
            return Calendar.current.isDateInToday(validDate)
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
                        
                        // 1. TODAY'S MANIFEST SECTION BLOCK
                        VStack(alignment: .leading, spacing: 16) {
                            Text("TODAY'S MISSIONS")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.secondary)
                                .tracking(2)
                                .padding(.horizontal)
                            
                            if viewModel.isLoading {
                                ProgressView("POLLING LOGS...")
                                    .font(.system(.caption, design: .monospaced))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 20)
                            } else if todaysLaunches.isEmpty {
                                // Standby status state when no flights match today's date parameters
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("NO TARGET OPERATIONS TODAY")
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
                                // Live list mapping launches happening TODAY
                                ForEach(todaysLaunches) { launch in
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
                                            Divider()
                                                .background(Color.white.opacity(0.1))
                                        }
                                        .padding(.horizontal)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                        }
                        
                        // 2. MASTER ACCESS CHANNEL ROADWAY LINK
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
                    }
                    .padding(.top, 24)
                }
            }
            .navigationTitle("COMMAND OPERATIONS")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await viewModel.fetchLaunches()
            }
        }
        .navigationViewStyle(.stack)
        .preferredColorScheme(.dark)
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
