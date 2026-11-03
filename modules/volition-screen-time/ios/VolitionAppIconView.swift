import ExpoModulesCore
import FamilyControls
import SwiftUI

final class VolitionAppIconView: ExpoView {
    private var controller: UIHostingController<AnyView>?
    func updateToken(_ encoded: String) {
        controller?.view.removeFromSuperview()
        guard let data = Data(base64Encoded: encoded),
              let token = try? JSONDecoder().decode(ApplicationToken.self, from: data) else { return }
        let host = UIHostingController(rootView: AnyView(Label(token).labelStyle(.iconOnly)))
        host.view.backgroundColor = .clear
        host.view.translatesAutoresizingMaskIntoConstraints = false
        addSubview(host.view)
        NSLayoutConstraint.activate([
            host.view.leadingAnchor.constraint(equalTo: leadingAnchor), host.view.trailingAnchor.constraint(equalTo: trailingAnchor),
            host.view.topAnchor.constraint(equalTo: topAnchor), host.view.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        controller = host
    }
}
