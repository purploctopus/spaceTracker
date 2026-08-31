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
    // 💡 Owned here, not in ContentView — spaceTrackerApp now also needs to trigger ads
    // (the app-transition ad break below), so there can only be one AdMobEngine instance
    // for the whole app. Two separate instances would have tracked purchase/unlock state
    // independently, which is a real bug waiting to happen (e.g. a restored purchase in one
    // instance never reflected in the other).
    @StateObject private var adEngine = AdMobEngine()
    // Tracks whether this process has had its first activation yet — a cold launch is not
    // a "natural pause point," it's the single least appropriate moment to interrupt
    // someone. The transition ad should only ever become eligible on a genuine
    // return-from-background, never on the literal moment the app opens.
    @State private var hasHadFirstActivation = false
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(adEngine)
                .onAppear {
                    //UserDefaults.standard.removeObject(forKey: "user_purchased_ad_free_forever")
                    //UserDefaults.standard.removeObject(forKey: "last_successful_ad_unlock_timestamp")
                    //UserDefaults.standard.set(true, forKey: "user_purchased_ad_free_forever")
                    MobileAds.shared.start()
                }
            // 💡 RE-ADDED ATT PIPELINE: Listens for when the app window is fully active on the iPad screen
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                    // Gives location and notification asks a 1-second window to clear out first
                    AskForReview().addTimesRan()
                    let timesRan = UserDefaults.standard.integer(forKey: "timesRan")
                    print("🏃 [TIMES RAN]: \(timesRan)")
                    
                    // Re-check the 24h unlock window on every activation, not just cold
                    // launch — otherwise a session left open across the 24h boundary would
                    // stay unlocked until the next full relaunch.
                    adEngine.checkDailyUnlockStatus()
                    
                    let isColdLaunch = !hasHadFirstActivation
                    hasHadFirstActivation = true
                    
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
                    
                    // 💡 AMBIENT AD BREAK: eligible on both cold launch and return-from-
                    // background — a full skip on cold launch turned out to leave a lot of
                    // revenue on the table, since many sessions for a quick-check utility
                    // app never background/return at all (open, glance, close). Cold launch
                    // gets a genuine 60-second grace period first, so nobody gets ambushed
                    // the instant they open the app; a return-from-background gets a shorter
                    // 3.5s delay since that grace already happened earlier in the day.
                    // timesRan == 1 (the very first session ever) still stays completely
                    // ad-free, and canShowTransitionAd() still handles the rest of the
                    // gating: already premium/unlocked, ad not ready, or shown within the
                    // last ~12 minutes all skip this automatically.
                    if timesRan > 1 {
                        let delay: TimeInterval = isColdLaunch ? 60.0 : 3.5
                        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                            if adEngine.canShowTransitionAd() {
                                adEngine.markTransitionAdShown()
                                adEngine.showAdFromKeyWindow()
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
