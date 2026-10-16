import SwiftUI
import WidgetKit
import ActivityKit
import AlarmKit

/// Lock Screen / Dynamic Island view AlarmKit shows for our alarms outside
/// the full-screen alert (AlarmKit expects an app to provide one).
struct AlarmLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: AlarmAttributes<MathAlarmMetadata>.self) { context in
            HStack(spacing: 12) {
                Image(systemName: "alarm.fill")
                    .font(.title)
                    .foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 2) {
                    Text(context.attributes.metadata?.label ?? "Math Alarm")
                        .font(.headline)
                    Text("Solve the \(context.attributes.metadata?.challenge ?? "math") challenge to stop it")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding()
            .activityBackgroundTint(Color.black)
            .activitySystemActionForegroundColor(Color.orange)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "alarm.fill").foregroundStyle(.orange)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.attributes.metadata?.label ?? "Math Alarm")
                        .font(.headline)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Open the app to solve")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } compactLeading: {
                Image(systemName: "alarm.fill").foregroundStyle(.orange)
            } compactTrailing: {
                Image(systemName: "function").foregroundStyle(.orange)
            } minimal: {
                Image(systemName: "alarm.fill").foregroundStyle(.orange)
            }
        }
    }
}
