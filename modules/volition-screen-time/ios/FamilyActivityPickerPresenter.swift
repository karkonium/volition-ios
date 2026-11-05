import SwiftUI
import FamilyControls
import ExpoModulesCore

/// Cancel and interactive dismissal preserve the caller's prior token. Exactly
/// one application and no category/domain selection completes the picker.
@MainActor
final class FamilyActivityPickerPresenter: NSObject, UIAdaptivePresentationControllerDelegate {
    static let shared = FamilyActivityPickerPresenter()
    private var pending: Promise?
    private weak var host: UIViewController?
    func present(promise: Promise) {
        guard pending == nil else { promise.reject("ERR_PICKER_BUSY", "An app picker is already open"); return }
        guard
            var root = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene })
                .flatMap(\.windows).first(where: \.isKeyWindow)?.rootViewController
        else {
            promise.reject("ERR_NO_ROOT", "No active window"); return
        }
        while let presented = root.presentedViewController { root = presented }
        pending = promise
        let controller = UIHostingController(
            rootView: SingleAppPicker { [weak self] selection in
                guard let self else { return }
                do {
                    guard selection.categoryTokens.isEmpty, selection.webDomainTokens.isEmpty,
                        selection.applicationTokens.count == 1, let token = selection.applicationTokens.first
                    else { return }
                    let encoded = try JSONEncoder().encode(token).base64EncodedString()
                    self.pending?.resolve(["tokenBase64": encoded]); self.pending = nil
                    self.host?.dismiss(animated: true)
                } catch { self.cancel() }
            } onCancel: { [weak self] in
                self?.cancel()
            })
        host = controller
        root.present(controller, animated: true)
        controller.presentationController?.delegate = self
    }
    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) { cancel() }
    private func cancel() {
        pending?.reject("ERR_CANCELLED", "App selection cancelled"); pending = nil
        host?.dismiss(animated: true)
    }
}

private struct SingleAppPicker: View {
    @State private var selection = FamilyActivitySelection()
    let onSelect: (FamilyActivitySelection) -> Void
    let onCancel: () -> Void
    var body: some View {
        NavigationStack {
            FamilyActivityPicker(selection: $selection)
                .navigationTitle("Choose App").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel", action: onCancel) } }
                .onChange(of: selection) { _, value in onSelect(value) }
        }
    }
}
