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
// 📡 JITTER-FREE ULTRA FLUID TELEMETRY MOTION TRACKING ENGINE
// ==============================================================================
class SkyMotionManager: ObservableObject {
    private let motionManager = CMMotionManager()
    private let calculationQueue = DispatchQueue(label: "com.orbitlog.skyfinder.math", qos: .userInteractive)
    
    @Published var azimuthHeading: Double = 0.0
    @Published var altitudeTilt: Double = 0.0
    @Published var isSensorActive: Bool = false
    
    var activeCelestialSkyCatalog: [APIPlanetItem] = []
    
    @Published var currentLockedTarget: TargetLockMatch? = nil
    @Published var currentlyVisibleInViewport: [ViewportMappedObject] = []
    
    // Low-Pass Filter history buffers to kill noise vibrations
    private var filteredAzimuth: Double = 0.0
    private var filteredAltitude: Double = 0.0
    private var isFirstSensorRun: Bool = true
    
    func engageSensorStreaming(with targets: [APIPlanetItem]) {
        self.activeCelestialSkyCatalog = targets
        self.isFirstSensorRun = true
        
        guard motionManager.isDeviceMotionAvailable else { return }
        
        // Polling loop execution matching your screen's presentation speed
        motionManager.deviceMotionUpdateInterval = 1.0 / 30.0
        motionManager.startDeviceMotionUpdates(using: .xMagneticNorthZVertical, to: .main) { [weak self] (motionData, error) in
            guard let self = self, let data = motionData else { return }
            
            let rawPitch = data.attitude.pitch * (180.0 / .pi)
            var rawYaw = -data.attitude.yaw * (180.0 / .pi)
            if rawYaw < 0 { rawYaw += 360.0 }
            
            // 💡 JITTER MITIGATION FILTER (LOW-PASS): Smooths out hand tremors
            let filterFactor: Double = 0.06 // Dampening stiffness constant (Lower = Smoother, Higher = Faster response)
            
            if self.isFirstSensorRun {
                self.filteredAzimuth = rawYaw
                self.filteredAltitude = rawPitch
                self.isFirstSensorRun = false
            } else {
                // Smoothly interpolate around the standard 360 degree compass boundary ring
                var azDelta = rawYaw - self.filteredAzimuth
                if azDelta > 180.0 { azDelta -= 360.0 }
                if azDelta < -180.0 { azDelta += 360.0 }
                
                self.filteredAzimuth = (self.filteredAzimuth + azDelta * filterFactor).truncatingRemainder(dividingBy: 360.0)
                if self.filteredAzimuth < 0 { self.filteredAzimuth += 360.0 }
                
                self.filteredAltitude = self.filteredAltitude + (rawPitch - self.filteredAltitude) * filterFactor
            }
            
            // Push filtered metrics directly to the interface
            self.azimuthHeading = self.filteredAzimuth
            self.altitudeTilt = self.filteredAltitude
            self.isSensorActive = true
            
            // Offload targeting calculations to the private thread
            self.calculationQueue.async {
                self.evaluateTargetLockOns(currentAz: self.filteredAzimuth, currentAlt: self.filteredAltitude)
            }
        }
    }
    
    private func evaluateTargetLockOns(currentAz: Double, currentAlt: Double) {
        var visiblePlots: [ViewportMappedObject] = []
        var primaryLock: TargetLockMatch? = nil
        
        let viewportFOV: Double = 35.0
        let lockRadius: Double = 6.0
        let degreeToPixelMultiplier: CGFloat = 8.0
        
        for planet in activeCelestialSkyCatalog {
            let azimuthDelta = planet.azimuth - currentAz
            var normalizedAzDelta = azimuthDelta
            if normalizedAzDelta > 180.0 { normalizedAzDelta -= 360.0 }
            if normalizedAzDelta < -180.0 { normalizedAzDelta += 360.0 }
            
            let altitudeDelta = planet.altitude - currentAlt
            
            if abs(normalizedAzDelta) <= viewportFOV && abs(altitudeDelta) <= viewportFOV {
                let isLocked = abs(normalizedAzDelta) <= lockRadius && abs(altitudeDelta) <= lockRadius
                let plotX = CGFloat(normalizedAzDelta) * degreeToPixelMultiplier
                let plotY = CGFloat(-altitudeDelta) * degreeToPixelMultiplier
                
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
    }
}
