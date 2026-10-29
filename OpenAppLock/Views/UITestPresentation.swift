import SwiftUI

/// Presentation overrides are confined to explicit UI-test launches.
struct UITestPresentation: ViewModifier {
    func body(content: Content) -> some View {
        if LaunchConfiguration.current.isUITesting {
            content
                .preferredColorScheme(ProcessInfo.processInfo.arguments.contains("-dark-mode") ? .dark : nil)
                .transformEnvironment(\.dynamicTypeSize) { size in
                    if ProcessInfo.processInfo.arguments.contains("-large-text") { size = .accessibility3 }
                }
        } else { content }
    }
}
