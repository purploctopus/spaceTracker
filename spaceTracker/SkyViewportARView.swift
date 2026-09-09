//
//  SkyViewportARView.swift
//  spaceTracker
//
//  Created by Ben Clary on 8/24/26.
//  Yet another file but i hope this is the one that frees everyone of stress and makes an app colin loves
//
//  ARCHITECTURE CHANGE: this used to be an ARSCNView running a full ARKit world-tracking
//  session, with its camera image painted over solid black (see backgroundColor/background
//  below) and never actually shown to the user. That meant we paid ARKit's full cost --
//  camera permission, an active camera feed, on-device visual-inertial tracking -- for a
//  benefit (accurate camera-relative 3D position tracking) this feature never used: nothing
//  here is anchored to real-world surfaces, since the celestial sphere is effectively "at
//  infinity" and only the DIRECTION the phone points ever matters, never its position in the
//  room. Worse, ARKit's visual tracking is weakest exactly when this feature is used most --
//  pointed at a dark night sky, the camera has almost nothing to visually lock onto, which is
//  what caused most of the jitter/drift/alignment bugs this file has been through.
//
//  Now this is a plain (non-AR) SCNView. The camera's rotation is driven every frame directly
//  from SkyMotionManager's continuously-fused compass heading + device tilt (see
//  Coordinator.renderer below) using the exact same azimuth/altitude -> rotation formula as
//  each catalog object's own placement in populateARSkyDome -- pointing the camera AT a
//  bearing is the same geometric operation as placing an object AT that bearing, so both use
//  the identical, already-verified formula. There is no "capture once at session start and
//  freeze" step anymore, so there's nothing for the camera to fall out of sync with over
//  time, and no camera permission is needed at all.

import SwiftUI
import SceneKit

// ==============================================================================
// 🪐 SPATIAL SKY DOME ENGINE (DIRECT ANGLE ROTATION HOOK WITH RE-INJECTED LOGS)
// ==============================================================================
class SkyViewportARView: UIView {
    let scnView = SCNView()
    
    init(celestialCatalog: [APIPlanetItem]) {
        super.init(frame: .zero)
        
        let scene = SCNScene()
        scene.background.contents = UIColor.black
        scnView.scene = scene
        scnView.backgroundColor = .black
        scnView.antialiasingMode = .multisampling4X
        // automaticallyUpdatesLighting was an ARSCNView-only property (it toggles ARKit's
        // camera-image-based light estimation, which needs a live camera feed to estimate
        // from) -- doesn't exist on plain SCNView, and doesn't need a replacement here: every
        // dot's material below sets its own .emission, so it's self-illuminating and doesn't
        // depend on any scene light existing at all.
        
        // The "camera rig" -- a plain SCNNode with an SCNCamera attached, not tied to any
        // ARKit session. Its rotation is set every frame by Coordinator.renderer below, read
        // straight from the phone's live compass + tilt. Named (rather than kept as a stored
        // property here) so the Coordinator -- which owns the per-frame update -- can look it
        // up the same way it already looks up CELESTIAL_SPHERE_SHELL, without this view
        // needing to expose a second public hook for it.
        let cameraNode = SCNNode()
        cameraNode.name = "SKY_CAMERA_RIG"
        cameraNode.camera = SCNCamera()
        scene.rootNode.addChildNode(cameraNode)
        scnView.pointOfView = cameraNode
        
        scnView.frame = self.bounds
        scnView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        self.addSubview(scnView)
        
        populateARSkyDome(catalog: celestialCatalog, inside: scene)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        scnView.frame = self.bounds
    }
    
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    private func populateARSkyDome(catalog: [APIPlanetItem], inside scene: SCNScene) {
        let domeRadius: Float = 25.0
        
        let celestialSphereNode = SCNNode()
        celestialSphereNode.name = "CELESTIAL_SPHERE_SHELL"
        scene.rootNode.addChildNode(celestialSphereNode)
        
        // 🔬 MANDATORY FORENSIC GRAPHICS PRINTS - PERMANENTLY RETAINED AND RESTORED
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("🖥️ [GRAPHICS PIPELINE] PLOTTING TELEMETRY VIA PURE EULER ANGLES")
        
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
    /// Continuously-updated compass heading (already including the user's own sync
    /// correction, if any -- see LiveSkyViewfinderOverlay) and device tilt, applied to the
    /// camera every rendered frame in Coordinator.renderer below. Unlike the old one-shot
    /// capture, there's no "session start" moment for these to fall out of sync with -- the
    /// camera always reflects whatever SkyMotionManager is reading right now.
    var headingDegrees: Double
    var pitchDegrees: Double
    
    /// The actual measured center of the on-screen reticle ring, in the same coordinate
    /// space as `scnView.projectPoint(_:)` output (i.e. the view's own top-left-origin
    /// screen space). Supplied by the SwiftUI parent via a GeometryReader on the reticle
    /// itself, so lock detection always targets exactly where the ring is drawn — never a
    /// guessed offset, and never `UIScreen.main.bounds`, which doesn't reflect the actual
    /// view size in multitasking / Split View / Slide Over on iPad.
    var reticleCenter: CGPoint
    
    func makeUIView(context: Context) -> SkyViewportARView {
        let view = SkyViewportARView(celestialCatalog: celestialCatalog)
        view.scnView.delegate = context.coordinator
        context.coordinator.parent = self
        return view
    }
    
    func updateUIView(_ uiView: SkyViewportARView, context: Context) {
        context.coordinator.parent = self
    }
    
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    
    class Coordinator: NSObject, SCNSceneRendererDelegate {
        var parent: SkyViewportARViewContainer
        
        init(_ parent: SkyViewportARViewContainer) {
            self.parent = parent
        }
        
        func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
            guard let scnView = renderer as? SCNView, let scene = scnView.scene else { return }
            
            // Point the camera rig at wherever the phone is ACTUALLY facing right now, using
            // the same -azRad/altRad convention as each catalog object's own placement above
            // -- "look toward bearing θ" and "place an object at bearing θ" are the same
            // geometric operation, so reusing the identical formula here means there's no
            // separate sign convention to independently get right for the camera.
            if let cameraRig = scene.rootNode.childNode(withName: "SKY_CAMERA_RIG", recursively: false) {
                let azRad = Float(self.parent.headingDegrees * .pi / 180.0)
                let altRad = Float((90.0 - self.parent.pitchDegrees) * .pi / 180.0)
                cameraRig.eulerAngles = SCNVector3(altRad, -azRad, 0)
            }
            
            var temporaryPlots: [ScreenProjectedObject] = []
            
            // Named bodies (planets, the Moon, and naked-eye stars with a real name rather than
            // just a HIP catalog number -- see isMajorLabelBody/hasPermanentLabel in
            // populateARSkyDome) get their own closest-match tracking, separate from the general
            // "anything under the reticle" tracking below. That way a named object anywhere
            // inside the lock radius always outranks a closer but unnamed background star,
            // instead of pure on-screen distance deciding the winner.
            var closestNamedNode: SCNNode? = nil
            var closestNamedDistance: Float = Float.infinity
            var closestAnyNode: SCNNode? = nil
            var closestAnyDistance: Float = Float.infinity
            
            let targetCenterPoint = self.parent.reticleCenter
            
            guard let sphereContainer = scene.rootNode.childNode(withName: "CELESTIAL_SPHERE_SHELL", recursively: true) else { return }
            
            sphereContainer.enumerateChildNodes { (parentNode, _) in
                // Intercept the visual dot nodes sitting inside the rotated parent shells
                parentNode.enumerateChildNodes { (node, _) in
                    guard let packet = node.value(forKey: "celestial_packet") as? ARNodeMetadataPacket else { return }
                    
                    let worldPosition = node.worldPosition
                    let screenPoint = scnView.projectPoint(worldPosition)
                    
                    if screenPoint.z > 0 && screenPoint.z < 1.0 {
                        let screenX = CGFloat(screenPoint.x)
                        let screenY = CGFloat(screenPoint.y)
                        let isNamedBody = node.value(forKey: "hasPermanentLabel") as? Bool == true
                        
                        if isNamedBody {
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
                        
                        guard distanceToCenter < 35.0 else { return }
                        
                        if isNamedBody {
                            if distanceToCenter < closestNamedDistance {
                                closestNamedDistance = distanceToCenter
                                closestNamedNode = node
                            }
                        } else if distanceToCenter < closestAnyDistance {
                            closestAnyDistance = distanceToCenter
                            closestAnyNode = node
                        }
                    }
                }
            }
            
            // A named body anywhere in the lock radius always wins; only fall back to the
            // nearest unnamed star when nothing named is under the reticle at all.
            let activeLockNode = closestNamedNode ?? closestAnyNode
            
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
    // Content-based identity — NOT a fresh UUID(). This struct gets rebuilt on every rendered
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
