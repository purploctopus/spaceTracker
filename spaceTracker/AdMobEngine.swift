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
import StoreKit // 💡 INJECTED: Modern StoreKit 2 E-Commerce Framework

@MainActor
class AdMobEngine: NSObject, ObservableObject, FullScreenContentDelegate {
    @Published var isPremiumUnlocked = false
    @Published var isAdReady = false
    @Published var premiumProduct: Product? // 💡 INJECTED: Stores localized pricing metadata from Apple's servers
    
    // 💡 DEFINED: Your production-ready StoreKit Identifier matching App Store Connect configuration profiles
    private let removeAdsProductID = "com.PurplOctopus.spaceTracker.removeAds"
    
    private var rewardedInterstitialAd: RewardedInterstitialAd?
    private let testAdUnitID = "ca-app-pub-3940256099942544/6978759866"
    private var updatesTask: Task<Void, Never>?
    
    override init() {
        super.init()
        checkDailyUnlockStatus()
        loadRewardedInterstitial()
        
        // 💡 INJECTED: Listen for remote transaction completions asynchronously on boot
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
    
    /// Pulls localized pricing currency strings directly down from Apple's servers
    private func fetchStoreProduct() async {
        do {
            let products = try await Product.products(for: [removeAdsProductID])
            self.premiumProduct = products.first
            print("🛍️ [STOREKIT]: Safely localized currency value: \(self.premiumProduct?.displayPrice ?? "")")
        } catch {
            print("❌ [STOREKIT ERROR]: Failed to pull product sheet metrics: \(error)")
        }
    }
    
    /// Coordinates transaction processing window sheets natively inside the overlay prompts
    func purchasePremium() async {
        guard let product = premiumProduct else { return }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try verifyTransaction(verification)
                print("✅ [STOREKIT]: Purchase verified. Granting permanent premium state.")
                self.isPremiumUnlocked = true
                UserDefaults.standard.set(true, forKey: "user_purchased_ad_free_forever")
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
    
    /// Asserts historic ownership parameters on clean application boots
    func verifyActivePurchases() async {
        if UserDefaults.standard.bool(forKey: "user_purchased_ad_free_forever") {
            self.isPremiumUnlocked = true
            return
        }
        
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                if transaction.productID == removeAdsProductID {
                    self.isPremiumUnlocked = true
                    UserDefaults.standard.set(true, forKey: "user_purchased_ad_free_forever")
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
    
    // MARK: - 1. SYNCHRONIZE DATA PATHWAY TIMELINES
    func checkDailyUnlockStatus() {
        // 💡 CRUCIAL SHIELD: If they have bought it once, they permanently skip calendar day calculations
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
    
    // MARK: - 2. STREAM BACKGROUND DIGITAL CONTENT CACHE
    func loadRewardedInterstitial() {
        let request = Request()
        
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
    nonisolated func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        print("✅ [ADMOB]: Video closed by user. Reloading background pipeline channel...")
        Task { @MainActor in
            self.isAdReady = false
            self.loadRewardedInterstitial()
        }
    }
}
