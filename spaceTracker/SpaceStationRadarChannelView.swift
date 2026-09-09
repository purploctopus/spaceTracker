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
    @State private var showFullScreenGlobe = false
    
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
                ZStack(alignment: .bottomTrailing) {
                    OrbitalGlobeView(
                        issCoordinate: $trackingViewModel.stationState.issCoordinate,
                        tiangongCoordinate: $trackingViewModel.stationState.tiangongCoordinate,
                        currentFocus: $trackingViewModel.stationState.currentFocus, // 💡 FIXED: Safely wires the selection binding token down to MapKit
                        issGroundTrack: $trackingViewModel.stationState.issGroundTrack,
                        tiangongGroundTrack: $trackingViewModel.stationState.tiangongGroundTrack
                    )
                    .frame(height: 280)
                    .contentShape(Rectangle())
                    
                    // 🔍 EXPAND AFFORDANCE: Opens the same live globe full-screen for easier zoom/pan/rotate
                    Button(action: { showFullScreenGlobe = true }) {
                        Image(systemName: "arrow.up.left.and.arrow.down.right.circle.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.cyan)
                            .padding(6)
                            .background(Circle().fill(Color.black.opacity(0.65)))
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .accessibilityLabel("Expand globe to full screen")
                    .accessibilityHint("Opens an enlarged, interactive view of the orbital station tracker")
                    
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
        .fullScreenCover(isPresented: $showFullScreenGlobe) {
            OrbitalGlobeFullScreenView(trackingViewModel: trackingViewModel)
        }

    }
}

// 🌍🔭 FULL-SCREEN INTERCEPT VIEW: Same live globe + tracking dock, given the whole screen to
// make pinch-zoom, pan, and rotate around the ISS/Tiangong ground tracks easier to work with.
// Shares the SAME OrbitalTrackingViewModel instance as the card (passed in, not re-created),
// so the live network polling started by the card's onAppear keeps running underneath and this
// view just reflects it -- no duplicate polling, no restart when the sheet opens or closes.
struct OrbitalGlobeFullScreenView: View {
    @ObservedObject var trackingViewModel: OrbitalTrackingViewModel
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            OrbitalGlobeView(
                issCoordinate: $trackingViewModel.stationState.issCoordinate,
                tiangongCoordinate: $trackingViewModel.stationState.tiangongCoordinate,
                currentFocus: $trackingViewModel.stationState.currentFocus,
                issGroundTrack: $trackingViewModel.stationState.issGroundTrack,
                tiangongGroundTrack: $trackingViewModel.stationState.tiangongGroundTrack
            )
            .ignoresSafeArea()

            VStack {
                HStack {
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 30))
                            .foregroundColor(.white)
                            .background(Circle().fill(Color.black.opacity(0.5)))
                    }
                    .accessibilityLabel("Close full screen tracker")
                }
                .padding(.top, 50)
                .padding(.trailing, 20)

                Spacer()

                HStack(spacing: 12) {
                    Button(action: { trackingViewModel.stationState.currentFocus = .iss }) {
                        Text("TRACKING: ISS")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(trackingViewModel.stationState.currentFocus == .iss ? .black : .cyan)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(trackingViewModel.stationState.currentFocus == .iss ? Color.cyan : Color.black.opacity(0.75))
                            .border(Color.cyan.opacity(0.5), width: 1)
                            .cornerRadius(2)
                    }

                    Button(action: { trackingViewModel.stationState.currentFocus = .tiangong }) {
                        Text("TRACKING: TIANGONG")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(trackingViewModel.stationState.currentFocus == .tiangong ? .black : .orange)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(trackingViewModel.stationState.currentFocus == .tiangong ? Color.orange : Color.black.opacity(0.75))
                            .border(Color.orange.opacity(0.5), width: 1)
                            .cornerRadius(2)
                    }
                }
                .padding(.bottom, 40)
            }
        }
        .statusBarHidden()
    }
}
