import SwiftUI
import WidgetKit
import ActivityKit
import AlarmKit

/// Lock Screen / Dynamic Island view AlarmKit shows for our alarms and timers
/// outside the full-screen alert: a live countdown for timers.
struct AlarmLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: AlarmAttributes<MathAlarmMetadata>.self) { context in
            HStack(spacing: 12) {
                Image(systemName: icon(context.state.mode))
                    .font(.title)
                    .foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 2) {
                    Text(context.attributes.metadata?.label ?? "Math Alarm")
                        .font(.headline)
                    status(context.state.mode)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                countdown(context.state.mode)
                    .font(.system(size: 34, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.orange)
            }
            .padding()
            .activityBackgroundTint(Color.black)
            .activitySystemActionForegroundColor(Color.orange)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: icon(context.state.mode)).foregroundStyle(.orange)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.attributes.metadata?.label ?? "Math Alarm").font(.headline)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    countdown(context.state.mode).monospacedDigit().foregroundStyle(.orange)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    status(context.state.mode).font(.subheadline).foregroundStyle(.secondary)
                }
            } compactLeading: {
                Image(systemName: icon(context.state.mode)).foregroundStyle(.orange)
            } compactTrailing: {
                countdown(context.state.mode).monospacedDigit().foregroundStyle(.orange).frame(maxWidth: 64)
            } minimal: {
                Image(systemName: icon(context.state.mode)).foregroundStyle(.orange)
            }
        }
    }

    private func icon(_ mode: AlarmPresentationState.Mode) -> String {
        switch mode {
        case .countdown: "timer"
        case .paused: "pause.circle.fill"
        default: "alarm.fill"
        }
    }

    @ViewBuilder
    private func status(_ mode: AlarmPresentationState.Mode) -> some View {
        switch mode {
        case .countdown: Text("Rings with a math challenge")
        case .paused: Text("Paused")
        default: Text("Solve the challenge to stop it")
        }
    }

    @ViewBuilder
    private func countdown(_ mode: AlarmPresentationState.Mode) -> some View {
        switch mode {
        case .countdown(let c):
            Text(c.fireDate, style: .timer)
        case .paused(let p):
            Text(Self.format(p.totalCountdownDuration - p.previouslyElapsedDuration))
        default:
            Text("")
        }
    }

    static func format(_ t: TimeInterval) -> String {
        let s = Swift.max(0, Int(t.rounded()))
        return s >= 3600 ? String(format: "%d:%02d:%02d", s / 3600, (s / 60) % 60, s % 60)
                         : String(format: "%d:%02d", s / 60, s % 60)
    }
}
