//
//  CelestialProfileEngine.swift
//  spaceTracker
//
//  Created by Ben Clary on 8/27/26.
//  make and app that colin loves

import Foundation
import SwiftUI

// MARK: - 📥 STATIC COMPONENT DATA MODEL CONTRACT
struct CelestialProfile: Identifiable, Codable {
    var id: String { name.uppercased() }
    let name: String
    let subTitle: String
    let assetImageName: String? 
    let encyclopediaSummary: String
    let classification: String
    var liveAltitude: Double? = nil
    var liveAzimuth: Double? = nil
    var liveDistanceAU: Double? = nil
}

// MARK: - 🗄️ MASTER OFFLINE ENCYCLOPEDIA REGISTRY STORAGE
struct CelestialDatabaseRegistry {
    
    // Custom color property mapping our interactive stars to Electric Blue!
    static let electricBlue = Color(red: 0.0, green: 0.6, blue: 1.0)
    
    static let profiles: [String: CelestialProfile] = [
        // ==============================================================================
        // 🪐 THE CORE PLANETS (WITH FULL-GLOBE PORTRAITS)
        // ==============================================================================
        "MERCURY": CelestialProfile(
            name: "Mercury",
            subTitle: "THE FIRST PLANET",
            assetImageName: "mercury",
            encyclopediaSummary: "The smallest and closest planet to the Sun. Mercury experiences extreme temperature swings, fluctuating from baking daytime heat to frozen night drops due to its lack of a protective atmosphere.",
            classification: "PLANET"
        ),
        "VENUS": CelestialProfile(
            name: "Venus",
            subTitle: "THE SECOND PLANET",
            assetImageName: "venus",
            encyclopediaSummary: "This Sun-chasing world, named for the Roman goddess of love and beauty, is the brightest planet in our night sky. It is often dubbed 'Earth's Twin' due to its similar size and mass.",
            classification: "PLANET"
        ),
        "MARS": CelestialProfile(
            name: "Mars",
            subTitle: "THE RED DESERT PLANET",
            assetImageName: "mars",
            encyclopediaSummary: "A cold, dusty desert world with a very thin carbon dioxide atmosphere. Mars features massive extinct volcanoes and deep canyon systems, making it a primary destination for future exploration.",
            classification: "PLANET"
        ),
        "JUPITER": CelestialProfile(
            name: "Jupiter",
            subTitle: "THE GAS GIANT MASTER",
            assetImageName: "jupiter",
            encyclopediaSummary: "The largest planet in our solar system, packing more mass than all other planets combined. It is a massive ball of hydrogen and helium gas, famous for its centuries-old Great Red Spot storm.",
            classification: "PLANET"
        ),
        "SATURN": CelestialProfile(
            name: "Saturn",
            subTitle: "THE RINGED ICON",
            assetImageName: "saturn",
            encyclopediaSummary: "A massive gas giant planet adorned with a dazzling, complex system of thousands of icy rings. It is the least dense planet in the system, composed mostly of hydrogen.",
            classification: "PLANET"
        ),
        
        // ==============================================================================
        // ✦ MULTI-TIER STARS & NEIGHBORS (TEXT & VECTOR ICON EXCLUSIVES)
        // ==============================================================================
        "SIRIUS": CelestialProfile(
            name: "Sirius",
            subTitle: "THE BLAZING DOG STAR",
            assetImageName: nil, // Nil tells the card layout to render a vector icon layout smoothly
            encyclopediaSummary: "The absolute brightest star visible in Earth's night sky, sitting within the Canis Major constellation matrix. Sirius is actually a binary star system containing a bright main-sequence star and a dense, white dwarf companion star.",
            classification: "STAR"
        ),
        "BETELGEUSE": CelestialProfile(
            name: "Betelgeuse",
            subTitle: "THE RED SUPERGIANT HEART",
            assetImageName: nil,
            encyclopediaSummary: "A massive, dying red supergiant star marking the shoulder point of Orion. Betelgeuse is so bloated that if placed in our solar system, its surface would swallow Mars and Jupiter. It is expected to detonate as a brilliant supernova within astronomical timelines.",
            classification: "STAR"
        ),
        "RIGEL": CelestialProfile(
            name: "Rigel",
            subTitle: "THE BLUE SUPERGIANT FOOT",
            assetImageName: nil,
            encyclopediaSummary: "A blazing blue supergiant star representing the left foot of Orion the Hunter. Rigel shines with the blinding light of roughly 120,000 Suns combined, illuminating massive dust clouds across its deep-space neighborhood sector.",
            classification: "STAR"
        ),
        "VEGA": CelestialProfile(
            name: "Vega",
            subTitle: "THE SUMMER SKY ANCHOR",
            assetImageName: nil,
            encyclopediaSummary: "A bright blue-white star in the Lyra constellation. Vega is incredibly important to astronomy because it served as the baseline standard for measuring the brightness scale of all stars in the universe for decades.",
            classification: "STAR"
        ),
        "POLARIS": CelestialProfile(
            name: "Polaris",
            subTitle: "THE STATIONARY NORTH STAR",
            assetImageName: nil,
            encyclopediaSummary: "The pivot point star of the northern hemisphere sky. Polaris sits almost perfectly aligned with the Earth's northern rotational axis vector. Because of this, it remains completely frozen in the exact same spot in the sky while the entire night dome rotates around it.",
            classification: "STAR"
        ),
        "PROCYON": CelestialProfile(
            name: "Procyon",
            subTitle: "THE LITTLE CANINE STAR",
            assetImageName: nil,
            encyclopediaSummary: "The brightest star in Canis Minor, representing the lesser dog companion trailing behind Orion. Procyon is a bright white star that is rapidly expanding as it finishes burning the core hydrogen fuel supplies of its main life cycle.",
            classification: "STAR"
        ),
        "ANTARES": CelestialProfile(
            name: "Antares",
            subTitle: "THE HEART OF THE SCORPION",
            assetImageName: nil,
            encyclopediaSummary: "A colossal red supergiant star burning fiercely at the center of Scorpius. Its fiery orange appearance makes it easily mistaken for Mars with the bare eye, which is why ancient cultures named it Antares, translating directly to 'The Rival of Mars.'",
            classification: "STAR"
        ),
        "ALDEBARAN": CelestialProfile(
            name: "Aldebaran",
            subTitle: "THE FIERY EYE OF TAURUS",
            assetImageName: nil,
            encyclopediaSummary: "A giant, reddish-orange star marking the eye of Taurus the Bull. Aldebaran is an aging star that has expanded to 44 times the diameter of our Sun, throwing out massive stellar winds into the surrounding interstellar space tracks.",
            classification: "STAR"
        ),
        "CAPELLA": CelestialProfile(
            name: "Capella",
            subTitle: "THE GOLDEN GOAT SYSTEM",
            assetImageName: nil,
            encyclopediaSummary: "The brightest stellar node inside Auriga. While Capella looks like a single golden point to human eyes, it is actually a tight family of four distinct stars bound together by gravity—containing two large yellow giants orbiting each other.",
            classification: "STAR"
        ),
        "ARCTURUS": CelestialProfile(
            name: "Arcturus",
            subTitle: "THE FAST-MOVING WIND STAR",
            assetImageName: nil,
            encyclopediaSummary: "A brilliant orange giant star located in Bootes. Arcturus is ancient, forming long before our solar system. It is currently tearing through our sector of the Milky Way galaxy at an incredible speed of over 260,000 miles per hour.",
            classification: "STAR"
        ),
        // 💡 FIXED: Keys changed from "THE_SUN"/"THE_MOON" to plain "SUN"/"MOON" — the
        // telemetry model tracks these bodies under the short name (trackingCelestialBodies
        // = ["SUN", "MOON", ...]), and the info-icon lookup in LiveSkyViewfinderOverlay does
        // an exact-match dictionary lookup on object.name.uppercased(). "THE_SUN" != "SUN",
        // so the lookup always came back nil for both — hasProfileInfo was false, so the
        // info icon (and tapping through to the detail sheet) never appeared for either body,
        // even though their entries existed here the whole time.
        "SUN": CelestialProfile(
            name: "The Sun",
            subTitle: "OUR SYSTEM ANCHOR",
            assetImageName: nil,
            encyclopediaSummary: "The yellow dwarf star sitting at the absolute center of our system. Accounting for 99.8% of the entire solar system's mass, its immense gravitational field and thermal heat drive the lifecycle and orbital tracking geometry of every planet.",
            classification: "STAR"
        ),
        "MOON": CelestialProfile(
            name: "The Moon",
            subTitle: "OUR NEIGHBOR SATELLITE",
            assetImageName: nil,
            encyclopediaSummary: "Earth's only natural satellite. The Moon is tidally locked to our planet, meaning it always shows us the exact same face. Its changing reflection angles create the familiar crescent and full illumination cycles on your camera viewport glass.",
            // 💡 FIXED: was "STAR" — left over from when the Sun and Moon were the only two
            // non-planet bodies and both got lumped under the same placeholder value. The
            // Sun's "STAR" is actually correct astronomically, so that one was never wrong;
            // the Moon's was, and it renders directly as visible on-screen text in
            // CelestialDetailSheet ("CLASSIFICATION: STAR"), not just an internal value.
            classification: "MOON"
        )
    ]
}

// MARK: - 🛠️ EXTENDED DATA TRACKER CONTRACT REGISTRY
extension CelestialDatabaseRegistry {
    
    // 💡 HIGH-VALUE SORTED TARGET LIST:
    // A clean, sorted sequence containing exactly your 5 core planets, the Sun, the Moon,
    // and your 10 navigation stars, which feeds the hamburger navigation drawer list natively!
    static let interactiveTargetsList: [String] = [
        "MERCURY", "VENUS", "MARS", "JUPITER", "SATURN",
        "SIRIUS", "BETELGEUSE", "RIGEL", "VEGA", "POLARIS",
        "PROCYON", "ANTARES", "ALDEBARAN", "CAPELLA", "ARCTURUS", "SUN", "MOON"
    ].sorted()
}
