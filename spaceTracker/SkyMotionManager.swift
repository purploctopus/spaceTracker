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
//  ONCE using a heading sample captured here. After that one-time alignment, ARKit's own
//  gyro/visual tracking -- not the magnetometer -- holds the scene steady.
//
//  FOLLOW-UP FIX: the first version of this fix averaged a blind fixed time window right
//  as the view appeared, which is exactly while the user is still raising/aiming the phone
//  -- and separately, SkyViewportARView started its AR session immediately on creation,
//  before that average had even finished. .gravity alignment anchors its zero-orientation
//  reference to whichever direction the device faces at the exact moment session.run() is
//  called, so those two moments need to refer to the same instant; they didn't, which
//  produced an alignment error that also changed from launch to launch (whatever motion was
//  in progress each time happened to differ). Fixed by waiting for the device to actually
//  settle before trusting a heading sample (see captureInitialTrueHeading below), and by
//  SkyViewportARView deferring session.run() until that settled heading is in hand -- see
//  SkyViewportARView.beginTracking(initialHeadingDegrees:).

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

    /// Captures ONE heading value -- not a stream -- for SkyViewportARView to rotate its
    /// celestial sphere by exactly once, right before its AR session actually starts (see
    /// SkyViewportARView.beginTracking(initialHeadingDegrees:) -- the two are deliberately
    /// coupled, see that method's doc comment for why).
    ///
    /// BUG FIX: this used to just average a fixed 0.6s window of samples unconditionally.
    /// But this fires the moment Live Sky mode opens, while the user is very likely still
    /// raising/aiming the phone -- averaging blindly through that motion captured whatever
    /// direction they happened to be sweeping through, not where they actually ended up
    /// pointing, which is exactly why the sky came out rotated to some arbitrary-seeming
    /// offset that also differed between launches (different motion each time the view
    /// opened). Now it waits for the device's rotation rate to actually settle down before
    /// trusting any samples, with a capped max wait so a shaky hand can't hang the sky map
    /// forever.
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

        // Tuning: requiredStableSamples * update interval is roughly how long the device
        // must sit still before its heading is trusted (~0.27s at 30Hz); rotationRate is in
        // rad/s, so 0.12 is a gentle hand tremor, not a real aiming movement. maxWait is the
        // hard ceiling if the user just can't hold it still -- falls back to whatever's been
        // sampled so far rather than hanging indefinitely.
        let stabilityThreshold = 0.12
        let requiredStableSamples = 8
        let maxWait: TimeInterval = 3.0
        let startTime = Date()

        var stableRun: [Double] = []
        var allSamples: [Double] = []
        var didComplete = false

        headingCaptureManager.deviceMotionUpdateInterval = 1.0 / 30.0
        headingCaptureManager.startDeviceMotionUpdates(using: referenceFrame, to: .main) { [weak self] motionData, _ in
            guard let self, !didComplete, let data = motionData else { return }
            // heading is documented to come back negative specifically to mean "invalid"
            // (rather than something that needs +360 wraparound) -- skip those samples
            // instead of folding them into the average.
            let heading = data.heading
            if heading >= 0 {
                allSamples.append(heading)
                if allSamples.count > 90 { allSamples.removeFirst() }

                let rotationMagnitude = sqrt(
                    data.rotationRate.x * data.rotationRate.x +
                    data.rotationRate.y * data.rotationRate.y +
                    data.rotationRate.z * data.rotationRate.z
                )
                if rotationMagnitude < stabilityThreshold {
                    stableRun.append(heading)
                } else {
                    stableRun.removeAll()
                }
            }

            let isStable = stableRun.count >= requiredStableSamples
            let timedOut = Date().timeIntervalSince(startTime) >= maxWait
            guard isStable || timedOut else { return }

            didComplete = true
            self.headingCaptureManager.stopDeviceMotionUpdates()
            let finalSamples = isStable ? stableRun : allSamples
            completion(Self.circularMeanDegrees(finalSamples))
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
