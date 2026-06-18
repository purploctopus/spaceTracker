//
//  Launch.swift
//  spaceTracker
//
//  Created by Ben Clary on 6/17/26.
//

import Foundation

struct LaunchResponse: Decodable {
    let count: Int?
    let next: String?
    let previous: String?
    let results: [SpaceLaunch]
}

struct SpaceLaunch: Decodable, Identifiable {
    let id: String
    let name: String
    let net: String?
    let pad: Pad?
    let vid_urls: [VideoURL]?
    let launch_service_provider: LaunchServiceProvider?
    let status: LaunchStatus?
    let rocket: RocketInfo?
    let mission: MissionObjective?
    let image: LaunchImage? // 💡 CRITICAL FIX: Maps to the v2.3.0 'image' nested object wrapper
    
    // 💡 THE DATE DECODER EXTENSION: Formats the raw timestamp into clear calendar layouts
    var localLaunchTimeDisplay: String {
        guard let netString = self.net else { return "NET LAUNCH SCHEDULED" }
        
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        var date = formatter.date(from: netString)
        if date == nil {
            let backup = ISO8601DateFormatter()
            date = backup.date(from: netString)
        }
        
        guard let validDate = date else { return "LAUNCH WINDOW OPEN" }
        
        let outputFormatter = DateFormatter()
        outputFormatter.dateFormat = "MMM d 'AT' h:mm a"
        return "LAUNCH: \(outputFormatter.string(from: validDate).uppercased())"
    }
}

// 💡 New nested structure matching the live production schema specs
struct LaunchImage: Decodable {
    let image_url: String? // 💡 The actual string key sitting inside the dictionary
}

struct LaunchStatus: Decodable {
    let id: Int?
    let name: String?
    let abbrev: String?
}

struct RocketInfo: Decodable {
    let configuration: RocketConfig?
}

struct RocketConfig: Decodable {
    let full_name: String?
}

struct MissionObjective: Decodable {
    let description: String?
    let type: String?
    let orbit: OrbitDetails?
}

struct OrbitDetails: Decodable {
    let abbrev: String?
}

struct LaunchServiceProvider: Decodable {
    let id: Int?
    let name: String?
}

struct Pad: Decodable {
    let name: String?
    let location: Location?
}

struct Location: Decodable {
    let name: String?
}

struct VideoURL: Decodable {
    let url: String?
}
