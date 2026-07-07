//
//  AdPromptOverlayView.swift
//  spaceTracker
//
//  Created by Ben Clary on 7/7/26.
//  MAKE AN APP COLIN LOVES

import SwiftUI

struct AdPromptOverlayView: View {
    @ObservedObject var adEngine: AdMobEngine
    let actionLabel: String
    let onTriggerAd: () -> Void
    let onDismiss: () -> Void
    
    @State private var countdownTimer = 10
    @State private var timerSubscription: Timer.TimerPublisher?
    @State private var cancellable: AnyCancellable?
    
    var body: some View {
        ZStack {
            // Darkened frosted glass back-shield
            Color.black.opacity(0.85)
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                // Tactical Warning Header Row
                VStack(spacing: 6) {
                    Image(systemName: "video.badge.checkmark")
                        .font(.largeTitle)
                        .foregroundColor(.cyan)
                    Text("UNLOCK DAILY DETAILED REPORTS")
                        .font(.system(.headline, design: .monospaced))
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .tracking(1)
                    Text("SUPPORT THE TERMINAL // WATCH AN AD TO UNLOCK ALL DATA")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(.orange)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                
                Divider()
                    .background(Color.white.opacity(0.15))
                
                // Content Description
                Text("Watch a brief network briefing transmission to unlock unlimited access to all system detail modules until midnight.")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)
                    .lineSpacing(4)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
                
                // Countdown Tracker Box
                VStack(spacing: 4) {
                    if countdownTimer > 0 {
                        Text("INITIATING DATA FEED IN")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(.orange)
                        Text("\(countdownTimer)")
                            .font(.system(size: 32, weight: .bold, design: .monospaced))
                            .foregroundColor(.white) 
                    } else {
                        Text("TRANSMISSION FEED READY")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.green)
                            .fontWeight(.bold)
                    }
                }
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .background(Color.white.opacity(0.02))
                .border(Color.white.opacity(0.08), width: 1)
                
                // Action Control Layout Row
                HStack(spacing: 16) {
                    // Cancel Outbound Vector
                    Button(action: onDismiss) {
                        Text("ABORT MISSION")
                            .font(.system(.caption, design: .monospaced))
                            .fontWeight(.bold)
                            .foregroundColor(.gray)
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity)
                            .background(Color.white.opacity(0.05))
                            .cornerRadius(4)
                    }
                    
                    // Direct Instant Play Trigger Bypass
                    Button(action: {
                        countdownTimer = 0
                        onTriggerAd()
                    }) {
                        Text(adEngine.isAdReady ? "WATCH NOW" : "LOADING INTEL...")
                            .font(.system(.caption, design: .monospaced))
                            .fontWeight(.bold)
                            .foregroundColor(.black)
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity)
                            .background(adEngine.isAdReady ? Color.cyan : Color.gray.opacity(0.3))
                            .cornerRadius(4)
                    }
                    .disabled(!adEngine.isAdReady)
                }
            }
            .padding(24)
            .background(Color(red: 0.06, green: 0.06, blue: 0.06))
            .border(Color.orange.opacity(0.3), width: 1)
            .cornerRadius(8)
            .padding(.horizontal, horizontalSizeClass == .regular ? 120 : 24)
        }
        .onAppear {
            startCountdownLoop()
        }
        .onDisappear {
            stopCountdownLoop()
        }
    }
    
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    private func startCountdownLoop() {
        let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
        self.cancellable = timer.sink { _ in
            if countdownTimer > 1 {
                countdownTimer -= 1
            } else {
                countdownTimer = 0
                stopCountdownLoop()
                onTriggerAd() // Automatically deploy ad when timer reaches zero
            }
        }
    }
    
    private func stopCountdownLoop() {
        cancellable?.cancel()
    }
}
import Combine
