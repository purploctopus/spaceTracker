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

    @State private var isPurchasing = false

    private var expiryTimeString: String? {
        guard let expiresAt = adEngine.temporaryAdFreeExpiresAt else { return nil }
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: expiresAt)
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.85)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                // Header — adapts based on whether a temporary ad-free window is active.
                VStack(spacing: 6) {
                    Image(systemName: adEngine.hasTemporaryAdFreeActive ? "checkmark.seal.fill" : "video.badge.checkmark")
                        .font(.largeTitle)
                        .foregroundColor(.cyan)
                    Text(adEngine.hasTemporaryAdFreeActive ? "ADS ARE OFF RIGHT NOW" : "UNLOCK 24H AD-FREE ACCESS")
                        .font(.system(.headline, design: .monospaced))
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .tracking(1)
                    Text(adEngine.hasTemporaryAdFreeActive ? "YOU'RE COVERED — GO PERMANENT ANYTIME" : "SUPPORT OrbitLog // WATCH AN AD TO UNLOCK ALL DATA")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(.orange)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                Divider()
                    .background(Color.white.opacity(0.15))

                // Content Description
                if adEngine.hasTemporaryAdFreeActive, let expiryTimeString {
                    Text("Ads are already off until \(expiryTimeString). Buy once below and they're gone for good.")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.secondary)
                        .lineSpacing(4)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                } else {
                    Text("Watch a brief ad to unlock unlimited access for 24 hours.")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.secondary)
                        .lineSpacing(4)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                }

                // Status Box
                VStack(spacing: 4) {
                    if isPurchasing {
                        Text("TRANSACTION IN PROGRESS")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(.yellow)
                            .fontWeight(.bold)
                        Text("PAUSED")
                            .font(.system(size: 32, weight: .bold, design: .monospaced))
                            .foregroundColor(.yellow)
                    } else if adEngine.hasTemporaryAdFreeActive, let expiryTimeString {
                        Text("AD-FREE UNTIL")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(.green)
                            .fontWeight(.bold)
                        Text(expiryTimeString)
                            .font(.system(size: 24, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
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

                // Permanent In-App Purchase Trigger Lane — always available regardless of
                // temporary ad-free state. Never gated behind waiting for a free window to
                // expire; the $2.99 option should always be reachable, right up until the
                // moment someone actually buys it.
                Button(action: {
                    isPurchasing = true
                    Task {
                        await adEngine.purchasePremium()
                        if adEngine.hasPermanentAdFree {
                            onDismiss()
                        } else {
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
                    isPurchasing = true
                    Task {
                        await adEngine.manualRestorePurchases()
                        if adEngine.hasPermanentAdFree {
                            onDismiss()
                        } else {
                            isPurchasing = false
                        }
                    }
                }) {
                    Text("Restore Purchases")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.gray)
                        .underline()
                        .padding(.vertical, 4)
                }
                .disabled(isPurchasing)

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
                    .disabled(isPurchasing)

                    // 💡 The button that changes shape: right after watching today's ad
                    // (hasTemporaryAdFreeActive), there's nothing left to watch, so this
                    // slot becomes a second, prominent path straight to the permanent
                    // purchase instead — reinforcing that $2.99 is always available, not
                    // just something to circle back to once the free window runs out.
                    if adEngine.hasTemporaryAdFreeActive {
                        Button(action: {
                            isPurchasing = true
                            Task {
                                await adEngine.purchasePremium()
                                if adEngine.hasPermanentAdFree {
                                    onDismiss()
                                } else {
                                    isPurchasing = false
                                }
                            }
                        }) {
                            Text("BUY AD-FREE FOREVER")
                                .font(.system(.caption, design: .monospaced))
                                .fontWeight(.bold)
                                .foregroundColor(.black)
                                .padding(.vertical, 12)
                                .frame(maxWidth: .infinity)
                                .background(Color.yellow)
                                .cornerRadius(4)
                        }
                        .disabled(isPurchasing)
                    } else {
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
