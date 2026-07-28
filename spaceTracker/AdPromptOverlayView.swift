//
//  AdPromptOverlayView.swift
//  spaceTracker
//
//  Created by Ben Clary on 7/7/26.
//  MAKE AN APP COLIN LOVES

import SwiftUI
import StoreKit
import Combine

struct AdPromptOverlayView: View {
    @ObservedObject var adEngine: AdMobEngine
    let actionLabel: String
    let onTriggerAd: () -> Void
    let onDismiss: () -> Void
    
    @State private var countdownTimer = 10 // Your 10-second warning state
    @State private var cancellable: AnyCancellable?
    
    // 💡 THE TIMER SHIELD: Freezes the countdown if Apple's credit card sheet is active
    @State private var isPurchasing = false
    
    var body: some View {
        ZStack {
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
                    if isPurchasing {
                        Text("TRANSACTION IN PROGRESS")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(.yellow)
                            .fontWeight(.bold)
                        Text("PAUSED")
                            .font(.system(size: 32, weight: .bold, design: .monospaced))
                            .foregroundColor(.yellow)
                    } else if countdownTimer > 0 {
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
                .border(isPurchasing ? Color.yellow.opacity(0.3) : Color.white.opacity(0.08), width: 1)
                
                // Permanent In-App Purchase Trigger Lane
                Button(action: {
                    // 💡 LOCK THE TIMER: Instantly pauses the countdown pipeline
                    isPurchasing = true
                    
                    Task {
                        await adEngine.purchasePremium()
                        
                        if adEngine.isPremiumUnlocked {
                            onDismiss() // Success: Tear down the overlay completely
                        } else {
                            // 💡 UNLOCK THE TIMER: If they cancel Apple's sheet, resume the countdown
                            isPurchasing = false
                        }
                    }
                }) {
                    HStack {
                        Image(systemName: "crown.fill")
                            .foregroundColor(.yellow)
                        Text("REMOVE ADS FOREVER — \(adEngine.premiumProduct?.displayPrice ?? "$2.99")")
                            .font(.system(.caption, design: .monospaced))
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    }
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity)
                    .background(Color.yellow.opacity(0.15))
                    .border(Color.yellow.opacity(0.4), width: 1)
                    .cornerRadius(4)
                }
                .padding(.bottom, 4)
                
                Button(action: {
                    // Lock the timer if needed, then fire the manual check
                    isPurchasing = true
                    Task {
                        await adEngine.manualRestorePurchases()
                        if adEngine.isPremiumUnlocked {
                            onDismiss() // Close the paywall completely on success
                        } else {
                            isPurchasing = false // Resume normal operation if no purchase found
                        }
                    }
                }) {
                    Text("Restore Purchases")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.gray)
                        .underline()
                        .padding(.vertical, 4)
                }
                .disabled(isPurchasing) // Prevent multiple concurrent taps while processing

                
                // Action Control Layout Row
                HStack(spacing: 16) {
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
                    .disabled(isPurchasing) // Block dismissing while buying
                    
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
                    .disabled(!adEngine.isAdReady || isPurchasing)
                }
            }
            .padding(24)
            .background(Color(red: 0.06, green: 0.06, blue: 0.06))
            .border(isPurchasing ? Color.yellow.opacity(0.3) : Color.orange.opacity(0.3), width: 1)
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
            // 💡 REFIED GUARD RULE: If buying, skip the mathematical clock calculations completely
            guard !isPurchasing else { return }
            
            if countdownTimer > 1 {
                countdownTimer -= 1
            } else {
                countdownTimer = 0
                stopCountdownLoop()
                onTriggerAd()
            }
        }
    }
    
    private func stopCountdownLoop() {
        cancellable?.cancel()
    }
}
