//
//  AdMobEngine.swift
//  spaceTracker
//
//  Created by Ben Clary on 7/7/26.
//  MAKE AN APP COLIN LOVES

// test     private let testAdUnitID = "ca-app-pub-3940256099942544/6978759866"
// prod     private let liveAdUnitID = "ca-app-pub-1070603260872166/4282670561"

import Foundation
import StoreKit
import GoogleMobileAds
import Combine

class AdMobEngine: NSObject, ObservableObject, FullScreenContentDelegate {
    @Published var isPremiumUnlocked = false
    @Published var isAdReady = false
    @Published var premiumProduct: Product?
    
    private let removeAdsProductID = "RemoveAdsOrbitLog"
    private var rewardedInterstitialAd: RewardedInterstitialAd?
    private let liveAdUnitID = "ca-app-pub-3940256099942544/6978759866"
    private var updatesTask: Task<Void, Never>?
    
    override init() {
        super.init()
        checkDailyUnlockStatus()
        loadRewardedInterstitial()
        
        updatesTask = listenForTransactions()
        
        // 💡 FIXED: Standard background task handles data fetching smoothly away from the main thread
        Task {
            await fetchStoreProduct()
            await verifyActivePurchases()
        }
    }
    
    deinit {
        updatesTask?.cancel()
    }
    
    // MARK: - 🛍️ STOREKIT 2 MANAGEMENT SYSTEMS
    
    private func fetchStoreProduct() async {
        do {
            let products = try await Product.products(for: [removeAdsProductID])
            let foundProduct = products.first
            
            // 💡 FIXED: Explicitly hop to MainActor only when updating the UI published properties
            await MainActor.run {
                self.premiumProduct = foundProduct
                print("🛍️ [STOREKIT]: Safely localized currency value: \(self.premiumProduct?.displayPrice ?? "")")
            }
        } catch {
            print("❌ [STOREKIT ERROR]: Failed to pull product sheet metrics: \(error)")
        }
    }
    
    func purchasePremium() async {
        if premiumProduct == nil {
            print("⚠️ [STOREKIT]: Product missing from memory cache. Attempting immediate refresh...")
            await fetchStoreProduct()
        }
        
        guard let product = premiumProduct else {
            print("❌ [STOREKIT ERROR]: Aborted. Apple servers failed to return product metadata.")
            return
        }
        
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try verifyTransaction(verification)
                print("✅ [STOREKIT]: Purchase verified. Granting permanent premium state.")
                
                await MainActor.run {
                    self.isPremiumUnlocked = true
                    UserDefaults.standard.set(true, forKey: "user_purchased_ad_free_forever")
                }
                await transaction.finish()
            case .pending, .userCancelled:
                break
            @unknown default:
                break
            }
        } catch {
            print("❌ [STOREKIT ERROR]: Transaction execution fault: \(error.localizedDescription)")
        }
    }
    
    func verifyActivePurchases() async {
        if UserDefaults.standard.bool(forKey: "user_purchased_ad_free_forever") {
            await MainActor.run { self.isPremiumUnlocked = true }
            return
        }
        
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                if transaction.productID == removeAdsProductID {
                    await MainActor.run {
                        self.isPremiumUnlocked = true
                        UserDefaults.standard.set(true, forKey: "user_purchased_ad_free_forever")
                    }
                    return
                }
            }
        }
    }
    
    private func verifyTransaction<T>(_ verification: VerificationResult<T>) throws -> T {
        switch verification {
        case .unverified(_, let error): throw error
        case .verified(let safeSignatures): return safeSignatures
        }
    }
    
    private func listenForTransactions() -> Task<Void, Never> {
        Task.detached {
            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    await MainActor.run {
                        if transaction.productID == self.removeAdsProductID {
                            self.isPremiumUnlocked = true
                            UserDefaults.standard.set(true, forKey: "user_purchased_ad_free_forever")
                        }
                    }
                    await transaction.finish()
                }
            }
        }
    }
    
    // 💡 MANDATORY FOR GUIDELINE 3.1.1: Explicitly triggers a manual look up of historical purchases
    func manualRestorePurchases() async {
        print("🛍️ [STOREKIT]: Manual restore requested by user. Syncing entitlements...")
        
        // Loop through all historically verified purchases associated with the user's Apple ID
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                if transaction.productID == removeAdsProductID {
                    // Update the UI state safely on the Main Actor
                    await MainActor.run {
                        self.isPremiumUnlocked = true
                        UserDefaults.standard.set(true, forKey: "user_purchased_ad_free_forever")
                    }
                    print("✅ [STOREKIT]: Historical entitlement found and restored successfully.")
                    return
                }
            }
        }
        print("ℹ️ [STOREKIT]: Manual restore complete. No historical active entitlements discovered.")
    }
    
    // MARK: - ADMOB INTEGRATION LOGIC
    
    func checkDailyUnlockStatus() {
        if UserDefaults.standard.bool(forKey: "user_purchased_ad_free_forever") {
            self.isPremiumUnlocked = true
            return
        }
        
        // 💡 FIXED: rolling 24h window from a stored timestamp, not a calendar-date string
        // comparison. The old version compared "yyyy-MM-dd" strings, so watching an ad at
        // 11:58 PM only bought ~2 minutes of ad-free time before the calendar day rolled
        // over — not the "24 hours" / "until midnight" the popup copy promised (those two
        // phrases didn't even agree with each other). Also, this now gets called whenever
        // the app becomes active (see spaceTrackerApp.swift), not just at cold launch, so a
        // long-running session crossing the 24h boundary re-locks correctly instead of
        // staying unlocked until the next full relaunch.
        if let unlockedAt = UserDefaults.standard.object(forKey: "last_successful_ad_unlock_timestamp") as? Date {
            self.isPremiumUnlocked = Date().timeIntervalSince(unlockedAt) < 24 * 60 * 60
        } else {
            self.isPremiumUnlocked = false
        }
    }
    
    /// Whether enough time has passed since the last automatically-shown transition ad to
    /// show another one. Keeps the ambient "ad break on app transition" from firing every
    /// single time the app comes back to foreground (e.g. quickly switching to Messages and
    /// back) — capped to roughly once per 12 minutes.
    func canShowTransitionAd() -> Bool {
        guard !isPremiumUnlocked, isAdReady else { return false }
        guard let lastShown = UserDefaults.standard.object(forKey: "last_transition_ad_shown_at") as? Date else {
            return true
        }
        return Date().timeIntervalSince(lastShown) > 12 * 60
    }
    
    func markTransitionAdShown() {
        UserDefaults.standard.set(Date(), forKey: "last_transition_ad_shown_at")
    }
    
    private var rewardedInterstitialLoadAttempts = 0
    
    func loadRewardedInterstitial() {
        let request = Request()
        
        RewardedInterstitialAd.load(with: liveAdUnitID, request: request) { ad, error in
            Task { @MainActor in
                if let error = error {
                    print("❌ [ADMOB ERROR]: Asset pre-fetch failure: \(error.localizedDescription)")
                    self.isAdReady = false
                    
                    // 💡 FIXED: previously a failed initial load left isAdReady stuck at
                    // false for the rest of the session — the "Watch Ad" button would show
                    // "LOADING Ad..." forever with nothing ever retrying. Retries with a
                    // short backoff, capped so a persistently offline device doesn't retry
                    // forever in the background.
                    self.rewardedInterstitialLoadAttempts += 1
                    if self.rewardedInterstitialLoadAttempts <= 5 {
                        let delaySeconds = Double(self.rewardedInterstitialLoadAttempts) * 15.0
                        try? await Task.sleep(nanoseconds: UInt64(delaySeconds * 1_000_000_000))
                        self.loadRewardedInterstitial()
                    }
                    return
                }
                
                self.rewardedInterstitialLoadAttempts = 0
                self.rewardedInterstitialAd = ad
                self.rewardedInterstitialAd?.fullScreenContentDelegate = self
                self.isAdReady = true
                print("🚀 [ADMOB LIVE]: Production Rewarded Interstitial asset cached and armed.")
            }
        }
    }
    
    func showAd(from viewController: UIViewController, completion: @escaping () -> Void) {
        guard let ad = rewardedInterstitialAd else {
            print("⚠️ [ADMOB]: Presentation aborted. Asset not cached yet.")
            completion()
            return
        }
        
        ad.present(from: viewController) {
            UserDefaults.standard.set(Date(), forKey: "last_successful_ad_unlock_timestamp")
            
            DispatchQueue.main.async {
                self.isPremiumUnlocked = true
                completion()
            }
        }
    }
    
    /// Shared "find the key window and present" helper — both the voluntary watch-ad button
    /// and the automatic app-transition trigger need this exact lookup, previously
    /// duplicated inline wherever an ad needed to be shown.
    func showAdFromKeyWindow(completion: @escaping () -> Void = {}) {
        guard let rootVC = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { $0.isKeyWindow })?.rootViewController else {
            completion()
            return
        }
        showAd(from: rootVC, completion: completion)
    }
    
    nonisolated func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        print("✅ [ADMOB]: Video closed by user. Reloading background pipeline channel...")
        Task { @MainActor in
            self.isAdReady = false
            self.loadRewardedInterstitial()
        }
    }
}
