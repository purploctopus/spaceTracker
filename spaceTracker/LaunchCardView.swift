//
//  LaunchCardView.swift
//  spaceTracker
//
//  Created by Ben Clary on 6/24/26.
//

import SwiftUI

// MARK: - THE HORIZONTAL LAUNCH COMPONENT CARD
import SwiftUI

struct LaunchCardView: View {
    let launch: SpaceLaunch
    
    // 💡 FIXED: Injected parameter action line allows data to flow up to your root views safely
    let onWatchTap: (String) -> Void
    
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
                .font(.system(size: horizontalSizeClass == .regular ? 13 : 11, design: .monospaced))
                .foregroundColor(.yellow)
            
            // 2. Identification Configurations Block
            VStack(alignment: .leading, spacing: 2) {
                Text(launch.name.uppercased())
                    .font(.system(horizontalSizeClass == .regular ? .body : .subheadline, design: .monospaced))
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .lineLimit(2)
                
                // 💡 FIXED: Safely unwraps the provider name checking model optionals seamlessly
                Text(launch.launch_service_provider?.name?.uppercased() ?? "GLOBAL RANGE")
                    .font(.system(horizontalSizeClass == .regular ? .caption : .caption2, design: .monospaced))
                    .foregroundColor(.blue)
                    .lineLimit(1)
            }
            
            // 💡 THE INJECTED RADAR COUNTDOWN TICKER: Tracks days, hours, and minutes to T-0
            LaunchCountdownView(targetDateString: launch.net)
                .padding(.top, 2)
            
            // 💡 FIXED: Dynamically matches its button properties to the live countdown status window! [1.13]
            if let videoLink = launch.webcast_live, !videoLink.trimmingCharacters(in: .whitespaces).isEmpty {
                Button(action: {
                    onWatchTap(videoLink)
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: launch.isWebcastLiveRightNow ? "play.tv.fill" : "antenna.radiowaves.left.and.right")
                            .font(.system(size: 8))
                        Text(launch.webcastButtonDescriptorString + " ❯")
                            .font(.system(size: 8, weight: .black, design: .monospaced))
                    }
                    .foregroundColor(launch.isWebcastLiveRightNow ? .white : .black)
                    // 💡 VISUAL ANCHOR: Red alert style if broadcasting live; sleek orange/amber if in standby [1.13]
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(launch.isWebcastLiveRightNow ? Color.red : Color.orange)
                    .cornerRadius(3)
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.top, 4)
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


