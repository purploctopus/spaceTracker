//
//  SkyMotionManager.swift
//  spaceTracker
//
//  Created by Ben Clary on 8/14/26.
//  MAKE AN APP COLIN LOVES AND ENABLES SARA'S FREEDOM!
//
//  ARCHITECTURE CHANGE: Live Sky mode used to run this alongside a full ARKit world-tracking
//  session (see SkyViewportARView.swift), with this file only ever contributing a single
//  one-shot heading sample that got frozen for the rest of the session while ARKit's own
//  gyro/visual tracking took over. That two-system split is where most of this feature's bugs
//  came from: a timing mismatch between when the heading was captured and when the AR session
//  actually started, then (once that was fixed) a sign error in how the frozen heading got
//  applied, and finally residual pointing error that no one-shot capture could ever fully
//  correct for, because raw magnetometer readings just aren't reliably accurate to much
//  better than 5-15 degrees on a real phone (see the "sync to a known object" feature this
//  shipped alongside, which exists precisely because that hardware limit is real and
//  irreducible in software).
//
//  ARKit is gone now (see SkyViewportARView.swift's header comment for why -- it was never
//  actually useful here, since nothing in this feature is anchored to real-world position,
//  only direction). This file is now the ONLY thing driving the sky dome's orientation: a
//  single continuous CMDeviceMotion stream, north-referenced, publishing both heading and
//  tilt every frame for as long as Live Sky mode is open. There is no "capture once and
//  freeze" step anymore -- the camera always reflects whatever the phone is actually doing
//  right now, which means there's nothing for it to fall out of sync with over time, and it
//  works identically whether the sky is visible or not: day or night, indoors or out.

import Foundation
import CoreMotion
import CoreLocation
import Combine

class SkyMotionManager: ObservableObject {
    private let motionManager = CMMotionManager()
    
    /// Raw CMAttitude pitch in degrees -- 0 when the device lies flat on a table, 90 when
    /// held upright/vertical. Drives the "VIEWPORT TILT PITCH" HUD readout directly, and (via
    /// SkyViewportARViewContainer.pitchDegrees) the camera's own tilt. Kept under its
    /// original name so the HUD call site didn't need to change. This was never part of any
    /// jitter/alignment bug -- it comes purely from gravity (accelerometer) and the
    /// gyroscope, with no compass/magnetometer involvement at all, so it's always been
    /// trustworthy on its own.
    @Published var currentAltitude: Double = 0.0
    
    /// Continuously-updated compass heading in degrees (0-360), true- or magnetic-north
    /// referenced depending on location authorization (see engageSensorStreaming). Lightly
    /// smoothed over a short rolling window (see recentHeadingSamples below) to iron out
    /// ordinary magnetometer sample noise -- Core Motion's own sensor fusion already does
    /// most of this, but since this value now feeds the camera directly every frame (instead
    /// of ARKit mediating it), a small extra guard against jitter costs nothing and is worth
    /// keeping.
    @Published var currentHeadingDegrees: Double = 0.0
    
    /// False until the first valid heading sample arrives. LiveSkyViewfinderOverlay's
    /// stabilization veil waits on this instead of a fixed timer or a one-shot capture
    /// completion -- there's no "capture" step to wait on anymore, just "has a real reading
    /// come in yet."
    @Published var isHeadingAvailable = false
    
    private var recentHeadingSamples: [Double] = []
    private let smoothingWindowSize = 5
    
    func engageSensorStreaming() {
        guard motionManager.isDeviceMotionAvailable else { return }
        
        // .xTrueNorthZVertical requires location access so Core Motion can calculate the
        // difference between magnetic and true north (this is Core Motion's own documented
        // requirement, not a guess) -- fall back to magnetic north rather than fail outright
        // if that isn't available. A few degrees of declination error is a much smaller
        // problem than the sky dome never getting aligned at all, and the sync-to-object
        // feature can absorb it either way.
        let status = CLLocationManager().authorizationStatus
        let locationAuthorized = status == .authorizedWhenInUse || status == .authorizedAlways
        let referenceFrame: CMAttitudeReferenceFrame = locationAuthorized ? .xTrueNorthZVertical : .xMagneticNorthZVertical
        
        motionManager.deviceMotionUpdateInterval = 1.0 / 60.0
        motionManager.startDeviceMotionUpdates(using: referenceFrame, to: .main) { [weak self] motionData, _ in
            guard let self, let data = motionData else { return }
            
            self.currentAltitude = data.attitude.pitch * (180.0 / .pi)
            
            // heading is documented to come back negative specifically to mean "invalid"
            // (rather than something that needs +360 wraparound) -- skip those samples
            // instead of folding them into the smoothed value.
            let heading = data.heading
            guard heading >= 0 else { return }
            
            self.recentHeadingSamples.append(heading)
            if self.recentHeadingSamples.count > self.smoothingWindowSize {
                self.recentHeadingSamples.removeFirst()
            }
            self.currentHeadingDegrees = Self.circularMeanDegrees(self.recentHeadingSamples)
            self.isHeadingAvailable = true
        }
    }
    
    func disengageSensorStreaming() {
        motionManager.stopDeviceMotionUpdates()
        recentHeadingSamples.removeAll()
        isHeadingAvailable = false
    }
    
    /// Plain averaging breaks across the 0°/360° seam (359° and 1° should average to 0°, not
    /// 180°) -- averaging each sample's sine/cosine components instead is immune to wherever
    /// that seam happens to land.
    private static func circularMeanDegrees(_ degrees: [Double]) -> Double {
        guard !degrees.isEmpty else { return 0 }
        let radians = degrees.map { $0 * .pi / 180.0 }
        let sumSin = radians.reduce(0.0) { $0 + sin($1) }
        let sumCos = radians.reduce(0.0) { $0 + cos($1) }
        var mean = atan2(sumSin, sumCos) * (180.0 / .pi)
        if mean < 0 { mean += 360.0 }
        return mean
    }
}
