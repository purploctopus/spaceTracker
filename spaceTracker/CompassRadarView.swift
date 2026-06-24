//
//  CompassRadarView.swift
//  spaceTracker
//
//  Created by Ben Clary on 6/24/26.
//

import SwiftUI

struct CompassRadarView: View {
    let pass: SatellitePass
    let userHeading: Double // Injected from viewModel.currentHeading
    
    @State private var pulseAnimation = false
    @State private var radarSweepRotation = 0.0
    
    var body: some View {
        VStack(spacing: 16) {
            // Live Azimuth Compass Status Banner
            HStack(spacing: 8) {
                Image(systemName: "location.north.circle.fill")
                    .foregroundColor(.cyan)
                    .font(.subheadline)
                Text(String(format: "HEADING: %03d°", Int(userHeading)))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.white)
                Spacer()
                Text("MAGNETIC CALIBRATION ACTIVE")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(.gray)
            }
            .padding(.horizontal, 4)
            
            // Core Radar Instrument Canvas Panel
            ZStack {
                // Background Glow Plate
                Circle()
                    .fill(Color.black.opacity(0.6))
                    .shadow(color: Color.cyan.opacity(0.15), radius: 20)
                
                // 1. Concentric Grid Circles (Outer Horizon = 10°, Inner Center = 90° Zenith)
                Group {
                    Circle().stroke(Color.white.opacity(0.04), lineWidth: 1) // Horizon line
                    Circle().scale(0.66).stroke(Color.white.opacity(0.06), lineWidth: 1) // 35° Elevation
                    Circle().scale(0.33).stroke(Color.white.opacity(0.08), lineWidth: 1) // 65° Elevation
                }
                
                // 2. Crosshair Guidelines
                GeometryReader { geo in
                    let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
                    Path { p in
                        p.move(to: CGPoint(x: center.x, y: 0))
                        p.addLine(to: CGPoint(x: center.x, y: geo.size.height))
                        p.move(to: CGPoint(x: 0, y: center.y))
                        p.addLine(to: CGPoint(x: geo.size.width, y: center.y))
                    }
                    .stroke(Color.white.opacity(0.05), lineWidth: 1)
                }
                
                // 3. Compass Direction Indicators Grid (N, S, E, W)
                // This group remains locked to True North, rotating dynamically matching phone twists!
                Group {
                    compassLabel("N", alignment: .top).padding(.top, 8)
                    compassLabel("S", alignment: .bottom).padding(.bottom, 8)
                    compassLabel("E", alignment: .trailing).padding(.trailing, 8)
                    compassLabel("W", alignment: .leading).padding(.leading, 8)
                }
                .rotationEffect(.degrees(-userHeading)) // Dynamic Rotation matrix link 🔄
                
                // 4. Premium Vector Sky-Pass Trajectory Arc Track
                GeometryReader { geo in
                    let bounds = min(geo.size.width, geo.size.height)
                   // let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
                    let pathVectors = parseFlightPathVectors(for: pass, layoutRadius: bounds / 2)
                    
                    // Trace out the projected geometric arc path the satellite will take across the dome
                    Path { p in
                        p.move(to: pathVectors.startPoint)
                        p.addQuadCurve(to: pathVectors.endPoint, control: pathVectors.apexPoint)
                    }
                    .stroke(
                        LinearGradient(
                            colors: [.cyan.opacity(0.1), .cyan, .cyan.opacity(0.1)],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: 2, lineCap: .round) // Dash removed entirely
                    )
                    
                    // Rises Dot
                    Circle()
                        .fill(Color.yellow)
                        .frame(width: 6, height: 6)
                        .position(pathVectors.startPoint)
                    
                    // Sets Dot
                    Circle()
                        .fill(Color.gray)
                        .frame(width: 6, height: 6)
                        .position(pathVectors.endPoint)
                    
                    // Live Blinking Satellite Target Apex Indicator
                    ZStack {
                        Circle()
                            .stroke(Color.cyan, lineWidth: 1)
                            .scaleEffect(pulseAnimation ? 2.5 : 1.0)
                            .opacity(pulseAnimation ? 0.0 : 0.8)
                        Circle()
                            .fill(Color.cyan)
                            .frame(width: 10, height: 10)
                    }
                    .position(pathVectors.apexPoint)
                }
                .rotationEffect(.degrees(-userHeading)) // Locked to the physical gyro compass vector matrix 🔄
                
                // 5. Classic Continuous Radar Sweep Sweep Line Overlay
                Circle()
                    .fill(AngularGradient(colors: [.cyan.opacity(0.15), .clear, .clear], center: .center, angle: .degrees(radarSweepRotation)))
                    .rotationEffect(.degrees(radarSweepRotation))
            }
            .aspectRatio(1, contentMode: .fit)
            .padding(4)
            .onAppear {
                pulseAnimation = true
                withAnimation(.linear(duration: 4.0).repeatForever(autoreverses: false)) {
                    radarSweepRotation = 360.0
                }
            }
            
            // Legend readout footer matrix block
            HStack {
                HStack(spacing: 4) { Circle().fill(Color.yellow).frame(width: 6, height: 6); Text("RISE").font(.system(size: 10, design: .monospaced)) }
                Spacer()
                HStack(spacing: 4) { Circle().fill(Color.cyan).frame(width: 6, height: 6); Text("PEAK").font(.system(size: 10, design: .monospaced)) }
                Spacer()
                HStack(spacing: 4) { Circle().fill(Color.gray).frame(width: 6, height: 6); Text("SET").font(.system(size: 10, design: .monospaced)) }
            }
            .foregroundColor(.gray)
            .padding(.horizontal, 24)
        }
        .padding(16)
        .background(Color.white.opacity(0.02))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.05), lineWidth: 1))
    }
    
    // Compass label styling builder helper
    private func compassLabel(_ text: String, alignment: Alignment) -> some View {
        VStack {
            Text(text)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(.white.opacity(0.4))
                .frame(maxHeight: .infinity, alignment: alignment)
        }
    }
    
    // Geometric Trigonometric Vector Projection Pipeline Model Engine
    private func parseFlightPathVectors(for pass: SatellitePass, layoutRadius: CGFloat) -> (startPoint: CGPoint, apexPoint: CGPoint, endPoint: CGPoint) {
        let center = CGPoint(x: layoutRadius, y: layoutRadius)
        
        // Parse "RISES SOUTH-WEST ➔ SETS NORTH-EAST" text line safely
        let components = pass.travelDirection.components(separatedBy: " ➔ ")
        let startStr = components.first?.replacingOccurrences(of: "RISES ", with: "") ?? "NORTH"
        let endStr = components.last?.replacingOccurrences(of: "SETS ", with: "") ?? "SOUTH"
        
        let startAngle = headingStringToDegrees(startStr)
        let endAngle = headingStringToDegrees(endStr)
        let apexAngle = (startAngle + endAngle) / 2.0 // Simple median vector sweep interpolation
        
        // Project outer radius coordinates (horizon)
        let startPt = polarToCartesian(center: center, radius: layoutRadius * 0.9, angleDegrees: startAngle)
        let endPt = polarToCartesian(center: center, radius: layoutRadius * 0.9, angleDegrees: endAngle)
        
        // Project peak apex coordinate scale factor inverted matching overhead look rules
        let elevationScale = (90.0 - pass.peakElevationDegrees) / 90.0
        let apexPt = polarToCartesian(center: center, radius: layoutRadius * CGFloat(elevationScale), angleDegrees: apexAngle)
        
        return (startPt, apexPt, endPt)
    }
    
    private func headingStringToDegrees(_ heading: String) -> Double {
        switch heading.uppercased().trimmingCharacters(in: .whitespacesAndNewlines) {
        case "NORTH": return 0.0
        case "NORTH-EAST": return 45.0
        case "EAST": return 90.0
        case "SOUTH-EAST": return 135.0
        case "SOUTH": return 180.0
        case "SOUTH-WEST": return 225.0
        case "WEST": return 270.0
        case "NORTH-WEST": return 315.0
        default: return 0.0
        }
    }
    
    private func polarToCartesian(center: CGPoint, radius: CGFloat, angleDegrees: Double) -> CGPoint {
        // Adjust angle calculation layout mapping polar mathematical orientation vectors up toward 0 degrees north
        let radians = (angleDegrees - 90.0) * .pi / 180.0
        return CGPoint(
            x: center.x + (radius * CGFloat(cos(radians))),
            y: center.y + (radius * CGFloat(sin(radians)))
        )
    }
}
