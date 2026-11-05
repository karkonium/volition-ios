import ExpoModulesCore
import UIKit

final class FocusTimePickerView: ExpoView {
    let onTimeChange = EventDispatcher()
    private let picker = UIDatePicker()
    private var clock = Calendar(identifier: .gregorian)

    required init(appContext: AppContext? = nil) {
        super.init(appContext: appContext)
        let utc = TimeZone(secondsFromGMT: 0) ?? .current
        clock.timeZone = utc
        picker.timeZone = utc
        picker.datePickerMode = .time
        picker.preferredDatePickerStyle = .compact
        picker.addTarget(self, action: #selector(timeChanged), for: .valueChanged)
        addSubview(picker)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        picker.frame = bounds
    }

    func setMinutes(_ minutes: Int) {
        picker.setDate(Date(timeIntervalSince1970: Double(minutes * 60)), animated: false)
    }

    func setLabel(_ label: String) { picker.accessibilityLabel = label }

    @objc private func timeChanged() {
        let parts = clock.dateComponents([.hour, .minute], from: picker.date)
        onTimeChange(["minutes": (parts.hour ?? 0) * 60 + (parts.minute ?? 0)])
    }
}
