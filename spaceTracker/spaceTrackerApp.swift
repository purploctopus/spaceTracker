//
//  spaceTrackerApp.swift
//  spaceTracker
//
//  Created by Ben Clary on 6/17/26.
//  MAKE AN APP COLIN LOVES

import SwiftUI
import GoogleMobileAds

@main
struct spaceTrackerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    // 💡 FIXED: Updated initialization call pattern to comply with Swift 6 SDK standards
                    MobileAds.shared.start()
                }
        }
    }
}

