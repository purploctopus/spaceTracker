//
//  spaceTrackerWidgets.swift
//  spaceTrackerWidgets
//
//  Created by Ben Clary on 9/9/26.
//  Rebuilt by Claude on 9/9/26 for FEAT-04 -- Xcode's default template scaffolded a
//  configurable "favorite emoji" example widget; replaced with a plain (no user
//  configuration needed) widget reading the shared "next launch or pass" snapshot that
//  LiveActivityCoordinator publishes from the main app.

import WidgetKit
import SwiftUI

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> UpcomingEventEntry {
        UpcomingEventEntry(date: Date(), event: Self.placeholderEvent)
    }

    func getSnapshot(in context: Context, completion: @escaping (UpcomingEventEntry) -> Void) {
        // Widget gallery / preview surfaces want to see real-looking content, not "no data."
        let event = context.isPreview ? Self.placeholderEvent : SharedSpaceStore.loadNextEvent()
        completion(UpcomingEventEntry(date: Date(), event: event))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<UpcomingEventEntry>) -> Void) {
        let event = SharedSpaceStore.loadNextEvent()
        let entry = UpcomingEventEntry(date: Date(), event: event)

        // Refresh an hour from now, or right after the tracked event's own moment passes
        // (e.g. a countdown reaching zero), whichever comes first -- otherwise a widget
        // showing "in 3 minutes" would sit stale well past T-0 until the next hourly tick.
        let hourFromNow = Date().addingTimeInterval(3600)
        let nextRefresh = event.map { min($0.date.addingTimeInterval(60), hourFromNow) } ?? hourFromNow
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }

    private static var placeholderEvent: UpcomingSpaceEvent {
        UpcomingSpaceEvent(
            kind: .launch,
            title: "FALCON 9 · STARLINK",
            subtitle: "SPACEX",
            date: Date().addingTimeInterval(5400),
            identifier: "placeholder"
        )
    }
}

struct UpcomingEventEntry: TimelineEntry {
    let date: Date
    let event: UpcomingSpaceEvent?
}

struct spaceTrackerWidgetsEntryView: View {
    @Environment(\.widgetFamily) private var family
    var entry: Provider.Entry

    var body: some View {
        switch family {
        case .accessoryInline:
            inlineBody
        case .accessoryRectangular:
            rectangularBody
        default:
            cardBody
        }
    }

    @ViewBuilder
    private var inlineBody: some View {
        if let event = entry.event {
            Label {
                Text("\(event.title) \u{00B7} \(event.date, style: .relative)")
            } icon: {
                Image(systemName: event.kind.systemImageName)
            }
        } else {
            Label("No events tracked", systemImage: "sparkles")
        }
    }

    @ViewBuilder
    private var rectangularBody: some View {
        if let event = entry.event {
            VStack(alignment: .leading, spacing: 1) {
                Text(event.kind.displayLabel)
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                Text(event.title)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
                Text(event.date, style: .relative)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
            }
        } else {
            Text("NO EVENTS TRACKED")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
        }
    }

    @ViewBuilder
    private var cardBody: some View {
        if let event = entry.event {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: event.kind.systemImageName)
                        .font(.system(size: 10, weight: .bold))
                    Text(event.kind.displayLabel)
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                }
                .foregroundStyle(.cyan)

                Text(event.title.uppercased())
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)

                Spacer(minLength: 2)

                Text(event.date, style: .relative)
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white)
                Text(event.subtitle.uppercased())
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(.vertical, 2)
        } else {
            VStack(spacing: 4) {
                Image(systemName: "sparkles")
                    .foregroundStyle(.cyan)
                Text("NO EVENTS TRACKED")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct spaceTrackerWidgets: Widget {
    let kind: String = "spaceTrackerWidgets"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            spaceTrackerWidgetsEntryView(entry: entry)
                .containerBackground(Color.black, for: .widget)
        }
        .configurationDisplayName("Next Space Event")
        .description("Shows the next upcoming launch or visible satellite pass.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryInline])
    }
}

#Preview(as: .systemSmall) {
    spaceTrackerWidgets()
} timeline: {
    UpcomingEventEntry(date: .now, event: UpcomingSpaceEvent(kind: .launch, title: "FALCON 9 \u{00B7} STARLINK GROUP 12-4", subtitle: "SPACEX", date: Date().addingTimeInterval(5400), identifier: "preview-launch"))
    UpcomingEventEntry(date: .now, event: UpcomingSpaceEvent(kind: .satellitePass, title: "ISS (ZARYA)", subtitle: "LOOK NORTHWEST", date: Date().addingTimeInterval(720), identifier: "preview-pass"))
    UpcomingEventEntry(date: .now, event: nil)
}
