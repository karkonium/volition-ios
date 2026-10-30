import SwiftUI

/// Compact native surfaces shared by the main screens. Borders provide structure;
/// icons, chevrons and button treatments distinguish actions from information.
enum VolitionStyle {
    static let background = Color(uiColor: .systemBackground)
    static let surface = Color(uiColor: .secondarySystemGroupedBackground)
    static let subtle = Color(uiColor: .secondarySystemBackground)
    static let border = Color.primary.opacity(0.10)
    static let accent = Color(uiColor: .systemBlue)
    static let radius: CGFloat = 16
}

struct VolitionCard<Content: View>: View {
    var accented = false
    @ViewBuilder let content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 12) { content }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(accented ? VolitionStyle.accent.opacity(0.08) : VolitionStyle.surface,
                in: RoundedRectangle(cornerRadius: VolitionStyle.radius))
            .overlay { RoundedRectangle(cornerRadius: VolitionStyle.radius).strokeBorder(VolitionStyle.border, lineWidth: 1) }
    }
}

struct VolitionScroll<Content: View>: View {
    @ViewBuilder let content: Content
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) { content }
                .frame(maxWidth: 720, alignment: .leading)
                .padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 24)
                .frame(maxWidth: .infinity, alignment: .top)
        }.background(VolitionStyle.background)
    }
}

struct VolitionSectionHeading: View {
    let title: String
    var count: Int? = nil
    var body: some View {
        HStack(spacing: 8) {
            Text(title).font(.headline).accessibilityAddTraits(.isHeader)
            if let count {
                Text(count.formatted()).font(.caption.weight(.semibold))
                    .padding(.horizontal, 7).padding(.vertical, 3)
                    .background(VolitionStyle.subtle, in: RoundedRectangle(cornerRadius: 6))
            }
            Spacer(minLength: 0)
        }
    }
}

struct VolitionIcon: View {
    let symbol: String
    var accented = false
    var body: some View {
        Image(systemName: symbol).font(.body.weight(.medium))
            .foregroundStyle(accented ? VolitionStyle.accent : .primary)
            .frame(width: 36, height: 36)
            .background(accented ? VolitionStyle.accent.opacity(0.10) : VolitionStyle.subtle,
                in: RoundedRectangle(cornerRadius: 10))
            .accessibilityHidden(true)
    }
}

/// Recommended actions use a bright fill and bold label; alternatives remain
/// readable with a lighter surface and label. Both retain a 44-point touch target.
struct VolitionButtonStyle: ButtonStyle {
    var primary = true
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.subheadline.weight(primary ? .bold : .regular))
            .frame(maxWidth: .infinity, minHeight: 44)
            .padding(.horizontal, 12)
            .foregroundStyle(primary ? Color.white : configuration.role == .destructive ? Color.red : Color.secondary)
            .background(primary ? (configuration.role == .destructive ? Color.red : VolitionStyle.accent) : VolitionStyle.subtle,
                in: RoundedRectangle(cornerRadius: 12))
            .overlay { RoundedRectangle(cornerRadius: 12).strokeBorder(primary ? Color.clear : VolitionStyle.border, lineWidth: 1) }
            .opacity(enabled ? (configuration.isPressed ? 0.72 : 1) : 0.35)
            .contentShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct VolitionSettingsLabel: View {
    let title: String
    let subtitle: String
    let symbol: String
    var body: some View {
        HStack(spacing: 12) {
            VolitionIcon(symbol: symbol)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(Color.primary)
                Text(subtitle).font(.caption).foregroundStyle(Color.secondary)
            }
            Spacer(minLength: 8)
            Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.tertiary)
        }.frame(minHeight: 44).contentShape(Rectangle())
    }
}

extension View {
    /// Tab labels identify the root screen; its navigation bar need not take space.
    /// Setup and pushed detail screens retain their titles and navigation controls.
    func volitionTabRoot(setupTitle: String? = nil) -> some View {
        navigationTitle(setupTitle ?? "").navigationBarTitleDisplayMode(.inline)
            .toolbar(setupTitle == nil ? .hidden : .visible, for: .navigationBar)
            .toolbarBackground(VolitionStyle.background, for: .navigationBar)
    }
    func volitionRoot(_ title: String) -> some View {
        navigationTitle(title).navigationBarTitleDisplayMode(.inline)
            .toolbar(.visible, for: .navigationBar)
            .toolbarBackground(VolitionStyle.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
    }
    func volitionForm() -> some View {
        scrollContentBackground(.hidden)
            .contentMargins(.top, 8, for: .scrollContent)
            .listSectionSpacing(.compact)
            .background(VolitionStyle.subtle)
            .navigationBarTitleDisplayMode(.inline)
            .tint(VolitionStyle.accent)
    }
}
