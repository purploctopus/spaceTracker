//
//  OnboardingViews.swift
//  spaceTracker
//
//  First-launch welcome sheet (bottom half-sheet, so it stays out of the middle of the
//  screen) and the one-line tab tip banner shown at the top of each tab once.

import SwiftUI

struct WelcomeHighlight {
    let icon: String
    let title: String
    let detail: String
}

struct WelcomeSheet: View {
    /// The best "tonight" highlight available right now (nil while still loading).
    let highlight: WelcomeHighlight?
    /// True once SHOW ME was tapped and the location-based load has started.
    let hasStartedScan: Bool
    let onShowMe: () -> Void
    let onSkyMap: () -> Void
    let onLookAround: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("WHAT'S OVER YOU TONIGHT?")
                .font(.system(.title3, design: .monospaced))
                .fontWeight(.bold)
                .foregroundColor(.cyan)
                .fixedSize(horizontal: false, vertical: true)

            if !hasStartedScan {
                Text("OrbitLog shows satellite passes, planets, launches and meteor showers from right where you are.")
                    .font(.system(.footnote, design: .monospaced))
                    .foregroundColor(.white.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
                Text("Your location is only used to work out what's in your sky.")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundColor(.gray)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)

                primaryButton("SHOW ME", icon: "location.fill", action: onShowMe)
                secondaryButton("SKIP", action: onLookAround)
            } else {
                highlightCard

                Spacer(minLength: 0)

                primaryButton("POINT AT THE SKY", icon: "camera.viewfinder", action: onSkyMap)
                secondaryButton("LOOK AROUND", action: onLookAround)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(red: 0.04, green: 0.05, blue: 0.08))
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private var highlightCard: some View {
        HStack(alignment: .top, spacing: 12) {
            if let highlight {
                Image(systemName: highlight.icon)
                    .font(.title3)
                    .foregroundColor(.yellow)
                VStack(alignment: .leading, spacing: 4) {
                    Text(highlight.title)
                        .font(.system(.subheadline, design: .monospaced))
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(highlight.detail)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.gray)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else {
                ProgressView()
                Text("SCANNING YOUR SKY...")
                    .font(.system(.subheadline, design: .monospaced))
                    .foregroundColor(.gray)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.05))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.cyan.opacity(0.35), lineWidth: 1))
        .cornerRadius(8)
        .accessibilityElement(children: .combine)
    }

    private func primaryButton(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                Text(title)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .font(.system(.subheadline, design: .monospaced).weight(.bold))
            .foregroundColor(.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.cyan)
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func secondaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(.caption, design: .monospaced).weight(.bold))
                .foregroundColor(.gray)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
        }
        .buttonStyle(PlainButtonStyle())
    }

    /// 8-point compass word for an azimuth, for the "look east" style highlight.
    static func compassWord(_ azimuth: Double) -> String {
        let words = ["NORTH", "NORTHEAST", "EAST", "SOUTHEAST", "SOUTH", "SOUTHWEST", "WEST", "NORTHWEST"]
        let index = Int((azimuth + 22.5).truncatingRemainder(dividingBy: 360.0) / 45.0)
        return words[max(0, min(index, 7))]
    }
}

/// One-line tip shown at the top of a tab the first time it's opened. Tap X to dismiss.
struct TabTipBanner: View {
    let tab: AppTab
    @ObservedObject private var onboarding = OnboardingStore.shared

    var body: some View {
        if onboarding.shouldShowTip(tab) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "lightbulb.fill")
                    .font(.caption)
                    .foregroundColor(.yellow)
                    .padding(.top, 2)
                Text(tab.tipText)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.white)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 4)
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) { onboarding.dismissTip(tab) }
                }) {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.bold))
                        .foregroundColor(.gray)
                        .padding(6)
                }
                .buttonStyle(PlainButtonStyle())
                .accessibilityLabel("Dismiss tip")
            }
            .padding(12)
            .background(Color.black.opacity(0.88))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.cyan.opacity(0.4), lineWidth: 1))
            .cornerRadius(8)
            .padding(.horizontal)
            .padding(.top, 4)
            .transition(.opacity)
        }
    }
}
