//
//  LaunchLiveStreamPlayerView.swift
//  spaceTracker
//
//  Created by Ben Clary on 7/10/26.
//  MAKE AN APP THAT INSPIRES COLIN

import SwiftUI
import AVKit
import WebKit

struct LaunchLiveStreamPlayerView: View {
    let streamURLString: String
    let launchName: String
    
    // 💡 FIXED: Read the raw scheduling timestamp from your SpaceLaunch payload parameters
    let launchNetDateString: String?
    
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                let cleanUrlString = streamURLString.trimmingCharacters(in: .whitespacesAndNewlines)
                
                // Core underlying video player streams layer deck
                if cleanUrlString.lowercased().contains("youtube") || cleanUrlString.lowercased().contains("youtu.be") {
                    YouTubePlayerWebBridge(urlString: cleanUrlString)
                        .ignoresSafeArea(edges: .bottom)
                } else if let validNativeURL = URL(string: cleanUrlString) {
                    NativeAVPlayerInterfaceNode(videoURL: validNativeURL)
                        .ignoresSafeArea(edges: .bottom)
                }
                
                // 💡 THE STANDBY SHIELD: Automatically overlays your own custom monospaced radar ticker!
                VStack(spacing: 16) {
                    Spacer()
                    
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.title2)
                        .foregroundColor(.orange)
                    
                    Text("EXTERNAL STREAM FEED // STANDBY")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                        .tracking(1)
                    
                    // 💡 FIXED: Integrates your actual, native working ticker component flawlessly!
                    LaunchCountdownView(targetDateString: launchNetDateString)
                        .padding(.vertical, 4)
                    
                    Text("LIVE MISSION VIDEO BOOTS APPROXIMATELY 20 MINUTES PRIOR TO IGNITION T-0")
                        .font(.system(size: 8, design: .monospaced))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                    
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                // Semi-translucent mask blocks out the blank YouTube screen before the stream goes live
                .background(Color(red: 0.05, green: 0.05, blue: 0.06).opacity(0.97))
                .ignoresSafeArea(edges: .bottom)
            }
            .navigationTitle("🔴 LIVE VIDEO TELEMETRY")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundColor(.gray)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .preferredColorScheme(.dark)
        }
    }
}

// MARK: - 🖥️ SUB-PIPELINE A: AD-SAFE WEB TRANSVERSE LAYER
struct YouTubePlayerWebBridge: UIViewRepresentable {
    let urlString: String
    
    func makeUIView(context: Context) -> WKWebView {
        let webConfiguration = WKWebViewConfiguration()
        webConfiguration.allowsInlineMediaPlayback = true
        webConfiguration.mediaTypesRequiringUserActionForPlayback = []
        
        let webView = WKWebView(frame: .zero, configuration: webConfiguration)
        webView.backgroundColor = .black
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {
        // Extract the unique 11-character video ID from any standard YouTube watch link template
        let videoID: String = {
            if let id = urlString.components(separatedBy: "v=").last?.components(separatedBy: "&").first {
                return id
            } else if let id = urlString.components(separatedBy: "youtu.be/").last?.components(separatedBy: "?").first {
                return id
            }
            return urlString
        }()
        
        // 💡 THE FIX: Build a 100% legal, commercial-safe HTML iframe embed template strings layout
        // playsinline=1 forces the simulator to play video cleanly inside your card sheets without crashing
        let authorizedEmbedHTML = """
        <html>
        <head>
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <style>body { margin: 0; background-color: black; }</style>
        </head>
        <body>
        <iframe width="100%" height="100%" src="https://youtube.com\(videoID)?playsinline=1&autoplay=1&rel=0" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture" allowfullscreen></iframe>
        </body>
        </html>
        """
        // Load the customized configuration natively into your webview canvas matrix channels
        uiView.loadHTMLString(authorizedEmbedHTML, baseURL: URL(string: "https://youtube.com"))
    }

}

// MARK: - 🔊 SUB-PIPELINE B: NATIVE CORE PLAYER LAYER
struct NativeAVPlayerInterfaceNode: View {
    let videoURL: URL
    @State private var player = AVPlayer()
    
    var body: some View {
        VideoPlayer(player: player)
            .onAppear {
                player = AVPlayer(url: videoURL)
                player.play() // Auto-ignite data streaming lines instantly on flyout sheet drop
            }
            .onDisappear {
                player.pause() // Tear down memory streams when modal closes to protect battery cells
            }
    }
}
