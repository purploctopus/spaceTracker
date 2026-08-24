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
// 🪐 SPATIAL TRACKING ENGINE (PURE BLACK SPACE MODE)
// ==============================================================================
struct SkyViewportARView: UIViewRepresentable {
    let celestialCatalog: [APIPlanetItem]
    
    func makeUIView(context: Context) -> ARSCNView {
        let arView = ARSCNView()
        
        // 💡 THE WHITEWASH FIX: Force a solid black background color contents!
        // This shuts down the live camera video overlay feed completely, replacing
        // it with a crisp, high-contrast pure black outer space canvas layout.
        arView.scene.background.contents = UIColor.black
        arView.antialiasingMode = .multisampling4X
        arView.automaticallyUpdatesLighting = false
        
        // Initialize world-tracking configuration locked directly to North and Gravity
        let configuration = ARWorldTrackingConfiguration()
        configuration.worldAlignment = .gravityAndHeading
        
        // Project only the visible above-horizon star database onto our 3D space
        populateARSkyDome(catalog: celestialCatalog, inside: arView.scene)
        
        // Spin up the native spatial hardware tracking session loop
        arView.session.run(configuration)
        
        return arView
    }
    
    func updateUIView(_ uiView: ARSCNView, context: Context) {}
    
    private func populateARSkyDome(catalog: [APIPlanetItem], inside scene: SCNScene) {
        let domeRadius: Float = 30.0 // Projects star dots out onto a crisp 30-meter spatial sphere path
        
        for object in catalog {
            // ==============================================================================
            // 🛡️ THE ADJUSTED LOWER HORIZON GATE (SAVES NECK STRAIN)
            // ==============================================================================
            // 💡 CHANGED: Lowered the visibility gate threshold from 0.0 down to -25.0!
            // This pulls up the stars sitting just beneath your local tree and horizon lines,
            // filling your screen with stars while you hold the phone comfortably in front of you.
            if object.altitude < -25.0 { continue }
            
            // Convert input Azimuth and Altitude degrees into standard radians
            let azRad = Float(object.azimuth) * .pi / 180.0
            let altRad = Float(object.altitude) * .pi / 180.0
            
            // True AR spherical vector equations mapping coordinates relative to your camera glass
            let x = domeRadius * cos(altRad) * sin(azRad)
            let y = domeRadius * sin(altRad)
            let z = -domeRadius * cos(altRad) * cos(azRad)
            
            let isPlanet = object.classification == "PLANET"
            
            // Generate a vector graphic dot node for the star body
            let dotGeometry = SCNSphere(radius: isPlanet ? 0.12 : 0.04)
            dotGeometry.firstMaterial?.diffuse.contents = isPlanet ? UIColor.cyan : UIColor.white
            dotGeometry.firstMaterial?.emission.contents = isPlanet ? UIColor.cyan : UIColor.white
            
            let dotNode = SCNNode(geometry: dotGeometry)
            dotNode.position = SCNVector3(x, y, z)
            
            // High-performance flat billboard text labels (prevents rendering drops)
            let textGeometry = SCNText(string: object.name.uppercased(), extrusionDepth: 0.0)
            textGeometry.font = UIFont.monospacedSystemFont(ofSize: 0.22, weight: .bold)
            textGeometry.firstMaterial?.diffuse.contents = isPlanet ? UIColor.cyan : UIColor.white.withAlphaComponent(0.8)
            
            let textNode = SCNNode(geometry: textGeometry)
            textNode.position = SCNVector3(0.12, -0.05, 0)
            
            // Force text labels to automatically turn and face flat at your eyes continuously
            let billboardConstraint = SCNBillboardConstraint()
            billboardConstraint.freeAxes = .all
            textNode.constraints = [billboardConstraint]
            
            dotNode.addChildNode(textNode)
            scene.rootNode.addChildNode(dotNode)
        }
    }
    
    static func dismantleUIView(_ uiView: ARSCNView, coordinator: ()) {
        uiView.session.pause()
        uiView.scene.rootNode.enumerateChildNodes { (node, _) in
            node.removeFromParentNode()
        }
    }
}
