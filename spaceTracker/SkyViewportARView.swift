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
    
    init(celestialCatalog: [APIPlanetItem]) {
        super.init(frame: .zero)
        
        arView.backgroundColor = .black
        arView.scene.background.contents = UIColor.black
        arView.antialiasingMode = .multisampling4X
        arView.automaticallyUpdatesLighting = false
        
        let configuration = ARWorldTrackingConfiguration()
        configuration.worldAlignment = .gravityAndHeading
        
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
    
    private func populateARSkyDome(catalog: [APIPlanetItem], inside scene: SCNScene) {
        let domeRadius: Float = 25.0
        
        let celestialSphereNode = SCNNode()
        celestialSphereNode.name = "CELESTIAL_SPHERE_SHELL"
        scene.rootNode.addChildNode(celestialSphereNode)
        
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
            let isMajorLabelBody = isPlanet || (!object.name.contains("HIP") && object.nakedEyeObject)
            
            // 💡 THE SYNTAX CORRECTION: Cleaned out the double text block typo identifier!
            let xLogVal = domeRadius * sin(azRad) * cos(altRad)
            let yLogVal = domeRadius * sin(altRad)
            let zLogVal = -domeRadius * cos(azRad) * cos(altRad)
            
            if isPlanet {
                print("   🌐 PLOTTING PLANET: \(object.name)")
                print("      ├─> Input Math Model : ALT: \(String(format: "%.2f°", object.altitude)) | AZ: \(String(format: "%.2f°", object.azimuth))")
                print("      └─> SCN Graphic Node : X: \(String(format: "%.3f", xLogVal)) | Y: \(String(format: "%.3f", yLogVal)) | Z: \(String(format: "%.3f", zLogVal))")
            }
            
            let dotGeometry = SCNSphere(radius: isPlanet ? 0.09 : (object.nakedEyeObject ? 0.03 : 0.015))
            dotGeometry.firstMaterial?.diffuse.contents = isPlanet ? UIColor.cyan : UIColor.white
            dotGeometry.firstMaterial?.emission.contents = isPlanet ? UIColor.cyan : UIColor.white.withAlphaComponent(0.5)
            
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
                altitude: Int(object.altitude),
                azimuth: Int(object.azimuth)
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
    
    private let safeScreenCenter = CGPoint(
        x: UIScreen.main.bounds.width / 2,
        y: UIScreen.main.bounds.height / 2
    )
    
    func makeUIView(context: Context) -> SkyViewportARView {
        let view = SkyViewportARView(celestialCatalog: celestialCatalog)
        view.arView.delegate = context.coordinator
        return view
    }
    
    func updateUIView(_ uiView: SkyViewportARView, context: Context) {}
    
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    
    class Coordinator: NSObject, ARSCNViewDelegate {
        var parent: SkyViewportARViewContainer
        
        init(_ parent: SkyViewportARViewContainer) {
            self.parent = parent
        }
        
        func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
            guard let arView = renderer as? ARSCNView else { return }
            
            var temporaryPlots: [ScreenProjectedObject] = []
            var activeLockNode: SCNNode? = nil
            var closestDistance: Float = Float.infinity
            
            let targetCenterPoint = parent.safeScreenCenter
            
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
                        azimuth: packet.azimuth
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
    let altitude: Int
    let azimuth: Int
    
    init(name: String, classification: String, constellation: String, altitude: Int, azimuth: Int) {
        self.name = name
        self.classification = classification
        self.constellation = constellation
        self.altitude = altitude
        self.azimuth = azimuth
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
    let id = UUID()
    let name: String
    let constellation: String
    let altitude: Int
    let azimuth: Int
}
