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
//
//  FOLLOW-UP FIX: the first version of this rewrite smoothed heading over a tiny 5-sample
//  rolling window (~80ms at 60Hz) before handing it straight to the camera every frame. That
//  is nowhere near enough damping for raw magnetometer output -- with ARKit gone, nothing was
//  left to absorb ordinary compass noise the way ARKit's own visual-inertial fusion used to
//  (it wasn't only smoothing position; it was also cross-checking rotation against the gyro
//  and visual features, which damps compass jitter far more than a short average can). The
//  result was the sky visibly jumping around even with the phone dead still on a desk --
//  worse than the ORIGINAL .gravityAndHeading jitter bug this whole rewrite exists to fix,
//  because at least ARKit was damping that. Fixed with a proper exponential moving average
//  (see smoothedHeadingSin/Cos and smoothedPitch below) instead of a fixed window: it reacts
//  quickly to real movement but heavily damps frame-to-frame sensor noise, the same category
//  of filter real compass apps use. The smoothing constants below are a first reasonable
//  pass, not something verified on a real device -- they may need tuning.

import Foundation
import CoreMotion
import CoreLocation
import Combine

class SkyMotionManager: ObservableObject {
    private let motionManager = CMMotionManager()
    
    /// Filtered pitch in degrees -- 0 when the device lies flat on a table, 90 when held
    /// upright/vertical. Drives the "VIEWPORT TILT PITCH" HUD readout directly, and (via
    /// SkyViewportARViewContainer.pitchDegrees) the camera's own tilt. Kept under its
    /// original name so the HUD call site didn't need to change. This axis was never part of
    /// the original jitter bug (it's gravity/gyro based, no magnetometer), but now that it
    /// drives continuous 3D rendering every frame instead of an occasionally-glanced-at HUD
    /// number, it gets the same light exponential smoothing as heading as a precaution.
    @Published var currentAltitude: Double = 0.0
    
    /// Continuously-updated, exponentially-smoothed compass heading in degrees (0-360), true-
    /// or magnetic-north referenced depending on location authorization (see
    /// engageSensorStreaming below).
    @Published var currentHeadingDegrees: Double = 0.0
    
    /// False until the first valid heading sample arrives. LiveSkyViewfinderOverlay's
    /// stabilization veil waits on this instead of a fixed timer or a one-shot capture
    /// completion -- there's no "capture" step to wait on anymore, just "has a real reading
    /// come in yet."
    @Published var isHeadingAvailable = false
    
    // Exponential moving average state. Heading is filtered as sine/cosine components rather
    // than the raw degrees value -- filtering the angle directly breaks across the 0°/360°
    // seam (359° smoothing toward 1° would incorrectly ease through 180° instead of straight
    // across zero); filtering its unit-circle components sidesteps that entirely, the same
    // trick the old fixed-window circular mean used, just applied continuously instead of
    // over a fixed batch of samples.
    private var smoothedHeadingSin: Double?
    private var smoothedHeadingCos: Double?
    private var smoothedPitchDegrees: Double?
    
    // Smoothing factor per update (0-1): lower = smoother but slower to react, higher =
    // snappier but noisier. At the ~60Hz update rate set below, 0.12 works out to roughly an
    // 0.1s time constant -- heavy enough to flatten ordinary compass noise, still well within
    // "feels responsive" for someone panning a phone across the sky. Pitch gets a lighter
    // touch since its underlying sensor (gravity + gyro) was never the noisy one.
    private let headingSmoothingFactor = 0.12
    private let pitchSmoothingFactor = 0.25
    
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
            
            let rawPitch = data.attitude.pitch * (180.0 / .pi)
            if let previousPitch = self.smoothedPitchDegrees {
                self.smoothedPitchDegrees = previousPitch + self.pitchSmoothingFactor * (rawPitch - previousPitch)
            } else {
                self.smoothedPitchDegrees = rawPitch
            }
            self.currentAltitude = self.smoothedPitchDegrees ?? rawPitch
            
            // heading is documented to come back negative specifically to mean "invalid"
            // (rather than something that needs +360 wraparound) -- skip those samples
            // instead of folding them into the smoothed value.
            let heading = data.heading
            guard heading >= 0 else { return }
            
            let headingRadians = heading * .pi / 180.0
            let sample = (sin: sin(headingRadians), cos: cos(headingRadians))
            if let previousSin = self.smoothedHeadingSin, let previousCos = self.smoothedHeadingCos {
                self.smoothedHeadingSin = previousSin + self.headingSmoothingFactor * (sample.sin - previousSin)
                self.smoothedHeadingCos = previousCos + self.headingSmoothingFactor * (sample.cos - previousCos)
            } else {
                self.smoothedHeadingSin = sample.sin
                self.smoothedHeadingCos = sample.cos
            }
            
            var filteredHeading = atan2(self.smoothedHeadingSin ?? sample.sin, self.smoothedHeadingCos ?? sample.cos) * (180.0 / .pi)
            if filteredHeading < 0 { filteredHeading += 360.0 }
            self.currentHeadingDegrees = filteredHeading
            self.isHeadingAvailable = true
        }
    }
    
    func disengageSensorStreaming() {
        motionManager.stopDeviceMotionUpdates()
        smoothedHeadingSin = nil
        smoothedHeadingCos = nil
        smoothedPitchDegrees = nil
        isHeadingAvailable = false
    }
}
