//
//  ShareContentBuilder.swift
//  spaceTracker
//
//  Created by Claude on 9/9/26.
//
//  FEAT-08: turns a launch, satellite pass, or asteroid into a short, well-formatted text
//  summary for the native share sheet (SwiftUI's ShareLink, which takes a plain String out
//  of the box since String already conforms to Transferable -- no custom wrapping needed).
//  Kept separate from the card views themselves so the "what does a share look like" copy
//  lives in one place instead of three.

import Foundation

enum ShareContentBuilder {
    // FEAT-23: real App Store link (confirmed by the user, 2026-09-15) -- appended after the
    // "Tracked in OrbitLog" line on every share so whoever receives one of these can actually
    // get the app, not just see data from it.
    private static let appStoreLine = "Get OrbitLog: https://apps.apple.com/us/app/orbitlog-space-tracker-hub/id6791340139"

    static func shareText(for launch: SpaceLaunch) -> String {
        var lines = ["🚀 \(launch.name)"]
        if let provider = launch.launch_service_provider?.name {
            lines.append(provider)
        }
        lines.append(launch.localLaunchTimeDisplay)
        if let orbit = launch.mission?.orbit?.abbrev {
            lines.append("Target orbit: \(orbit)")
        }
        lines.append("\nTracked in OrbitLog 🛰️")
        lines.append(appStoreLine)
        return lines.joined(separator: "\n")
    }

    static func shareText(for pass: SatellitePass) -> String {
        """
        🛰️ \(pass.name) is passing overhead
        \(pass.localDisplayTime)
        Look \(pass.travelDirection.uppercased()) \u{2014} peak elevation \(Int(pass.peakElevationDegrees))°, visible for \(pass.durationMinutes) min.

        Tracked in OrbitLog 🛰️
        \(appStoreLine)
        """
    }

    static func shareText(for asteroid: Asteroid) -> String {
        let hazardLine = asteroid.is_potentially_hazardous_asteroid
            ? "⚠️ Classified as potentially hazardous"
            : "Not considered hazardous"
        return """
        ☄️ \(asteroid.name) makes its closest approach on \(asteroid.localDateDisplay)
        Miss distance: \(asteroid.missDistanceLunar) lunar distances
        Estimated size: up to \(asteroid.maxDiameterMeters)m
        \(hazardLine)

        Tracked in OrbitLog 🛰️
        \(appStoreLine)
        """
    }
}
