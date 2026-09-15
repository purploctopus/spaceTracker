//
//  SettingsView.swift
//  spaceTracker
//
//  FEAT-02: an options screen for choosing which notifications the user wants and how
//  much lead time each one gets, binding directly to the state NotificationManager
//  already persists (see NotificationManager.swift).

import SwiftUI

struct SettingsView: View {
    @ObservedObject var notificationEngine: NotificationManager
    @ObservedObject private var favorites = FavoritesStore.shared
    // FEAT-15: the dashboard reorder sheet lives here, off a single row below.
    @ObservedObject private var dashboardLayout = DashboardLayoutStore.shared
    @State private var showDashboardReorderSheet = false
    // 2026-09-15: moved here from Home Command's own nav bar header, which dropped this
    // entry point on iPhone (see ContentView.swift's principalToolbarHeaderTitleStack) to
    // fix "DAILY COMMAND" truncating -- Acknowledgements still needs to be reachable
    // everywhere, so Settings > Legal is its home on every size class now.
    @State private var showAcknowledgementsSheet = false
    @Environment(\.dismiss) var dismiss

    private let leadTimeOptions = [5, 10, 15, 30, 60]

    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    permissionStatusCard

                    sectionHeader("NOTIFICATION TYPES")
                    VStack(spacing: 0) {
                        toggleRow(
                            icon: "sun.max.fill",
                            title: "DAILY BRIEFING",
                            subtitle: "One summary every morning at 8:00 AM",
                            isOn: $notificationEngine.dailyBriefingEnabled
                        )
                        Divider().background(Color.white.opacity(0.08))

                        toggleRow(
                            icon: "flame.fill",
                            title: "LAUNCH ALERTS",
                            subtitle: "Alert before liftoff",
                            isOn: $notificationEngine.launchAlertsEnabled
                        )
                        if notificationEngine.launchAlertsEnabled {
                            leadTimeRow(label: "ALERT LEAD TIME", minutes: $notificationEngine.launchLeadMinutes)
                        }
                        Divider().background(Color.white.opacity(0.08))

                        toggleRow(
                            icon: "scope",
                            title: "SATELLITE PASS ALERTS",
                            subtitle: "Alert before a visible pass starts",
                            isOn: $notificationEngine.passAlertsEnabled
                        )
                        if notificationEngine.passAlertsEnabled {
                            leadTimeRow(label: "ALERT LEAD TIME", minutes: $notificationEngine.passLeadMinutes)
                        }
                        Divider().background(Color.white.opacity(0.08))

                        toggleRow(
                            icon: "sparkles",
                            title: "METEOR SHOWER ALERTS",
                            subtitle: "Alert the evening a shower peaks",
                            isOn: $notificationEngine.meteorAlertsEnabled
                        )
                    }
                    .background(Color(red: 0.06, green: 0.06, blue: 0.06))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.1), lineWidth: 1))
                    .cornerRadius(8)

                    sectionHeader("DASHBOARD LAYOUT")
                    Button(action: { showDashboardReorderSheet = true }) {
                        HStack(spacing: 12) {
                            Image(systemName: "arrow.up.arrow.down.circle.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.cyan)
                                .frame(width: 20)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("REORDER HOME COMMAND")
                                    .font(.system(.footnote, design: .monospaced))
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                Text(dashboardLayout.channelOrder.map { $0.title }.joined(separator: " · "))
                                    .font(.system(.caption2, design: .monospaced))
                                    .foregroundColor(.gray)
                                    .lineLimit(1)
                            }
                            Spacer(minLength: 8)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.gray)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .background(Color(red: 0.06, green: 0.06, blue: 0.06))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.1), lineWidth: 1))
                    .cornerRadius(8)

                    sectionHeader("QUIET HOURS")
                    VStack(spacing: 0) {
                        toggleRow(
                            icon: "moon.zzz.fill",
                            title: "QUIET HOURS",
                            subtitle: "Don't send launch/pass/meteor alerts overnight",
                            isOn: $notificationEngine.quietHoursEnabled
                        )
                        if notificationEngine.quietHoursEnabled {
                            Divider().background(Color.white.opacity(0.08))
                            hourRow(label: "STARTS AT", hour: $notificationEngine.quietHoursStartHour)
                            hourRow(label: "ENDS AT", hour: $notificationEngine.quietHoursEndHour)
                        }
                    }
                    .background(Color(red: 0.06, green: 0.06, blue: 0.06))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.1), lineWidth: 1))
                    .cornerRadius(8)

                    // Required Apple Weather legal attribution -- kept reachable here as a
                    // second, independent copy alongside the one on Home Command's field
                    // briefing bar (see BUG-05), since this screen is presented as its own
                    // .sheet, outside whatever's causing that one to be unreliable on iPad.
                    sectionHeader("LEGAL")
                    Link(destination: URL(string: "https://weather-data.apple.com/legal-attribution.html")!) {
                        HStack(spacing: 12) {
                            Image(systemName: "apple.logo")
                                .font(.system(size: 14))
                                .foregroundColor(.cyan)
                                .frame(width: 20)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("WEATHER DATA ATTRIBUTION")
                                    .font(.system(.footnote, design: .monospaced))
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                Text("Required legal attribution for the Apple Weather data used throughout the app.")
                                    .font(.system(.caption2, design: .monospaced))
                                    .foregroundColor(.gray)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer(minLength: 8)
                            Image(systemName: "arrow.up.right.square")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.gray)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                    }
                    .background(Color(red: 0.06, green: 0.06, blue: 0.06))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.1), lineWidth: 1))
                    .cornerRadius(8)

                    Button(action: { showAcknowledgementsSheet = true }) {
                        HStack(spacing: 12) {
                            Image(systemName: "info.circle")
                                .font(.system(size: 14))
                                .foregroundColor(.cyan)
                                .frame(width: 20)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("OPEN SOURCE ACKNOWLEDGEMENTS")
                                    .font(.system(.footnote, design: .monospaced))
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                Text("License text for the open-source libraries this app is built on.")
                                    .font(.system(.caption2, design: .monospaced))
                                    .foregroundColor(.gray)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer(minLength: 8)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.gray)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                    }
                    .background(Color(red: 0.06, green: 0.06, blue: 0.06))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.1), lineWidth: 1))
                    .cornerRadius(8)

                    Text("ALERTS ARE SCHEDULED FROM WHATEVER LAUNCH, PASS, AND METEOR SHOWER DATA HAS ALREADY LOADED. REOPEN THE APP TO REFRESH THEM AGAINST THE LATEST SCHEDULE.")
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundColor(.gray)
                        .padding(.horizontal, 4)

                    if !favorites.favoriteProviders.isEmpty || !favorites.favoriteSatellites.isEmpty {
                        Text("★ NOTE: YOU'VE STARRED SPECIFIC PROVIDERS AND/OR SATELLITES, SO LAUNCH AND PASS ALERTS ONLY FIRE FOR THOSE. UNSTAR EVERYTHING TO GET ALERTS FOR ALL OF THEM AGAIN.")
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundColor(.yellow)
                            .padding(.horizontal, 4)
                    }
                }
                .padding()
                .padding(.bottom, 40)
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("NOTIFICATIONS")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showDashboardReorderSheet) {
                DashboardReorderSheetView(layoutStore: dashboardLayout)
            }
            .sheet(isPresented: $showAcknowledgementsSheet) {
                AcknowledgementsView()
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(.cyan)
                        .fontWeight(.semibold)
                }
            }
        }
        .navigationViewStyle(.stack)
        .preferredColorScheme(.dark)
        .onAppear {
            notificationEngine.refreshAuthorizationStatus()
        }
    }

    // MARK: - Sections

    private var permissionStatusCard: some View {
        HStack(spacing: 12) {
            Image(systemName: notificationEngine.isAuthorized ? "bell.fill" : "bell.slash.fill")
                .font(.title2)
                .foregroundColor(notificationEngine.isAuthorized ? .green : .orange)

            VStack(alignment: .leading, spacing: 2) {
                Text(notificationEngine.isAuthorized ? "NOTIFICATIONS ENABLED" : "NOTIFICATIONS OFF")
                    .font(.system(.subheadline, design: .monospaced))
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                Text(notificationEngine.isAuthorized
                     ? "The toggles below control what you're alerted about."
                     : "Turn on notifications in Settings to use any of this.")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundColor(.gray)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)

            if !notificationEngine.isAuthorized {
                Button(action: {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }) {
                    Text("ENABLE")
                        .font(.system(.caption, design: .monospaced))
                        .fontWeight(.bold)
                        .foregroundColor(.black)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.orange)
                        .cornerRadius(6)
                }
            }
        }
        .padding()
        .background(Color(red: 0.06, green: 0.06, blue: 0.06))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.1), lineWidth: 1))
        .cornerRadius(8)
    }

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.system(.caption, design: .monospaced))
            .fontWeight(.bold)
            .foregroundColor(.cyan)
    }

    private func toggleRow(icon: String, title: String, subtitle: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(.cyan)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(.footnote, design: .monospaced))
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                Text(subtitle)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundColor(.gray)
            }
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(.cyan)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private func leadTimeRow(label: String, minutes: Binding<Int>) -> some View {
        HStack {
            Text(label)
                .font(.system(.caption2, design: .monospaced))
                .foregroundColor(.gray)
            Spacer()
            Picker("", selection: minutes) {
                ForEach(leadTimeOptions, id: \.self) { value in
                    Text("\(value) MIN").tag(value)
                }
            }
            .pickerStyle(.menu)
            .tint(.cyan)
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 10)
    }

    private func hourRow(label: String, hour: Binding<Int>) -> some View {
        HStack {
            Text(label)
                .font(.system(.caption2, design: .monospaced))
                .foregroundColor(.gray)
            Spacer()
            Picker("", selection: hour) {
                ForEach(0..<24, id: \.self) { value in
                    Text(String(format: "%02d:00", value)).tag(value)
                }
            }
            .pickerStyle(.menu)
            .tint(.cyan)
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 10)
    }
}
