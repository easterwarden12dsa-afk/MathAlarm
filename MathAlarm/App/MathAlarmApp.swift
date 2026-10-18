import SwiftUI

@main
struct MathAlarmApp: App {
    @StateObject private var store = AlarmStore.shared
    @StateObject private var ring = RingCoordinator.shared
    @ObservedObject private var settings = AppSettings.shared
    @Environment(\.scenePhase) private var scenePhase

    init() {
        RingCoordinator.shared.start()
        _ = TimerStore.shared   // starts following timer state
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .environmentObject(ring)
                .preferredColorScheme(.dark)
                .tint(.orange)
                .appLanguage(settings.language)
                .id(settings.language)   // rebuild every screen in the new language
        }
        .onChange(of: scenePhase, initial: true) { _, newPhase in
            ring.scenePhaseChanged(newPhase)
        }
    }
}
