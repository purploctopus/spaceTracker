//
//  SpaceStationRadarChannelView.swift
//  spaceTracker
//
//  Created by Ben Clary on 8/6/26.
//  build an app colin enjoys and it supports saras happiness

import SwiftUI
import CoreLocation

struct SpaceStationRadarChannelView: View {
    @StateObject private var trackingViewModel = OrbitalTrackingViewModel()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("SPACE STATION TRACKER // LIVE ORBITAL POSITION")
                .font(.system(.caption, design: .monospaced).weight(.bold))
                .foregroundColor(.cyan)
                .tracking(1)
            
            VStack(alignment: .leading, spacing: 0) {
                // (Keep your top horizontal live telemetry instrument text grid cell block exactly as it is right now)
                
                Divider()
                    .background(Color.white.opacity(0.12))
                
                // 🌍 INTERACTIVE RENDER INTERCEPT AREA
                ZStack(alignment: .bottomLeading) {
                    OrbitalGlobeView(
                        issCoordinate: $trackingViewModel.stationState.issCoordinate,
                        tiangongCoordinate: $trackingViewModel.stationState.tiangongCoordinate,
                        currentFocus: $trackingViewModel.stationState.currentFocus // 💡 FIXED: Safely wires the selection binding token down to MapKit
                    )
                    .frame(height: 280)
                    
                    // 🎛️ 💡 THE TARGET SELECTOR DOCK: Floating terminal button controllers
                    HStack(spacing: 8) {
                        // CONTROLLER 1: INTERCEPT FOCUS ISS
                        Button(action: { trackingViewModel.stationState.currentFocus = .iss }) {
                            Text("TRACKING: ISS")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundColor(trackingViewModel.stationState.currentFocus == .iss ? .black : .cyan)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(trackingViewModel.stationState.currentFocus == .iss ? Color.cyan : Color.black.opacity(0.75))
                                .border(Color.cyan.opacity(0.5), width: 1)
                                .cornerRadius(2)
                        }
                        
                        // CONTROLLER 2: INTERCEPT FOCUS TIANGONG
                        Button(action: { trackingViewModel.stationState.currentFocus = .tiangong }) {
                            Text("TRACKING: TIANGONG")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundColor(trackingViewModel.stationState.currentFocus == .tiangong ? .black : .orange)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(trackingViewModel.stationState.currentFocus == .tiangong ? Color.orange : Color.black.opacity(0.75))
                                .border(Color.orange.opacity(0.5), width: 1)
                                .cornerRadius(2)
                        }
                    }
                    .padding(12) // Positions the dock beautifully inside the lower-left corner bounding edge
                }
            }
            .background(Color.white.opacity(0.04))
            .cornerRadius(4)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
        }
        .padding(.horizontal)
        .onAppear {
            // Automatically spin up your network tracking timer heartbeat on viewport load
            trackingViewModel.startTrackingPipeline()
        }
        .onDisappear {
            // Cleanly kill asynchronous networking task loops on background view sleep states
            trackingViewModel.stopTrackingPipeline()
        }

    }
}
