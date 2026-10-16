import SwiftUI

struct RootView: View {
    @AppStorage("didFinishOnboarding") private var didFinishOnboarding = false
    @EnvironmentObject private var store: AlarmStore
    @EnvironmentObject private var ring: RingCoordinator

    var body: some View {
        Group {
            if didFinishOnboarding {
                AlarmListView()
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
        }
    }
}
