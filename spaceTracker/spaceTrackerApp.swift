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
                    //UserDefaults.standard.removeObject(forKey: "user_purchased_ad_free_forever")
                    //UserDefaults.standard.removeObject(forKey: "last_successful_ad_unlock_date")
                    //UserDefaults.standard.set(true, forKey: "user_purchased_ad_free_forever")
                    MobileAds.shared.start()
                }
        }
    }
}

