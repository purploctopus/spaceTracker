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
    
    // ✅ RESPONSIVE: Listens to the environment window layout size category
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    // Dynamically scales the card width footprint matching screen real estate
    private var dynamicCardWidth: CGFloat {
        if horizontalSizeClass == .regular {
            // Expanded format for spacious iPad view tracks
            return 260.0
        } else {
            // Streamlined format tailored perfectly to iPhone screen glass widths
            return 190.0
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 1. Core Mission Schedule Track Timestamp
            Text(launch.localLaunchTimeDisplay.uppercased())
                .font(.system(size: horizontalSizeClass == .regular ? 11 : 9, design: .monospaced))
                .foregroundColor(.yellow)
            
            // 2. Identification Configurations Block
            VStack(alignment: .leading, spacing: 2) {
                Text(launch.name.uppercased())
                    .font(.system(horizontalSizeClass == .regular ? .body : .subheadline, design: .monospaced))
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Text(launch.launch_service_provider?.name?.uppercased() ?? "GLOBAL RANGE")
                    .font(.system(horizontalSizeClass == .regular ? .caption : .caption2, design: .monospaced))
                    .foregroundColor(.blue)
                    .lineLimit(1)
            }
        }
        .padding(horizontalSizeClass == .regular ? 16 : 12)
        // ✅ RESPONSIVE: Binds the structural layout frame constraints to the dynamic size-class property
        .frame(width: dynamicCardWidth, alignment: .leading)
        .background(Color.white.opacity(0.04))
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}

