//
//  DashboardLayoutStore.swift
//  spaceTracker
//
//  FEAT-15: lets users drag-to-reorder the Home Command dashboard's channel blocks
//  (missions, satellites, asteroids, meteor showers) so whatever they check most often
//  shows up first, instead of always scrolling past the same fixed sequence.

import Foundation
import Combine

/// One reorderable section of the Home Command dashboard. Cases are the actual channel
/// blocks ContentView renders in its big VStack -- the "hero" elements above them (the
/// stargazing conditions bar, the live sky map banner) stay pinned since they're the
/// daily entry point rather than a feed worth reprioritizing.
enum DashboardChannel: String, CaseIterable, Codable, Identifiable {
    case missions
    case satellites
    case asteroids
    case meteorShowers

    var id: String { rawValue }

    var title: String {
        switch self {
        case .missions: return "Launches"
        case .satellites: return "Satellite Passes"
        case .asteroids: return "Near-Earth Asteroids"
        case .meteorShowers: return "Meteor Showers"
        }
    }

    var systemImageName: String {
        switch self {
        case .missions: return "flame.fill"
        case .satellites: return "antenna.radiowaves.left.and.right"
        case .asteroids: return "circle.hexagongrid.fill"
        case .meteorShowers: return "sparkles"
        }
    }
}

final class DashboardLayoutStore: ObservableObject {
    /// One shared instance -- same reasoning as FavoritesStore: the persisted order is
    /// read from ContentView's body and written from a standalone reorder sheet reached
    /// through Settings, with no existing environment-object plumbing between the two.
    static let shared = DashboardLayoutStore()

    @Published private(set) var channelOrder: [DashboardChannel] {
        didSet {
            UserDefaults.standard.set(channelOrder.map { $0.rawValue }, forKey: Keys.order)
        }
    }

    private enum Keys {
        static let order = "dashboard_channel_order_v1"
    }

    private init() {
        if let storedRawValues = UserDefaults.standard.stringArray(forKey: Keys.order) {
            let storedChannels = storedRawValues.compactMap(DashboardChannel.init(rawValue:))
            // Backfills any channel introduced after a user's order was already saved (or
            // silently drops one whose rawValue is ever retired) so the list always holds
            // every current case exactly once, with the user's chosen order preserved first.
            let missing = DashboardChannel.allCases.filter { !storedChannels.contains($0) }
            channelOrder = storedChannels + missing
        } else {
            channelOrder = DashboardChannel.allCases
        }
    }

    func move(fromOffsets source: IndexSet, toOffset destination: Int) {
        channelOrder.move(fromOffsets: source, toOffset: destination)
    }

    func resetToDefault() {
        channelOrder = DashboardChannel.allCases
    }
}
