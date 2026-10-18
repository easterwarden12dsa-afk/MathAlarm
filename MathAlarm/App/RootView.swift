import SwiftUI

struct RootView: View {
    @AppStorage("didFinishOnboarding") private var didFinishOnboarding = false
    @EnvironmentObject private var store: AlarmStore
    @EnvironmentObject private var ring: RingCoordinator

    var body: some View {
        Group {
            if didFinishOnboarding {
                TabView {
                    AlarmListView()
                        .tabItem { Label("Alarms", systemImage: "alarm.fill") }
                    TimerView()
                        .tabItem { Label("Timer", systemImage: "timer") }
                    PracticeView()
                        .tabItem { Label("Practice", systemImage: "function") }
                    InsightsView()
                        .tabItem { Label("Progress", systemImage: "chart.line.uptrend.xyaxis") }
                    SettingsView()
                        .tabItem { Label("Settings", systemImage: "gearshape.fill") }
                }
            } else {
                OnboardingView { didFinishOnboarding = true }
            }
        }
        .toast($ring.toast)
        // The ringing screen can only be closed by resolving the ring.
        .fullScreenCover(isPresented: Binding(get: { ring.session != nil }, set: { _ in })) {
            RingingView()
                .environmentObject(ring)
                .environmentObject(store)
                .preferredColorScheme(.dark)
                .appLanguage(AppSettings.shared.language)
        }
    }
}
