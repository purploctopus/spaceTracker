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
// 🪐 SPATIAL AR ENGINE (SEAMLESS UN-CLAMPED CELESTIAL GLOBAL SPHERE)
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
        
        for object in catalog {
            // 💡 ALL HOLES PLUGGED: No filters or altitude cuts exist anymore.
            // All 2,551 stars populate the inside of your virtual planetarium globe.
            let azRad = Float(object.azimuth) * .pi / 180.0
            let altRad = Float(object.altitude) * .pi / 180.0
            
            let x = domeRadius * cos(altRad) * sin(azRad)
            let y = domeRadius * sin(altRad)
            let z = -domeRadius * cos(altRad) * cos(azRad)
            
            let isPlanet = object.classification == "PLANET"
            let isMajorLabelBody = isPlanet || (!object.name.contains("HIP") && object.nakedEyeObject)
            
            let dotGeometry = SCNSphere(radius: isPlanet ? 0.09 : (object.nakedEyeObject ? 0.03 : 0.015))
            dotGeometry.firstMaterial?.diffuse.contents = isPlanet ? UIColor.cyan : UIColor.white
            dotGeometry.firstMaterial?.emission.contents = isPlanet ? UIColor.cyan : UIColor.white.withAlphaComponent(0.5)
            
            let dotNode = SCNNode(geometry: dotGeometry)
            dotNode.position = SCNVector3(x, y, z)
            
            dotNode.name = object.name
            dotNode.setValue(object.constellation, forKey: "constellation")
            dotNode.setValue(object.altitude, forKey: "altitude")
            dotNode.setValue(object.azimuth, forKey: "azimuth")
            dotNode.setValue(isPlanet ? "PLANET" : "STAR", forKey: "classification")
            
            if isMajorLabelBody {
                dotNode.setValue(true, forKey: "hasPermanentLabel")
            }
            
            scene.rootNode.addChildNode(dotNode)
        }
    }
}

// ==============================================================================
// 🔌 SWIFTUI REPRESENTABLE CONTAINER (UN-CLAMPED SPATIAL RAYCASTER)
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
            
            arView.scene.rootNode.enumerateChildNodes { (node, _) in
                guard let nodeName = node.name else { return }
                
                let worldPosition = node.worldPosition
                let screenPoint = arView.projectPoint(worldPosition)
                
                if screenPoint.z > 0 && screenPoint.z < 1.0 {
                    let screenX = CGFloat(screenPoint.x)
                    let screenY = CGFloat(screenPoint.y)
                    
                    // 💡 FIXED: Permanent labels show up across all directions smoothly
                    if node.value(forKey: "hasPermanentLabel") as? Bool == true {
                        let isPlanet = node.value(forKey: "classification") as? String == "PLANET"
                        temporaryPlots.append(ScreenProjectedObject(
                            name: nodeName,
                            classification: isPlanet ? "PLANET" : "STAR",
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
            
            DispatchQueue.main.async {
                self.parent.projectedScreenPlots = temporaryPlots
                
                // 💡 FIXED: The crosshairs will lock onto below-horizon targets natively!
                if let lockNode = activeLockNode, let name = lockNode.name {
                    let con = lockNode.value(forKey: "constellation") as? String ?? "UNKNOWN"
                    let alt = lockNode.value(forKey: "altitude") as? Double ?? 0.0
                    let az = lockNode.value(forKey: "azimuth") as? Double ?? 0.0
                    
                    self.parent.currentCrosshairTarget = TargetLockMatch(
                        name: name.uppercased(),
                        constellation: con.uppercased(),
                        altitude: Int(alt),
                        azimuth: Int(az)
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
