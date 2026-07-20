//
//  LaunchLiveStreamPlayerView.swift
//  spaceTracker
//
//  Created by Ben Clary on 7/10/26.
//  MAKE AN APP THAT INSPIRES COLIN

import SwiftUI
import WebKit
import AVKit
import Combine

struct LaunchLiveStreamPlayerView: View {
    let streamURLString: String
    let launchName: String
    let launchNetDateString: String?
    
    @State private var isStreamActive = false
    @Environment(\.dismiss) var dismiss
    
    let lifecycleTimer = Timer.publish(every: 5, on: .main, in: .common).autoconnect()
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                let cleanUrlString = streamURLString.trimmingCharacters(in: .whitespacesAndNewlines)
                
                if cleanUrlString.lowercased().contains("youtube") || cleanUrlString.lowercased().contains("youtu.be") {
                    // 💡 RENAMED STRUCT CALL HERE
                    SpaceTrackerVideoWebView(urlString: cleanUrlString)
                        .ignoresSafeArea(edges: .bottom)
                } else if let validNativeURL = URL(string: cleanUrlString) {
                    NativeAVPlayerInterfaceNode(videoURL: validNativeURL)
                        .ignoresSafeArea(edges: .bottom)
                }
                
                if !isStreamActive {
                    VStack(spacing: 16) {
                        Spacer()
                        
                        Image(systemName: "antenna.radiowaves.left.and.right")
                            .font(.title2)
                            .foregroundColor(.orange)
                        
                        Text("EXTERNAL STREAM FEED // STANDBY")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                            .tracking(1)
                        
                        LaunchCountdownView(targetDateString: launchNetDateString)
                            .padding(.vertical, 4)
                        
                        Text("LIVE MISSION VIDEO BOOTS APPROXIMATELY 20 MINUTES PRIOR TO IGNITION T-0")
                            .font(.system(size: 8, design: .monospaced))
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                        
                        Button(action: { isStreamActive = true }) {
                            Text("FORCE MONITOR FEED")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(4)
                        }
                        .padding(.top, 12)
                        
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(red: 0.05, green: 0.05, blue: 0.06).opacity(0.98))
                    .ignoresSafeArea(edges: .bottom)
                }
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
            .onReceive(lifecycleTimer) { _ in
                checkStreamTimeline()
            }
            .onAppear {
                checkStreamTimeline()
            }
            .preferredColorScheme(.dark)
        }
    }
    
    private func checkStreamTimeline() {
        guard let dateString = launchNetDateString else { return }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        var targetDate = formatter.date(from: dateString)
        if targetDate == nil {
            let backup = ISO8601DateFormatter()
            targetDate = backup.date(from: dateString)
        }
        
        guard let validTarget = targetDate else { return }
        let timeRemaining = validTarget.timeIntervalSince(Date())
        
        if timeRemaining <= 1200 {
            isStreamActive = true
        }
    }
}

// MARK: - 🖥️ SUB-PIPELINE A: DEBUGENABLED WEB PLAYER LAYER
struct SpaceTrackerVideoWebView: UIViewRepresentable {
    let urlString: String
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIView(context: Context) -> WKWebView {
        let webConfiguration = WKWebViewConfiguration()
        webConfiguration.allowsInlineMediaPlayback = true
        webConfiguration.mediaTypesRequiringUserActionForPlayback = []
        
        let webView = WKWebView(frame: .zero, configuration: webConfiguration)
        webView.backgroundColor = .black
        webView.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"
        webView.navigationDelegate = context.coordinator
        
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {
        guard let originalURL = URL(string: urlString) else { return }
        
        let videoID: String? = {
            if originalURL.host?.contains("youtu.be") == true {
                return originalURL.pathComponents.last
            } else if originalURL.pathComponents.contains("live") || originalURL.pathComponents.contains("shorts") || originalURL.pathComponents.contains("embed") {
                return originalURL.pathComponents.last
            } else if let components = URLComponents(url: originalURL, resolvingAgainstBaseURL: true) {
                return components.queryItems?.first(where: { $0.name == "v" })?.value
            }
            return nil
        }()
        
        guard let validID = videoID, !validID.isEmpty else {
            print("📺 INSPECTOR FAILED: Could not isolate an 11-character video ID from raw text line: \(urlString)")
            return
        }
        
        // 💡 EXPLICIT HARDCODED FALLBACK: This path syntax is physically impossible to merge incorrectly
        // 💡 THE PATH RESOLUTION: Uses the standard watch path directory to form a completely valid URL string
        let cleanEmbedPath = "https://www.youtube.com/watch?v=\(validID)&playsinline=1&autoplay=1&rel=0"
        guard let targetURL = URL(string: cleanEmbedPath) else { return }
        
        print("📺 INSPECTOR START: Routing Request Path -> \(cleanEmbedPath)")
        
        var request = URLRequest(url: targetURL)
        request.setValue("https://github.io", forHTTPHeaderField: "Referer")
        request.setValue("https://github.io", forHTTPHeaderField: "Origin")
        
        uiView.load(request)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: SpaceTrackerVideoWebView
        
        init(_ parent: SpaceTrackerVideoWebView) {
            self.parent = parent
        }
        
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            print("❌ CONSOLE FAULT (PROVISIONAL): \(error.localizedDescription)")
            
            if let urlError = error as? URLError, let brokenURL = urlError.failingURL {
                print("🔍 DETECTED HOSTNAME FAILURE: The app could not resolve or find the server address: '\(brokenURL.host ?? "EMPTY HOSTNAME")' (Full URL attempted: \(brokenURL.absoluteString))")
            } else {
                let nsError = error as NSError
                if let brokenURLString = nsError.userInfo["NSErrorFailingURLStringKey"] as? String {
                    print("🔍 DETECTED HOSTNAME FAILURE (NS-FALLBACK): The app could not find the server address: '\(URL(string: brokenURLString)?.host ?? "EMPTY HOSTNAME")' (Full URL attempted: \(brokenURLString))")
                }
            }
            
            print("⚠️ CODE: \((error as NSError).code) | DOMAIN: \((error as NSError).domain)")
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            print("❌ CONSOLE FAULT (NAVIGATION): \(error.localizedDescription)")
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            print("✅ CONSOLE SUCCESS: WebView finished loading page architecture. URL is: \(webView.url?.absoluteString ?? "NONE")")
        }
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
                player.play()
            }
            .onDisappear {
                player.pause()
            }
    }
}
