//
//  AdPromptOverlayView.swift
//  spaceTracker
//
//  Created by Ben Clary on 7/7/26.
//  MAKE AN APP COLIN LOVES

import SwiftUI
import StoreKit

struct AdPromptOverlayView: View {
    @ObservedObject var adEngine: AdMobEngine
    let actionLabel: String
    let onTriggerAd: () -> Void
    let onDismiss: () -> Void
    
    // 💡 REMOVED: the 10-second auto-play countdown. This view is only ever reached now
    // through a voluntary tap (the persistent "Go Ad-Free" entry point, or a post-ad toast)
    // — never as a forced interrupt — so there's no reason for the ad to fire itself if the
    // person just sits on the screen. Auto-playing also worked against the whole point of
    // using a *rewarded* format: completion rates (and therefore eCPM) are meaningfully
    // better when someone actively chose to watch, versus an ad that happens to them.
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
                    Text("UNLOCK 24H AD-FREE ACCESS")
                        .font(.system(.headline, design: .monospaced))
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .tracking(1)
                    Text("SUPPORT OrbitLog // WATCH AN AD TO UNLOCK ALL DATA")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(.orange)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                Divider()
                    .background(Color.white.opacity(0.15))
                
                // Content Description
                Text("Watch a brief ad to unlock unlimited access for 24 hours.")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)
                    .lineSpacing(4)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
                
                // Ready State Box
                VStack(spacing: 4) {
                    if isPurchasing {
                        Text("TRANSACTION IN PROGRESS")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(.yellow)
                            .fontWeight(.bold)
                        Text("PAUSED")
                            .font(.system(size: 32, weight: .bold, design: .monospaced))
                            .foregroundColor(.yellow)
                    } else {
                        Text(adEngine.isAdReady ? "Ad READY" : "PREPARING Ad...")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(adEngine.isAdReady ? .green : .orange)
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
                        Image(systemName: "tv.slash.fill")
                            .foregroundColor(.red)
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
                        Text("CANCEL")
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
                        onTriggerAd()
                    }) {
                        Text(adEngine.isAdReady ? "WATCH Ad 24-Hours FREE" : "LOADING Ad...")
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
    }
    
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
}
