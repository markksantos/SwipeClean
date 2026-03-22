import SwiftUI

struct StatsCard: View {
    let photosDeleted: Int
    let storageFreed: Int64

    private var hasActivity: Bool {
        photosDeleted > 0
    }

    var body: some View {
        VStack(spacing: 16) {
            if hasActivity {
                HStack(spacing: 24) {
                    statColumn(
                        value: "\(photosDeleted)",
                        label: "Photos Cleaned"
                    )
                    Divider()
                        .frame(height: 48)
                    statColumn(
                        value: StorageFormatter.humanReadable(bytes: storageFreed),
                        label: "Storage Freed"
                    )
                }
            } else {
                VStack(spacing: 8) {
                    Text("0")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                    Text("photos cleaned")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("Start swiping to free up space")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func statColumn(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview("With Stats") {
    StatsCard(photosDeleted: 247, storageFreed: 4_800_000_000)
        .padding()
}

#Preview("Zero State") {
    StatsCard(photosDeleted: 0, storageFreed: 0)
        .padding()
}
