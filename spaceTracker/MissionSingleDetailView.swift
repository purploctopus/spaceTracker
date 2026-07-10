//
//  MissionSingleDetailView.swift
//  spaceTracker
//
//  Created by Ben Clary on 6/17/26.
//

import SwiftUI

struct MissionSingleDetailView: View {
    let launch: SpaceLaunch
    
    @State private var showInternalVideoSheet = false
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                
                // FULL HEIGHT RESPONSIVE STACK BOOSTER ILLUSTRATION
                if let imageString = launch.image?.image_url,
                   let imageUrl = URL(string: imageString) {
                    AsyncImage(url: imageUrl) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxHeight: 280)
                                .frame(maxWidth: .infinity, alignment: .center)
                        case .failure:
                            Color.clear.frame(height: 0)
                        case .empty:
                            ProgressView()
                                .frame(height: 200)
                                .frame(maxWidth: .infinity)
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
                
                // 2. Real-Time Countdown Engine Track
                LaunchCountdownView(targetDateString: launch.net)
                
                // 3. Identification Configurations Block
                VStack(alignment: .leading, spacing: 4) {
                    Text(launch.rocket?.configuration?.full_name?.uppercased() ?? "VEHICLE UNKNOWN")
                        .font(.system(.headline, design: .monospaced))
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text(launch.name.uppercased())
                        .font(.system(.subheadline, design: .monospaced))
                        .foregroundColor(.secondary)
                }
                
                // 4. Trajectory Space Ranges Telemetry
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
                
                // 5. Long-Form Objective Briefing
                if let description = launch.mission?.description {
                    Text("MISSION PROFILE:\n\(description)")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.gray)
                        .lineSpacing(5)
                        .padding(14)
                        .background(Color.white.opacity(0.02))
                        .cornerRadius(4)
                }
                
                // 6. Streaming Destination Actions Direct Link
                // 💡 FIXED: Replaced external browser logic link container with your custom video web bridge [1.13]
                if let videoLink = launch.webcast_live, !videoLink.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    
                    Button(action: {
                        // Sets sheet presentation trigger to live
                        showInternalVideoSheet = true
                    }) {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(launch.isWebcastLiveRightNow ? Color.red : Color.orange)
                                .frame(width: 6, height: 6)
                            
                            Text(launch.isWebcastLiveRightNow ? "LIVE BROADCAST FEED" : "LIVE BROADCAST FEED // STANDBY")
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
                    .padding(.top, 4)
                    // 💡 INJECTED ZONE: Slides your high-fidelity, sandboxed video overlay up straight from inside this card screen layout! [1.13]
                    .sheet(isPresented: $showInternalVideoSheet) {
                        LaunchLiveStreamPlayerView(
                            streamURLString: videoLink,
                            launchName: launch.name,
                            launchNetDateString: launch.net
                        )
                    }
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

