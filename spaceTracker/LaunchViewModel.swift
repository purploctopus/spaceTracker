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
    @Published var launches: [SpaceLaunch] = [] // 💡 Renamed to SpaceLaunch
    @Published var isLoading = false
    @Published var errorMessage: String? = nil
    
    func fetchLaunches() async {
        guard let url = URL(string: "https://purploctopus.github.io/launches.json") else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            // Set cache policy to reload so we always check your fresh daily updates
            request.cachePolicy = .reloadIgnoringLocalCacheData
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                throw URLError(.badServerResponse)
            }
            
            let decodedPayload = try JSONDecoder().decode(LaunchResponse.self, from: data)
            self.launches = decodedPayload.results
            
        } catch {
            self.errorMessage = "Failed to load timeline: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
}
