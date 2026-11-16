//
//  SightingsViews.swift
//  spaceTracker
//
//  FEAT-32: the "I saw it" button used on cards, the My Sightings card on Star Gazers, and
//  the sightings index/log sheet it opens.

import SwiftUI

// MARK: - "I SAW IT" button (tap again to undo)

struct SawItButton: View {
    let isLogged: Bool
    var label: String = "I SAW IT"
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 3) {
                Image(systemName: isLogged ? "checkmark.circle.fill" : "eye")
                    .font(.system(size: 9, weight: .bold))
                Text(isLogged ? "LOGGED" : label)
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .lineLimit(1)
                    .fixedSize()
            }
            .foregroundColor(isLogged ? .black : .cyan)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(isLogged ? Color.green : Color.cyan.opacity(0.12))
            .cornerRadius(3)
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel(isLogged ? "Logged. Double tap to undo." : label.capitalized)
    }
}

// MARK: - My Sightings card (Star Gazers)

struct MySightingsCard: View {
    @ObservedObject private var store = SightingsStore.shared

    private var planetsSeen: Int {
        SightingsStore.planetIndex.filter { store.count(.planet, $0) > 0 }.count
    }

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "binoculars.fill")
                .font(.title3)
                .foregroundColor(.cyan)

            VStack(alignment: .leading, spacing: 4) {
                Text("MY SIGHTINGS")
                    .font(.system(.subheadline, design: .monospaced))
                    .fontWeight(.bold)
                    .foregroundColor(.primary)

                Text("\(store.sightings.count) LOGGED · \(planetsSeen)/\(SightingsStore.planetIndex.count) PLANETS & MOON")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if store.weeklyStreak > 0 {
                    Label("\(store.weeklyStreak)-WEEK STREAK", systemImage: "flame.fill")
                        .font(.system(.caption2, design: .monospaced).weight(.bold))
                        .foregroundColor(.orange)
                } else {
                    Text("LOG A SIGHTING TO START A STREAK")
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 3)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens your sightings index")
    }
}

// MARK: - Sightings index + log sheet

struct SightingsIndexSheet: View {
    /// Current pass list, so passes that just ended (and dropped off Home Command's list)
    /// can still be logged here for up to 3 hours.
    let passes: [SatellitePass]

    @ObservedObject private var store = SightingsStore.shared
    @Environment(\.dismiss) private var dismiss

    private var recentPasses: [SatellitePass] {
        passes.filter { SightingsStore.canLogPass($0) }
    }

    private let logDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, h:mm a"
        return formatter
    }()

    var body: some View {
        NavigationStack {
            List {
                Section {
                    statRow("TOTAL SIGHTINGS", "\(store.sightings.count)")
                    statRow("WEEK STREAK", store.weeklyStreak > 0 ? "\(store.weeklyStreak)" : "—")
                }

                if !recentPasses.isEmpty {
                    Section(header: sectionHeader("LOG A RECENT PASS")) {
                        ForEach(recentPasses, id: \.id_swiftui) { pass in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(pass.name.uppercased())
                                        .font(.system(.footnote, design: .monospaced))
                                        .fontWeight(.bold)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.8)
                                    Text(pass.localDisplayTime.uppercased())
                                        .font(.system(.caption2, design: .monospaced))
                                        .foregroundColor(.secondary)
                                }
                                Spacer(minLength: 8)
                                SawItButton(isLogged: store.isLogged(eventKey: SightingsStore.passEventKey(pass))) {
                                    store.togglePass(pass)
                                }
                            }
                        }
                    }
                }

                Section(header: sectionHeader("PLANETS & MOON")) {
                    ForEach(SightingsStore.planetIndex, id: \.self) { name in
                        indexRow(name, store.count(.planet, name), seenWord: "SEEN")
                    }
                }

                Section(header: sectionHeader("SATELLITES")) {
                    ForEach(SightingsStore.satelliteIndex, id: \.name) { entry in
                        indexRow(entry.name, store.count(.satellite, entry.name), seenWord: "SEEN")
                    }
                }

                if !store.otherSatellites.isEmpty {
                    Section(header: sectionHeader("OTHER SATELLITES SPOTTED")) {
                        ForEach(store.otherSatellites) { item in
                            indexRow(item.name, item.count, seenWord: "SEEN")
                        }
                    }
                }

                Section(header: sectionHeader("METEOR SHOWERS")) {
                    ForEach(SightingsStore.meteorShowerIndex, id: \.self) { name in
                        indexRow(name, store.count(.meteorShower, name), seenWord: "SEEN")
                    }
                }

                Section(header: sectionHeader("LAUNCHES WATCHED")) {
                    if store.launchProviders.isEmpty {
                        Text("None yet. Tap WATCHED on a launch card after liftoff.")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        ForEach(store.launchProviders) { item in
                            indexRow(item.name, item.count, seenWord: "WATCHED")
                        }
                    }
                }

                if !store.sightings.isEmpty {
                    let recent = Array(store.recentSightings.prefix(50))
                    Section(header: sectionHeader("RECENT LOG"),
                            footer: Text("Swipe left on an entry to remove it.")
                                .font(.system(.caption2, design: .monospaced))) {
                        ForEach(recent) { sighting in
                            HStack {
                                Text(sighting.displayName.uppercased())
                                    .font(.system(.footnote, design: .monospaced))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                                Spacer(minLength: 8)
                                Text(logDateFormatter.string(from: sighting.date).uppercased())
                                    .font(.system(.caption2, design: .monospaced))
                                    .foregroundColor(.secondary)
                                    .fixedSize()
                            }
                        }
                        .onDelete { offsets in
                            offsets.map { recent[$0] }.forEach { store.delete($0) }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("MY SIGHTINGS")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.system(.caption, design: .monospaced).weight(.bold))
            .foregroundColor(.cyan)
    }

    private func statRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(.footnote, design: .monospaced))
                .fontWeight(.bold)
            Spacer()
            Text(value)
                .font(.system(.footnote, design: .monospaced))
                .fontWeight(.bold)
                .foregroundColor(.cyan)
        }
    }

    private func indexRow(_ name: String, _ count: Int, seenWord: String) -> some View {
        HStack {
            Text(name.uppercased())
                .font(.system(.footnote, design: .monospaced))
                .fontWeight(.bold)
                .foregroundColor(count > 0 ? .primary : .secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 8)
            Text(count > 0 ? "\(seenWord) ×\(count)" : "NOT SEEN YET")
                .font(.system(.caption2, design: .monospaced))
                .foregroundColor(count > 0 ? .green : .secondary)
                .fixedSize()
        }
        .opacity(count > 0 ? 1 : 0.6)
    }
}
