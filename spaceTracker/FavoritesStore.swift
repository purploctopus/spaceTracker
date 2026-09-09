//
//  FavoritesStore.swift
//  spaceTracker
//
//  FEAT-06: lets users star specific launch providers, satellites, and asteroids, then
//  scopes notifications and the dashboard's launch filter to just what they follow.

import Foundation
import Combine

final class FavoritesStore: ObservableObject {
    /// One shared instance rather than an injected dependency -- card views for launches,
    /// satellites, and asteroids are constructed from several places across the app with no
    /// existing environment-object plumbing for a store like this, and NotificationManager
    /// (not a View) needs to read it too when scoping alerts.
    static let shared = FavoritesStore()

    @Published private(set) var favoriteProviders: Set<String> {
        didSet { UserDefaults.standard.set(Array(favoriteProviders), forKey: Keys.providers) }
    }
    @Published private(set) var favoriteSatellites: Set<String> {
        didSet { UserDefaults.standard.set(Array(favoriteSatellites), forKey: Keys.satellites) }
    }
    @Published private(set) var favoriteAsteroids: Set<String> {
        didSet { UserDefaults.standard.set(Array(favoriteAsteroids), forKey: Keys.asteroids) }
    }

    private enum Keys {
        static let providers = "favorites_providers"
        static let satellites = "favorites_satellites"
        static let asteroids = "favorites_asteroids"
    }

    private init() {
        let defaults = UserDefaults.standard
        favoriteProviders = Set(defaults.stringArray(forKey: Keys.providers) ?? [])
        favoriteSatellites = Set(defaults.stringArray(forKey: Keys.satellites) ?? [])
        favoriteAsteroids = Set(defaults.stringArray(forKey: Keys.asteroids) ?? [])
    }

    func isProviderFavorite(_ name: String) -> Bool { favoriteProviders.contains(name) }
    func toggleProvider(_ name: String) {
        if favoriteProviders.contains(name) { favoriteProviders.remove(name) } else { favoriteProviders.insert(name) }
    }

    func isSatelliteFavorite(_ id: String) -> Bool { favoriteSatellites.contains(id) }
    func toggleSatellite(_ id: String) {
        if favoriteSatellites.contains(id) { favoriteSatellites.remove(id) } else { favoriteSatellites.insert(id) }
    }

    func isAsteroidFavorite(_ id: String) -> Bool { favoriteAsteroids.contains(id) }
    func toggleAsteroid(_ id: String) {
        if favoriteAsteroids.contains(id) { favoriteAsteroids.remove(id) } else { favoriteAsteroids.insert(id) }
    }
}
