//
//  SkyMotionManager.swift
//  spaceTracker
//
//  Created by Ben Clary on 8/14/26.
//  MAKE AN APP COLIN LOVES AND ENABLES SARA'S FREEDOM!

import Foundation
import CoreMotion
import Combine

class SkyMotionManager: ObservableObject {
    private let motionManager = CMMotionManager()
    
    // 💡 CLEAN UN-DRIFTED VARIABLES:
    @Published var currentAltitude: Double = 0.0
    @Published var currentAzimuth: Double = 0.0
    @Published var isPointingBelowHorizon: Bool = false
    
    func engageSensorStreaming(with targets: [APIPlanetItem]) {
        guard motionManager.isDeviceMotionAvailable else { return }
        
        motionManager.deviceMotionUpdateInterval = 1.0 / 60.0 // 60Hz high-frequency streaming
        
        // Using high-precision attitude reference grids with magnetic yaw correction layers
        motionManager.startDeviceMotionUpdates(using: .xMagneticNorthZVertical, to: .main) { [weak self] (motionData, error) in
            guard let self = self, let data = motionData else { return }
            
            // Extracts simple 3D pitch angles relative to your portrait camera view glass axis
            let pitchDegrees = data.attitude.pitch * (180.0 / .pi)
            
            // Extract a clean 0 to 360 degree compass bearing clockwise from North
            var compassHeading = data.heading
            if compassHeading < 0 { compassHeading += 360.0 }
            
            DispatchQueue.main.async {
                self.currentAltitude = pitchDegrees
                self.currentAzimuth = compassHeading
                
                if pitchDegrees < -2.0 {
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
