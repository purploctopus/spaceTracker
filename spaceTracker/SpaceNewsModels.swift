//
//  SpaceNewsModels.swift
//  spaceTracker
//
//  Created by Ben Clary on 8/12/26.
//  MAKE AN APP COLIN LOVES AND SUPPORTS SARA'S HAPPINESS
//  https://raw.githubusercontent.cm/purploctopus/orbitlog-news-tracker/main/news.json

import Foundation
import Combine

// MARK: - 📰 SPACEFLIGHT NEWS API V4 ITEM DECODER MODEL
struct SpaceNewsArticle: Codable, Identifiable {
    let id: Int
    let title: String
    let summary: String
    let imageUrl: String
    let newsSite: String
    let publishedAt: String
    let url: String
    
    // Explicit map layout matching your flat repository JSON property keys perfectly
    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case summary
        case imageUrl
        case newsSite
        case publishedAt
        case url
    }
}

// MARK: - 🎯 APP STATE SPACE NEWS BINDING LAYOUT
class SpaceNewsState: ObservableObject {
    @Published var topStories: [SpaceNewsArticle] = []
    @Published var isNewsLoaded: Bool = false
}

// ==============================================================================
// 🚀 MAIN NEWS MANAGEMENT VIEW MODEL
// ==============================================================================
class SpaceNewsViewModel: ObservableObject {
    @Published var newsState = SpaceNewsState()
    
    /// Pulls the flat pre-computed news list directly from your personal GitHub CDN bucket on app launch
    func loadLatestSpaceNews() async {
        // 💡 THE DATA LINK: Points directly to your clean flat repository text file path!
        //https://raw.githubusercontent.cm/purploctopus/orbitlog-news-tracker/main/news.json
        guard let url = URL(string: "https://raw.githubusercontent.com/purploctopus/orbitlog-news-tracker/main/news.json") else {
            print("❌ [NEWS CHANNEL ERROR]: Repository link configuration is invalid.")
            return
        }
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 5.0
        let secureSession = URLSession(configuration: config)
        
        do {
            let (data, _) = try await secureSession.data(from: url)
            let decodedArticles = try JSONDecoder().decode([SpaceNewsArticle].self, from: data)
            
            // Securely write values back down to your main SwiftUI rendering thread variables
            DispatchQueue.main.async {
                self.newsState.topStories = decodedArticles
                self.newsState.isNewsLoaded = true
                print("🌐 [NEWS CDN SUCCESS]: Loaded \(decodedArticles.count) space stories smoothly.")
            }
        } catch {
            print("❌ [NEWS PROCESSING CRASH]: Failed to unbox JSON asset payload: \(error)")
        }
    }
}
