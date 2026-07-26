import StoreKit
import SwiftUI

/// The single purchase screen. Presented when a locked feature is tapped, and
/// reachable any time from Settings.
///
/// Apple requires a paywall to state what is being sold, that it is a one-time
/// charge, and to link the terms and privacy policy — all three are here rather
/// than buried in Settings.
struct PaywallView: View {
    @ObservedObject var pro: ProManager
    /// The feature the user actually tapped, so the screen opens on their reason
    /// for being here instead of a generic pitch.
    var highlighted: ProFeature?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    header

                    VStack(spacing: 14) {
                        ForEach(orderedFeatures, id: \.self) { feature in
                            featureRow(feature)
                        }
                    }

                    purchaseSection
                    legalLinks
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.footnote.weight(.bold))
                            .foregroundStyle(.secondary)
                            .padding(8)
                            .background(Color(.tertiarySystemFill), in: Circle())
                    }
                    .accessibilityLabel("Close")
                }
            }
            .onChange(of: pro.isPro) { isPro in
                if isPro { dismiss() }
            }
        }
    }

    /// The tapped feature leads; the rest follow in their declared order.
    private var orderedFeatures: [ProFeature] {
        guard let highlighted else { return ProFeature.allCases }
        return [highlighted] + ProFeature.allCases.filter { $0 != highlighted }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 10) {
            Image(systemName: "sparkles")
                .font(.system(size: 40, weight: .semibold))
                .foregroundStyle(.tint)

            Text("SwipeClean Pro")
                .font(.system(size: 30, weight: .bold, design: .rounded))

            Text("Swiping is always free. Pro adds the passes that do the deciding for you.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 12)
    }

    // MARK: - Features

    private func featureRow(_ feature: ProFeature) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: feature.icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.tint)
                .frame(width: 38, height: 38)
                .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(feature.title)
                    .font(.body.weight(.semibold))
                Text(feature.pitch)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            if feature == highlighted {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.accentColor.opacity(0.4), lineWidth: 1.5)
            }
        }
    }

    // MARK: - Purchase

    private var purchaseSection: some View {
        VStack(spacing: 12) {
            Button {
                Task { await pro.purchase() }
            } label: {
                HStack(spacing: 8) {
                    if pro.isWorking {
                        ProgressView().tint(.white)
                    } else {
                        Text("Unlock Pro — \(pro.displayPrice)")
                    }
                }
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .disabled(pro.isWorking)

            Text("One-time purchase. No subscription, and it stays unlocked on every device signed in to your Apple Account.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if let message = pro.errorMessage {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }

            Button("Restore Purchase") {
                Task { await pro.restore() }
            }
            .font(.subheadline.weight(.medium))
            .disabled(pro.isWorking)
        }
    }

    // MARK: - Legal

    private var legalLinks: some View {
        HStack(spacing: 6) {
            Link("Privacy Policy", destination: SwipeCleanLinks.privacy)
            Text("·").foregroundStyle(.tertiary)
            Link("Terms of Use", destination: SwipeCleanLinks.terms)
        }
        .font(.caption)
    }
}

/// Canonical destinations for the app's legal and support pages, so the paywall,
/// Settings, and the App Store listing can never drift apart.
enum SwipeCleanLinks {
    static let privacy = URL(string: "https://nosleeplab.com/swipeclean/privacy")!
    static let terms = URL(string: "https://nosleeplab.com/swipeclean/terms")!
    static let support = URL(string: "https://nosleeplab.com/swipeclean/support")!
    /// The marketing page App Store Connect points at.
    static let appPage = URL(string: "https://nosleeplab.com/apps/swipeclean")!
}
