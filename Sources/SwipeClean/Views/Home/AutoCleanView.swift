import SwiftUI
import Photos

/// View showing toggleable cleanup rules with a "Find Matches" action.
struct AutoCleanView: View {
    @EnvironmentObject private var deleteManager: DeleteManager
    @EnvironmentObject private var sessionTracker: SessionTracker

    @State private var rules: [CleanupRule] = CleanupRule.loadPresets()
    @State private var isScanning = false
    @State private var scanProgress: Double = 0
    @State private var matchedAssets: [PHAsset] = []
    @State private var estimatedBytes: Int64 = 0
    @State private var hasScanned = false
    @State private var navigateToSwipe = false

    private let engine = CleanupRuleEngine()

    private var enabledCount: Int {
        rules.filter(\.isEnabled).count
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 6) {
                    Text("Auto Clean")
                        .font(.title2.weight(.bold))
                    Text("Enable rules below to find photos and videos you can clean up.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 8)

                // Rule Cards
                VStack(spacing: 12) {
                    ForEach(Array(rules.enumerated()), id: \.element.id) { index, rule in
                        ruleCard(rule: rule, index: index)
                    }
                }

                // Find Matches button
                if enabledCount > 0 {
                    Button {
                        Task { await runScan() }
                    } label: {
                        HStack {
                            if isScanning {
                                ProgressView()
                                    .tint(.white)
                                    .padding(.trailing, 4)
                                Text("Scanning... \(Int(scanProgress * 100))%")
                            } else {
                                Image(systemName: "magnifyingglass")
                                Text("Find Matches")
                            }
                        }
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(isScanning ? Color.gray : Color.accentColor)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .disabled(isScanning)
                }

                // Results
                if hasScanned {
                    resultsSection
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 32)
        }
        .navigationTitle("Auto Clean")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $navigateToSwipe) {
            SwipeView(albumName: "Auto Clean", albumSource: .autoClean)
                .environmentObject(deleteManager)
                .environmentObject(sessionTracker)
        }
    }

    // MARK: - Rule Card

    private func ruleCard(rule: CleanupRule, index: Int) -> some View {
        HStack(spacing: 14) {
            Image(systemName: rule.iconName)
                .font(.title2)
                .foregroundStyle(rule.isEnabled ? Color.accentColor : Color.secondary)
                .frame(width: 40, height: 40)
                .background(rule.isEnabled ? Color.accentColor.opacity(0.12) : Color.secondary.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(rule.name)
                    .font(.body.weight(.medium))
                    .lineLimit(1)
                Text(rule.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            Toggle("", isOn: Binding(
                get: { rules[index].isEnabled },
                set: { newValue in
                    rules[index].isEnabled = newValue
                    CleanupRule.saveEnabledRules(rules)
                    // Clear previous results when rules change
                    if hasScanned {
                        hasScanned = false
                        matchedAssets = []
                        estimatedBytes = 0
                    }
                }
            ))
            .labelsHidden()
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: - Results Section

    private var resultsSection: some View {
        VStack(spacing: 14) {
            if matchedAssets.isEmpty {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.title2)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("All Clean!")
                            .font(.body.weight(.semibold))
                        Text("No photos matched your rules.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(14)
                .background(Color.green.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            } else {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .font(.title2)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(matchedAssets.count) items found")
                            .font(.body.weight(.semibold))
                        Text("Estimated \(formattedStorage)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(14)
                .background(Color.orange.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                Button {
                    // Store matched assets for PhotoLoader to pick up
                    AutoCleanAssetStore.shared.assets = matchedAssets
                    navigateToSwipe = true
                } label: {
                    HStack {
                        Image(systemName: "hand.draw")
                        Text("Start Reviewing")
                    }
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.orange)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
        }
    }

    // MARK: - Actions

    private func runScan() async {
        isScanning = true
        scanProgress = 0
        hasScanned = false

        let result = await engine.findMatches(for: rules) { progress in
            scanProgress = progress
        }

        matchedAssets = result.assets
        estimatedBytes = result.estimatedBytes
        isScanning = false
        hasScanned = true
    }

    private var formattedStorage: String {
        ByteCountFormatter.string(fromByteCount: estimatedBytes, countStyle: .file)
    }
}

// MARK: - Shared Asset Store

/// Holds pre-filtered assets from AutoCleanView so PhotoLoader can pick them up.
final class AutoCleanAssetStore {
    static let shared = AutoCleanAssetStore()
    var assets: [PHAsset] = []
    private init() {}
}
