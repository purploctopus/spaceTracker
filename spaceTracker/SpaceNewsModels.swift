//
//  SpaceNewsModels.swift
//  spaceTracker
//
//  Created by Ben Clary on 8/12/26.
//  MAKE AN APP COLIN LOVES AND SUPPORTS SARA'S HAPPINESS
//  https://raw.githubusercontent.cm/purploctopus/orbitlog-news-tracker/main/news.json
//  https://raw.githubusercontent.com/purploctopus/orbitlog-news-tracker/main/news_page\(newsState.currentPage).json

import Foundation
import Combine

import Foundation
import Combine

// MARK: - 📰 SPACEFLIGHT NEWS API V4 ITEM DECODER MODEL
struct SpaceNewsArticle: Codable, Identifiable, Equatable {
    let id: Int
    let title: String
    let summary: String
    let imageUrl: String
    let newsSite: String
    let publishedAt: String
    let url: String
    
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
    
    // 💡 THE PAGINATION TRACKERS: Keeps track of where the user is scrolling
    var currentPage: Int = 1
    let maxPages: Int = 10
    var isFetchingNextPage: Bool = false
}

// ==============================================================================
// 🚀 MAIN NEWS MANAGEMENT VIEW MODEL
// ==============================================================================
class SpaceNewsViewModel: ObservableObject {
    @Published var newsState = SpaceNewsState()
    
    /// Pulls a specific numbered news page directly from your personal GitHub CDN bucket
    func loadLatestSpaceNews() async {
        // Reset state tracker parameters to ensure a clean boot sequence layout
        self.newsState.currentPage = 1
        self.newsState.topStories = []
        self.newsState.isNewsLoaded = false
        
        await fetchNextPagePayload()
    }
    
    /// Increments the page page index track loop counter and downloads the next block of 10 articles
    func fetchNextPagePayload() async {
        // Safety guard checks to prevent multi-triggering network calls simultaneously
        guard !newsState.isFetchingNextPage else { return }
        guard newsState.currentPage <= newsState.maxPages else { return }
        
        newsState.isFetchingNextPage = true
        
        // 💡 THE MULTI-PAGE CDN LINK: Points directly to your specific numbered page files on the fly!
        let pageUrlString = "https://raw.githubusercontent.com/purploctopus/orbitlog-news-tracker/main/news_page\(newsState.currentPage).json"
        print (pageUrlString)
        guard let url = URL(string: pageUrlString) else {
            newsState.isFetchingNextPage = false
            return
        }
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 5.0
        let secureSession = URLSession(configuration: config)
        
        do {
            let (data, _) = try await secureSession.data(from: url)
            let decodedArticles = try JSONDecoder().decode([SpaceNewsArticle].self, from: data)
            
            DispatchQueue.main.async {
                // 💡 THE VIEW REFRESH FIX: Forcefully alerts your SwiftUI ContentView layout
                // that new items have arrived so it instantly draws the new card rows!
                self.objectWillChange.send()
                
                // Append the new 10 articles right to the end of the existing list seamlessly
                self.newsState.topStories.append(contentsOf: decodedArticles)
                
                // Advance page tracking indicators
                self.newsState.currentPage += 1
                self.newsState.isNewsLoaded = true
                self.newsState.isFetchingNextPage = false
                print("🌐 [NEWS PAGE CDN SUCCESS]: Loaded page data block index frame successfully.")
            }
        } catch {
            print("❌ [NEWS CHANNEL EXCEPTION]: Ingestion aborted or complete: \(error)")
            DispatchQueue.main.async {
                self.newsState.isFetchingNextPage = false
            }
        }
    }
}
