//
//  SkyViewportARView.swift
//  spaceTracker
//
//  Created by Ben Clary on 8/24/26.
//  Yet another file but i hope this is the one that frees everyone of stress and makes an app colin loves

import SwiftUI
import ARKit
import SceneKit

// ==============================================================================
// 🪐 SPATIAL AR MASTER ENGINE (DIRECT ANGLE ROTATION HOOK WITH RE-INJECTED LOGS)
// ==============================================================================
class SkyViewportARView: UIView {
    let arView = ARSCNView()
    /// Kept as a property (not just a local in populateARSkyDome) so applyHeadingOffset
    /// below can rotate the whole dome after the fact, once SkyMotionManager's one-shot
    /// true-heading capture completes -- see that file's header comment for why this
    /// replaced the old continuous-compass jitter.
    private var celestialSphereNode: SCNNode?
    
    init(celestialCatalog: [APIPlanetItem]) {
        super.init(frame: .zero)
        
        arView.backgroundColor = .black
        arView.scene.background.contents = UIColor.black
        arView.antialiasingMode = .multisampling4X
        arView.automaticallyUpdatesLighting = false
        
        let configuration = ARWorldTrackingConfiguration()
        // BUG FIX: was .gravityAndHeading, which keeps ARKit's own world orientation tied to
        // a *continuous* live magnetometer reading for as long as the session runs -- any
        // magnetic interference (a desk, nearby electronics, an iPad's own magnetic
        // case/keyboard/Pencil) directly wobbled the whole scene, even at rest. .gravity
        // uses only gravity (accelerometer) plus ARKit's gyro/visual tracking -- no ongoing
        // compass input at all. The one-time north alignment .gravity gives up is restored
        // separately via applyHeadingOffset(degrees:), called once real-world heading is
        // known (see SkyMotionManager.captureInitialTrueHeading).
        configuration.worldAlignment = .gravity
        
        arView.frame = self.bounds
        arView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        self.addSubview(arView)
        
        populateARSkyDome(catalog: celestialCatalog, inside: arView.scene)
        arView.session.run(configuration)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        arView.frame = self.bounds
    }
    
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    /// Applies the ONE-TIME true-north alignment captured by
    /// SkyMotionManager.captureInitialTrueHeading, rotating the whole sky dome to match the
    /// compass bearing the device actually faced when the AR session started -- needed now
    /// that worldAlignment is .gravity, which (unlike .gravityAndHeading) has no absolute
    /// heading reference of its own. Safe to call more than once; each call just re-sets the
    /// same absolute rotation, it doesn't accumulate.
    func applyHeadingOffset(degrees: Double) {
        let radians = Float(degrees * .pi / 180.0)
        // Same sign convention as each individual object's own yaw below (-azRad) -- negating
        // here makes a sphere-wide offset behave exactly like an object-level azimuth would.
        celestialSphereNode?.eulerAngles.y = -radians
    }
    
    private func populateARSkyDome(catalog: [APIPlanetItem], inside scene: SCNScene) {
        let domeRadius: Float = 25.0
        
        let celestialSphereNode = SCNNode()
        celestialSphereNode.name = "CELESTIAL_SPHERE_SHELL"
        scene.rootNode.addChildNode(celestialSphereNode)
        self.celestialSphereNode = celestialSphereNode
        
        // 🔬 MANDATORY FORENSIC GRAPHICS PRINTS - PERMANENTLY RETAINED AND RESTORED
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("🖥️ [AR GRAPHICS PIPELINE] PLOTTING TELEMETRY VIA PURE EULER ANGLES")
        
        for object in catalog {
            // Convert clean input model degrees directly to standard rotation radians
            let azRad = Float(object.azimuth) * .pi / 180.0
            let altRad = Float(object.altitude) * .pi / 180.0
            
            // 📐 PURE 1:1 ANGLE MOUNT:
            // Stop converting angles to 3D Cartesian coordinates! We position a baseline node
            // pointing forward on the North horizon line, then pivot its parent shell by your exact angles.
            let targetAnchorNode = SCNNode()
            
            let isPlanet = object.classification == "PLANET"
            let isMoon = object.classification == "MOON"
            let isMajorLabelBody = isPlanet || isMoon || (!object.name.contains("HIP") && object.nakedEyeObject)
            
            // 💡 THE SYNTAX CORRECTION: Cleaned out the double text block typo identifier!
            let xLogVal = domeRadius * sin(azRad) * cos(altRad)
            let yLogVal = domeRadius * sin(altRad)
            let zLogVal = -domeRadius * cos(azRad) * cos(altRad)
            
            if isMoon {
                print("   🌙 PLOTTING MOON")
                print("      ├─> Input Math Model : ALT: \(String(format: "%.2f°", object.altitude)) | AZ: \(String(format: "%.2f°", object.azimuth))")
                print("      └─> SCN Graphic Node : X: \(String(format: "%.3f", xLogVal)) | Y: \(String(format: "%.3f", yLogVal)) | Z: \(String(format: "%.3f", zLogVal))")
            } else if isPlanet {
                print("   🌐 PLOTTING PLANET: \(object.name)")
                print("      ├─> Input Math Model : ALT: \(String(format: "%.2f°", object.altitude)) | AZ: \(String(format: "%.2f°", object.azimuth))")
                print("      └─> SCN Graphic Node : X: \(String(format: "%.3f", xLogVal)) | Y: \(String(format: "%.3f", yLogVal)) | Z: \(String(format: "%.3f", zLogVal))")
            }
            
            // The Moon gets the most prominent treatment of anything in the sky dome — bigger
            // than a planet dot and a warm pale-white "moonlight" color rather than reusing
            // planet cyan, since it's not really in the same visual "category" as the planets.
            let dotGeometry: SCNSphere
            let bodyColor: UIColor
            if isMoon {
                dotGeometry = SCNSphere(radius: 0.14)
                bodyColor = UIColor(red: 0.96, green: 0.96, blue: 0.88, alpha: 1.0)
            } else if isPlanet {
                dotGeometry = SCNSphere(radius: 0.09)
                bodyColor = .cyan
            } else {
                dotGeometry = SCNSphere(radius: object.nakedEyeObject ? 0.03 : 0.015)
                bodyColor = .white
            }
            dotGeometry.firstMaterial?.diffuse.contents = bodyColor
            dotGeometry.firstMaterial?.emission.contents = isMoon || isPlanet ? bodyColor : bodyColor.withAlphaComponent(0.5)
            
            let visualDotMeshNode = SCNNode(geometry: dotGeometry)
            visualDotMeshNode.position = SCNVector3(0, 0, -domeRadius) // Position forward on the radius boundary
            targetAnchorNode.addChildNode(visualDotMeshNode)
            
            // Apply raw calculated angles directly to the node axes.
            // X-Axis controls Altitude (Pitch), Y-Axis controls Azimuth (Yaw).
            // Inverting the azimuth heading matches ARKit's native counter-clockwise rotation pass.
            targetAnchorNode.eulerAngles = SCNVector3(altRad, -azRad, 0)
            
            // Tag the inner mesh node with structural metadata packets for the raycast picker sights
            let metadata = ARNodeMetadataPacket(
                name: object.name,
                classification: object.classification,
                constellation: object.constellation,
                altitude: object.altitude,
                azimuth: object.azimuth,
                magnitude: object.magnitude,
                distanceAU: object.range_au
            )
            visualDotMeshNode.setValue(metadata, forKey: "celestial_packet")
            
            if isMajorLabelBody {
                visualDotMeshNode.setValue(true, forKey: "hasPermanentLabel")
            }
            
            celestialSphereNode.addChildNode(targetAnchorNode)
        }
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    }
}

// ==============================================================================
// 🔌 SWIFTUI REPRESENTABLE CONTAINER (THREAD-SAFE SPATIAL RAYCASTER)
// ==============================================================================
struct SkyViewportARViewContainer: UIViewRepresentable {
    let celestialCatalog: [APIPlanetItem]
    @Binding var projectedScreenPlots: [ScreenProjectedObject]
    @Binding var currentCrosshairTarget: TargetLockMatch?
    /// Nil until SkyMotionManager.captureInitialTrueHeading finishes its one-shot sample;
    /// applied to the AR dome the moment it arrives (see makeUIView/updateUIView below).
    var headingOffsetDegrees: Double?
    /// Set from Coordinator.session(_:cameraDidChangeTrackingState:) so the SwiftUI layer
    /// can tell the user when ARKit's own visual tracking has degraded (e.g. pointed at a
    /// featureless patch of sky/ceiling with nothing for it to visually lock onto) instead
    /// of silently drifting with no explanation.
    @Binding var trackingStatusMessage: String?
    
    /// The actual measured center of the on-screen reticle ring, in the same coordinate
    /// space as `arView.projectPoint(_:)` output (i.e. the AR view's own top-left-origin
    /// screen space). Supplied by the SwiftUI parent via a GeometryReader on the reticle
    /// itself, so lock detection always targets exactly where the ring is drawn — never a
    /// guessed offset, and never `UIScreen.main.bounds`, which doesn't reflect the actual
    /// view size in multitasking / Split View / Slide Over on iPad.
    var reticleCenter: CGPoint
    
    func makeUIView(context: Context) -> SkyViewportARView {
        let view = SkyViewportARView(celestialCatalog: celestialCatalog)
        // Setting .delegate alone is sufficient -- ARSCNViewDelegate inherits from
        // ARSessionObserver and ARSCNView forwards session-status callbacks (tracking
        // state, interruptions, etc.) to it automatically. Separately assigning
        // view.arView.session.delegate would risk stepping on whatever ARSCNView's own
        // internals rely on that property for -- deliberately not doing that here.
        view.arView.delegate = context.coordinator
        context.coordinator.reticleCenter = reticleCenter
        if let headingOffsetDegrees {
            view.applyHeadingOffset(degrees: headingOffsetDegrees)
        }
        return view
    }
    
    func updateUIView(_ uiView: SkyViewportARView, context: Context) {
        context.coordinator.reticleCenter = reticleCenter
        context.coordinator.parent = self
        if let headingOffsetDegrees {
            uiView.applyHeadingOffset(degrees: headingOffsetDegrees)
        }
    }
    
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    
    class Coordinator: NSObject, ARSCNViewDelegate {
        var parent: SkyViewportARViewContainer
        var reticleCenter: CGPoint
        
        init(_ parent: SkyViewportARViewContainer) {
            self.parent = parent
            self.reticleCenter = parent.reticleCenter
        }
        
        // ARSCNViewDelegate inherits from ARSessionObserver, which declares this --
        // ARSCNView forwards it here automatically since this Coordinator is set as
        // arView.delegate (see makeUIView), no separate session.delegate assignment
        // needed. Surfaces ARKit's own read on tracking quality (e.g. pointed at a
        // blank ceiling/sky with nothing visually distinctive to lock onto -- one of the
        // worst-case scenes for camera-based tracking) instead of leaving the jitter/drift
        // that produces unexplained on screen.
        func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
            let message: String?
            switch camera.trackingState {
            case .normal:
                message = nil
            case .notAvailable:
                message = "TRACKING UNAVAILABLE"
            case .limited(.initializing):
                // Already covered by the app's own stabilization veil right after this view
                // appears -- no need for a second, redundant "loading" message here.
                message = nil
            case .limited(.relocalizing):
                message = "RELOCALIZING…"
            case .limited(.excessiveMotion):
                message = "HOLD STEADY"
            case .limited(.insufficientFeatures):
                message = "POINT AT A MORE DETAILED AREA TO STABILIZE"
            @unknown default:
                message = nil
            }
            DispatchQueue.main.async { [weak self] in
                self?.parent.trackingStatusMessage = message
            }
        }
        
        func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
            guard let arView = renderer as? ARSCNView else { return }
            
            var temporaryPlots: [ScreenProjectedObject] = []
            var activeLockNode: SCNNode? = nil
            var closestDistance: Float = Float.infinity
            
            let targetCenterPoint = self.reticleCenter
            
            guard let sphereContainer = arView.scene.rootNode.childNode(withName: "CELESTIAL_SPHERE_SHELL", recursively: true) else { return }
            
            sphereContainer.enumerateChildNodes { (parentNode, _) in
                // Intercept the visual dot nodes sitting inside the rotated parent shells
                parentNode.enumerateChildNodes { (node, _) in
                    guard let packet = node.value(forKey: "celestial_packet") as? ARNodeMetadataPacket else { return }
                    
                    let worldPosition = node.worldPosition
                    let screenPoint = arView.projectPoint(worldPosition)
                    
                    if screenPoint.z > 0 && screenPoint.z < 1.0 {
                        let screenX = CGFloat(screenPoint.x)
                        let screenY = CGFloat(screenPoint.y)
                        
                        if node.value(forKey: "hasPermanentLabel") as? Bool == true {
                            temporaryPlots.append(ScreenProjectedObject(
                                name: packet.name,
                                classification: packet.classification,
                                x: screenX,
                                y: screenY
                            ))
                        }
                        
                        let dx = Float(screenX - targetCenterPoint.x)
                        let dy = Float(screenY - targetCenterPoint.y)
                        let distanceToCenter = sqrt(dx*dx + dy*dy)
                        
                        if distanceToCenter < 35.0 && distanceToCenter < closestDistance {
                            closestDistance = distanceToCenter
                            activeLockNode = node
                        }
                    }
                }
            }
            
            DispatchQueue.main.async {
                self.parent.projectedScreenPlots = temporaryPlots
                
                if let lockNode = activeLockNode, let packet = lockNode.value(forKey: "celestial_packet") as? ARNodeMetadataPacket {
                    self.parent.currentCrosshairTarget = TargetLockMatch(
                        name: packet.name.uppercased(),
                        constellation: packet.constellation.uppercased(),
                        altitude: packet.altitude,
                        azimuth: packet.azimuth,
                        magnitude: packet.magnitude,
                        distanceAU: packet.distanceAU
                    )
                } else {
                    self.parent.currentCrosshairTarget = nil
                }
            }
        }
    }
}

// ==============================================================================
// 📦 SHARED DATATYPE SCHEMAS (DECLARED GLOBAL SCOPE)
// ==============================================================================
class ARNodeMetadataPacket: NSObject {
    let name: String
    let classification: String
    let constellation: String
    let altitude: Double
    let azimuth: Double
    let magnitude: Double?
    let distanceAU: Double?
    
    init(name: String, classification: String, constellation: String, altitude: Double, azimuth: Double, magnitude: Double?, distanceAU: Double?) {
        self.name = name
        self.classification = classification
        self.constellation = constellation
        self.altitude = altitude
        self.azimuth = azimuth
        self.magnitude = magnitude
        self.distanceAU = distanceAU
        super.init()
    }
}

struct ScreenProjectedObject: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let classification: String
    let x: CGFloat
    let y: CGFloat
}

struct TargetLockMatch: Identifiable, Equatable {
    // Content-based identity — NOT a fresh UUID(). This struct gets rebuilt on every AR
    // frame (~60Hz) via Coordinator.renderer, including frames where the crosshair is still
    // locked on the exact same object. A random per-init UUID would make every single frame
    // look like "a new lock" to SwiftUI, defeating Equatable-based diffing/animations that
    // key off this type (e.g. the fade transition on the live info readout).
    var id: String { name }
    let name: String
    let constellation: String
    let altitude: Double
    let azimuth: Double
    let magnitude: Double?
    let distanceAU: Double?
}
