import SwiftUI
import AlarmKit

/// First-launch screen: asks for alarm permission and explains the limits.
struct OnboardingView: View {
    @EnvironmentObject private var store: AlarmStore
    var onFinish: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Math Alarm")
                    .font(.largeTitle.bold())
                    .padding(.top, 32)

                Text("Your alarm only goes quiet when you solve a math problem — or press Surrender.")
                    .font(.title3)

                VStack(alignment: .leading, spacing: 16) {
                    tip("bell.badge.fill", "Allow alarms",
                        "Alarms then ring like the Clock app: on the lock screen, on Silent and in Focus.")
                    tip("speaker.wave.3.fill", "Turn the volume up",
                        "The system alarm uses your Alarm volume. Inside the app the sound follows your media volume.")
                    tip("function", "Tap \"Solve\", not Stop",
                        "Stop can't be hidden by any app. If you press it, the alarm rings again within seconds until you solve or surrender.")
                    tip("calendar.badge.clock", "Reinstall every 7 days",
                        "Apps installed with a free Apple ID stop opening after 7 days. Reinstall with Sideloadly before then; your alarms are kept.")
                }

                permissionSection

                Button(action: onFinish) {
                    Text("Continue")
                        .font(.title3.bold())
                        .frame(maxWidth: .infinity, minHeight: 56)
                }
                .buttonStyle(.borderedProminent)
                .disabled(store.authorization == .notDetermined)
            }
            .padding(24)
        }
        .background(Color.black.ignoresSafeArea())
    }

    @ViewBuilder
    private var permissionSection: some View {
        switch store.authorization {
        case .authorized:
            Label("Alarms allowed", systemImage: "checkmark.circle.fill")
                .font(.title3.bold())
                .foregroundStyle(.green)
        case .denied:
            VStack(alignment: .leading, spacing: 8) {
                Label("Alarms are turned off", systemImage: "xmark.octagon.fill")
                    .font(.title3.bold())
                    .foregroundStyle(.red)
                Text("Open Settings › Math Alarm and allow Alarms & Timers.")
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .buttonStyle(.bordered)
            }
        default:
            Button {
                Task { await store.requestAuthorization() }
            } label: {
                Text("Allow alarms")
                    .font(.title3.bold())
                    .frame(maxWidth: .infinity, minHeight: 56)
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private func tip(_ symbol: String, _ title: String, _ body: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.title2)
                .foregroundStyle(.orange)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                Text(body).font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }
}
