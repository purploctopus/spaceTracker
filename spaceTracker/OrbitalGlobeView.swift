//
//  OrbitalGlobeView.swift
//  spaceTracker
//
//  Created by Ben Clary on 8/6/26.
//  make an app Colin loves and support Saras happiness!

import SwiftUI
import MapKit

import SwiftUI
import MapKit

struct OrbitalGlobeView: UIViewRepresentable {
    // Bind your live coordinates coming from the tracking API layer
    @Binding var issCoordinate: CLLocationCoordinate2D
    @Binding var tiangongCoordinate: CLLocationCoordinate2D
    @Binding var currentFocus: OrbitalStationState.TrackingTarget // 💡 THE FOCUS BINDING RESCUE LINE
    // Predicted future ground-track points, from real SGP4 propagation — drawn as dashed
    // lines distinct from the solid current-position markers.
    @Binding var issGroundTrack: [CLLocationCoordinate2D]
    @Binding var tiangongGroundTrack: [CLLocationCoordinate2D]
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        
        // 🌍 FORCE 3D GLOBE MODE: SatelliteFlyover displays a 3D sphere with true Earth curvature
        mapView.mapType = .satelliteFlyover
        
        // 🧭 COCKPIT INTERACTION CONTROLS: Enable manual zoom, pitch (tilting), and rotational panning
        mapView.isZoomEnabled = true
        mapView.isScrollEnabled = true
        mapView.isRotateEnabled = true
        mapView.isPitchEnabled = true
        
        // 🛰️ ATMOSPHERIC FIELD OF VIEW: Set a massive altitudinal camera angle looking down from space
        let spaceCamera = MKMapCamera(
            lookingAtCenter: CLLocationCoordinate2D(latitude: 0, longitude: 0),
            fromDistance: 25_000_000, // Distance in meters (high enough to view the entire planet curve)
            pitch: 0,                 // 0 degrees looks flat straight down at the core axis
            heading: 0
        )
        mapView.setCamera(spaceCamera, animated: false)
        
        // Connect the layout delegate to custom marker render layers
        mapView.delegate = context.coordinator
        
        return mapView
    }
    
    func updateUIView(_ uiView: MKMapView, context: Context) {
        context.coordinator.updateAnnotationPositions(on: uiView, iss: issCoordinate, tiangong: tiangongCoordinate)
        context.coordinator.updateGroundTracks(on: uiView, issTrack: issGroundTrack, tiangongTrack: tiangongGroundTrack)
        
        let activeTargetCoordinate = currentFocus == .iss ? issCoordinate : tiangongCoordinate
        
        let trackingCamera = MKMapCamera(
            lookingAtCenter: activeTargetCoordinate,
            fromDistance: 16_000_000,
            pitch: 30,
            heading: 0
        )
        
        // 💡 SMOOTH TRANSLATION: Animating over 2.5 seconds creates a cinematic tracking sweep that bridges the data intervals beautifully
        UIView.animate(withDuration: 2.5, delay: 0, options: [.allowUserInteraction, .curveEaseInOut]) {
            uiView.setCamera(trackingCamera, animated: false)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
}

class Coordinator: NSObject, MKMapViewDelegate {
    private var issAnnotation = MKPointAnnotation()
    private var tiangongAnnotation = MKPointAnnotation()
    private var isFirstLoad = true
    
    // Predicted ground-track overlays. MKPolyline's point array is immutable once created,
    // so unlike the point annotations above (which slide smoothly via animated coordinate
    // changes), a changed track means removing the old overlay and adding a fresh one.
    private var issTrackOverlay: MKPolyline?
    private var tiangongTrackOverlay: MKPolyline?
    
    override init() {
        super.init()
        issAnnotation.title = "ISS"
        tiangongAnnotation.title = "TIANGONG"
    }
    
    func updateAnnotationPositions(on mapView: MKMapView, iss: CLLocationCoordinate2D, tiangong: CLLocationCoordinate2D) {
        // 💡 FIRST TIME SETUP: Safely attach the nodes onto the 3D grid layout mesh exactly once
        if isFirstLoad {
            issAnnotation.coordinate = iss
            tiangongAnnotation.coordinate = tiangong
            mapView.addAnnotations([issAnnotation, tiangongAnnotation])
            isFirstLoad = false
            return
        }
        
        // ⚡️ REAL-TIME POSITION SMOOTHING: Slide coordinates smoothly to prevent marker stutter
        UIView.animate(withDuration: 1.0) {
            self.issAnnotation.coordinate = iss
            self.tiangongAnnotation.coordinate = tiangong
        }
    }
    
    /// Replaces each satellite's predicted ground-track overlay with a fresh one built from
    /// its latest SGP4-propagated points. Empty arrays (TLE not loaded yet) simply clear
    /// any existing line rather than drawing nothing new.
    func updateGroundTracks(on mapView: MKMapView, issTrack: [CLLocationCoordinate2D], tiangongTrack: [CLLocationCoordinate2D]) {
        if let existing = issTrackOverlay {
            mapView.removeOverlay(existing)
            issTrackOverlay = nil
        }
        if !issTrack.isEmpty {
            let polyline = MKPolyline(coordinates: issTrack, count: issTrack.count)
            polyline.title = "ISS_TRACK"
            mapView.addOverlay(polyline)
            issTrackOverlay = polyline
        }
        
        if let existing = tiangongTrackOverlay {
            mapView.removeOverlay(existing)
            tiangongTrackOverlay = nil
        }
        if !tiangongTrack.isEmpty {
            let polyline = MKPolyline(coordinates: tiangongTrack, count: tiangongTrack.count)
            polyline.title = "TIANGONG_TRACK"
            mapView.addOverlay(polyline)
            tiangongTrackOverlay = polyline
        }
    }
    
    // 🎨 GROUND TRACK STYLING: color-matches each satellite's existing callsign label color
    // (cyan for ISS, orange for Tiangong), dashed to visually read as "predicted future
    // path" rather than a solid, already-traveled trail.
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        guard let polyline = overlay as? MKPolyline else {
            return MKOverlayRenderer(overlay: overlay)
        }
        
        let renderer = MKPolylineRenderer(polyline: polyline)
        renderer.strokeColor = (polyline.title == "TIANGONG_TRACK" ? UIColor.orange : UIColor.cyan).withAlphaComponent(0.75)
        renderer.lineWidth = 2.0
        renderer.lineDashPattern = [6, 5]
        return renderer
    }
    
    // 🎨 TELMETRY TEXT INTERCEPT: Stacks a clean monospace tracking label directly beneath your satellite emoji vector
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        guard let annotation = annotation as? MKPointAnnotation else { return nil }
        
        let identifier = annotation.title == "ISS" ? "ISS_Marker" : "Tiangong_Marker"
        var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
        
        if annotationView == nil {
            annotationView = MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
            annotationView?.canShowCallout = true
            
            // 📦 CONTAINER STACK: Combine your icon and text inside a clean vertical UIKit layout container
            let containerStack = UIStackView()
            containerStack.axis = .vertical
            containerStack.alignment = .center
            containerStack.spacing = 2 // Tight 2-point spacing keeps it incredibly compact
            
            // 1. THE ICON NODE LAYER
            let iconLabel = UILabel()
            iconLabel.text = "🛰️"
            iconLabel.font = .systemFont(ofSize: 24) // Slightly downscaled from 28 to balance the text addition
            
            // 2. THE FLIGHT CALLSIGN TEXT LAYER
            let callsignLabel = UILabel()
            callsignLabel.text = annotation.title // Displays "ISS" or "TIANGONG" automatically
            // 💡 TERMINAL WEIGHTS: Monospaced font configuration matching your main app dashboard panels
            callsignLabel.font = .monospacedSystemFont(ofSize: 8, weight: .bold)
            // Color codes them to match your top status instrument gauges (Cyan for ISS, Orange for Tiangong)
            callsignLabel.textColor = annotation.title == "ISS" ? .cyan : .orange
            callsignLabel.backgroundColor = UIColor.black.withAlphaComponent(0.6) // Tiny backdrop prevents map bleed
            callsignLabel.clipsToBounds = true
            callsignLabel.layer.cornerRadius = 2

            // Add layers to the stack view container mesh
            containerStack.addArrangedSubview(iconLabel)
            containerStack.addArrangedSubview(callsignLabel)
            
            // Measure frames and assign the composition directly into your annotation boundaries
            containerStack.frame = CGRect(x: 0, y: 0, width: 60, height: 42)
            annotationView?.addSubview(containerStack)
            annotationView?.frame = containerStack.bounds
            
            // Centers the entire stacked block directly over the target's exact GPS tracking coordinate point
            annotationView?.centerOffset = CGPoint(x: 0, y: 0)
        } else {
            annotationView?.annotation = annotation
        }
        
        return annotationView
    }
}
