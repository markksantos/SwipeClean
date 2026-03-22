import SwiftUI
import Photos

struct AlbumCard: View {
    let source: AlbumSource
    let photoCount: Int
    let onTap: () -> Void

    private var isEmpty: Bool {
        photoCount == 0
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                // Icon
                Image(systemName: source.iconName)
                    .font(.title2)
                    .foregroundStyle(isEmpty ? .tertiary : .primary)
                    .frame(width: 40, height: 40)
                    .background(isEmpty ? Color.secondary.opacity(0.08) : Color.accentColor.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                // Name and count
                VStack(alignment: .leading, spacing: 2) {
                    Text(source.displayName)
                        .font(.body.weight(.medium))
                        .foregroundStyle(isEmpty ? .tertiary : .primary)
                        .lineLimit(1)

                    if isEmpty {
                        Text("Empty")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    } else {
                        Text("\(photoCount) photos")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                if !isEmpty {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(PressDownButtonStyle())
        .disabled(isEmpty)
    }
}

// MARK: - Press-Down Button Style

struct PressDownButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

#Preview {
    VStack(spacing: 12) {
        AlbumCard(source: .allPhotos, photoCount: 1234) {}
        AlbumCard(source: .screenshots, photoCount: 56) {}
        AlbumCard(source: .videos, photoCount: 0) {}
    }
    .padding()
}
