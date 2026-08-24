//
//  SkyMotionManager.swift
//  spaceTracker
//
//  Created by Ben Clary on 8/14/26.
//  MAKE AN APP COLIN LOVES AND ENABLES SARA'S FREEDOM!

import Foundation
import CoreMotion
import Combine

// ==============================================================================
// 📡 LIGHTWEIGHT HORIZON GUARD SENSOR UTILITY
// ==============================================================================
class SkyMotionManager: ObservableObject {
    private let motionManager = CMMotionManager()
    
    @Published var altitudeTilt: Double = 0.0
    @Published var isPointingBelowHorizon: Bool = false
    
    func engageSensorStreaming(with targets: [APIPlanetItem]) {
        guard motionManager.isDeviceMotionAvailable else { return }
        
        motionManager.deviceMotionUpdateInterval = 1.0 / 30.0
        motionManager.startDeviceMotionUpdates(using: .xMagneticNorthZVertical, to: .main) { [weak self] (motionData, error) in
            guard let self = self, let data = motionData else { return }
            
            let pitchDegrees = data.attitude.pitch * (180.0 / .pi)
            
            DispatchQueue.main.async {
                self.altitudeTilt = pitchDegrees
                
                // If gravity.z drops below -0.1 while tilted down, the phone is pointing at your shoes
                if data.gravity.z < -0.1 && pitchDegrees < 15.0 {
                    self.isPointingBelowHorizon = true
                } else {
                    self.isPointingBelowHorizon = false
                }
            }
        }
    }
    
    func disengageSensorStreaming() {
        motionManager.stopDeviceMotionUpdates()
        self.isPointingBelowHorizon = false
    }
}
