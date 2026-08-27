//
//  CelestialDetailSheet.swift
//  spaceTracker
//
//  Created by Ben Clary on 8/27/26.
//  make an app that colin uses and sara find relief from stress

import SwiftUI

struct CelestialDetailSheet: View {
    let profile: CelestialProfile
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 24) {
                    
                    // ==============================================================================
                    // 📸 HIGH-FIDELITY IMAGE HEADER MODULE
                    // ==============================================================================
                    if let imageName = profile.assetImageName {
                        ZStack(alignment: .topTrailing) {
                            Image(imageName)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(maxWidth: UIScreen.main.bounds.width)
                                .frame(height: 380)
                                .clipped()
                                .cornerRadius(12)
                            
                            dismissButton
                        }
                    } else {
                        VStack(spacing: 16) {
                            HStack {
                                Spacer()
                                dismissButton
                            }
                            Text("✦")
                                .font(.system(size: 64, design: .monospaced))
                                .foregroundColor(CelestialDatabaseRegistry.electricBlue)
                                .padding(.top, 20)
                            Text("STELLAR DATABLOCK")
                                .font(.system(.caption, design: .monospaced))
                                .fontWeight(.bold)
                                .foregroundColor(.gray)
                        }
                    }
                    
                    // ==============================================================================
                    // 🏷️ SYSTEM NOMENCLATURE PROFILE
                    // ==============================================================================
                    VStack(alignment: .leading, spacing: 4) {
                        Text(profile.name.uppercased())
                            .font(.system(.largeTitle, design: .monospaced))
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Text(profile.subTitle.uppercased())
                            .font(.system(.caption, design: .monospaced))
                            .fontWeight(.semibold)
                            .foregroundColor(.gray)
                    }
                    .padding(.horizontal, 16)
                    
                    Divider()
                        .background(Color.gray.opacity(0.3))
                        .padding(.horizontal, 16)
                    
                    // ==============================================================================
                    // 📖 LOG ENTRY PARAGRAPH MATRIX
                    // ==============================================================================
                    VStack(alignment: .leading, spacing: 12) {
                        Text("OBSERVATION LOG DATA")
                            .font(.system(.subheadline, design: .monospaced))
                            .fontWeight(.bold)
                            .foregroundColor(.white.opacity(0.9))
                        
                        Text(profile.encyclopediaSummary)
                            .font(.system(.body, design: .default))
                            .foregroundColor(.white.opacity(0.85))
                            .lineSpacing(6)
                    }
                    .padding(.horizontal, 16)
                    
                    // ==============================================================================
                    // 🌐 LIVE METRIC TELEMETRY OVERLAY (REAL NASA DISTANCE INJECTED)
                    // ==============================================================================
                    // 💡 FIXED: Stripped out the static placeholders. The sheet now calculates the true
                    // physical range parameters and real-time look angles passing down from your live script!
                    VStack(alignment: .leading, spacing: 14) {
                        Text("LIVE NASA TELEMETRY LINK")
                            .font(.system(.subheadline, design: .monospaced))
                            .fontWeight(.bold)
                            .foregroundColor(.green)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("├─> CLASSIFICATION:")
                                    .font(.system(.footnote, design: .monospaced))
                                    .foregroundColor(.gray)
                                Text(profile.classification)
                                    .font(.system(.footnote, design: .monospaced))
                                    .foregroundColor(.white)
                            }
                            
                            if let alt = profile.liveAltitude, let az = profile.liveAzimuth {
                                HStack {
                                    Text("├─> BACKYARD LOOK :")
                                        .font(.system(.footnote, design: .monospaced))
                                        .foregroundColor(.gray)
                                    Text(String(format: "ALT %04.1f° / AZ %05.1f°", alt, az))
                                        .font(.system(.footnote, design: .monospaced))
                                        .foregroundColor(.white)
                                }
                            }
                            
                            if let distanceAU = profile.liveDistanceAU {
                                // 1 AU is exactly 149,597,870.7 kilometers
                                let kmDistance = distanceAU * 149597870.7
                                // Light travels at roughly 299,792.458 km per second
                                let lightMinutes = (kmDistance / 299792.458) / 60.0
                                
                                HStack {
                                    Text("├─> SPATIAL RANGE :")
                                        .font(.system(.footnote, design: .monospaced))
                                        .foregroundColor(.gray)
                                    Text(String(format: "%.0f KM (%.4f AU)", kmDistance, distanceAU))
                                        .font(.system(.footnote, design: .monospaced))
                                        .foregroundColor(.cyan)
                                }
                                
                                HStack {
                                    Text("└─> LIGHT TIMELINE:")
                                        .font(.system(.footnote, design: .monospaced))
                                        .foregroundColor(.gray)
                                    Text(String(format: "%.1f MINUTES TRAVEL TIME", lightMinutes))
                                        .font(.system(.footnote, design: .monospaced))
                                        .foregroundColor(.yellow)
                                }
                            } else {
                                HStack {
                                    Text("└─> INTERACTIVE ID :")
                                        .font(.system(.footnote, design: .monospaced))
                                        .foregroundColor(.gray)
                                    Text("FIXED_STELLAR_BASE")
                                        .font(.system(.footnote, design: .monospaced))
                                        .foregroundColor(.white)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 40)
                }
            }
        }
    }
    
    private var dismissButton: some View {
        Button(action: { dismiss() }) {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.white.opacity(0.7))
                .padding(16)
        }
    }
}
