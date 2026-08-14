//
//  SkyMotionManager.swift
//  spaceTracker
//
//  Created by Ben Clary on 8/14/26.
//  MAKE AN APP COLIN LOVES AND ENABLES SARA'S FREEDOM!

import Foundation
import CoreMotion
import Combine

// MARK: - 🎯 COMPACT VIEWPORT PLOT MODEL
struct ViewportMappedObject: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let classification: String
    let screenX: CGFloat
    let screenY: CGFloat
    let isPrimaryLock: Bool
}

// ==============================================================================
// 📡 STABILIZED CONTINUOUS PANORAMIC MOTION TRACKING ENGINE
// ==============================================================================
class SkyMotionManager: ObservableObject {
    private let motionManager = CMMotionManager()
    private let calculationQueue = DispatchQueue(label: "com.orbitlog.skyfinder.math", qos: .userInteractive)
    
    @Published var azimuthHeading: Double = 0.0
    @Published var altitudeTilt: Double = 0.0
    @Published var isSensorActive: Bool = false
    
    // UI tracking flag to trigger human-readable guidance overlays
    @Published var isPointingBelowHorizon: Bool = false
    
    var activeCelestialSkyCatalog: [APIPlanetItem] = []
    
    @Published var currentLockedTarget: TargetLockMatch? = nil
    @Published var currentlyVisibleInViewport: [ViewportMappedObject] = []
    
    private var filteredAzimuth: Double = 0.0
    private var filteredAltitude: Double = 0.0
    private var isFirstSensorRun: Bool = true
    
    func engageSensorStreaming(with targets: [APIPlanetItem]) {
        self.activeCelestialSkyCatalog = targets
        self.isFirstSensorRun = true
        
        guard motionManager.isDeviceMotionAvailable else { return }
        
        motionManager.deviceMotionUpdateInterval = 1.0 / 30.0
        motionManager.startDeviceMotionUpdates(using: .xMagneticNorthZVertical, to: .main) { [weak self] (motionData, error) in
            guard let self = self, let data = motionData else { return }
            
            // ==============================================================================
            // 🛡️ THE ACCURATE FLIPPED GRAVITY GATE
            // ==============================================================================
            // 💡 FIXED: Changed to less-than (< -0.1).
            // When the phone faces down toward the ground, gravity pulls out the back lens,
            // pushing the Z vector negative. This catches the ground dip perfectly!
            if data.gravity.z < -0.1 {
                DispatchQueue.main.async {
                    self.isPointingBelowHorizon = true
                    self.currentlyVisibleInViewport = []
                    self.currentLockedTarget = nil
                }
                return // Freeze tracking loop instantly BEFORE the heading compass can glitch flip!
            }
            
            // Native device orientation tracking outputs
            let pitchDegrees = data.attitude.pitch * (180.0 / .pi)
            var yawDegrees = -data.attitude.yaw * (180.0 / .pi)
            if yawDegrees < 0 { yawDegrees += 360.0 }
            
            // Strong dampening shock absorber factor to iron out any hand trembles
            let filterFactor: Double = 0.06
            
            if self.isFirstSensorRun {
                self.filteredAzimuth = yawDegrees
                self.filteredAltitude = pitchDegrees
                self.isFirstSensorRun = false
            } else {
                var azDelta = yawDegrees - self.filteredAzimuth
                if azDelta > 180.0 { azDelta -= 360.0 }
                if azDelta < -180.0 { azDelta += 360.0 }
                
                self.filteredAzimuth = (self.filteredAzimuth + azDelta * filterFactor).truncatingRemainder(dividingBy: 360.0)
                if self.filteredAzimuth < 0 { self.filteredAzimuth += 360.0 }
                
                self.filteredAltitude = self.filteredAltitude + (pitchDegrees - self.filteredAltitude) * filterFactor
            }
            
            self.azimuthHeading = self.filteredAzimuth
            self.altitudeTilt = self.filteredAltitude
            self.isPointingBelowHorizon = false
            self.isSensorActive = true
            
            self.calculationQueue.async {
                self.evaluateTargetLockOns(currentAz: self.filteredAzimuth, currentAlt: self.filteredAltitude)
            }
        }
    }
    
    private func evaluateTargetLockOns(currentAz: Double, currentAlt: Double) {
        var visiblePlots: [ViewportMappedObject] = []
        var primaryLock: TargetLockMatch? = nil
        
        let viewportFOV: Double = 45.0
        let lockRadius: Double = 6.0
        let degreeToPixelMultiplier: CGFloat = 10.0
        
        for planet in activeCelestialSkyCatalog {
            var deltaAz = planet.azimuth - currentAz
            if deltaAz > 180.0 { deltaAz -= 360.0 }
            if deltaAz < -180.0 { deltaAz += 360.0 }
            
            var deltaAlt = planet.altitude - currentAlt
            if deltaAlt > 180.0 { deltaAlt -= 360.0 }
            if deltaAlt < -180.0 { deltaAlt += 360.0 }
            
            if abs(deltaAz) <= viewportFOV && abs(deltaAlt) <= viewportFOV {
                let plotX = CGFloat(deltaAz) * degreeToPixelMultiplier
                let plotY = CGFloat(deltaAlt) * degreeToPixelMultiplier
                
                let isLocked = abs(deltaAz) <= lockRadius && abs(deltaAlt) <= lockRadius
                
                if planet.classification == "PLANET" || planet.nakedEyeObject {
                    visiblePlots.append(ViewportMappedObject(
                        name: planet.name,
                        classification: planet.classification,
                        screenX: plotX,
                        screenY: plotY,
                        isPrimaryLock: isLocked
                    ))
                }
                
                if isLocked && primaryLock == nil {
                    primaryLock = TargetLockMatch(
                        name: planet.name.uppercased(),
                        constellation: planet.constellation.uppercased(),
                        altitude: Int(planet.altitude),
                        azimuth: Int(planet.azimuth)
                    )
                }
            }
        }
        
        DispatchQueue.main.async {
            if self.currentlyVisibleInViewport != visiblePlots {
                self.currentlyVisibleInViewport = visiblePlots
            }
            if self.currentLockedTarget != primaryLock {
                self.currentLockedTarget = primaryLock
            }
        }
    }
    
    func disengageSensorStreaming() {
        motionManager.stopDeviceMotionUpdates()
        self.isSensorActive = false
        self.currentLockedTarget = nil
        self.currentlyVisibleInViewport = []
        self.isPointingBelowHorizon = false
    }
}
