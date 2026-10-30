import SwiftUI

/// Brief attention without losing input. Reduce Motion uses the outline alone.
private struct VolitionAttention: ViewModifier {
    let trigger: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func body(content: Content) -> some View {
        let motionReduced = reduceMotion
        let attentionColor = VolitionStyle.accent
        let radius = VolitionStyle.radius
        return content.keyframeAnimator(initialValue: CGFloat.zero, trigger: trigger) { view, offset in
            view.overlay {
                RoundedRectangle(cornerRadius: radius)
                    .strokeBorder(attentionColor.opacity(Double(abs(offset) / 7)), lineWidth: 2)
                    .allowsHitTesting(false)
            }
            .scaleEffect(motionReduced ? 1 : 1 + abs(offset) * 0.002)
            .offset(x: motionReduced ? 0 : offset)
        } keyframes: { _ in
            LinearKeyframe(CGFloat(-7), duration: 0.06)
            LinearKeyframe(CGFloat(7), duration: 0.08)
            LinearKeyframe(CGFloat(-4), duration: 0.08)
            LinearKeyframe(CGFloat(4), duration: 0.08)
            LinearKeyframe(CGFloat.zero, duration: 0.08)
        }
        .sensoryFeedback(.warning, trigger: trigger)
    }
}
extension View {
    func volitionAttention(trigger: Int) -> some View { modifier(VolitionAttention(trigger: trigger)) }
}
