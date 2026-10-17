import SwiftUI
import UIKit

/// Vibration feedback so every press is felt, not just seen.
enum Haptics {
    static func tap() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    static func press() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func error() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }

    static func warning() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }
}

/// Buttons visibly shrink and brighten while pressed.
struct PressableStyle: ButtonStyle {
    var scale: CGFloat = 0.92

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .brightness(configuration.isPressed ? 0.15 : 0)
            .animation(.spring(response: 0.18, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

/// A short message that slides in at the top of the screen.
struct Toast: Equatable, Identifiable {
    enum Style { case info, success, warning }
    let id = UUID()
    let message: String
    let symbol: String
    var style: Style = .info

    var color: Color {
        switch style {
        case .info: .orange
        case .success: .green
        case .warning: .yellow
        }
    }
}

struct ToastView: View {
    let toast: Toast

    var body: some View {
        Label(toast.message, systemImage: toast.symbol)
            .font(.headline)
            .foregroundStyle(.black)
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(toast.color, in: Capsule())
            .shadow(radius: 8)
            .padding(.top, 8)
            .transition(.move(edge: .top).combined(with: .opacity))
            // Never block taps on the buttons underneath.
            .allowsHitTesting(false)
    }
}

extension View {
    /// Shows `toast` at the top and clears it after a couple of seconds.
    func toast(_ toast: Binding<Toast?>) -> some View {
        overlay(alignment: .top) {
            if let t = toast.wrappedValue {
                ToastView(toast: t)
                    .id(t.id)
                    .task(id: t.id) {
                        try? await Task.sleep(nanoseconds: 2_200_000_000)
                        withAnimation(.easeOut(duration: 0.25)) {
                            if toast.wrappedValue?.id == t.id { toast.wrappedValue = nil }
                        }
                    }
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: toast.wrappedValue)
    }
}

/// Horizontal shake used for a wrong answer.
struct Shake: GeometryEffect {
    var travel: CGFloat = 10
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: travel * sin(animatableData * .pi * 4), y: 0))
    }
}
