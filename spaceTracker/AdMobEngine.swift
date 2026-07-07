//
//  AdMobEngine.swift
//  spaceTracker
//
//  Created by Ben Clary on 7/7/26.
//  MAKE AN APP COLIN LOVES

import Foundation
import SwiftUI
import Combine
import GoogleMobileAds

// 💡 FIXED: Annotated with @MainActor to safely bind UI state modifications to the main execution thread
@MainActor
class AdMobEngine: NSObject, ObservableObject, FullScreenContentDelegate {
    @Published var isPremiumUnlocked = false
    @Published var isAdReady = false
    
    private var rewardedInterstitialAd: RewardedInterstitialAd?
    
    // Google AdMob test identity unit code (safe for developer hardware logging)
    private let testAdUnitID = "ca-app-pub-3940256099942544/6978759866"
    
    override init() {
        super.init()
        checkDailyUnlockStatus()
        loadRewardedInterstitial()
    }
    
    // MARK: - 1. SYNCHRONIZE DATA PATHWAY TIMELINES
    func checkDailyUnlockStatus() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        let todayString = formatter.string(from: Date())
        let lastUnlockDate = UserDefaults.standard.string(forKey: "last_successful_ad_unlock_date") ?? ""
        
        if todayString == lastUnlockDate {
            self.isPremiumUnlocked = true
        } else {
            self.isPremiumUnlocked = false
        }
    }
    
    // MARK: - 2. STREAM BACKGROUND DIGITAL CONTENT CACHE
    func loadRewardedInterstitial() {
        let request = Request()
        
        // 💡 FIXED: Let Google's handler complete natively, then instantly hop onto the MainActor securely
        RewardedInterstitialAd.load(with: testAdUnitID, request: request) { ad, error in
            Task { @MainActor in
                if let error = error {
                    print("❌ [ADMOB ERROR]: Asset pre-fetch failure: \(error.localizedDescription)")
                    self.isAdReady = false
                    return
                }
                
                self.rewardedInterstitialAd = ad
                self.rewardedInterstitialAd?.fullScreenContentDelegate = self
                self.isAdReady = true
                print("✅ [ADMOB]: Modernized Rewarded Interstitial asset cached and armed.")
            }
        }
    }
    
    // MARK: - 3. EXECUTE DASHBOARD FULL SCREEN DISPATCH
    func showAd(from viewController: UIViewController, completion: @escaping () -> Void) {
        guard let ad = rewardedInterstitialAd else {
            print("⚠️ [ADMOB]: Presentation aborted. Asset not cached yet.")
            completion()
            return
        }
        
        ad.present(from: viewController) {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            let todayString = formatter.string(from: Date())
            
            UserDefaults.standard.set(todayString, forKey: "last_successful_ad_unlock_date")
            
            DispatchQueue.main.async {
                self.isPremiumUnlocked = true
                completion()
            }
        }
    }
    
    // MARK: - FullScreenContentDelegate Event Handlers
    // 💡 FIXED: Marked nonisolated to satisfy background framework protocol requirements under Swift 6
    nonisolated func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        print("✅ [ADMOB]: Video closed by user. Reloading background pipeline channel...")
        Task { @MainActor in
            self.isAdReady = false
            self.loadRewardedInterstitial()
        }
    }
}

