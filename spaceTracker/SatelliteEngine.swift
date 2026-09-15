//
//  SatelliteViewModel.swift
//  spaceTracker
//
//  Created by Ben Clary on 6/18/26.
//  MAKE AN APP COLIN LOVES

import Foundation
import Combine
import CoreLocation
import SwiftUI
import MapKit

// MARK: - 1. THE DATA MODELS
struct SatelliteResponse: Codable {
    let total_visible_passes: Int
    let passes: [SatellitePass]
}

struct SatellitePass: Codable, Identifiable {
    let id: String
    let name: String
    // FEAT-25 follow-up (2026-09-15): real launch year, parsed server-side straight from the
    // TLE's international designator -- present for every satellite the worker now returns,
    // not just the ~9 with a hand-written missionProfile entry below. Optional/decodes to nil
    // rather than breaking anything if an older cached response doesn't have it.
    let launchYear: String?
    let utcTimeISO: String
    let peakElevationDegrees: Double
    let durationMinutes: Int
    let travelDirection: String
    
    var id_swiftui: String {
        return "\(id)-\(utcTimeISO)"
    }
    
    var localDisplayTime: String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = formatter.date(from: utcTimeISO) else { return "STANDBY" }
        
        let outputFormatter = DateFormatter()
        outputFormatter.dateFormat = "h:mm a (MMM d)"
        return outputFormatter.string(from: date)
    }

    // FEAT-25 follow-up (2026-09-15): the small set of satellites with a real hand-written
    // missionProfile entry below -- same name-substring list, shared here so
    // NotificationManager can use it too. Now that the worker's whitelist is gone and it
    // returns everything in CelesTrak's visual group (100+ objects on a clear night), this is
    // also what NotificationManager falls back to for alerts when the user hasn't explicitly
    // favorited specific satellites, so an opted-out user doesn't get flooded with alerts for
    // satellites they've never heard of.
    static let originalCuratedNameFragments = [
        "ISS", "CSS", "TIANHE", "SHENZHOU", "TIANGONG", "HUBBLE", "STARLINK", "X37-B", "ENVISAT", "AQUA", "TERRA"
    ]

    var isOriginalCuratedTarget: Bool {
        let upperName = name.uppercased()
        return Self.originalCuratedNameFragments.contains { upperName.contains($0) }
    }
}

// MARK: - 2. THE DEBUG-READY RADAR VIEW MODEL
class SatelliteViewModel: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var locationName: String = ""
    @Published var visiblePasses: [SatellitePass] = []
    @Published var isTracking: Bool = false
    @Published var errorMessage: String? = nil
    @Published var requiresManualSelection: Bool = false
    @Published var currentHeading: Double = 0.0
    @Published var countryISOCode: String = "PND" // Defaults to "Pending" on boot

    
    private let locationManager = CLLocationManager()
    private let workerURLString = "https://sat-tracker.purploctopus.workers.dev"
    private var lastQueriedLocationVector: String = ""
    
    override init() {
        super.init()
        print("🤖 [RADAR ENGINE]: Initializing core class framework...")
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyThreeKilometers
        if CLLocationManager.headingAvailable() {
            locationManager.startUpdatingHeading()
        }
        
        // 💡 FIXED: Make sure this structural check is nested INSIDE these initializer brackets!
        let savedCity = UserDefaults.standard.string(forKey: "cached_location_name") ?? ""
        let savedCountry = UserDefaults.standard.string(forKey: "cached_country_iso") ?? "USA" // 💡 Read country cache [1.13]
        let savedLat = UserDefaults.standard.string(forKey: "cached_latitude") ?? ""
        let savedLng = UserDefaults.standard.string(forKey: "cached_longitude") ?? ""
        
        if !savedCity.isEmpty && !savedLat.isEmpty && !savedLng.isEmpty {
            self.locationName = savedCity
            self.countryISOCode = savedCountry.uppercased() // 💡 Restore country instantly [1.13]
            print("📡 [CACHE hit]: Instant terminal initialization using saved footprint metrics.")
            Task { @MainActor in
                await self.fetchPasses(latitude: savedLat, longitude: savedLng)
            }
        }
    } // 🎛️ This is the closing bracket of override init()
    
    func requestPasses() {
        print("🤖 [RADAR ENGINE]: requestPasses() triggered by parent view.")
        
        // 💡 INSTANT MEMORY BYPASS: If we already have the location data, use it directly and skip the GPS hardware!
        if !locationName.isEmpty && !visiblePasses.isEmpty {
            print("📡 [RADAR ENGINE]: Cache hit. Re-using active footprints without re-triggering GPS hardware.")
            self.isTracking = false
            return
        }
        
        isTracking = true
        errorMessage = nil
        requiresManualSelection = false
        
        let status = locationManager.authorizationStatus
        print("🤖 [RADAR ENGINE]: Current system authorization status code: \(status.rawValue)")
        
        if status == .denied || status == .restricted {
            print("❌ [RADAR ENGINE]: Access denied by user system security controls.")
            isTracking = false
            requiresManualSelection = true
            return
        }
        
        if status == .notDetermined {
            print("🤖 [RADAR ENGINE]: Permission undetermined. Triggering native Apple dialog...")
            locationManager.requestWhenInUseAuthorization()
        } else {
            print("🤖 [RADAR ENGINE]: Permission authorized. Initializing core background GPS chip update stream...")
            locationManager.startUpdatingLocation()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) { [weak self] in
                guard let self = self else { return }
                if self.isTracking && self.visiblePasses.isEmpty {
                    print("⚠️ [RADAR ENGINE]: 4-second safety boundary reached with zero coordinates captured. Switching to manual selector UI.")
                    self.locationManager.stopUpdatingLocation()
                    self.isTracking = false
                    self.requiresManualSelection = true
                }
            }
        }
    }
    
    func selectCityCoordinates(lat: String, lng: String) {
        print("🤖 [RADAR ENGINE]: Manual coordinates received vector: \(lat), \(lng)")
        lastQueriedLocationVector = ""
        isTracking = true
        requiresManualSelection = false
        errorMessage = nil
        
        Task {
            await fetchPasses(latitude: lat, longitude: lng)
        }
    }
    
    // MARK: - CoreLocation GPS Location Callback
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        print("✅ [RADAR ENGINE]: Hardware callback received! Found \(locations.count) valid locations in vector stack.")
        guard let location = locations.last else {
            print("⚠️ [RADAR ENGINE]: Location array was empty inside completion delegate.")
            return
        }
        
        manager.stopUpdatingLocation()
        
        // Fixed: Locked to US Locale formatting rules to guarantee agnostic period decimal points
        let lat = String(format: "%.4f", locale: Locale(identifier: "en_US_POSIX"), location.coordinate.latitude)
        let lng = String(format: "%.4f", locale: Locale(identifier: "en_US_POSIX"), location.coordinate.longitude)

        print("🤖 [RADAR ENGINE]: Extracted coordinates: Lat \(lat), Lng \(lng)")
        
        // MARK: - 📡 FIXED: HIGH-DENSITY AEROSPACE ADDRESS RECONSTRUCTION WITH DYNAMIC ISO TRACKING
        Task {
            let geocoder = CLGeocoder()
            
            do {
                let placemarks = try await geocoder.reverseGeocodeLocation(location)
                
                if let verifiedPlacemark = placemarks.first {
                    // Extract individual street attributes natively from the Apple placemark model [1.1]
                    let subThoroughfare = verifiedPlacemark.subThoroughfare ?? "" // e.g., "1-99"
                    let thoroughfare = verifiedPlacemark.thoroughfare ?? ""       // e.g., "Stockton St"
                    let locality = verifiedPlacemark.locality ?? "Unknown City"   // e.g., "San Francisco"
                    
                    // 💡 NEW COUNTRY ISO EXTRACTOR: Grabs "US", "GB", "JP", etc., natively from Apple's data sheets [1.1]
                    let extractedCountryCode = verifiedPlacemark.isoCountryCode ?? "USA"
                    
                    let streetPart = "\(subThoroughfare) \(thoroughfare)".trimmingCharacters(in: .whitespacesAndNewlines)
                    let resolvedCityName: String = {
                        if streetPart.isEmpty {
                            return locality
                        } else {
                            return "\(streetPart), \(locality)" // Reconstructs: "1-99 Stockton St, San Francisco"
                        }
                    }()
                    
                    await MainActor.run {
                        // 💡 RADAR GUARD: Only trigger a full refresh loop if the user actually shifted cities! [1.13]
                        if self.locationName != resolvedCityName {
                            print("🛰️ [SECTOR CHANGED]: Transitioning data channels over to: \(resolvedCityName)")
                            
                            // Commit the fresh data points straight over to local system storage memory [1.13]
                            UserDefaults.standard.set(resolvedCityName, forKey: "cached_location_name")
                            UserDefaults.standard.set(extractedCountryCode.uppercased(), forKey: "cached_country_iso") // 💡 Cache country code [1.13]
                            UserDefaults.standard.set(lat, forKey: "cached_latitude")
                            UserDefaults.standard.set(lng, forKey: "cached_longitude")
                            
                            withAnimation(.easeInOut) {
                                self.locationName = resolvedCityName
                                self.countryISOCode = extractedCountryCode.uppercased() // 💡 Update active layout memory state [1.13]
                            }
                        } else {
                            print("🎯 [RADAR GUARD]: Station location matches existing footprint vector fields. Aborting redundant download pipelines.")
                        }
                    }
                }
            } catch {
                print("⚠️ [RADAR ENGINE]: System Core Location Geocoder execution fault: \(error.localizedDescription)")
            }
        }

        Task { @MainActor in
            await fetchPasses(latitude: lat, longitude: lng)
        }
    }

    
    // MARK: - CoreLocation Compass Heading Callback
    // FIXED: Separated into its own dedicated delegate function to fix the scoping error
    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        let headingDegrees = newHeading.trueHeading >= 0 ? newHeading.trueHeading : newHeading.magneticHeading
        
        Task { @MainActor in
            withAnimation(.interactiveSpring(response: 0.3, dampingFraction: 0.6)) {
                self.currentHeading = headingDegrees
            }
        }
    }
    
    // MARK: - CoreLocation Error Stream Callback
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("❌ [RADAR ENGINE]: CoreLocation Hardware Error stream: \(error.localizedDescription)")
        manager.stopUpdatingLocation()
        Task { @MainActor in
            if self.visiblePasses.isEmpty {
                self.isTracking = false
                self.requiresManualSelection = true
                self.errorMessage = "HARDWARE TIMEOUT: \(error.localizedDescription)"
            }
        }
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        print("🤖 [RADAR ENGINE]: System Authorization changed dynamically to status code: \(status.rawValue)")
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            print("🤖 [RADAR ENGINE]: Authorization granted. Activating hardware scan cycle...")
            isTracking = true
            manager.startUpdatingLocation()
        } else if status == .denied || status == .restricted {
            print("❌ [RADAR ENGINE]: Authorization explicitly refused on user prompt.")
            self.requiresManualSelection = true
        }
    }
    
    @MainActor
    private func fetchPasses(latitude: String, longitude: String) async {
        let locationKey = "\(latitude),\(longitude)"
        guard locationKey != lastQueriedLocationVector else {
            print("🤖 [RADAR ENGINE]: Target vector matches existing footprint. Aborting double query stream fetch.")
            self.isTracking = false
            return
        }
        
        lastQueriedLocationVector = locationKey
        isTracking = true
        errorMessage = nil
        
        let urlString = "\(workerURLString)?lat=\(latitude)&lng=\(longitude)&days=2"
        print("📡 [RADAR ENGINE]: Initiating background fetch path to: \(urlString)")
        
        guard let url = URL(string: urlString) else {
            print("❌ [RADAR ENGINE]: Malformed endpoint URL parsing construction.")
            return
        }
        
        do {
            // 1. Execute the network transaction first
            let (data, response) = try await URLSession.shared.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ [RADAR ENGINE]: Upstream server response was not an HTTP transmission matrix.")
                self.errorMessage = "NETWORK INTERFACE FAULT"
                self.isTracking = false
                return
            }
            
            print("📡 [RADAR ENGINE]: Cloudflare Gateway handshake complete. Response HTTP Code: \(httpResponse.statusCode)")
            
            // 2. Safely evaluate errors now that httpResponse and data exist in this scope
            guard httpResponse.statusCode == 200 else {
                if let errorBody = String(data: data, encoding: .utf8) {
                    print("❌ [RADAR ENGINE] Upstream Error Body: \(errorBody)")
                }
                self.errorMessage = "UPSTREAM SYNC FAIL (\(httpResponse.statusCode))"
                self.isTracking = false
                self.lastQueriedLocationVector = ""
                return
            }
            
            // 3. Parse successful 200 payload
            let decoded = try JSONDecoder().decode(SatelliteResponse.self, from: data)
            print("✅ [RADAR ENGINE]: Successful pipeline synchronization. Loaded \(decoded.passes.count) visual pass records.")
            self.visiblePasses = decoded.passes
            self.isTracking = false
            
        } catch {
            print("❌ [RADAR ENGINE]: Data processing conversion exception thrown: \(error)")
            self.errorMessage = "DECODING ENGINE FAULT"
            self.isTracking = false
            self.lastQueriedLocationVector = ""
        }
    }
    
    func searchAndSelectCity(query: String) {
        print("🤖 [RADAR ENGINE]: Processing manual string text geocode search query: '\(query)'")
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        
        DispatchQueue.main.async {
            self.lastQueriedLocationVector = ""
            self.isTracking = true
            self.errorMessage = nil
        }
        
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.resultTypes = .address
        
        let search = MKLocalSearch(request: request)
        
        Task {
            do {
                let response = try await search.start()
                if let firstItem = response.mapItems.first {
                    
                    // 💡 FIXED: Extract the location coordinate vector directly from your placemark model
                    let coordinate = firstItem.placemark.coordinate
                    
                    let lat = String(format: "%.4f", coordinate.latitude)
                    let lng = String(format: "%.4f", coordinate.longitude)
                    
                    // 💡 FIXED: Extract the clean city string parameters using standard placemark attributes safely
                    let formattedName = firstItem.placemark.locality ?? firstItem.name ?? query
                    
                    print("✅ [RADAR ENGINE]: Manual string lookup successful: \(lat), \(lng) for \(formattedName)")
                    
                    await MainActor.run {
                        self.locationName = formattedName
                        self.selectCityCoordinates(lat: lat, lng: lng)
                    }
                } else {
                    await MainActor.run {
                        self.errorMessage = "CITY NOT FOUND"
                        self.isTracking = false
                    }
                }
            } catch {
                print("❌ [RADAR ENGINE]: MapKit geocoding search block context failed: \(error)")
                await MainActor.run {
                    self.errorMessage = "SEARCH FAILED"
                    self.isTracking = false
                }
            }
        }
    }
}


// MARK: - 3. THE ISOLATED SUB-VIEW COMPONENT
struct SatelliteCardView: View {
    let sat: SatellitePass
    let location: String
    @ObservedObject private var favorites = FavoritesStore.shared
    
    // ✅ RESPONSIVE: Listens directly to the device window width size class environment
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    // ✅ RESPONSIVE: Calculates fluid proportional width boundaries without hardcoded pixels
    private var responsiveCardWidth: CGFloat {
        if horizontalSizeClass == .regular {
            return 260.0
        } else {
            return 190.0
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                Text(sat.name.uppercased())
                    .font(.system(horizontalSizeClass == .regular ? .body : .subheadline, design: .monospaced))
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .lineLimit(1)

                // 💡 FEAT-06: star this satellite to follow it -- scopes pass alerts to just
                // the satellites followed once at least one is starred.
                Button(action: { favorites.toggleSatellite(sat.id) }) {
                    Image(systemName: favorites.isSatelliteFavorite(sat.id) ? "star.fill" : "star")
                        .font(.system(size: 10))
                        .foregroundColor(favorites.isSatelliteFavorite(sat.id) ? .yellow : .gray.opacity(0.5))
                }
                .buttonStyle(PlainButtonStyle())
                .accessibilityLabel(favorites.isSatelliteFavorite(sat.id) ? "Unfollow \(sat.name)" : "Follow \(sat.name)")

                Spacer()

                // 💡 FEAT-08: share this pass as a short text summary via the native share
                // sheet -- upper-right corner of this same row, so it doesn't add card height.
                ShareLink(item: ShareContentBuilder.shareText(for: sat)) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.cyan.opacity(0.7))
                }
                .buttonStyle(PlainButtonStyle())
                .accessibilityLabel("Share \(sat.name)")
            }
            
            Text(sat.localDisplayTime.uppercased())
                .font(.system(horizontalSizeClass == .regular ? .subheadline : .caption, design: .monospaced))
                .foregroundColor(.yellow)
            
            if !location.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.system(size: horizontalSizeClass == .regular ? 11 : 10))
                    Text(location.uppercased())
                        .font(.system(size: horizontalSizeClass == .regular ? 11 : 10, design: .monospaced))
                        .lineLimit(1)
                }
                .foregroundColor(.cyan)
                .padding(.top, -2)
            }
            
            HStack(spacing: 4) {
                Image(systemName: "safari")
                    .font(.system(size: horizontalSizeClass == .regular ? 10 : 9))
                Text(sat.travelDirection.uppercased())
                    .font(.system(size: horizontalSizeClass == .regular ? 10 : 9, design: .monospaced))
                    .fontWeight(.semibold)
            }
            .foregroundColor(.green)
            .padding(.vertical, 2)
            
            HStack(spacing: 4) {
                Image(systemName: "scope")
                    .font(.caption2)
                Text("HEIGHT: \(Int(sat.peakElevationDegrees))°")
                    .font(.system(size: horizontalSizeClass == .regular ? 11 : 10, design: .monospaced))
                
                Spacer()
                
                Image(systemName: "clock")
                    .font(.caption2)
                Text("\(sat.durationMinutes) MIN")
                    .font(.system(size: horizontalSizeClass == .regular ? 11 : 10, design: .monospaced))
            }
            .foregroundColor(.gray)

            HStack {
                Spacer()
                Text("❯")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.cyan.opacity(0.45))
            }
        }
        .padding(horizontalSizeClass == .regular ? 16 : 14)
        // ✅ RESPONSIVE: Locked smoothly to size-class boundaries instead of a static point value
        .frame(width: responsiveCardWidth, alignment: .leading)
        .background(Color.white.opacity(0.04))
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}

// MARK: - 4. THE DETAILED MISSIONS PROFILE SHEET
struct SatelliteDetailSheet: View {
    @State private var presentFullScreenHUD = false
    let sat: SatellitePass
    @ObservedObject var weatherEngine: StargazingWeatherViewModel

    let location: String
    let userHeading: Double // ✅ FIXED: Explicitly added this plain primitive variable

    /// Caller's best-known coordinate (real GPS fix, or the Madison, WI fallback — see
    /// isUsingFallbackLocation below). Replaces a `CLLocationManager().location?.coordinate`
    /// read that used to happen right here: a fresh CLLocationManager instance has no
    /// authorization and no time to acquire a fix, so that read was essentially always nil,
    /// silently falling back to Madison every time regardless of the user's real permission
    /// state or actual location.
    let knownLatitude: Double
    let knownLongitude: Double
    /// True when knownLatitude/knownLongitude is the Madison, WI fallback rather than a real
    /// device fix, so this sheet can tell the user the weather readout below is approximate.
    let isUsingFallbackLocation: Bool

    @Environment(\.dismiss) var dismiss
    
    // Curated telemetry database for your 11 high-visibility targets
    private var missionProfile: (country: String, launched: String, type: String, summary: String) {
        let name = sat.name.uppercased()
        if name.contains("ISS") {
            return ("MULTINATIONAL", "1998-11-20", "HABITATION LAB", "THE INTERNATIONAL SPACE STATION SERVES AS A PERMANENT ORBITAL BASE FOR ASTROPHYSICS, BIOLOGY, AND MICROGRAVITY LABORATORY RESEARCH.")
        } else if name.contains("CSS") || name.contains("TIANHE") || name.contains("TIANGONG") || name.contains("SHENZHOU") {
            return ("CHINA", "2021-04-29", "HABITATION LAB", "THE TIANGONG CORE MODULE SERVES AS THE FOUNDATION FOR EXPANDED LONG-DURATION CHINESE ACADEMIC ORBITAL FLIGHTS.")
        } else if name.contains("HUBBLE") {
            return ("UNITED STATES (NASA)", "1990-04-24", "SPACE TELESCOPE", "THE DEEP SPACE OBSERVATORY TRACKS OPTICAL, ULTRAVIOLET, AND INFRARED SPECTRAL COSMIC TRAJECTORIES.")
        } else if name.contains("STARLINK") {
            return ("UNITED STATES (SPACEX)", "COMMERCIAL", "TELECOM CONSTELLATION", "LOW-EARTH ORBIT BROADBAND TRANSMISSION SATELLITE DESIGNED FOR GLOBAL HIGH-SPEED INTERNET LINK ROUTING.")
        } else if name.contains("X37-B") {
            return ("UNITED STATES (USAF)", "CLASSIFIED", "EXPERIMENTAL SPACEPLANE", "AUTONOMOUS REUSABLE MILITARY ROBOTIC VEHICLE CONDUCTING LONG-DURATION ORBITAL TECHNOLOGICAL FLIGHT TESTS.")
        } else if name.contains("ENVISAT") {
            return ("EUROPEAN UNION (ESA)", "2002-03-01", "ENVIRONMENTAL RADAR", "MASSIVE ACTIVE INFRASTRUCTURE ELEMENT DEDICATED TO RADAR ATMOSPHERIC AND EARTH FOOTPRINT TRACKING INTERCEPTS.")
        } else if name.contains("AQUA") {
            return ("UNITED STATES (NASA)", "2002-05-04", "EARTH OBSERVATION", "MULTINATIONAL RECONNAISSANCE PLATFORM STUDYING EARTH WATER CYCLES, PRECIPITATION, AND OCEAN EVAPORATION SIGNS.")
        } else if name.contains("TERRA") {
            return ("UNITED STATES (NASA)", "1999-12-18", "EARTH OBSERVATION", "PRIMARY FLAGSHIP SPECTRUM MONITOR ANALYZING THE GLOBAL SPREAD OF VEGETATION AND CLIMATE TRANSITIONS OVER HORIZONS.")
        }
        // FEAT-25 curated additions (2026-09-15): picked from the first real post-space-junk-filter
        // pass list -- real, verified satellites judged worth a real writeup, beyond the original
        // 9. Launch dates below use sat.launchYear (parsed live from this exact object's own TLE)
        // rather than a hardcoded date, since several of these are shared entries covering more
        // than one satellite (a whole family/constellation, or a name too generic to disambiguate),
        // so a single fixed date would be wrong for some of the satellites it matches.
        else if name.contains("AJISAI") {
            return ("JAPAN (NASDA)", sat.launchYear ?? "1986", "GEODETIC SATELLITE", "A SPHERE COVERED IN OVER 1,400 MIRRORS, BUILT SPECIFICALLY TO REFLECT SUNLIGHT AND LASER RANGING BEAMS FOR PRECISE EARTH-SHAPE MEASUREMENTS -- ONE OF THE FEW SATELLITES EVER DESIGNED FROM THE START TO BE THIS BRIGHT.")
        } else if name.contains("SAOCOM") {
            return ("ARGENTINA (CONAE)", sat.launchYear ?? "UNKNOWN", "RADAR EARTH OBSERVATION", "L-BAND RADAR SATELLITE FOR SOIL MOISTURE, AGRICULTURE, AND EMERGENCY/DISASTER MONITORING -- FLIES AS PART OF A JOINT CONSTELLATION WITH ITALY'S COSMO-SKYMED RADAR SATELLITES.")
        } else if name.contains("COSMO-SKYMED") {
            return ("ITALY (ASI)", sat.launchYear ?? "UNKNOWN", "RADAR EARTH OBSERVATION", "X-BAND RADAR IMAGING SATELLITE, PART OF A DUAL CIVIL/MILITARY ITALIAN CONSTELLATION USED FOR DISASTER RESPONSE, MARITIME SURVEILLANCE, AND MAPPING.")
        } else if name.contains("ERS-1") {
            return ("EUROPEAN UNION (ESA)", sat.launchYear ?? "1991", "RADAR EARTH OBSERVATION", "EUROPE'S FIRST EARTH REMOTE-SENSING SATELLITE -- RADAR IMAGING OF OCEANS, ICE, AND LAND. RETIRED IN 2000 AFTER NEARLY A DECADE OF SERVICE.")
        } else if name.contains("ISIS 1") {
            return ("CANADA (WITH NASA)", sat.launchYear ?? "1969", "IONOSPHERIC RESEARCH SATELLITE", "ONE OF CANADA'S EARLIEST SATELLITES, PART OF A JOINT CANADA-US PROGRAM STUDYING THE IONOSPHERE AND UPPER ATMOSPHERE.")
        } else if name.contains("OAO 2") {
            return ("UNITED STATES (NASA)", sat.launchYear ?? "1968", "SPACE TELESCOPE", "THE FIRST SUCCESSFUL ORBITING ASTRONOMICAL OBSERVATORY -- AN EARLY UV SPACE TELESCOPE AND A DIRECT PRECURSOR TO HUBBLE.")
        } else if name.contains("OAO 3") {
            return ("UNITED STATES (NASA)", sat.launchYear ?? "1972", "SPACE TELESCOPE", "NICKNAMED \"COPERNICUS\" -- FOLLOWED UP OAO-2 WITH X-RAY AND ULTRAVIOLET ASTRONOMY INSTRUMENTS.")
        } else if name.contains("SERT 2") {
            return ("UNITED STATES (NASA)", sat.launchYear ?? "1970", "ION PROPULSION TECH DEMO", "TESTED ONE OF THE EARLIEST ELECTRIC ION THRUSTERS FLOWN IN ORBIT -- THE SAME BASIC TECHNOLOGY MANY MODERN SATELLITES NOW USE FOR STATION-KEEPING.")
        } else if name.contains("ADEOS") {
            return ("JAPAN (JAXA)", sat.launchYear ?? "2002", "EARTH OBSERVATION", "CLIMATE AND OCEAN/ATMOSPHERE MONITORING SATELLITE, ALSO KNOWN AS MIDORI II -- MISSION ENDED AFTER ABOUT 10 MONTHS DUE TO A SOLAR-POWER SYSTEM FAILURE.")
        } else if name.contains("ALOS") {
            return ("JAPAN (JAXA)", sat.launchYear ?? "2006", "EARTH OBSERVATION", "ALSO KNOWN AS DAICHI -- A HIGH-RESOLUTION LAND-IMAGING SATELLITE USED FOR MAPPING, DISASTER RESPONSE, AND RESOURCE SURVEYING.")
        } else if name.contains("ORBVIEW") {
            return ("UNITED STATES (ORBITAL SCIENCES)", sat.launchYear ?? "1997", "OCEAN COLOR OBSERVATION", "CARRIED THE SEAWIFS SENSOR, WHICH PROVIDED NEARLY A DECADE OF GLOBAL OCEAN-COLOR AND VEGETATION DATA FOR CLIMATE RESEARCH.")
        } else if name.contains("SPACEMOBILE") {
            return ("UNITED STATES (AST SPACEMOBILE)", sat.launchYear ?? "UNKNOWN", "DIRECT-TO-PHONE BROADBAND", "PART OF A NEW CONSTELLATION WITH HUGE PHASED-ARRAY ANTENNAS BUILT TO CONNECT DIRECTLY TO ORDINARY, UNMODIFIED SMARTPHONES -- THEIR SIZE IS EXACTLY WHY THEY'RE BRIGHT ENOUGH TO NOTICE.")
        } else if name.contains("ACS3") {
            return ("UNITED STATES (NASA)", sat.launchYear ?? "2024", "SOLAR SAIL TECH DEMO", "NASA'S ADVANCED COMPOSITE SOLAR SAIL SYSTEM -- UNFURLED A LARGE REFLECTIVE SAIL FROM A SMALL CUBESAT TO TEST LIGHTWEIGHT DEPLOYABLE BOOMS, BECOMING ONE OF THE BRIGHTER OBJECTS IN THE SKY PURELY BECAUSE OF ITS SIZE.")
        } else if name.contains("INTERCOSMOS") {
            return ("SOVIET UNION / RUSSIA", sat.launchYear ?? "UNKNOWN", "SPACE PHYSICS RESEARCH", "PART OF THE INTERCOSMOS PROGRAM -- A COLD WAR-ERA COOPERATIVE EFFORT BETWEEN THE USSR AND ALLIED NATIONS STUDYING THE IONOSPHERE, MAGNETOSPHERE, AND NEAR-EARTH SPACE ENVIRONMENT.")
        } else if name.contains("YAOGAN") {
            return ("CHINA", sat.launchYear ?? "UNKNOWN", "REMOTE SENSING SATELLITE", "OFFICIALLY DESIGNATED FOR CIVILIAN REMOTE SENSING AND DISASTER/RESOURCE MONITORING, THOUGH THE YAOGAN SERIES IS WIDELY BELIEVED TO ALSO SERVE CHINESE MILITARY RECONNAISSANCE.")
        } else if name.contains("OKEAN") {
            return ("UKRAINE / RUSSIA", sat.launchYear ?? "1999", "OCEAN & EARTH OBSERVATION", "JOINT UKRAINIAN-RUSSIAN SATELLITE CARRYING RADAR AND MULTISPECTRAL SENSORS TO MONITOR OCEANS, ICE, AND VEGETATION -- MISSION CUT SHORT BY AN ATTITUDE-CONTROL FAILURE ABOUT A YEAR IN.")
        } else if name.contains("ASTEX") {
            return ("UNITED STATES (USAF)", sat.launchYear ?? "1971", "EXPERIMENTAL TECH SATELLITE", "TESTED A LARGE DEPLOYABLE FLEXIBLE SOLAR ARRAY AND AN INFRARED SENSOR FOR THE AIR FORCE'S SPACE TEST PROGRAM -- OPERATED UNTIL A TRANSMITTER FAILURE IN 1973.")
        } else if name.contains("USA ") {
            return ("UNITED STATES (CLASSIFIED)", sat.launchYear ?? "UNKNOWN", "CLASSIFIED PAYLOAD", "\"USA\" IS A GENERIC COVER DESIGNATION USED FOR CLASSIFIED U.S. GOVERNMENT SATELLITES -- THE SPECIFIC MISSION BEHIND THIS PARTICULAR ONE ISN'T PUBLICLY DISCLOSED.")
        } else if name.contains("COSMOS") {
            return ("SOVIET UNION / RUSSIA", sat.launchYear ?? "UNKNOWN", "MILITARY / SCIENTIFIC SATELLITE", "\"COSMOS\" IS THE GENERIC NAME THE USSR (AND LATER RUSSIA) GAVE TO THOUSANDS OF SATELLITES ACROSS EVERY PROGRAM -- MILITARY RECONNAISSANCE, NAVIGATION, EARLY-WARNING, AND SCIENTIFIC RESEARCH ALIKE. FOR MOST INDIVIDUAL COSMOS SATELLITES, INCLUDING THIS ONE, THE EXACT MISSION WAS NEVER PUBLICLY DISCLOSED.")
        }
        // FEAT-25 follow-up (2026-09-15): satellites without a hand-written entry above now
        // get a real launch year (parsed server-side from the TLE itself) instead of a
        // hardcoded "UNKNOWN" -- still generic on country/type/summary since we have no
        // catalog lookup for those, but at least one real fact instead of none. See FEAT-25
        // backlog note for growing the hand-written list above as specific satellites are spotted.
        let launched = sat.launchYear ?? "UNKNOWN"
        return ("INTERNATIONAL", launched, "ORBITAL PAYLOAD", "HIGH-VISIBILITY TARGET TRACKED IN REAL-TIME BY HORIZON COMPASS SURVEILLANCE RADAR RAILS.")
    }
    
    var body: some View {
        ZStack {
            Color(red: 0.04, green: 0.04, blue: 0.04).ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(sat.name.uppercased())
                                .font(.system(.title2, design: .monospaced))
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            Text("NORAD CATALOG ID: #\(sat.id)")
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundColor(.cyan)
                        }
                        
                        Spacer()
                        
                        HStack(spacing: 12) {
                            Button(action: { presentFullScreenHUD = true }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "arkit")
                                        .font(.caption)
                                    Text("ENGAGE RADAR HUD")
                                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                                }
                                .foregroundColor(.cyan)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.cyan.opacity(0.08))
                                .cornerRadius(4)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4)
                                        .stroke(Color.cyan.opacity(0.2), lineWidth: 1)
                                )
                            }
                            
                            Button(action: { dismiss() }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    .padding(.bottom, 8)
                    
                    // Live Calibrated Radar Component View
                    GeometryReader { radarGeometry in
                        HStack {
                            Spacer()
                            CompassRadarView(pass: sat, userHeading: userHeading)
                                .aspectRatio(1, contentMode: .fit)
                                // ✅ PURE % OF VIEWPORT WIDTH: Hard-clamps to exactly 55% of the screen box size
                                .frame(width: radarGeometry.size.width * 0.55)
                            Spacer()
                        }
                    }
                    // Uses the viewport width directly to calculate responsive aspect constraints without any size classes
                    .aspectRatio(1.6, contentMode: .fit)
                    .contentShape(Circle())
                    .onTapGesture {
                        presentFullScreenHUD = true
                    }
                    .accessibilityLabel("Full screen tactical view")
                    .accessibilityHint("Opens a larger radar display")
                    .accessibilityAddTraits(.isButton)
                    
                    VStack(spacing: 0) {
                        telemetryRow(label: "ORIGIN REALM", value: missionProfile.country)
                        telemetryRow(label: "LAUNCH TIMELINE", value: missionProfile.launched)
                        telemetryRow(label: "PLATFORM TYPE", value: missionProfile.type)
                        telemetryRow(label: "OBSERVER LOCATION", value: location.isEmpty ? "CURRENT POSITION" : location.uppercased())
                        if isUsingFallbackLocation {
                            telemetryRow(label: "LOCATION SOURCE", value: "APPROXIMATE — ENABLE LOCATION")
                        }
                        telemetryRow(label: "FLIGHT TRAJECTORY", value: sat.travelDirection.uppercased())
                        telemetryRow(label: "MAX ELEVATION", value: "\(Int(sat.peakElevationDegrees))° ANGLE")
                        telemetryRow(label: "WINDOW DURATION", value: "\(sat.durationMinutes) MINUTES")
                        
                        // 💡 INTEGRATED WEATERKIT DATA MATRIX: Appended directly inside your original table container row
                        if weatherEngine.isLoading {
                            telemetryRow(label: "ATMOSPHERIC RADAR", value: "POLLING APPLE WEATHER ENGINE...")
                        } else {
                            telemetryRow(label: "LOCAL CLOUD COVER", value: "\(weatherEngine.cloudCoverPercent)% CLOUDS")
                            telemetryRow(label: "RELATIVE MOISTURE", value: "\(weatherEngine.humidityPercent)% HUMIDITY")
                            telemetryRow(label: "SKY OPTICAL RATING", value: weatherEngine.observationRating)
                        }
                    }
                    .border(Color.white.opacity(0.1), width: 1)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("MISSION OBJECTIVES //")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.yellow)
                        Text(missionProfile.summary)
                            .font(.system(.subheadline, design: .monospaced))
                            .foregroundColor(.gray)
                            .lineSpacing(4)
                    }
                }
                .padding(24)
            }
        }
        .preferredColorScheme(.dark)
        .fullScreenCover(isPresented: $presentFullScreenHUD) {
            SatelliteTacticalHUDView(pass: sat, userHeading: userHeading)
        }
        // 💡 SECURE TASK MODIFIER HOOK: Triggers background telemetry download exactly on overlay bootup
        .task {
            await weatherEngine.fetchStargazingWeather(lat: knownLatitude, lng: knownLongitude, targetISO8601Date: sat.utcTimeISO)
        }
    }
    
    // Kept helper function declaration scope clean assuming implementation exists below
    private func telemetryRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.gray)
            Spacer()
            Text(value)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.01))
        .overlay(Rectangle().stroke(Color.white.opacity(0.04), lineWidth: 0.5))
    }
}
