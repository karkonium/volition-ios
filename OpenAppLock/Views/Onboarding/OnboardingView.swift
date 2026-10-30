//
//  OnboardingView.swift
//  OpenAppLock
//

import SwiftUI

/// Consent-aware onboarding introduces the access model before requesting
/// Screen Time permission. Onboarding only completes once
/// authorization is approved; MainView then requires per-app intention setup.
struct OnboardingView: View {
    @Environment(ConversationCoordinator.self) private var conversation
    @Environment(ScreenTimeAuthorization.self) private var authorization
    @Environment(\.openURL) private var openURL
    let onComplete: () -> Void

    private enum Step: Int, CaseIterable {
        case welcome
        case privacy
        case permission
    }

    @State private var step = Step.welcome
    @State private var isRequesting = false
    @State private var showingPrivacy = false

    var body: some View {
        VStack(spacing: 0) {
            progressHeader
                .padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 16)
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    switch step {
                    case .welcome: welcome
                    case .privacy: privacy
                    case .permission: permission
                    }
                }
                .frame(maxWidth: 560, alignment: .leading)
                .padding(.horizontal, 20).padding(.bottom, 24)
                .frame(maxWidth: .infinity, alignment: .top)
            }
            footer
                .frame(maxWidth: 560).padding(20).frame(maxWidth: .infinity)
                .background(VolitionStyle.background)
                .overlay(alignment: .top) { Divider() }
        }
        .background(VolitionStyle.background)
        .tint(VolitionStyle.accent)
    }

    private var progressHeader: some View {
        VStack(spacing: 12) {
            HStack {
                if step != .welcome {
                    Button { step = step == .permission ? .privacy : .welcome } label: {
                        Label(CopyKey.uiBack.resource, systemImage: "chevron.left")
                            .font(.subheadline.weight(.medium)).frame(minHeight: 44)
                    }.disabled(isRequesting).accessibilityIdentifier("onboardingBackButton")
                } else {
                    Text(CopyKey.uiWelcomeStep.resource).font(.subheadline.weight(.medium))
                        .frame(minHeight: 44)
                }
                Spacer()
                Text((step == .welcome ? CopyKey.uiWelcomeStep : step == .privacy ? .uiPrivacyStep : .uiPermissionStep).resource)
                    .font(.caption).foregroundStyle(.secondary)
                    .opacity(step == .welcome ? 0 : 1)
            }
            HStack(spacing: 6) {
                ForEach(Step.allCases, id: \.rawValue) { item in
                    Capsule().fill(item.rawValue <= step.rawValue ? Color.primary : VolitionStyle.border)
                        .frame(height: 3)
                }
            }.accessibilityHidden(true)
        }.frame(maxWidth: 560).frame(maxWidth: .infinity)
    }

    private var stepSpacing: CGFloat { 16 }

    private var welcome: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(spacing: 12) {
                appLogo
                Text(CopyKey.volitionWelcome.resource).font(.title.bold())
                    .accessibilityAddTraits(.isHeader)
            }
            Text(CopyKey.volitionWelcomeDescription.resource)
                .font(.body).foregroundStyle(.secondary)
            VolitionCard {
                Text(CopyKey.uiHowItWorks.resource).font(.headline)
                    .accessibilityIdentifier("welcomeHowItWorks")
                walkthrough("apps.iphone", .uiChooseStep, .uiChooseDetail)
                Divider()
                walkthrough("bubble.left.and.bubble.right", .uiConversationStep, .uiConversationDetail)
                Divider()
                walkthrough("lock.open", .uiAccessStep, .uiAccessDetail)
            }
            VStack(alignment: .leading, spacing: 6) {
                Label(CopyKey.uiVoluntaryTitle.resource, systemImage: "hand.raised")
                    .font(.subheadline.weight(.semibold))
                Text(CopyKey.uiVoluntaryDetail.resource).font(.footnote).foregroundStyle(.secondary)
            }
        }
    }

    private func walkthrough(_ symbol: String, _ title: CopyKey, _ detail: CopyKey) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VolitionIcon(symbol: symbol, accented: true)
            VStack(alignment: .leading, spacing: 4) {
                Text(title.resource).font(.subheadline.weight(.semibold))
                Text(detail.resource).font(.footnote).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }.padding(.vertical, 2)
    }

    /// The real app icon, shown as a rounded tile so the welcome screen leads
    /// with the app's own identity rather than a generic symbol.
    private var appLogo: some View {
        Image("VolitionLogo")
            .resizable()
            .scaledToFit()
            .frame(width: 48, height: 48)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            .accessibilityHidden(true)
    }

    private var privacy: some View {
        VStack(alignment: .leading, spacing: stepSpacing) {
                VolitionIcon(symbol: "hand.raised", accented: true)
                Text(CopyKey.aiConsentTitle.resource).font(.title.bold())
                AISharingDetails()
                Text(CopyKey.aiConsentWithdrawal.resource).font(.footnote).foregroundStyle(.secondary)
                Button(CopyKey.privacyTitle.resource, systemImage: "arrow.up.right") { showingPrivacy = true }
                    .buttonStyle(VolitionButtonStyle(primary: false))
                    .sheet(isPresented: $showingPrivacy) { NavigationStack { PrivacyDataView() } }
        }
    }

    private var permission: some View {
        VStack(alignment: .leading, spacing: stepSpacing) {
            VolitionIcon(symbol: "hourglass", accented: true)
            Text(.onboardingAllowScreenTime)
                .font(.title.bold())
                .multilineTextAlignment(.leading)
            VolitionCard {
                bullet("shield.fill", CopyKey.onboardingScreenTimeFrameworkBullet.string)
                bullet("hand.raised.fill", CopyKey.onboardingActivityStaysPrivateBullet.string)
                bullet("gearshape.fill", CopyKey.onboardingChangeAnytimeBullet.string)
            }
            if authorization.status == .denied || authorization.lastRequestFailed {
                VStack(spacing: 10) {
                    Text(.onboardingAccessDeclinedMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.leading)
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
                step = .privacy
            }
        case .privacy:
            VStack(spacing: 16) {
                pillButton(CopyKey.aiConsentAccept.string, identifier: "acceptAIConsentButton") {
                    conversation.setAIConsent(true); step = .permission
                }
                Button(CopyKey.aiConsentLater.resource) { conversation.setAIConsent(false); step = .permission }
                    .buttonStyle(VolitionButtonStyle(primary: false))
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
        .buttonStyle(VolitionButtonStyle())
        .accessibilityIdentifier(identifier)
    }
}
