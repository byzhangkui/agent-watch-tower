#if canImport(AppKit)
import SwiftUI

/// Chronological timeline of all events in a session.
struct EventTimelineView: View {
    let events: [AgentEvent]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader(title: "Recent Events")

            if events.isEmpty {
                Text("No events yet")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 16)
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(events) { event in
                        EventRowView(event: event)
                        if event.id != events.last?.id {
                            Divider()
                                .padding(.leading, 66)
                        }
                    }
                }
            }
        }
    }
}

/// Reusable section header.
struct SectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .padding(.horizontal, Constants.contentPadding)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.primary.opacity(0.03))
    }
}
#endif
