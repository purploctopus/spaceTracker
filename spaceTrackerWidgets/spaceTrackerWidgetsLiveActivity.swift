//
//  spaceTrackerWidgetsLiveActivity.swift
//  spaceTrackerWidgets
//
//  Created by Ben Clary on 9/9/26.
//  Rebuilt by Claude on 9/9/26 for FEAT-05 -- the ActivityAttributes type Xcode scaffolded
//  here (spaceTrackerWidgetsAttributes) moved into SharedSpaceTelemetry.swift as
//  SpaceTrackerLiveActivityAttributes, since the main app needs the exact same compiled
//  type to start/update/end the Activity (see that file's target-membership note). This
//  file just renders it.

import ActivityKit
import WidgetKit
import SwiftUI

struct spaceTrackerWidgetsLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: SpaceTrackerLiveActivityAttributes.self) { context in
            // Lock Screen / banner presentation
            HStack(spacing: 12) {
                Image(systemName: iconName(for: context.attributes.kindLabel))
                    .font(.title2)
                    .foregroundStyle(.cyan)
                    .frame(width: 30)

                VStack(alignment: .leading, spacing: 2) {
                    Text(context.state.phaseLabel)
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(.cyan)
                    Text(context.attributes.eventTitle)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text(context.attributes.eventSubtitle)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                countdownOrPhase(context.state, font: .system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 68)
            }
            .padding(16)
            .activityBackgroundTint(Color.black)
            .activitySystemActionForegroundColor(Color.cyan)

        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: iconName(for: context.attributes.kindLabel))
                        .foregroundStyle(.cyan)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    countdownOrPhase(context.state, font: .system(size: 14, weight: .bold, design: .monospaced))
                        .multilineTextAlignment(.trailing)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.attributes.eventTitle)
                        .font(.system(size: 13, weight: .bold))
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("\(context.state.phaseLabel) \u{00B7} \(context.attributes.eventSubtitle)")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            } compactLeading: {
                Image(systemName: iconName(for: context.attributes.kindLabel))
                    .foregroundStyle(.cyan)
            } compactTrailing: {
                countdownOrPhase(context.state, font: .system(size: 12, weight: .bold, design: .monospaced))
                    .frame(width: 44)
            } minimal: {
                Image(systemName: iconName(for: context.attributes.kindLabel))
                    .foregroundStyle(.cyan)
            }
            .widgetURL(URL(string: "spacetracker://"))
            .keylineTint(Color.cyan)
        }
    }

    private func iconName(for kindLabel: String) -> String {
        kindLabel == "LAUNCH" ? "flame.fill" : "antenna.radiowaves.left.and.right"
    }

    /// COUNTDOWN/INCOMING have a real future target -- a live-ticking countdown via
    /// Text(timerInterval:) reads best there. LIFTOFF/OVERHEAD mean targetDate is no longer
    /// in the future (it's already passed, or it's the pass's end time), so a ClosedRange
    /// countdown would be invalid -- show the plain phase word instead.
    @ViewBuilder
    private func countdownOrPhase(_ state: SpaceTrackerLiveActivityAttributes.ContentState, font: Font) -> some View {
        if state.phaseLabel == "COUNTDOWN" || state.phaseLabel == "INCOMING" {
            Text(timerInterval: Date()...state.targetDate, countsDown: true)
                .font(font)
        } else {
            Text(state.phaseLabel)
                .font(font)
        }
    }
}

extension SpaceTrackerLiveActivityAttributes {
    fileprivate static var previewLaunch: SpaceTrackerLiveActivityAttributes {
        SpaceTrackerLiveActivityAttributes(eventTitle: "FALCON 9 \u{00B7} STARLINK", eventSubtitle: "SPACEX", kindLabel: "LAUNCH", eventDate: Date().addingTimeInterval(600))
    }
}

extension SpaceTrackerLiveActivityAttributes.ContentState {
    fileprivate static var countdown: SpaceTrackerLiveActivityAttributes.ContentState {
        SpaceTrackerLiveActivityAttributes.ContentState(phaseLabel: "COUNTDOWN", targetDate: Date().addingTimeInterval(600))
    }

    fileprivate static var liftoff: SpaceTrackerLiveActivityAttributes.ContentState {
        SpaceTrackerLiveActivityAttributes.ContentState(phaseLabel: "LIFTOFF", targetDate: Date().addingTimeInterval(-30))
    }
}

#Preview("Notification", as: .content, using: SpaceTrackerLiveActivityAttributes.previewLaunch) {
   spaceTrackerWidgetsLiveActivity()
} contentStates: {
    SpaceTrackerLiveActivityAttributes.ContentState.countdown
    SpaceTrackerLiveActivityAttributes.ContentState.liftoff
}
