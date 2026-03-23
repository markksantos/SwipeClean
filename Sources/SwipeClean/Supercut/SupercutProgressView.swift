import SwiftUI

/// Displays real-time progress while the supercut video is being generated.
struct SupercutProgressView: View {
    @ObservedObject var composer: SupercutComposer
    let onCancel: () -> Void
    let onComplete: (URL) -> Void

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Progress ring
            ZStack {
                Circle()
                    .stroke(Color(.systemGray5), lineWidth: 8)
                    .frame(width: 120, height: 120)

                Circle()
                    .trim(from: 0, to: CGFloat(composer.progress))
                    .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.3), value: composer.progress)

                Text("\(Int(composer.progress * 100))%")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
            }

            // Status text
            Text(composer.status)
                .font(.subheadline.weight(.medium))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            // Error display
            if let error = composer.error {
                Text(error)
                    .font(.subheadline)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()

            // Cancel button
            Button {
                composer.cancel()
                onCancel()
            } label: {
                Text("Cancel")
                    .font(.headline)
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(Color(.systemGray5))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .onChange(of: composer.isComplete) { complete in
            if complete, let url = composer.outputURL {
                onComplete(url)
            }
        }
    }
}
