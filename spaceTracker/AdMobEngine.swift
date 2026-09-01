//
//  AdMobEngine.swift
//  spaceTracker
//
//  Created by Ben Clary on 7/7/26.
//  MAKE AN APP COLIN LOVES

import Foundation
import StoreKit
import GoogleMobileAds
import Combine

class AdMobEngine: NSObject, ObservableObject, FullScreenContentDelegate {
    // 💡 TEST MODE: flip this one flag to switch every ad unit ID below between Google's
    // published sample/demo IDs and your real production IDs. Nothing else needs touching
    // when going into or out of testing.
    static let isTestMode = false

    // MARK: - Ad unit IDs
    // Test IDs are Google's official published demo ad units (developers.google.com/admob/ios/test-ads) —
    // verified directly against that page, not from memory.
    private var rewardedInterstitialAdUnitID: String {
        Self.isTestMode
            ? "ca-app-pub-3940256099942544/6978759866"
            : "ca-app-pub-1070603260872166/4282670561"
    }
    private var appOpenAdUnitID: String {
        Self.isTestMode
            ? "ca-app-pub-3940256099942544/5575463023"
            : "ca-app-pub-1070603260872166/1125791047"
    }
    private var nativeAdUnitID: String {
        Self.isTestMode
            ? "ca-app-pub-3940256099942544/3986624511"
            : "ca-app-pub-1070603260872166/3751954388"
    }

    // MARK: - Ad-free state
    // Split into two genuinely different states rather than one flag: a permanent purchase
    // and a temporary 24h ad-watch unlock are different things with different UI needs (the
    // persistent "go ad-free" entry point should stay visible during a temporary window,
    // only disappearing on a real purchase — it should never look permanently gone just
    // because today's ad was already watched).
    @Published var hasPermanentAdFree = false
    @Published var hasTemporaryAdFreeActive = false
    @Published var temporaryAdFreeExpiresAt: Date?

    /// Whether ads should currently be suppressed anywhere in the app, for the many call
    /// sites that only care about the combined answer (transition ads, App Open ads, etc.)
    /// and don't need to distinguish *why*. UI code that needs to tell the two states apart
    /// (the persistent entry point, the prompt sheet) should use the two flags above instead.
    var isPremiumUnlocked: Bool { hasPermanentAdFree || hasTemporaryAdFreeActive }

    @Published var isAdReady = false
    @Published var premiumProduct: Product?

    private let removeAdsProductID = "RemoveAdsOrbitLog"
    private var rewardedInterstitialAd: RewardedInterstitialAd?
    private var updatesTask: Task<Void, Never>?

    override init() {
        super.init()

        // 💡 TEST MODE ONLY: a rewarded/App Open ad watched during an earlier test session
        // leaves the real 24h temporary ad-free window active, which then silently suppresses
        // every ad surface in the app (including this one) for the rest of that real day —
        // easy to mistake for a loading bug. This clears it fresh on every launch while
        // isTestMode is true. Never runs in production — a real user's temporary unlock is
        // never touched by this. The permanent purchase flag is deliberately left alone: a
        // real StoreKit entitlement would just re-grant itself via verifyActivePurchases()
        // regardless, so clearing it here wouldn't accomplish anything for testing purchases
        // anyway — that needs Apple's own Sandbox "clear purchase history," not app code.
        if Self.isTestMode {
            resetTemporaryUnlockStateForTesting()
        }

        checkDailyUnlockStatus()
        loadRewardedInterstitial()
        loadAppOpenAd()

        updatesTask = listenForTransactions()

        Task {
            await fetchStoreProduct()
            await verifyActivePurchases()
        }
    }

    private func resetTemporaryUnlockStateForTesting() {
        UserDefaults.standard.removeObject(forKey: "last_successful_ad_unlock_timestamp")
        UserDefaults.standard.removeObject(forKey: "last_transition_ad_shown_at")
        UserDefaults.standard.removeObject(forKey: "last_app_open_ad_shown_at")
        print("🧪 [TEST MODE]: Cleared temporary ad-free window + frequency caps for a fresh test session.")
    }

    deinit {
        updatesTask?.cancel()
    }

    // MARK: - 🛍️ STOREKIT 2 MANAGEMENT SYSTEMS

    private func fetchStoreProduct() async {
        do {
            let products = try await Product.products(for: [removeAdsProductID])
            let foundProduct = products.first

            await MainActor.run {
                self.premiumProduct = foundProduct
                print("🛍️ [STOREKIT]: Safely localized currency value: \(self.premiumProduct?.displayPrice ?? "")")
            }
        } catch {
            print("❌ [STOREKIT ERROR]: Failed to pull product sheet metrics: \(error)")
        }
    }

    /// Purchasing always remains possible regardless of temporary ad-free state — this is
    /// never gated behind "wait until your free window expires." The permanent option is
    /// meant to always be available until the moment someone actually buys it.
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
                print("✅ [STOREKIT]: Purchase verified. Granting permanent ad-free state.")

                await MainActor.run {
                    self.hasPermanentAdFree = true
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
            await MainActor.run { self.hasPermanentAdFree = true }
            return
        }

        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                if transaction.productID == removeAdsProductID {
                    await MainActor.run {
                        self.hasPermanentAdFree = true
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
                            self.hasPermanentAdFree = true
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

        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                if transaction.productID == removeAdsProductID {
                    await MainActor.run {
                        self.hasPermanentAdFree = true
                        UserDefaults.standard.set(true, forKey: "user_purchased_ad_free_forever")
                    }
                    print("✅ [STOREKIT]: Historical entitlement found and restored successfully.")
                    return
                }
            }
        }
        print("ℹ️ [STOREKIT]: Manual restore complete. No historical active entitlements discovered.")
    }

    // MARK: - 🎬 REWARDED INTERSTITIAL (cold-launch ad break + voluntary "watch ad" unlock)

    func checkDailyUnlockStatus() {
        if UserDefaults.standard.bool(forKey: "user_purchased_ad_free_forever") {
            self.hasPermanentAdFree = true
        }

        // Rolling 24h window from a stored timestamp, not a calendar-date comparison —
        // watching at 11:58 PM correctly buys a full 24 hours, not ~2 minutes. Called on
        // every app activation (see spaceTrackerApp.swift), not just cold launch, so a long
        // session crossing the boundary re-locks correctly.
        if let unlockedAt = UserDefaults.standard.object(forKey: "last_successful_ad_unlock_timestamp") as? Date {
            let expiresAt = unlockedAt.addingTimeInterval(24 * 60 * 60)
            self.hasTemporaryAdFreeActive = Date() < expiresAt
            self.temporaryAdFreeExpiresAt = self.hasTemporaryAdFreeActive ? expiresAt : nil
        } else {
            self.hasTemporaryAdFreeActive = false
            self.temporaryAdFreeExpiresAt = nil
        }
    }

    /// Whether enough time has passed since the last automatically-shown transition ad to
    /// show another one — capped to roughly once per 12 minutes.
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

        RewardedInterstitialAd.load(with: rewardedInterstitialAdUnitID, request: request) { ad, error in
            Task { @MainActor in
                if let error = error {
                    print("❌ [ADMOB ERROR]: Rewarded interstitial pre-fetch failure: \(error.localizedDescription)")
                    self.isAdReady = false

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
                print("🚀 [ADMOB]: Rewarded Interstitial asset cached and armed. (test mode: \(Self.isTestMode))")
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
                self.checkDailyUnlockStatus()
                completion()
            }
        }
    }

    /// Shared "find the key window and present" helper — used by the rewarded interstitial
    /// (voluntary button + cold-launch transition trigger) and the App Open ad below.
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
        print("✅ [ADMOB]: Full-screen ad closed. Reloading whichever pipeline just presented...")
        Task { @MainActor in
            if ad is RewardedInterstitialAd {
                self.isAdReady = false
                self.loadRewardedInterstitial()
            } else if ad is AppOpenAd {
                self.isAppOpenAdReady = false
                self.appOpenAd = nil
                self.loadAppOpenAd()
            }
        }
    }

    // MARK: - 🚪 APP OPEN AD (return-from-background ad break, never rewards anything)

    @Published var isAppOpenAdReady = false
    private var appOpenAd: AppOpenAd?
    private var appOpenAdLoadTime: Date?
    private var appOpenAdLoadAttempts = 0

    /// Google's own guidance: treat a cached App Open ad as stale after ~4 hours rather
    /// than show a potentially outdated creative.
    private var isAppOpenAdFresh: Bool {
        guard let loadTime = appOpenAdLoadTime else { return false }
        return Date().timeIntervalSince(loadTime) < 4 * 60 * 60
    }

    func loadAppOpenAd() {
        Task {
            do {
                let ad = try await AppOpenAd.load(with: appOpenAdUnitID, request: Request())
                await MainActor.run {
                    self.appOpenAd = ad
                    self.appOpenAd?.fullScreenContentDelegate = self
                    self.appOpenAdLoadTime = Date()
                    self.isAppOpenAdReady = true
                    self.appOpenAdLoadAttempts = 0
                    print("🚀 [ADMOB]: App Open ad cached and armed. (test mode: \(Self.isTestMode))")
                }
            } catch {
                await MainActor.run {
                    print("❌ [ADMOB ERROR]: App Open ad pre-fetch failure: \(error.localizedDescription)")
                    self.isAppOpenAdReady = false
                }
                self.appOpenAdLoadAttempts += 1
                if self.appOpenAdLoadAttempts <= 5 {
                    let delaySeconds = Double(self.appOpenAdLoadAttempts) * 15.0
                    try? await Task.sleep(nanoseconds: UInt64(delaySeconds * 1_000_000_000))
                    self.loadAppOpenAd()
                }
            }
        }
    }

    /// Same spirit as canShowTransitionAd, kept separate since App Open has its own cadence
    /// (fires on return-from-background specifically) and shouldn't share a cooldown clock
    /// with the rewarded interstitial's cold-launch trigger.
    func canShowAppOpenAd() -> Bool {
        guard !isPremiumUnlocked, isAppOpenAdReady, isAppOpenAdFresh else { return false }
        guard let lastShown = UserDefaults.standard.object(forKey: "last_app_open_ad_shown_at") as? Date else {
            return true
        }
        return Date().timeIntervalSince(lastShown) > 12 * 60
    }

    func markAppOpenAdShown() {
        UserDefaults.standard.set(Date(), forKey: "last_app_open_ad_shown_at")
    }

    /// App Open ads never grant the 24h reward — rewarding someone just for reopening the
    /// app (versus actively choosing to watch something) would muddy the "reward means you
    /// opted in" framing the rest of this file is built around.
    func showAppOpenAdFromKeyWindow(completion: @escaping () -> Void = {}) {
        guard let ad = appOpenAd, isAppOpenAdFresh else {
            print("⚠️ [ADMOB]: App Open presentation aborted. Asset not cached or stale.")
            completion()
            return
        }
        guard let rootVC = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { $0.isKeyWindow })?.rootViewController else {
            completion()
            return
        }

        ad.present(from: rootVC)
        completion()
    }

    // MARK: - 🗞️ NATIVE AD (news feed cards)

    /// Exposed so NativeAdCardLoader (see NativeAdCardView.swift) can request loads using
    /// the same test/prod-aware ID as everything else in this file, without duplicating the
    /// isTestMode branch anywhere else.
    var newsNativeAdUnitID: String { nativeAdUnitID }
}
