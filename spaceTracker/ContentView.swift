//
//  ContentView.swift
//  spaceTracker
//
//  Created by Ben Clary on 6/17/26.
//  MAKE AN APP COLIN LOVES

import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = LaunchViewModel()
    
    // Group launches by Company Name dynamically
    private var groupedProviders: [String: [SpaceLaunch]] {
        Dictionary(grouping: viewModel.launches) { launch in
            launch.launch_service_provider?.name ?? "UNKNOWN PROVIDER"
        }
    }
    
    // Sort company listings alphabetically
    private var sortedProviderNames: [String] {
        groupedProviders.keys.sorted()
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 24) {
                        if viewModel.isLoading {
                            ProgressView("FETCHING OPERATIONAL DATA...")
                                .font(.system(.caption, design: .monospaced))
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.top, 40)
                        } else if let error = viewModel.errorMessage {
                            Text("SYSTEM OFFLINE: \(error.uppercased())")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.red)
                                .padding(.horizontal)
                        } else {
                            // Loop through companies and push to their specific detail screens
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
                    }
                    .padding(.top, 20)
                }
            }
            .navigationTitle("ORBITAL PROVIDERS")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await viewModel.fetchLaunches()
            }
        }
        .navigationViewStyle(.stack)
        .preferredColorScheme(.dark)
    }
}
