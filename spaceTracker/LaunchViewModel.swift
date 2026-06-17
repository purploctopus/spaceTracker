//
//  LaunchViewModel.swift
//  spaceTracker
//
//  Created by Ben Clary on 6/17/26.
//

import Foundation
import Combine
import SwiftUI

@MainActor
class LaunchViewModel: ObservableObject {
    @Published var launches: [SpaceLaunch] = []
    @Published var isLoading = false
    @Published var errorMessage: String? = nil
    
    func fetchLaunches() async {
        guard let url = URL(string: "https://purploctopus.github.io/launches.json") else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            // 1. Build the network request
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.cachePolicy = .reloadIgnoringLocalCacheData
            
            // 2. Fire the background network fetch
            let (data, response) = try await URLSession.shared.data(for: request)
            
            // 3. Validate the server response status
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                throw URLError(.badServerResponse)
            }
            
            // 4. Decode the data payload
            let decodedPayload = try JSONDecoder().decode(LaunchResponse.self, from: data)
            self.launches = decodedPayload.results
            
            // 5. DIAGNOSTIC PRINT: Scans the file and logs live feeds down to the Xcode console
            let linkedMissions = self.launches.filter { !($0.vid_urls ?? []).isEmpty }
            print("📺 DATA STREAM REPORT: \(linkedMissions.count) OUT OF \(self.launches.count) UPCOMING LAUNCHES HAVE LIVE VIDEO LINKS ATTACHED.")
            
            for launch in linkedMissions {
                if let firstUrl = launch.vid_urls?.first?.url {
                    print("🔗 MISSION: \(launch.name) -> VIDEO FEED: \(firstUrl)")
                }
            }
            
        } catch {
            self.errorMessage = "Failed to load timeline: \(error.localizedDescription)"
            print("❌ NETWORK ENGINE FAILURE: \(error)")
        }
        
        isLoading = false
    }
}

