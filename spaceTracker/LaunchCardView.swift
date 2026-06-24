//
//  LaunchCardView.swift
//  spaceTracker
//
//  Created by Ben Clary on 6/24/26.
//

import SwiftUI

// MARK: - THE HORIZONTAL LAUNCH COMPONENT CARD
struct LaunchCardView: View {
    let launch: SpaceLaunch
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 1. Core Mission Schedule Track Timestamp
            Text(launch.localLaunchTimeDisplay.uppercased())
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.yellow)
            
            // 2. Identification Configurations Block
            VStack(alignment: .leading, spacing: 2) {
                Text(launch.name.uppercased())
                    .font(.system(.subheadline, design: .monospaced))
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Text(launch.launch_service_provider?.name?.uppercased() ?? "GLOBAL RANGE")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.blue)
                    .lineLimit(1)
            }
        }
        .padding(14)
        // MATCHES SATELLITE LAYOUT EXACTLY: Fixed horizontal dimension box
        .frame(width: 220, alignment: .leading)
        .background(Color.white.opacity(0.04))
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}
