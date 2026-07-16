//
//  AstronautVIewModel.swift
//  spaceTracker
//
//  Created by Ben Clary on 6/25/26.
//  make an app colin loves

import Foundation
import SwiftUI
import Combine

// 💡 THE FIX: Maps the expected view type directly to your new database record format
typealias Astronaut = AstronautRecord

// MARK: - PRODUCTION DATA MODELS
struct AstronautsResponse: Decodable {
    let count: Int
    let results: [AstronautRecord]
}

struct AstronautRecord: Decodable, Identifiable {
    let id: Int
    let name: String
    let bio: String
    let nationality: [NationalityInfo]
    let agency: AgencyInfo?
    let launch_designator: String?
}

struct NationalityInfo: Decodable {
    let id: Int
    let name: String
    let alpha_2_code: String
}

struct AgencyInfo: Decodable {
    let id: Int
    let name: String
    let abbrev: String
}

// MARK: - 2. THE OPEN-NOTIFY VIEW MODEL
@MainActor
class AstronautViewModel: ObservableObject {
    @Published var totalHumansInOrbit: Int = 0
    
    // Now these arrays perfectly satisfy lines 90 and 145 in your views!
    @Published var issCrew: [Astronaut] = []
    @Published var tiangongCrew: [Astronaut] = []
    @Published var otherCrew: [Astronaut] = []
    
    @Published var isLoading = false
    @Published var errorMessage: String? = nil
    
    private let openNotifyURLString = "https://purploctopus.github.io/astronauts.json"
    
    func fetchAstronautRoster() async {
        isLoading = true
        errorMessage = nil
        print(openNotifyURLString)
        guard let url = URL(string: openNotifyURLString) else { return }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                self.errorMessage = "MANIFEST SERVER BUSY"
                self.isLoading = false
                return
            }
            
            let decoded = try JSONDecoder().decode(AstronautsResponse.self, from: data)
            
            let livingHumans = decoded.results.filter { astronaut in
                let normalizedName = astronaut.name.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
                return normalizedName != "STARMAN"
            }
            
            self.totalHumansInOrbit = livingHumans.count
            
            self.issCrew = livingHumans.filter { astronaut in
                let agency = astronaut.agency?.abbrev.uppercased() ?? ""
                return agency == "NASA" || agency == "ESA" || agency == "JAXA" || agency == "RFSA"
            }
            
            // 💡 FIXED: Changed filter from CMSA to CNSA to match your active JSON feed data
            self.tiangongCrew = livingHumans.filter { astronaut in
                let agency = astronaut.agency?.abbrev.uppercased() ?? ""
                return agency == "CNSA"
            }
            
            // Evaluates correctly now that CNSA matches the Tiangong crew array
            self.otherCrew = livingHumans.filter { human in
                let agency = human.agency?.abbrev.uppercased() ?? ""
                return agency != "NASA" && agency != "ESA" && agency != "JAXA" && agency != "RFSA" && agency != "CNSA"
            }
            
            self.isLoading = false
        } catch {
            self.errorMessage = "ROSTER ALIGNMENT FAULT"
            self.isLoading = false
        }
    }

}

// MARK: - 3. UI DISPLAY COMPONENT: SPACECRAFT ROSTER CARD
struct SpacecraftRosterCardView: View {
    let craftName: String
    let crewList: [Astronaut]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(craftName.uppercased())
                    .font(.system(.subheadline, design: .monospaced))
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                Spacer()
                Text("\(crewList.count) CREW")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.cyan)
                    .fontWeight(.bold)
            }
            
            Divider().background(Color.white.opacity(0.1))
            
            VStack(alignment: .leading, spacing: 6) {
                if crewList.isEmpty {
                    Text("NO CREW LOGGED IN THIS VEHICLE")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.gray)
                } else {
                    ForEach(crewList) { astronaut in
                        HStack(spacing: 6) {
                            Image(systemName: "person.fill")
                                .font(.system(size: 9))
                                .foregroundColor(.gray)
                            Text(astronaut.name.uppercased())
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(.gray)
                        }
                    }
                }
            }
            
            // Upper ceiling push spring
            Spacer(minLength: 0)
        }
        .padding(14)
        // 💡 FIXED: Zero hardcoded pixel parameters. Stretches completely dynamically to fill layout space context safely.
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.white.opacity(0.04))
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}

// MARK: - 4. THE SPACECRAFT TACTICAL MISSION SHEET
struct SpacecraftDetailSheet: View {
    let craftName: String
    let crewList: [Astronaut]
    let passes: [SatellitePass]
    
    @Environment(\.dismiss) var dismiss
    
    // 💡 LOCAL TELEMETRY ENGINE: Keeps the app fast by hardcoding stable operational logs
    private var missionData: (days: String, speed: String, commander: String, expedition: String, nations: String, summary: String) {
        let name = craftName.uppercased()
        if name.contains("INTERNATIONAL") || name.contains("ISS") {
            return (
                "10,100+ DAYS",
                "VELOCITY: 27,560 KM/H // PERIOD: 92.8 MIN",
                "OLEG KONONENKO",
                "NASA / ROSCOSMOS EXPEDITION 71/72",
                "USA, RUS, JPN, DEU, GBR",
                "THE ISS IS A COLLABORATIVE MULTINATIONAL HABITATION OUTPOST CONDUCTING MICROGRAVITY BIOLOGY, SPACE WEATHER RADIATION MODELLING, AND LONG-DURATION FLIGHT COUNTERMEASURES."
            )
        } else if name.contains("TIANGONG") || name.contains("CHINESE") || name.contains("CSS") {
            return (
                "1,900+ DAYS",
                "VELOCITY: 27,610 KM/H // PERIOD: 91.5 MIN",
                "YE GUANGFU",
                "CMSA SHENZHOU-18 / SHENZHOU-19",
                "CHN",
                "THE TIANGONG SECTOR COMPRISES A THREE-MODULE T-SHAPE HUB FOR ADVANCED MATERIAL SCIENCE COMBUSTION AND LOW-EARTH ORBIT ASTROPHYSICS PHENOMENA MONITORING."
            )
        }
        return (
            "VARIABLE",
            "VELOCITY: 27,500 KM/H",
            "CREW COMMANDER ASSIGNED",
            "TRANSIT OPERATION",
            "INTL",
            "EXPERIMENTAL HIGH-VELOCITY TRANSIT FLIGHT COMPONENT CLEARING ORBITAL PATHS."
        )
    }
    
    // 💡 CROSS-REFERENCE RADAR ENGINE: Matches the tapped card with existing satellite pass logs
    private var matchingPassTelemetry: (time: String, rating: String) {
        let targetKeywords = craftName.uppercased().contains("ISS") ? ["ISS"] : ["CSS", "TIANHE", "TIANGONG"]
        
        // Find the absolute closest upcoming pass matching the target spacecraft signature
        let matchingPass = passes.first { pass in
            targetKeywords.contains { keyword in pass.name.uppercased().contains(keyword) }
        }
        
        guard let pass = matchingPass else {
            return ("NO PASSES DETECTED IN NOW WINDOW", "LOW VISIBILITY // TARGET BELOW HORIZON")
        }
        
        let rating = pass.peakElevationDegrees > 45 ? "EXCELLENT // VISIBLE SUNGLINT EXPECTED" : "FAIR VISIBILITY // LOW SKY HORIZON ARC"
        return (pass.localDisplayTime, rating)
    }
    
    var body: some View {
        ZStack {
            Color(red: 0.04, green: 0.04, blue: 0.04).ignoresSafeArea()
            
            VStack(alignment: .leading, spacing: 24) {
                // Header Control Row
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(craftName.uppercased())
                            .font(.system(.title3, design: .monospaced))
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        Text("MISSION DIRECTORY STATUS REPORT")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.cyan)
                    }
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.gray)
                    }
                }
                
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 24) {
                        
                        // Section 1: Unified Spacecraft Statistics
                        VStack(alignment: .leading, spacing: 8) {
                            Text("I. SPACECRAFT OPERATIONAL MATRIX //")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.yellow)
                            
                            VStack(spacing: 0) {
                                telemetryRow(label: "DAYS IN CONTINUOUS ORBIT", value: missionData.days)
                                telemetryRow(label: "CURRENT SPEED VECTOR", value: missionData.speed)
                                telemetryRow(label: "ACTIVE COMMANDER LOG", value: missionData.commander)
                            }
                            .border(Color.white.opacity(0.1), width: 1)
                        }
                        
                        // Section 2: Live Local Intercept Telemetry
                        VStack(alignment: .leading, spacing: 8) {
                            Text("II. LOCAL BACKYARD RADAR TRACKS //")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.yellow)
                            
                            VStack(spacing: 0) {
                                telemetryRow(label: "NEXT HORIZON ENTRY", value: matchingPassTelemetry.time)
                                telemetryRow(label: "PASS QUALITY RATING", value: matchingPassTelemetry.rating)
                            }
                            .border(Color.white.opacity(0.1), width: 1)
                        }
                        
                        // Section 3: Crew Complement Breakdown
                        VStack(alignment: .leading, spacing: 8) {
                            Text("III. CREW RECON DIRECTORY //")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.yellow)
                            
                            VStack(spacing: 0) {
                                telemetryRow(label: "EXPEDITION DESIGNATION", value: missionData.expedition)
                                telemetryRow(label: "NATIONALITIES PRESENT", value: missionData.nations)
                            }
                            .border(Color.white.opacity(0.1), width: 1)
                            
                            // Crew Manifest Text Sub-List
                            VStack(alignment: .leading, spacing: 6) {
                                Text("LOGGED INHABITANTS:")
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundColor(.secondary)
                                    .padding(.top, 4)
                                
                                ForEach(crewList) { astronaut in
                                    Text("• \(astronaut.name.uppercased())")
                                        .font(.system(.caption, design: .monospaced))
                                        .foregroundColor(.gray)
                                }
                            }
                            .padding(.horizontal, 4)
                        }
                    }
                }
                
                Spacer()
            }
            .padding(24)
        }
        .preferredColorScheme(.dark)
    }
    
    private func telemetryRow(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(.secondary)
            Text(value.uppercased())
                .font(.system(.caption, design: .monospaced))
                .fontWeight(.bold)
                .foregroundColor(.white)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.01))
        .overlay(Rectangle().stroke(Color.white.opacity(0.04), lineWidth: 0.5))
    }
}
