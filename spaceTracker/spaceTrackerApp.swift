//
//  spaceTrackerApp.swift
//  spaceTracker
//
//  Created by Ben Clary on 6/17/26.
//  MAKE AN APP COLIN LOVES

import SwiftUI
import GoogleMobileAds
import AppTrackingTransparency 

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
            // 💡 RE-ADDED ATT PIPELINE: Listens for when the app window is fully active on the iPad screen
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                    // Gives location and notification asks a 1-second window to clear out first
                    AskForReview().addTimesRan()
                    print("🏃 [TIMES RAN]: \(UserDefaults.standard.integer(forKey: "timesRan"))")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        if ATTrackingManager.trackingAuthorizationStatus == .notDetermined {
                            ATTrackingManager.requestTrackingAuthorization { status in
                                switch status {
                                case .authorized:
                                    print("✅ [ATT SUCCESS]: Tracking authorized. Arming production IDs.")
                                case .denied, .restricted, .notDetermined:
                                    print("⚠️ [ATT NOTICE]: Tracking denied. Falling back to non-targeted context.")
                                @unknown default:
                                    break
                                }
                            }
                        }
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) {
                        print("📈 [REVIEW]: Ask for review has been called")
                        AskForReview().askForReview()
                    }
                }
        }
    }
}

