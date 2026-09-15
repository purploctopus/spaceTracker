//
//  EarthWatchView.swift
//  spaceTracker
//
//  FEAT-13: the Earth Watch tab -- everything about looking down at Earth from space,
//  gathered in one place: a live NASA EPIC photo of the sunlit Earth, the live ISS/
//  Tiangong orbital tracker (moved here from Home Command), and the Humans in Space
//  crew roster (also moved here -- those astronauts are, quite literally, watching
//  Earth from orbit).
//
//  EPIC imagery is backed by the nasa-epic-worker Cloudflare Worker: KV-cached and
//  refreshed roughly every 20 minutes to match DSCOVR's real ~65-110 minute shot
//  cadence, so this app never hits NASA directly and never needs an API key client-side
//  -- image URLs point straight at epic.gsfc.nasa.gov, which serves them key-free.

import SwiftUI
import CoreLocation
import Combine

// MARK: - EPIC image model

struct EarthEPICImage: Decodable, Identifiable, Equatable {
    let identifier: String
    let caption: String
    let date: String
    let centroidLat: Double?
    let centroidLon: Double?
    let imageUrl: String
    let thumbnailUrl: String

    var id: String { identifier }

    /// EPIC's own date format ("2026-09-07 00:50:27") is UTC, space-separated rather
    /// than ISO 8601's "T" separator.
    var captureDate: Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.date(from: date)
    }
}

private struct EarthEPICResponse: Decodable {
    let images: [EarthEPICImage]
}

// MARK: - View model

@MainActor
class EarthWatchViewModel: ObservableObject {
    @Published var images: [EarthEPICImage] = []
    @Published var isLoading = false
    @Published var errorMessage: String? = nil

    private let workerURLString = "https://nasa-epic-worker.purploctopus.workers.dev"

    /// EPIC images arrive in chronological order, so the last one is the most recent.
    var latestImage: EarthEPICImage? { images.last }

    /// Whichever cached shot's centroid is geographically closest to `coordinate` -- the
    /// "what does Earth look like over where I am" view. A squared-distance comparison is
    /// plenty accurate for picking among a dozen widely-spaced candidates; falls back to
    /// the latest image when centroid data or a location isn't available.
    func nearestImage(to coordinate: CLLocationCoordinate2D?) -> EarthEPICImage? {
        guard let coordinate else { return latestImage }
        return images.min(by: { lhs, rhs in
            squaredAngularDistance(from: coordinate, toLat: lhs.centroidLat, lon: lhs.centroidLon) <
            squaredAngularDistance(from: coordinate, toLat: rhs.centroidLat, lon: rhs.centroidLon)
        }) ?? latestImage
    }

    private func squaredAngularDistance(from coordinate: CLLocationCoordinate2D, toLat lat: Double?, lon: Double?) -> Double {
        guard let lat, let lon else { return .greatestFiniteMagnitude }
        let dLat = coordinate.latitude - lat
        let dLon = coordinate.longitude - lon
        return dLat * dLat + dLon * dLon
    }

    func fetchLatestImagesIfNeeded() async {
        guard images.isEmpty, !isLoading else { return }
        isLoading = true
        errorMessage = nil

        guard let url = URL(string: workerURLString) else {
            errorMessage = "WORKER URL INVALID"
            isLoading = false
            return
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                errorMessage = "EARTH IMAGERY UNAVAILABLE"
                isLoading = false
                return
            }
            let decoded = try JSONDecoder().decode(EarthEPICResponse.self, from: data)
            self.images = decoded.images
            self.isLoading = false
        } catch {
            errorMessage = "EARTH IMAGERY UNAVAILABLE"
            isLoading = false
        }
    }
}

// MARK: - Earth Watch tab

struct EarthWatchView: View {
    @StateObject private var viewModel = EarthWatchViewModel()
    @ObservedObject var crewViewModel: AstronautViewModel
    @Binding var selectedSpacecraftCrewName: String?
    let userLatitude: Double
    let userLongitude: Double

    @State private var manuallySelectedImage: EarthEPICImage? = nil
    @State private var showNearestToMe = false
    @State private var showZoomedImage = false

    private var displayedImage: EarthEPICImage? {
        if showNearestToMe {
            return viewModel.nearestImage(to: CLLocationCoordinate2D(latitude: userLatitude, longitude: userLongitude))
        }
        return manuallySelectedImage ?? viewModel.latestImage
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                // THE 3D ORBITAL INTERCEPT RADAR MAP CONTAINER (moved from Home Command) --
                // promoted above the EPIC imagery below: the live tracker is the stronger
                // feature of this tab, so it's what greets you first.
                SpaceStationRadarChannelView()

                Divider().background(Color.cyan)

                Text("EARTH RIGHT NOW // NASA EPIC")
                    .font(.system(.caption, design: .monospaced).weight(.bold))
                    .foregroundColor(.cyan)
                    .tracking(2)
                    .padding(.horizontal)

                epicImageryBlock

                Divider().background(Color.cyan).padding(.top, 8)

                // LIVE HUMANS IN SPACE ROSTER CHANNEL BLOCK (moved from Home Command)
                HumansInSpaceRosterView(
                    crewViewModel: crewViewModel,
                    selectedSpacecraftCrewName: $selectedSpacecraftCrewName
                )
                .padding(.top, 8)
            }
            .padding(.top, 24)
            .padding(.bottom, 60)
        }
        .background(Color.black.ignoresSafeArea())
        .task {
            await viewModel.fetchLatestImagesIfNeeded()
        }
    }

    @ViewBuilder
    private var epicImageryBlock: some View {
        if viewModel.isLoading {
            ProgressView("SYNCHRONIZING EPIC FEED...")
                .tint(.cyan)
                .foregroundColor(.gray)
                .frame(maxWidth: .infinity)
                .padding(.top, 40)
        } else if let error = viewModel.errorMessage {
            Text(error)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.red)
                .padding(.horizontal)
        } else if let image = displayedImage {
            ZStack(alignment: .bottomTrailing) {
                AsyncImage(url: URL(string: image.imageUrl)) { phase in
                    switch phase {
                    case .success(let img):
                        img.resizable().aspectRatio(1, contentMode: .fit)
                    case .failure:
                        Color.white.opacity(0.05).aspectRatio(1, contentMode: .fit)
                            .overlay(
                                Text("IMAGE UNAVAILABLE")
                                    .font(.system(.caption2, design: .monospaced))
                                    .foregroundColor(.gray)
                            )
                    default:
                        Color.white.opacity(0.05).aspectRatio(1, contentMode: .fit)
                            .overlay(ProgressView().tint(.cyan))
                    }
                }
                .clipShape(Circle())

                Image(systemName: "arrow.up.left.and.arrow.down.right.circle.fill")
                    .font(.system(size: 22))
                    .foregroundColor(.cyan)
                    .background(Circle().fill(Color.black.opacity(0.65)))
                    .padding(.trailing, 40)
                    .padding(.bottom, 4)
            }
            .padding(.horizontal, 32)
            .contentShape(Rectangle())
            .onTapGesture {
                showZoomedImage = true
            }
            .accessibilityLabel("Earth as seen from NASA's EPIC camera aboard DSCOVR")
            .accessibilityHint("Double tap to view full screen and zoom")
            .accessibilityAddTraits(.isButton)
            .fullScreenCover(isPresented: $showZoomedImage) {
                ZoomableEarthImageView(imageUrl: image.imageUrl)
            }

            if let captureDate = image.captureDate {
                Text("CAPTURED \(captureDate.formatted(date: .abbreviated, time: .shortened)) UTC")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, alignment: .center)
            }

            Toggle(isOn: $showNearestToMe) {
                Text("SHOW SHOT NEAREST MY LOCATION")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundColor(.white)
            }
            .tint(.cyan)
            .padding(.horizontal, 32)
            .onChange(of: showNearestToMe) { _, isOn in
                if isOn { manuallySelectedImage = nil }
            }

            if viewModel.images.count > 1 {
                Text("TODAY'S PASSES (\(viewModel.images.count))")
                    .font(.system(.caption2, design: .monospaced).weight(.bold))
                    .foregroundColor(.cyan)
                    .padding(.horizontal)
                    .padding(.top, 4)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(viewModel.images) { shot in
                            let isSelected = shot.identifier == displayedImage?.identifier
                            AsyncImage(url: URL(string: shot.thumbnailUrl)) { phase in
                                if case .success(let img) = phase {
                                    img.resizable().aspectRatio(contentMode: .fill)
                                } else {
                                    Color.white.opacity(0.05)
                                }
                            }
                            .frame(width: 60, height: 60)
                            .clipShape(Circle())
                            .overlay(
                                Circle().stroke(isSelected ? Color.cyan : Color.white.opacity(0.15), lineWidth: isSelected ? 2 : 1)
                            )
                            .onTapGesture {
                                showNearestToMe = false
                                manuallySelectedImage = shot
                            }
                            .accessibilityLabel("EPIC image captured \(shot.date) UTC")
                            .accessibilityHint("Shows this shot")
                            .accessibilityAddTraits(.isButton)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        } else {
            Text("NO EARTH IMAGERY AVAILABLE RIGHT NOW")
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.gray)
                .padding(.horizontal)
        }
    }
}

// MARK: - Humans in Space (moved from ContentView.swift, unchanged behavior)

struct HumansInSpaceRosterView: View {
    @ObservedObject var crewViewModel: AstronautViewModel
    @Binding var selectedSpacecraftCrewName: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("CURRENT HUMANS IN SPACE (\(crewViewModel.totalHumansInOrbit) ACTIVE)")
                .font(.system(.caption, design: .monospaced).weight(.bold))
                .foregroundColor(.cyan)
                .tracking(2)
                .padding(.horizontal)

            if crewViewModel.isLoading {
                Text("SYNCHRONIZING OPEN MANIFEST...")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.gray)
                    .padding(.horizontal)
            } else if let error = crewViewModel.errorMessage {
                Text(error)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.red)
                    .padding(.horizontal)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        if !crewViewModel.issCrew.isEmpty {
                            SpacecraftRosterCardView(craftName: "International Space Station", crewList: crewViewModel.issCrew)
                                .onTapGesture {
                                    selectedSpacecraftCrewName = "International Space Station"
                                }
                                .accessibilityElement(children: .combine)
                                .accessibilityLabel("International Space Station crew")
                                .accessibilityHint("Opens details")
                                .accessibilityAddTraits(.isButton)
                        }

                        if !crewViewModel.tiangongCrew.isEmpty {
                            SpacecraftRosterCardView(craftName: "Tiangong Space Station", crewList: crewViewModel.tiangongCrew)
                                .onTapGesture {
                                    selectedSpacecraftCrewName = "Tiangong Space Station"
                                }
                                .accessibilityElement(children: .combine)
                                .accessibilityLabel("Tiangong Space Station crew")
                                .accessibilityHint("Opens details")
                                .accessibilityAddTraits(.isButton)
                        }

                        if !crewViewModel.otherCrew.isEmpty {
                            SpacecraftRosterCardView(craftName: "Experimental Transits", crewList: crewViewModel.otherCrew)
                            .onTapGesture {
                                selectedSpacecraftCrewName = "Experimental Transits"
                            }
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel("Experimental Transits crew")
                            .accessibilityHint("Opens details")
                            .accessibilityAddTraits(.isButton)
                        }
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal)
                }
            }
        }
    }
}

// MARK: - Full-screen zoomable EPIC image viewer

/// Pinch to zoom (clamped 1x-5x), drag to pan once zoomed, double-tap to toggle between
/// fit and a 3x zoom. EPIC's natural-color images are 2048x2048, so there's real detail
/// here worth zooming into -- this isn't just blowing up a small thumbnail.
struct ZoomableEarthImageView: View {
    let imageUrl: String
    @Environment(\.dismiss) var dismiss

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    private let minScale: CGFloat = 1.0
    private let maxScale: CGFloat = 5.0
    private let doubleTapScale: CGFloat = 3.0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            AsyncImage(url: URL(string: imageUrl)) { phase in
                switch phase {
                case .success(let img):
                    img
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .scaleEffect(scale)
                        .offset(offset)
                        .gesture(magnificationGesture)
                        .simultaneousGesture(dragGesture)
                        .onTapGesture(count: 2, perform: toggleDoubleTapZoom)
                case .failure:
                    Text("IMAGE UNAVAILABLE")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.gray)
                default:
                    ProgressView().tint(.cyan)
                }
            }

            VStack {
                HStack {
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.white.opacity(0.9))
                            .background(Circle().fill(Color.black.opacity(0.4)))
                    }
                    .padding()
                    .accessibilityLabel("Close")
                }
                Spacer()
            }
        }
        .statusBarHidden()
    }

    private var magnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                scale = min(max(lastScale * value, minScale), maxScale)
            }
            .onEnded { _ in
                lastScale = scale
                if scale <= minScale {
                    resetZoom()
                }
            }
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                guard scale > minScale else { return }
                offset = CGSize(
                    width: lastOffset.width + value.translation.width,
                    height: lastOffset.height + value.translation.height
                )
            }
            .onEnded { _ in
                lastOffset = offset
            }
    }

    private func toggleDoubleTapZoom() {
        withAnimation(.spring()) {
            if scale > minScale {
                resetZoom()
            } else {
                scale = doubleTapScale
                lastScale = doubleTapScale
            }
        }
    }

    private func resetZoom() {
        withAnimation(.spring()) {
            scale = minScale
            lastScale = minScale
            offset = .zero
            lastOffset = .zero
        }
    }
}
