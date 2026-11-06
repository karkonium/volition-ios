import AppIntents
import Foundation
internal import VolitionScreenTime

enum FocusIntentError: Error, CustomLocalizedStringResourceConvertible {
    case permission, configure, unavailable

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .permission: "Allow Screen Time access in Volition first."
        case .configure: "Choose which apps to protect in Quick Focus in Volition first."
        case .unavailable: "Volition couldn’t change Focus. Try again in the app."
        }
    }

    init(_ failure: FocusSystemActions.Failure) {
        switch failure {
        case .permission: self = .permission
        case .configure: self = .configure
        case .unavailable: self = .unavailable
        }
    }
}

struct StartVolitionFocusIntent: AppIntent {
    static let title: LocalizedStringResource = "Start Volition Focus"
    static let description = IntentDescription("Start a Quick Focus session using your saved Volition settings.")

    func perform() async throws -> some IntentResult & ProvidesDialog {
        do {
            let end = try await FocusSystemActions.start()
            return .result(dialog: "Volition Focus is active until \(end.formatted(date: .omitted, time: .shortened)).")
        } catch let failure as FocusSystemActions.Failure { throw FocusIntentError(failure) }
    }
}

struct EndVolitionFocusIntent: AppIntent {
    static let title: LocalizedStringResource = "End Volition Focus"
    static let description = IntentDescription("End the current Quick Focus session in Volition.")

    func perform() async throws -> some IntentResult & ProvidesDialog {
        do {
            try await FocusSystemActions.end()
            return .result(dialog: "Volition Quick Focus has ended.")
        } catch let failure as FocusSystemActions.Failure { throw FocusIntentError(failure) }
    }
}

struct VolitionFocusShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartVolitionFocusIntent(),
            phrases: ["Start Focus in \(.applicationName)"],
            shortTitle: "Start Focus",
            systemImageName: "moon.fill")
        AppShortcut(
            intent: EndVolitionFocusIntent(),
            phrases: ["End Focus in \(.applicationName)"],
            shortTitle: "End Focus",
            systemImageName: "moon")
    }
}
