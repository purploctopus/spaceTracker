//
//  spaceRocksEngine.swift
//  spaceTracker
//
//  Created by Ben Clary on 6/22/26.
//  MAKE AN APP COLIN LOVES

import Foundation
import Combine
import SwiftUI

// MARK: - 1. DECODER MODELS
struct CloudflareAsteroidResponse: Decodable {
    let asteroids: [Asteroid]
}

struct Asteroid: Decodable, Identifiable {
    let id: String
    let name: String
    let is_potentially_hazardous_asteroid: Bool
    let estimated_diameter_max: Double
    let close_approach_date: String
    let miss_distance_lunar: String
    
    var maxDiameterMeters: Int {
        return Int(estimated_diameter_max)
    }
    
    var missDistanceLunar: Int {
        if let doubleVal = Double(miss_distance_lunar) {
            return Int(doubleVal)
        }
        return 0
    }
    
    var localDateDisplay: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: close_approach_date) else { return close_approach_date }
        
        // 💡 FIXED: Resolved typo from MRM d to MMM d for a clean calendar printout
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date).uppercased()
    }
}

// MARK: - 2. THE DEDICATED VIEW MODEL
@MainActor
class SpaceRocksViewModel: ObservableObject {
    @Published var asteroids: [Asteroid] = []
    @Published var isLoading = false
    @Published var errorMessage: String? = nil
    
    // 💡 LOCKED: Pointed directly to your new independent asteroid cloud worker
    private let workerURLString = "https://space-rocks-worker.purploctopus.workers.dev"
    
    func fetchAsteroidRadar() async {
        isLoading = true
        errorMessage = nil
        
        guard let url = URL(string: workerURLString) else { return }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                self.errorMessage = "CLOUD SERVICE TIMEOUT"
                self.isLoading = false
                return
            }
            
            let decoded = try JSONDecoder().decode(CloudflareAsteroidResponse.self, from: data)
            self.asteroids = decoded.asteroids
            self.isLoading = false
        } catch let decodingError as DecodingError {
            // Unmasks key and schema faults instantly if payload properties change
            switch decodingError {
            case .typeMismatch(let type, _):
                self.errorMessage = "TYPE FAULT: \(type)"
            case .valueNotFound(let value, _):
                self.errorMessage = "VALUE MISSING: \(value)"
            case .keyNotFound(let key, _):
                self.errorMessage = "MISSING KEY: \(key.stringValue)"
            case .dataCorrupted(_):
                self.errorMessage = "PAYLOAD CORRUPTED"
            @unknown default:
                self.errorMessage = "DECODING CONFIG ERROR"
            }
            print("❌ NASA DECODER LOG: \(decodingError)")
            self.isLoading = false
        } catch {
            self.errorMessage = "NETWORK INTERCEPT FAULT"
            self.isLoading = false
        }
    }
}

// MARK: - 3. UI SUB-VIEW: ASTEROID RADAR MONITOR CELL CARD
struct AsteroidCardView: View {
    let asteroid: Asteroid
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(asteroid.name.uppercased())
                    .font(.system(.subheadline, design: .monospaced))
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .lineLimit(1)
                Spacer()
                
                if asteroid.is_potentially_hazardous_asteroid {
                    Text("⚠️ HAZARD")
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                        .foregroundColor(.red)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.red.opacity(0.15))
                        .border(Color.red.opacity(0.4), width: 1)
                } else {
                    Text("SAFE")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(.green)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.green.opacity(0.1))
                }
            }
            
            Text("APPROACH: \(asteroid.localDateDisplay)")
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.yellow)
            
            HStack(spacing: 12) {
                HStack(spacing: 3) {
                    Image(systemName: "arrow.down.forward.and.arrow.up.backward")
                        .font(.system(size: 10))
                    Text("MISS: \(asteroid.missDistanceLunar)LD")
                        .font(.system(size: 10, design: .monospaced))
                }
                
                HStack(spacing: 3) {
                    Image(systemName: "circle.circle")
                        .font(.system(size: 10))
                    Text("SIZE: \(asteroid.maxDiameterMeters)M")
                        .font(.system(size: 10, design: .monospaced))
                }
            }
            .foregroundColor(.gray)
        }
        .padding(14)
        .frame(width: 240, alignment: .leading)
        .background(Color.white.opacity(0.04))
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(asteroid.is_potentially_hazardous_asteroid ? Color.red.opacity(0.3) : Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}
