//
//  NativeAdCardView.swift
//  spaceTracker
//  make an app where sara is released from her job and colin LOVES!
//  Native ad card for the news feed — styled to match SpaceNewsCardView so it blends into
//  the list instead of reading as a foreign element (the whole reason native > banner here).

import SwiftUI
import GoogleMobileAds
import UIKit
import Combine

/// Loads a single native ad. One instance per ad slot in the feed, so each slot loads/holds
/// its own ad independently.
@MainActor
class NativeAdCardLoader: NSObject, ObservableObject, NativeAdLoaderDelegate {
    @Published var nativeAd: NativeAd?
    private var adLoader: AdLoader?
    private var hasStartedLoading = false
    private var loadAttempts = 0
    private var requestedAdUnitID: String?

    func loadIfNeeded(adUnitID: String) {
        guard !hasStartedLoading else { return }
        requestedAdUnitID = adUnitID

        // 💡 FIXED: previously set hasStartedLoading = true before this lookup — if the key
        // window wasn't resolvable yet at this exact moment (a real possibility this early
        // in a LazyVStack row's lifecycle), the slot would silently and permanently never
        // retry. Now only commits to "started" once a load actually fires.
        guard let rootVC = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { $0.isKeyWindow })?.rootViewController else {
            return
        }
        hasStartedLoading = true
        adLoader = AdLoader(adUnitID: adUnitID, rootViewController: rootVC, adTypes: [.native], options: nil)
        adLoader?.delegate = self
        adLoader?.load(Request())
    }

    nonisolated func adLoader(_ adLoader: AdLoader, didReceive nativeAd: NativeAd) {
        Task { @MainActor in
            self.nativeAd = nativeAd
        }
    }

    nonisolated func adLoader(_ adLoader: AdLoader, didFailToReceiveAdWithError error: Error) {
        print("❌ [ADMOB NATIVE ERROR]: \(error.localizedDescription)")
        Task { @MainActor in
            // 💡 FIXED: previously just logged and gave up forever for this slot. Retries
            // with a short backoff, capped at 3 attempts — same pattern as the retry logic
            // already in AdMobEngine for the other ad types.
            self.hasStartedLoading = false
            self.loadAttempts += 1
            if self.loadAttempts <= 3, let adUnitID = self.requestedAdUnitID {
                let delaySeconds = Double(self.loadAttempts) * 10.0
                try? await Task.sleep(nanoseconds: UInt64(delaySeconds * 1_000_000_000))
                self.loadIfNeeded(adUnitID: adUnitID)
            }
        }
    }
}

/// SwiftUI entry point — drop one of these into the feed wherever an ad slot belongs.
/// Renders nothing (zero height) until an ad actually loads, so it never leaves an empty gap.
struct NativeNewsAdCard: View {
    @StateObject private var loader = NativeAdCardLoader()
    let adUnitID: String

    var body: some View {
        Group {
            if let ad = loader.nativeAd {
                // 💡 FIXED: UIViewRepresentable has no intrinsic width of its own here —
                // without an explicit maxWidth, it can collapse to essentially zero visible
                // width inside a LazyVStack, a well-known SwiftUI/UIKit-bridging gotcha.
                // The ad could have loaded successfully and still been invisible.
                NativeAdCardRepresentable(nativeAd: ad)
                    .frame(maxWidth: .infinity)
                    .frame(height: 96)
            } else {
                Color.clear.frame(height: 0)
            }
        }
        .onAppear {
            loader.loadIfNeeded(adUnitID: adUnitID)
        }
    }
}

/// Bridges a real NativeAdView into SwiftUI. Required by AdMob policy: the ad's assets must
/// be displayed through actual registered subviews (iconView/headlineView/bodyView) on a
/// NativeAdView, not just raw asset strings dropped into arbitrary SwiftUI views — that's
/// what makes clicks and impressions attribute correctly.
struct NativeAdCardRepresentable: UIViewRepresentable {
    let nativeAd: NativeAd

    func makeUIView(context: Context) -> NativeAdCardUIView {
        let view = NativeAdCardUIView()
        view.configure(with: nativeAd)
        return view
    }

    func updateUIView(_ uiView: NativeAdCardUIView, context: Context) {
        uiView.configure(with: nativeAd)
    }
}

/// Hand-laid-out (not Auto Layout constraints — simpler to get right for this fixed, simple
/// shape) to approximate SpaceNewsCardView: an 80x80 leading image, a small label row, a
/// 2-line headline, a 2-line body, and a required "Ad" attribution badge. Being UIKit rather
/// than SwiftUI, expect to do a little manual tuning once you see it rendered next to the
/// real news cards to get exact pixel parity (fonts/colors here are matched by eye to
/// SpaceNewsCardView's SwiftUI font tokens, not guaranteed identical).
final class NativeAdCardUIView: NativeAdView {
    private let iconImageView = UIImageView()
    private let sponsoredLabel = UILabel()
    private let headlineLabel = UILabel()
    private let bodyLabel = UILabel()
    private let adBadgeLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupSubviews()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupSubviews()
    }

    private func setupSubviews() {
        backgroundColor = .clear

        iconImageView.contentMode = .scaleAspectFill
        iconImageView.clipsToBounds = true
        iconImageView.layer.cornerRadius = 8
        iconImageView.backgroundColor = .systemGray6
        addSubview(iconImageView)

        sponsoredLabel.font = .monospacedSystemFont(ofSize: 11, weight: .bold)
        sponsoredLabel.textColor = .systemOrange
        sponsoredLabel.text = "SPONSORED"
        addSubview(sponsoredLabel)

        headlineLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        headlineLabel.textColor = .label
        headlineLabel.numberOfLines = 2
        addSubview(headlineLabel)

        bodyLabel.font = .systemFont(ofSize: 12, weight: .regular)
        bodyLabel.textColor = .secondaryLabel
        bodyLabel.numberOfLines = 2
        addSubview(bodyLabel)

        // 💡 REQUIRED BY POLICY: every native ad must carry a visible "Ad" attribution
        // badge, no matter how closely everything else matches your app's styling.
        adBadgeLabel.font = .monospacedSystemFont(ofSize: 9, weight: .bold)
        adBadgeLabel.textColor = .white
        adBadgeLabel.text = "  Ad  "
        adBadgeLabel.backgroundColor = .systemOrange
        adBadgeLabel.layer.cornerRadius = 3
        adBadgeLabel.clipsToBounds = true
        addSubview(adBadgeLabel)

        // This is the part that actually matters for correctness: registering each UIKit
        // view with NativeAdView's asset properties is what makes AdMob treat these as the
        // ad's real, click/impression-tracked views, rather than inert decoration.
        self.iconView = iconImageView
        self.headlineView = headlineLabel
        self.bodyView = bodyLabel
    }

    func configure(with ad: NativeAd) {
        self.nativeAd = ad
        iconImageView.image = ad.icon?.image
        headlineLabel.text = ad.headline
        bodyLabel.text = ad.body
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        let iconSize: CGFloat = 80
        let horizontalPadding: CGFloat = 12
        let verticalPadding: CGFloat = 8

        iconImageView.frame = CGRect(x: 0, y: verticalPadding, width: iconSize, height: iconSize)

        let textX = iconSize + horizontalPadding
        let textWidth = max(bounds.width - textX - 40, 40) // leaves room for the Ad badge

        sponsoredLabel.frame = CGRect(x: textX, y: verticalPadding, width: textWidth, height: 14)

        let headlineY = sponsoredLabel.frame.maxY + 2
        headlineLabel.frame = CGRect(x: textX, y: headlineY, width: textWidth, height: 36)

        let bodyY = headlineLabel.frame.maxY + 2
        bodyLabel.frame = CGRect(x: textX, y: bodyY, width: textWidth, height: 30)

        adBadgeLabel.sizeToFit()
        adBadgeLabel.frame = CGRect(
            x: bounds.width - adBadgeLabel.frame.width - 8,
            y: 4,
            width: adBadgeLabel.frame.width + 6,
            height: adBadgeLabel.frame.height + 4
        )
    }
}
