import Foundation
import SwiftUI
import Combine

// ✅ KEEP THIS: Your app needs this structure to decode the JSON coming from your worker
struct APODPayload: Codable {
    let title: String
    let explanation: String
    let url: String
}

@MainActor
class APODViewModel: ObservableObject {
    @Published var backgroundImageURL: URL? = nil
    @Published var photoTitle: String = ""
    @Published var photoExplanation: String = ""
    @Published var isLoaded: Bool = false
    
    // 📡 PASTE YOUR LIVE CLOUDFLARE URL HERE (Spaced out to ensure zero char cutoff bugs):
    // https://nasa-apod-worker.purploctopus.workers.dev/
    private let workerURLString = "https://nasa-apod-worker.purploctopus.workers.dev/"
    
    func fetchDailyBackdrop() async {
        guard let url = URL(string: workerURLString) else {
            print("❌ [APOD ENGINE]: Invalid standalone worker endpoint path configuration.")
            return
        }
        
        do {
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.timeoutInterval = 6.0 // Clean connection timeout guard line limit
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                print("⚠️ [APOD ENGINE]: Separate worker server responded with an error code status matrix.")
                return
            }
            
            // Decodes the payload directly matching your clean worker output contract
            let decoded = try JSONDecoder().decode(APODPayload.self, from: data)
            
            if let imageUrl = URL(string: decoded.url) {
                self.backgroundImageURL = imageUrl
                self.photoTitle = decoded.title
                self.photoExplanation = decoded.explanation
                self.isLoaded = true
                print("🌌 [APOD ENGINE]: Standalone microservice successfully returned valid NASA image asset: \(decoded.title)")
            }
        } catch {
            print("❌ [APOD ENGINE]: Microservice data transaction network exception: \(error.localizedDescription)")
        }
    }
}

// MARK: - THE AMBIENT BACKDROP LAYER COMPONENT
struct TacticalAmbientBackdropView: View {
    @ObservedObject var apodViewModel: APODViewModel
    @Binding var showInfoSheet: Bool
    
    var body: some View {
        // Base layer takes up exactly 100% of the screen bounds
        Color(red: 0.02, green: 0.02, blue: 0.02)
            .ignoresSafeArea()
            // ✅ THE FIX: Image is isolated inside an overlay so it cannot expand your layout containers
            .overlay(
                Group {
                    if let imgUrl = apodViewModel.backgroundImageURL {
                        AsyncImage(url: imgUrl) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .opacity(0.35)
                                    .transition(.opacity.animation(.easeIn(duration: 0.5)))
                            default:
                                Color.clear
                            }
                        }
                    }
                }
                .ignoresSafeArea()
            )
    }
}

// MARK: - NASA TELEMETRY TEXT SHEET COMPONENT
struct APODCreditDetailSheet: View {
    let title: String
    let explanation: String
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack {
            Color(red: 0.04, green: 0.04, blue: 0.04).ignoresSafeArea()
            
            // ✅ THE FIX: Wraps the entire layout tree so nothing can get pushed off the phone screen
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("NASA ASTRONOMY BACKGROUND //")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.yellow)
                            Text(title.uppercased())
                                .font(.system(.title3, design: .monospaced))
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .fixedSize(horizontal: false, vertical: true) // Prevents title truncation
                        }
                        Spacer()
                        Button(action: { dismiss() }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title2)
                                .foregroundColor(.gray)
                        }
                    }
                    
                    Text(explanation)
                        .font(.system(.subheadline, design: .monospaced))
                        .foregroundColor(.gray)
                        .lineSpacing(5)
                        .padding(.vertical, 4)
                        .fixedSize(horizontal: false, vertical: true) // Forces system to render full paragraph text
                    
                    Spacer()
                }
                .padding(24)
            }
        }
        .preferredColorScheme(.dark)
    }
}
