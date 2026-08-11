//
//  AskForReview.swift
//  spaceTracker
//
//  Created by Ben Clary on 8/10/26.
//  MAKE AN APP COLIN LOVES AND ENAHANCES SARA'S HAPPINESS

import Foundation
import StoreKit

struct AskForReview {
    var timesRan = UserDefaults.standard.integer(forKey: "timesRan")
    func askForReview() {
        if timesRan == 10 || timesRan == 30 || timesRan == 90 {
            if let scene = UIApplication.shared.connectedScenes
                .first(where: { $0.activationState == .foregroundActive })
                as? UIWindowScene {
                
                Task { @MainActor in
                    AppStore.requestReview(in: scene)
                }
            }
        }
    }
    
    func addTimesRan() {
        var updatedTimesRan = timesRan
        updatedTimesRan += 1
        UserDefaults.standard.set(updatedTimesRan, forKey: "timesRan")
    }
}
