//
//  CelestialDetailSheet.swift
//  spaceTracker
//
//  Created by Ben Clary on 8/27/26.
//  make an app that colin uses

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
                    // 📸 CONDITIONAL ASSET HEADER DISPLAY VIEW
                    // ==============================================================================
                    if let imageName = profile.assetImageName {
                        // PREMIUM PLANET PHOTO HEADER
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
                        // MINIMALIST STAR INTERFACE ICON UNIT
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
                    // 🌐 LIVE METRIC TELEMETRY OVERLAY FLAG
                    // ==============================================================================
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
                            
                            HStack {
                                Text("├─> INTERACTIVE ID :")
                                    .font(.system(.footnote, design: .monospaced))
                                    .foregroundColor(.gray)
                                Text("LOCAL_SECURE_V1")
                                    .font(.system(.footnote, design: .monospaced))
                                    .foregroundColor(.white)
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
