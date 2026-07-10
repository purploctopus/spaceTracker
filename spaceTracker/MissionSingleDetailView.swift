//
//  MissionSingleDetailView.swift
//  spaceTracker
//
//  Created by Ben Clary on 6/17/26.
//

import SwiftUI

struct MissionSingleDetailView: View {
    let launch: SpaceLaunch
    
    // Injected sheet presenter state variable
    @State private var showInternalVideoSheet = false
    
    // Environment handler binds safely at the root level of the struct to open external links
    @Environment(\.openURL) var openExternalLink
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                
                // FULL HEIGHT RESPONSIVE STACK BOOSTER ILLUSTRATION (Screen-Agnostic Layout Matrix)
                if let imageString = launch.image?.image_url,
                   let imageUrl = URL(string: imageString) {
                    
                    AsyncImage(url: imageUrl) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit) // Fits layout bounds cleanly on all devices
                                .frame(maxWidth: .infinity, alignment: .center)
                                .cornerRadius(4)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4)
                                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                                )
                        case .failure:
                            Color.clear.frame(height: 0)
                        case .empty:
                            // 💡 FIXED: Uses dynamic layout constraints instead of hardcoded point sizes
                            VStack {
                                Spacer()
                                ProgressView()
                                Spacer()
                            }
                            .frame(maxWidth: .infinity)
                            .aspectRatio(16/9, contentMode: .fit) // 💡 Forces a fluid, responsive container footprint while loading
                            .background(Color.white.opacity(0.02))
                            .cornerRadius(4)
                        @unknown default:
                            EmptyView()
                        }
                    }
                    .padding(.bottom, 6)
                }
                
                // 1. Time / Date Target Matrix Row
                HStack {
                    Text(formatToLocalTime(launch.net))
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.blue)
                        .fontWeight(.bold)
                    
                    Spacer()
                    
                    if let status = launch.status?.abbrev?.uppercased() {
                        Text(status)
                            .font(.system(.caption2, design: .monospaced))
                            .fontWeight(.bold)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .foregroundColor(status == "GO" ? .black : .white)
                            .background(status == "GO" ? Color.green : Color.white.opacity(0.15))
                            .cornerRadius(3)
                    }
                }
                
                // 💡 UPGRADED: 2. STREAMING DESTINATION ACTIONS (Moved to the high-priority slot row)
                if let videoLink = launch.webcast_live, !videoLink.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    HStack(spacing: 12) {
                        // 🟢 BUTTON OPTION A: Launch the full-screen internal video player sheet
                        Button(action: {
                            showInternalVideoSheet = true
                        }) {
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(launch.isWebcastLiveRightNow ? Color.green : Color.orange)
                                    .frame(width: 6, height: 6)
                                
                                Text(launch.isWebcastLiveRightNow ? "STREAM LIVE TRANSMISSION" : "STREAMING SOON")
                                    .font(.system(.caption, design: .monospaced))
                                    .fontWeight(.bold)
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Color.white.opacity(0.08))
                            .cornerRadius(4)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        // 🛰️ BUTTON OPTION B: Open the webcast externally in Safari or native YouTube App!
                        Button(action: {
                            if let externalUrl = URL(string: videoLink) {
                                openExternalLink(externalUrl)
                            }
                        }) {
                            HStack(spacing: 6) {
                                Text("OPEN EXTERNAL")
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                Image(systemName: "safari")
                                    .font(.system(size: 10))
                            }
                            .foregroundColor(.cyan)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.cyan.opacity(0.05))
                            .cornerRadius(4)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(Color.cyan.opacity(0.2), lineWidth: 1)
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(.vertical, 4)
                    .sheet(isPresented: $showInternalVideoSheet) {
                        LaunchLiveStreamPlayerView(
                            streamURLString: videoLink,
                            launchName: launch.name,
                            launchNetDateString: launch.net
                        )
                    }
                }
                
                // 3. Real-Time Countdown Engine Track
                LaunchCountdownView(targetDateString: launch.net)
                
                // 4. Identification Configurations Block
                VStack(alignment: .leading, spacing: 4) {
                    Text(launch.rocket?.configuration?.full_name?.uppercased() ?? "VEHICLE UNKNOWN")
                        .font(.system(.headline, design: .monospaced))
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text(launch.name.uppercased())
                        .font(.system(.subheadline, design: .monospaced))
                        .foregroundColor(.secondary)
                }
                
                // 5. Trajectory Space Ranges Telemetry
                HStack(spacing: 16) {
                    if let orbit = launch.mission?.orbit?.abbrev?.uppercased() {
                        Text("ORBIT: \(orbit)")
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(2)
                    }
                    
                    Text(launch.pad?.location?.name?.uppercased() ?? "GLOBAL RANGE")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.gray)
                }
                
                // 6. Long-Form Objective Briefing
                if let description = launch.mission?.description {
                    Text("MISSION PROFILE:\n\(description)")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.gray)
                        .lineSpacing(5)
                        .padding(14)
                        .background(Color.white.opacity(0.02))
                        .cornerRadius(4)
                }
            }
            .padding(.horizontal)
            .padding(.top, 20)
        }
        .navigationTitle("MISSION TELEMETRY")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func formatToLocalTime(_ isoString: String?) -> String {
        guard let isoString = isoString else { return "DATE / TIME TBD" }
        let inputFormatter = ISO8601DateFormatter()
        inputFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        var date = inputFormatter.date(from: isoString)
        if date == nil {
            let backupFormatter = ISO8601DateFormatter()
            date = backupFormatter.date(from: isoString)
        }
        guard let validDate = date else { return "DATE / TIME TBD" }
        let outputFormatter = DateFormatter()
        outputFormatter.dateFormat = "MMM d, yyyy • HH:mm 'LOCAL'"
        outputFormatter.timeZone = TimeZone.current
        return outputFormatter.string(from: validDate).uppercased()
    }
}
