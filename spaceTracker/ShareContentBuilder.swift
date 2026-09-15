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
        return lines.joined(separator: "\n")
    }

    static func shareText(for pass: SatellitePass) -> String {
        """
        🛰️ \(pass.name) is passing overhead
        \(pass.localDisplayTime)
        Look \(pass.travelDirection.uppercased()) \u{2014} peak elevation \(Int(pass.peakElevationDegrees))°, visible for \(pass.durationMinutes) min.

        Tracked in OrbitLog 🛰️
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
        """
    }
}
