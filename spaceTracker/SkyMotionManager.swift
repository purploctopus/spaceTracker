//
//  SkyMotionManager.swift
//  spaceTracker
//
//  Created by Ben Clary on 8/14/26.
//  MAKE AN APP COLIN LOVES AND ENABLES SARA'S FREEDOM!
//
//  BUG FIX: Live Sky mode was jittery and wouldn't hold still even with the device
//  completely stationary (e.g. resting flat on a desk). Two compounding causes, both
//  rooted in continuously re-reading the magnetometer for heading:
//    1. SkyViewportARView's ARWorldTrackingConfiguration used .gravityAndHeading, which
//       (per Apple's own docs) keeps ARKit's world orientation locked to live "compass
//       heading" for as long as the session runs. Magnetometer readings are noisy and
//       easily disturbed by nearby metal or magnetic fields -- a desk, a laptop, or (very
//       commonly on iPad specifically) a Smart Folio/Magic Keyboard/Pencil's own magnets --
//       so every wobble in that continuous compass feed directly wobbled the whole AR
//       scene, even at rest.
//    2. That heading is also just magnetic north, not true north, while every azimuth in
//       the celestial catalog (StargazerTelemetryModels.swift, via SwiftAA's
//       northBasedAzimuth) is measured from true geographic north -- a systematic offset of
//       however many degrees of local magnetic declination apply, on top of the jitter.
//  Fix: ARKit now uses plain .gravity alignment with no continuous compass input at all
//  (see SkyViewportARView.swift), and the sky dome is aligned to real-world north exactly
//  ONCE, at session start, using a short averaged (and, where location access allows it,
//  declination-corrected) heading sample captured here. After that one-time alignment,
//  ARKit's own gyro/visual tracking -- not the magnetometer -- holds the scene steady.

import Foundation
import CoreMotion
import CoreLocation
import Combine

class SkyMotionManager: ObservableObject {
    /// Drives the continuous "VIEWPORT TILT PITCH" HUD readout. A separate CMMotionManager
    /// instance from headingCaptureManager below -- each one only ever runs a single
    /// reference frame at a time, and pitch streaming needs to keep running independently
    /// of (and outlive) the brief one-shot heading capture.
    private let pitchMotionManager = CMMotionManager()
    /// Used only for the one-shot true-heading sample at session start -- always stopped
    /// right after, so it can never itself become a source of continuous compass jitter.
    private let headingCaptureManager = CMMotionManager()

    @Published var currentAltitude: Double = 0.0

    /// Continuous pitch-only stream. Deliberately uses .xArbitraryZVertical, which has no
    /// compass/magnetometer involvement at all -- pitch comes purely from gravity
    /// (accelerometer) and the gyroscope, so this readout was never actually part of the
    /// jitter bug and doesn't need to change to fix it.
    func engageSensorStreaming() {
        guard pitchMotionManager.isDeviceMotionAvailable else { return }
        pitchMotionManager.deviceMotionUpdateInterval = 1.0 / 30.0
        pitchMotionManager.startDeviceMotionUpdates(using: .xArbitraryZVertical, to: .main) { [weak self] motionData, _ in
            guard let self, let data = motionData else { return }
            let pitchDegrees = data.attitude.pitch * (180.0 / .pi)
            DispatchQueue.main.async {
                self.currentAltitude = pitchDegrees
            }
        }
    }

    func disengageSensorStreaming() {
        pitchMotionManager.stopDeviceMotionUpdates()
    }

    /// Captures ONE averaged heading value -- not a stream -- for SkyViewportARView to
    /// rotate its celestial sphere by exactly once at session start. Averaging over a short
    /// window (rather than trusting a single instantaneous sample) rides out ordinary
    /// magnetometer noise; using true north -- when location access lets Core Motion
    /// correct for local magnetic declination -- matches the true-north convention every
    /// catalog azimuth already uses, instead of leaving the sky dome rotated off by however
    /// many degrees of declination apply at the user's location.
    func captureInitialTrueHeading(completion: @escaping (Double) -> Void) {
        guard headingCaptureManager.isDeviceMotionAvailable else {
            completion(0)
            return
        }

        // .xTrueNorthZVertical requires location access so Core Motion can calculate the
        // difference between magnetic and true north (this is Core Motion's own documented
        // requirement, not a guess) -- fall back to magnetic north rather than fail outright
        // if that isn't available. A few degrees of declination error is a much smaller
        // problem than the sky dome never getting aligned at all.
        let status = CLLocationManager().authorizationStatus
        let locationAuthorized = status == .authorizedWhenInUse || status == .authorizedAlways
        let referenceFrame: CMAttitudeReferenceFrame = locationAuthorized ? .xTrueNorthZVertical : .xMagneticNorthZVertical

        var samples: [Double] = []
        let sampleWindow: TimeInterval = 0.6
        headingCaptureManager.deviceMotionUpdateInterval = 1.0 / 30.0
        headingCaptureManager.startDeviceMotionUpdates(using: referenceFrame, to: .main) { motionData, _ in
            // heading is documented to come back negative specifically to mean "invalid"
            // (rather than something that needs +360 wraparound) -- skip those samples
            // instead of folding them into the average.
            guard let heading = motionData?.heading, heading >= 0 else { return }
            samples.append(heading)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + sampleWindow) { [weak self] in
            self?.headingCaptureManager.stopDeviceMotionUpdates()
            completion(Self.circularMeanDegrees(samples))
        }
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
