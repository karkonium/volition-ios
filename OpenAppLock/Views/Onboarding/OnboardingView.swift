//
//  OnboardingView.swift
//  OpenAppLock
//

import SwiftUI

/// Consent-aware onboarding introduces the access model before requesting
/// Screen Time permission request. Onboarding only completes once
/// authorization is approved; MainView then requires per-app intention setup.
struct OnboardingView: View {
    @Environment(ConversationCoordinator.self) private var conversation
    @Environment(ScreenTimeAuthorization.self) private var authorization
    @Environment(\.openURL) private var openURL
    let onComplete: () -> Void

    private enum Step {
        case welcome
        case privacy
        case permission
    }

    @State private var step = Step.welcome
    @State private var isRequesting = false
    @State private var showingPrivacy = false

    var body: some View {
        VStack(spacing: 20) {
            GeometryReader { geometry in
                ScrollView {
                    VStack {
                        switch step {
                        case .welcome: welcome
                        case .privacy: privacy
                        case .permission: permission
                        }
                    }
                    .frame(maxWidth: 560)
                    .frame(maxWidth: .infinity, minHeight: geometry.size.height)
                }
            }
            footer
        }.padding()
    }

    /// Shared vertical rhythm so both onboarding steps line up.
    private var stepSpacing: CGFloat { 20 }

    private var welcome: some View {
        VStack(spacing: stepSpacing) {
            appLogo
            Text(CopyKey.volitionWelcome.resource)
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)
            Text(CopyKey.volitionWelcomeDescription.resource)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    /// The real app icon, shown as a rounded tile so the welcome screen leads
    /// with the app's own identity rather than a generic symbol.
    private var appLogo: some View {
        Image("VolitionLogo")
            .resizable()
            .scaledToFit()
            .frame(width: 96, height: 96)
            .clipShape(RoundedRectangle(cornerRadius: 21, style: .continuous))
            .shadow(color: .black.opacity(0.15), radius: 10, y: 4)
            .accessibilityHidden(true)
    }

    private var privacy: some View {
            VStack(alignment: .leading, spacing: stepSpacing) {
                Image(systemName: "hand.raised.fill").font(.largeTitle).foregroundStyle(.tint)
                Text(CopyKey.aiConsentTitle.resource).font(.largeTitle.bold())
                Text(CopyKey.aiConsentDisclosure.resource).foregroundStyle(.secondary)
                Text(CopyKey.aiConsentWithdrawal.resource).font(.footnote).foregroundStyle(.secondary)
                Button(CopyKey.privacyTitle.resource) { showingPrivacy = true }
                    .sheet(isPresented: $showingPrivacy) { NavigationStack { PrivacyDataView() } }
            }
    }

    private var permission: some View {
        VStack(spacing: stepSpacing) {
            Image(systemName: "hourglass")
                .font(.system(size: 52))
                .foregroundStyle(.tint)
            Text(.onboardingAllowScreenTime)
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)
            VStack(alignment: .leading, spacing: 14) {
                bullet("shield.fill", CopyKey.onboardingScreenTimeFrameworkBullet.string)
                bullet("hand.raised.fill", CopyKey.onboardingActivityStaysPrivateBullet.string)
                bullet("gearshape.fill", CopyKey.onboardingChangeAnytimeBullet.string)
            }
            if authorization.status == .denied || authorization.lastRequestFailed {
                VStack(spacing: 10) {
                    Text(.onboardingAccessDeclinedMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .accessibilityIdentifier("permissionDeniedLabel")
                    Button(CopyKey.onboardingOpenSettingsButton.resource) {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            openURL(url)
                        }
                    }
                    .accessibilityIdentifier("openSettingsButton")
                }
            }
        }
    }

    private func bullet(_ systemImage: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .foregroundStyle(.tint)
                .frame(width: 24)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var footer: some View {
        switch step {
        case .welcome:
            pillButton(CopyKey.onboardingContinueButton.string, identifier: "onboardingContinueButton") {
                step = conversation.preferences.hasConsent ? .permission : .privacy
            }
        case .privacy:
            VStack(spacing: 16) {
                pillButton(CopyKey.aiConsentAccept.string, identifier: "acceptAIConsentButton") {
                    conversation.setAIConsent(true); step = .permission
                }
                Button(CopyKey.aiConsentLater.resource) { step = .permission }
                    .accessibilityIdentifier("deferAIConsentButton")
            }
        case .permission:
            pillButton(
                isRequesting ? CopyKey.onboardingRequesting.string : CopyKey.onboardingAllowScreenTime.string,
                identifier: "allowScreenTimeButton"
            ) {
                guard !isRequesting else { return }
                isRequesting = true
                Task {
                    await authorization.request()
                    isRequesting = false
                    if authorization.status == .approved {
                        onComplete()
                    }
                }
            }
        }
    }

    private func pillButton(
        _ title: String, identifier: String, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .accessibilityIdentifier(identifier)
    }
}
