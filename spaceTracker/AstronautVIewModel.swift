//
//  AstronautVIewModel.swift
//  spaceTracker
//
//  Created by Ben Clary on 6/25/26.
//  make an app colin loves

import Foundation
import SwiftUI
import Combine

// MARK: - 1. OPEN NOTIFY DECODER MODELS
struct OpenNotifyRosterResponse: Decodable {
    let number: Int
    let people: [Astronaut]
    let message: String
}

struct Astronaut: Decodable, Identifiable {
    var id: String { name } // Uses the name as a unique identifier string token
    let name: String
    let craft: String
}

// MARK: - 2. THE OPEN-NOTIFY VIEW MODEL
@MainActor
class AstronautViewModel: ObservableObject {
    @Published var totalHumansInOrbit: Int = 0
    @Published var issCrew: [Astronaut] = []
    @Published var tiangongCrew: [Astronaut] = []
    @Published var otherCrew: [Astronaut] = []
    @Published var isLoading = false
    @Published var errorMessage: String? = nil
    
    // 💡 DIRECT ACCESS: Points directly to the open public json endpoint with the correct hyphen
    private let openNotifyURLString = "http://api.open-notify.org/astros.json"
    
    func fetchAstronautRoster() async {
        isLoading = true
        errorMessage = nil
        print (openNotifyURLString)
        guard let url = URL(string: openNotifyURLString) else { return }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                self.errorMessage = "MANIFEST SERVER BUSY"
                self.isLoading = false
                return
            }
            
            let decoded = try JSONDecoder().decode(OpenNotifyRosterResponse.self, from: data)
            
            self.totalHumansInOrbit = decoded.number
            
            // 💡 DYNAMIC GROUPING: Sort the flat roster array into distinct spacecraft bins on the fly
            self.issCrew = decoded.people.filter { $0.craft.uppercased().contains("ISS") }
            self.tiangongCrew = decoded.people.filter { $0.craft.uppercased().contains("TIANGONG") || $0.craft.uppercased().contains("CSS") }
            self.otherCrew = decoded.people.filter { !$0.craft.uppercased().contains("ISS") && !$0.craft.uppercased().contains("TIANGONG") && !$0.craft.uppercased().contains("CSS") }
            
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
        }
        .padding(14)
        .frame(width: 280, alignment: .top)
        .background(Color.white.opacity(0.04))
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}
