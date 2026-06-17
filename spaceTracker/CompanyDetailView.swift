//
//  CompanyDetailView.swift
//  spaceTracker
//
//  Created by Ben Clary on 6/17/26.
//  MAKE AN APP COLIN LOVES

import SwiftUI

struct CompanyDetailView: View {
    let companyName: String
    let launches: [SpaceLaunch]
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 44) {
                ForEach(launches, id: \.id) { launch in
                    VStack(alignment: .leading, spacing: 14) {
                        
                        if let imageString = launch.image?.image_url,
                           let imageUrl = URL(string: imageString) {
                            
                            AsyncImage(url: imageUrl) { phase in
                                switch phase {
                                case .success(let image):
                                    image
                                        .resizable()
                                        // 💡 Switch to .fit so the entire vertical rocket is visible
                                        .aspectRatio(contentMode: .fit)
                                        // 💡 Give it a taller max height frame for vertical breathing room
                                        .frame(maxHeight: 320)
                                        .frame(maxWidth: .infinity, alignment: .center)
                                        .background(Color.white.opacity(0.01))
                                        .cornerRadius(4)
                                case .failure:
                                    Color.clear.frame(height: 0)
                                case .empty:
                                    ProgressView()
                                        .frame(height: 200)
                                        .frame(maxWidth: .infinity)
                                        .background(Color.white.opacity(0.03))
                                        .cornerRadius(4)
                                @unknown default:
                                    EmptyView()
                                }
                            }
                            .padding(.bottom, 6)
                        }

                        
                        // 1. Target Timestamp & Status Bar Row
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
                        
                        // 2. Technical Vehicle Variant & Mission Code
                        VStack(alignment: .leading, spacing: 4) {
                            Text(launch.rocket?.configuration?.full_name?.uppercased() ?? "VEHICLE UNKNOWN")
                                .font(.system(.headline, design: .monospaced))
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            
                            Text(launch.name.uppercased())
                                .font(.system(.subheadline, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                        
                        // 3. Telemetry Metadata Labels
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
                        
                        // 4. Operational Objective Summary Log
                        if let description = launch.mission?.description {
                            Text("MISSION PROFILE:\n\(description)")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.gray)
                                .lineSpacing(5)
                                .padding(14)
                                .background(Color.white.opacity(0.02))
                                .cornerRadius(4)
                        }
                        
                        // 5. Livestream Routing Action Button
                        if let videoArray = launch.vid_urls,
                           let firstVideoString = videoArray.first?.url,
                           let liveUrl = URL(string: firstVideoString) {
                            
                            Link(destination: liveUrl) {
                                HStack(spacing: 8) {
                                    Circle()
                                        .fill(Color.red)
                                        .frame(width: 6, height: 6)
                                    Text("LIVE BROADCAST FEED")
                                        .font(.system(.caption, design: .monospaced))
                                        .fontWeight(.bold)
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(Color.white.opacity(0.08))
                                .cornerRadius(4)
                            }
                            .padding(.top, 4)
                        }
                        
                        Divider()
                            .background(Color.white.opacity(0.08))
                            .padding(.top, 20)
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.top, 20)
        }
        .navigationTitle(companyName.uppercased())
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
