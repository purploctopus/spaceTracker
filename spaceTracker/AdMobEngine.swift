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

@MainActor
class AdMobEngine: NSObject, ObservableObject, FullScreenContentDelegate {
    @Published var isPremiumUnlocked = false
    @Published var isAdReady = false
    @Published var premiumProduct: Product?
    
    // 💡 DEFINED: Verified App Store Connect product identifier matching your configuration dashboard
    private let removeAdsProductID = "RemoveAdsOrbitLog"
    
    private var rewardedInterstitialAd: RewardedInterstitialAd?
    
    // 💡 PRODUCTION SWAP: Updated to use your live, revenue-generating AdMob ID placement
    private let liveAdUnitID = "ca-app-pub-1070603260872166/4282670561"
    private var updatesTask: Task<Void, Never>?
    
    override init() {
        super.init()
        checkDailyUnlockStatus()
        loadRewardedInterstitial()
        
        updatesTask = listenForTransactions()
        
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
            self.premiumProduct = products.first
            print("🛍️ [STOREKIT]: Safely localized currency value: \(self.premiumProduct?.displayPrice ?? "")")
        } catch {
            print("❌ [STOREKIT ERROR]: Failed to pull product sheet metrics: \(error)")
        }
    }
    
    func purchasePremium() async {
        guard let product = premiumProduct else { return }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try verifyTransaction(verification)
                print("✅ [STOREKIT]: Purchase verified. Granting permanent premium state.")
                
                // 💡 THREAD SAFETY FIX: Safely route property updates back to the Main UI Thread
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
            self.isPremiumUnlocked = true
            return
        }
        
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                if transaction.productID == removeAdsProductID {
                    // 💡 THREAD SAFETY FIX: Safely route historic entitlement state changes back to Main Actor
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
    
    // MARK: - ADMOB INTEGRATION LOGIC
    
    func checkDailyUnlockStatus() {
        if UserDefaults.standard.bool(forKey: "user_purchased_ad_free_forever") {
            self.isPremiumUnlocked = true
            return
        }
        
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
    
    func loadRewardedInterstitial() {
        let request = Request()
        
        // Target your live production ad unit placement path
        RewardedInterstitialAd.load(with: liveAdUnitID, request: request) { ad, error in
            Task { @MainActor in
                if let error = error {
                    print("❌ [ADMOB ERROR]: Asset pre-fetch failure: \(error.localizedDescription)")
                    self.isAdReady = false
                    return
                }
                
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
    
    nonisolated func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        print("✅ [ADMOB]: Video closed by user. Reloading background pipeline channel...")
        Task { @MainActor in
            self.isAdReady = false
            self.loadRewardedInterstitial()
        }
    }
}
