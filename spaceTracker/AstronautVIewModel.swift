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
    // 💡 FEAT-16: the feed already carries these -- they just weren't being decoded.
    let image: AstronautImage?
    let time_in_space: String?
    let in_space: Bool?
    let first_flight: String?
    let wiki: String?

    /// time_in_space arrives as an ISO 8601 duration ("P412DT7H12M30S") -- real recorded
    /// flight time as of whenever this feed was last generated, not a live ticking
    /// counter. Presented as "career" time in the UI rather than implying second-by-second
    /// accuracy it doesn't have.
    var daysInSpace: Int? {
        Self.parseISO8601DurationDays(time_in_space)
    }

    static func parseISO8601DurationDays(_ duration: String?) -> Int? {
        guard let duration, duration.hasPrefix("P") else { return nil }
        guard let dIndex = duration.firstIndex(of: "D") else { return 0 }
        let start = duration.index(after: duration.startIndex)
        guard start < dIndex, let days = Int(duration[start..<dIndex]) else { return nil }
        return days
    }
}

struct AstronautImage: Decodable {
    let image_url: String
    let thumbnail_url: String?
}

struct NationalityInfo: Decodable {
    let id: Int
    let name: String
    let alpha_2_code: String

    /// Regional-indicator flag emoji built from the ISO 3166-1 alpha-2 code -- standard
    /// technique (each letter maps to a regional indicator symbol two code points above
    /// its ASCII value; a compliant renderer combines the pair into a flag glyph).
    var flagEmoji: String {
        let regionalIndicatorBase: UInt32 = 127397
        var scalars = String.UnicodeScalarView()
        for scalar in alpha_2_code.uppercased().unicodeScalars {
            guard let flagScalar = Unicode.Scalar(regionalIndicatorBase + scalar.value) else { continue }
            scalars.append(flagScalar)
        }
        return scalars.isEmpty ? "🏳️" : String(scalars)
    }
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
                            AsyncImage(url: URL(string: astronaut.image?.thumbnail_url ?? astronaut.image?.image_url ?? "")) { phase in
                                if case .success(let img) = phase {
                                    img.resizable().aspectRatio(contentMode: .fill)
                                } else {
                                    Image(systemName: "person.fill")
                                        .font(.system(size: 9))
                                        .foregroundColor(.gray)
                                }
                            }
                            .frame(width: 14, height: 14)
                            .clipShape(Circle())
                            if let flag = astronaut.nationality.first?.flagEmoji {
                                Text(flag)
                                    .font(.system(size: 10))
                            }
                            Text(astronaut.name.uppercased())
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(.gray)
                        }
                    }
                }
            }
            
            // Upper ceiling push spring
            Spacer(minLength: 0)

            HStack {
                Spacer()
                Text("❯")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.cyan.opacity(0.45))
            }
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
    
    // 💡 BUG-02 FIX: commander name, expedition designator, and days-in-orbit used to be
    // hardcoded strings presented as if live -- they went stale the moment crew rotated.
    // Days-in-orbit is now computed from each station's real assembly/launch date, so it's
    // correct every time this opens. Commander/expedition had no clean free live source,
    // so rather than keep inventing specifics, those rows are gone -- replaced by real
    // per-astronaut detail in the crew section below. Velocity/period are genuine physical
    // constants for the station's altitude, not per-crew facts, so those stay as-is.
    private var missionData: (daysInOrbit: String, speed: String, summary: String) {
        let name = craftName.uppercased()
        if name.contains("INTERNATIONAL") || name.contains("ISS") {
            return (
                Self.daysSinceAnchor(year: 1998, month: 11, day: 20), // Zarya, first ISS module in orbit
                "VELOCITY: 27,560 KM/H // PERIOD: 92.8 MIN",
                "THE ISS IS A COLLABORATIVE MULTINATIONAL HABITATION OUTPOST CONDUCTING MICROGRAVITY BIOLOGY, SPACE WEATHER RADIATION MODELLING, AND LONG-DURATION FLIGHT COUNTERMEASURES."
            )
        } else if name.contains("TIANGONG") || name.contains("CHINESE") || name.contains("CSS") {
            return (
                Self.daysSinceAnchor(year: 2021, month: 4, day: 29), // Tianhe core module launch
                "VELOCITY: 27,610 KM/H // PERIOD: 91.5 MIN",
                "THE TIANGONG SECTOR COMPRISES A THREE-MODULE T-SHAPE HUB FOR ADVANCED MATERIAL SCIENCE COMBUSTION AND LOW-EARTH ORBIT ASTROPHYSICS PHENOMENA MONITORING."
            )
        }
        return (
            "VARIABLE",
            "VELOCITY: 27,500 KM/H",
            "EXPERIMENTAL HIGH-VELOCITY TRANSIT FLIGHT COMPONENT CLEARING ORBITAL PATHS."
        )
    }

    /// Real elapsed days from a fixed historical anchor to today -- correct on every open,
    /// unlike the frozen string this replaces.
    private static func daysSinceAnchor(year: Int, month: Int, day: Int) -> String {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        guard let anchorDate = Calendar.current.date(from: components) else { return "VARIABLE" }
        let days = Calendar.current.dateComponents([.day], from: anchorDate, to: Date()).day ?? 0
        return "\(days)+ DAYS"
    }

    /// Real nationalities from the actual current crew, replacing BUG-02's hardcoded
    /// string that couldn't reflect crew rotation.
    private var nationsPresent: String {
        let names = crewList.compactMap { $0.nationality.first?.name }
        let unique = Array(Set(names)).sorted()
        return unique.isEmpty ? "UNKNOWN" : unique.joined(separator: ", ").uppercased()
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
                                telemetryRow(label: "DAYS IN CONTINUOUS ORBIT", value: missionData.daysInOrbit)
                                telemetryRow(label: "CURRENT SPEED VECTOR", value: missionData.speed)
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
                                telemetryRow(label: "NATIONALITIES PRESENT", value: nationsPresent)
                            }
                            .border(Color.white.opacity(0.1), width: 1)
                            
                            // Crew Manifest -- real per-astronaut detail (FEAT-16): photo,
                            // flag, agency, and recorded career time in space, replacing
                            // the plain name-only bullet list.
                            VStack(alignment: .leading, spacing: 10) {
                                Text("LOGGED INHABITANTS:")
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundColor(.secondary)
                                    .padding(.top, 4)
                                
                                ForEach(crewList) { astronaut in
                                    astronautRow(astronaut)
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

    /// Real per-astronaut detail (FEAT-16): photo, nationality flag, agency, and recorded
    /// career time in space -- everything the feed already provides but the roster used to
    /// throw away in favor of a bare uppercase name.
    private func astronautRow(_ astronaut: Astronaut) -> some View {
        HStack(alignment: .top, spacing: 10) {
            AsyncImage(url: URL(string: astronaut.image?.thumbnail_url ?? astronaut.image?.image_url ?? "")) { phase in
                if case .success(let img) = phase {
                    img.resizable().aspectRatio(contentMode: .fill)
                } else {
                    Color.white.opacity(0.06)
                        .overlay(
                            Image(systemName: "person.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                        )
                }
            }
            .frame(width: 32, height: 32)
            .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    if let flag = astronaut.nationality.first?.flagEmoji {
                        Text(flag)
                            .font(.system(size: 12))
                    }
                    Text(astronaut.name.uppercased())
                        .font(.system(.caption, design: .monospaced))
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
                HStack(spacing: 8) {
                    if let agencyAbbrev = astronaut.agency?.abbrev {
                        Text(agencyAbbrev)
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(.cyan)
                    }
                    if let days = astronaut.daysInSpace {
                        Text("\(days) DAYS IN SPACE (CAREER)")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(.gray)
                    }
                }
            }
        }
    }
}
