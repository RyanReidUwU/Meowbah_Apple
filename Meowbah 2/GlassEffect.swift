import SwiftUI

private struct GlassEffectModifier: ViewModifier {
    var cornerRadius: CGFloat = 12
    var strokeOpacity: Double = 0.25
    var shadowOpacity: Double = 0.08

    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(strokeOpacity), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(shadowOpacity), radius: 8, x: 0, y: 4)
    }
}

private struct InteractivePressModifier: ViewModifier {
    @GestureState private var isPressed = false
    let enabled: Bool

    func body(content: Content) -> some View {
        if enabled {
            content
                .scaleEffect(isPressed ? 0.98 : 1.0)
                .opacity(isPressed ? 0.9 : 1.0)
                .animation(.spring(response: 0.25, dampingFraction: 0.9), value: isPressed)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .updating($isPressed) { _, state, _ in
                            state = true
                        }
                )
        } else {
            content
        }
    }
}

extension View {
    func glassEffect(cornerRadius: CGFloat = 12) -> some View {
        modifier(GlassEffectModifier(cornerRadius: cornerRadius))
    }

    func interactive(_ enabled: Bool) -> some View {
        modifier(InteractivePressModifier(enabled: enabled))
    }
}
