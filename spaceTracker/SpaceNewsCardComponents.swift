//
//  SpaceNewsCardComponents.swift
//  spaceTracker
//
//  Created by Ben Clary on 8/12/26.
//

import SwiftUI
import Combine

// ==============================================================================
// 🎴 VIEW COMPONENT CELL: THE DASHBOARD NEWS FEED STORY CARD
// ==============================================================================
struct SpaceNewsCardView: View {
    let article: SpaceNewsArticle
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // 💡 REMOTE NETWORK PHOTO TRAY: Loads the host image asynchronously with safe placeholders
            AsyncImage(url: URL(string: article.imageUrl)) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                case .failure, .empty:
                    // Monospaced radar frame fallback asset graphic if image load lags
                    Color(.systemGray6)
                        .overlay(
                            Image(systemName: "antenna.radiowaves.left.and.right")
                                .foregroundColor(.gray)
                        )
                @unknown default:
                    EmptyView()
                }
            }
            .frame(width: 80, height: 80)
            .cornerRadius(8)
            .clipped()
            
            // TEXT WRAPPERS TRUNCH BLOCK
            VStack(alignment: .leading, spacing: 4) {
                // Publisher Tag Line label
                Text(article.newsSite.uppercased())
                    .font(.system(.caption2, design: .monospaced))
                    .fontWeight(.bold)
                    .foregroundColor(.accentColor)
                
                // Article Title text
                Text(article.title)
                    .font(.system(.subheadline, design: .default))
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                // Concise Summary sub-text line snippet
                Text(article.summary)
                    .font(.system(.caption, design: .default))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            
            Spacer(minLength: 0)
        }
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
    }
}

// ==============================================================================
// 📋 DETAILS OVERLAY SHEET: FULL SUMMARY AND EXTERNAL SAFARI LINKS
// ==============================================================================
struct SpaceNewsDetailSheet: View {
    let article: SpaceNewsArticle
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Header Cover Photo frame container
                    AsyncImage(url: URL(string: article.imageUrl)) { phase in
                        if let image = phase.image {
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } else {
                            Color(.systemGray6)
                                .overlay(Image(systemName: "photo").foregroundColor(.gray))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 200)
                    .clipped()
                    .cornerRadius(12)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        // Metadata Category info row
                        HStack {
                            Text(article.newsSite.uppercased())
                                .font(.system(.caption, design: .monospaced))
                                .fontWeight(.bold)
                                .foregroundColor(.accentColor)
                            
                            Spacer()
                            
                            // Format ISO published timestamp string into readable telemetry labels
                            if let formattedDate = formatTimestamp(article.publishedAt) {
                                Text(formattedDate)
                                    .font(.system(.caption2, design: .monospaced))
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        // Full Article Title
                        Text(article.title)
                            .font(.system(.title3, design: .default))
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        
                        Divider()
                        
                        // Complete Summary narrative paragraph text box
                        Text(article.summary)
                            .font(.system(.body, design: .default))
                            .foregroundColor(.secondary)
                            .lineSpacing(4)
                        
                        Spacer(minLength: 24)
                        
                        // 🚀 INTERACTIVE SAFARI WEBSITE LINK ACTION BUTTON
                        if let articleURL = URL(string: article.url) {
                            Link(destination: articleURL) {
                                HStack {
                                    Text("LAUNCH ORIGINAL ARTICLE")
                                    Image(systemName: "safari")
                                }
                                .font(.system(.callout, design: .monospaced))
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(Color.accentColor)
                                .cornerRadius(10)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("CLOSE") {
                        dismiss()
                    }
                    .font(.system(.footnote, design: .monospaced))
                    .fontWeight(.bold)
                }
            }
        }
    }
    
    // ISO String formatting helper utility routine
    private func formatTimestamp(_ rawDate: String) -> String? {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: rawDate) else { return nil }
        let displayFormatter = DateFormatter()
        displayFormatter.dateStyle = .medium
        displayFormatter.timeStyle = .short
        return displayFormatter.string(from: date).uppercased()
    }
}
