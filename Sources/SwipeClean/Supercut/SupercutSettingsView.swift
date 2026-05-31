import SwiftUI
import Photos
import UIKit

// CutSpeed is defined in SupercutComposer.swift

// MARK: - SupercutPhase

/// The stage of the supercut generation flow currently shown to the user.
private enum SupercutPhase: Identifiable {
    case generating
    case preview(URL)

    var id: String {
        switch self {
        case .generating: return "generating"
        case .preview(let url): return "preview-\(url.absoluteString)"
        }
    }
}

// MARK: - MaxDuration

enum MaxDuration: Int, CaseIterable, Identifiable {
    case thirtySeconds = 30
    case sixtySeconds = 60
    case ninetySeconds = 90
    case twoMinutes = 120

    var id: Int { rawValue }

    var displayName: String {
        switch self {
        case .thirtySeconds: return "30s"
        case .sixtySeconds: return "60s"
        case .ninetySeconds: return "90s"
        case .twoMinutes: return "2min"
        }
    }
}

// MARK: - SupercutNavItem

/// Navigation value used to push SupercutSettingsView from HomeView.
struct SupercutNavItem: Hashable {
    let albumSource: AlbumSource
    let photoCount: Int
}

// MARK: - SupercutSettingsView

struct SupercutSettingsView: View {
    let albumSource: AlbumSource
    let photoCount: Int
    @Environment(\.dismiss) var dismiss

    @State private var cutSpeed: CutSpeed = .medium
    @State private var maxDuration: MaxDuration = .sixtySeconds
    @State private var showMusicPicker = false
    @StateObject private var musicModel = MusicPickerModel()
    @StateObject private var composer = SupercutComposer()
    @State private var isGenerating = false
    @State private var phase: SupercutPhase?
    @State private var generationTask: Task<Void, Never>?

    /// Maximum number of photos pulled into a supercut. Keeps Vision analysis
    /// and frame rendering within a reasonable time/memory budget.
    private static let maxPhotos = 200

    var body: some View {
        Form {
            // Header
            Section {
                HStack {
                    Image(systemName: albumSource.iconName)
                        .font(.title2)
                        .foregroundStyle(.tint)
                        .frame(width: 36, height: 36)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(albumSource.displayName)
                            .font(.headline)
                        Text("\(photoCount) photos")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // Cut Speed
            Section {
                Picker("Cut Speed", selection: $cutSpeed) {
                    ForEach(CutSpeed.allCases) { speed in
                        Text(speed.displayName).tag(speed)
                    }
                }
                .pickerStyle(.menu)
            } header: {
                Text("Transition Speed")
            } footer: {
                if cutSpeed == .beatMatch {
                    Text("Photo transitions will sync to the beat of the selected music.")
                }
            }

            // Max Duration
            Section("Video Length") {
                Picker("Max Duration", selection: $maxDuration) {
                    ForEach(MaxDuration.allCases) { duration in
                        Text(duration.displayName).tag(duration)
                    }
                }
                .pickerStyle(.segmented)
            }

            // Music
            Section("Music") {
                Button {
                    showMusicPicker = true
                } label: {
                    HStack {
                        Image(systemName: musicModel.selectedSource.iconName)
                            .foregroundStyle(.tint)
                            .frame(width: 28)

                        if let name = musicModel.selectedTrackName {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(name)
                                    .font(.body.weight(.medium))
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)
                                Text(musicModel.selectedSource.displayName)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } else {
                            Text("No Music")
                                .foregroundStyle(.primary)
                        }

                        Spacer()

                        Text("Change")
                            .font(.subheadline)
                            .foregroundStyle(.tint)
                    }
                }
                .buttonStyle(.plain)
            }

            // Generate button
            Section {
                Button {
                    generateSupercut()
                } label: {
                    HStack {
                        Spacer()
                        if isGenerating {
                            ProgressView()
                                .tint(.white)
                                .padding(.trailing, 8)
                        }
                        Text("Generate Supercut")
                            .font(.body.weight(.semibold))
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
                .disabled(isGenerating || photoCount == 0)
                .listRowBackground(Color.accentColor)
                .foregroundStyle(.white)
            }
        }
        .navigationTitle("Supercut Settings")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showMusicPicker) {
            MusicPickerView(model: musicModel)
        }
        .fullScreenCover(item: $phase) { phase in
            switch phase {
            case .generating:
                SupercutProgressView(
                    composer: composer,
                    onCancel: {
                        generationTask?.cancel()
                        composer.cancel()
                        isGenerating = false
                        self.phase = nil
                    },
                    onComplete: { url in
                        self.phase = .preview(url)
                    }
                )
            case .preview(let url):
                SupercutPreviewView(
                    videoURL: url,
                    onSave: {},
                    onShare: {},
                    onRegenerate: {
                        generationTask?.cancel()
                        isGenerating = false
                        self.phase = nil
                        generateSupercut()
                    },
                    onDismiss: {
                        isGenerating = false
                        self.phase = nil
                    }
                )
            }
        }
        .onDisappear {
            generationTask?.cancel()
        }
    }

    // MARK: - Generate

    /// Runs the full supercut pipeline: fetch assets → score with Vision →
    /// load render-quality images for the winners → compose video → preview.
    private func generateSupercut() {
        guard !isGenerating else { return }
        isGenerating = true
        phase = .generating

        let source = albumSource
        let speed = cutSpeed
        let maxLength = TimeInterval(maxDuration.rawValue)
        let musicURL = musicModel.selectedTrackURL

        generationTask = Task { @MainActor in
            // 1. Fetch assets for the source on a background queue.
            let assets = await Task.detached {
                LiveAssetFetcher().fetchAssets(for: source, sortOrder: .newestFirst)
            }.value

            if Task.isCancelled { return }

            guard !assets.isEmpty else {
                composer.error = "No photos found for this album."
                return
            }

            // 2. Cap the candidate pool, then score with the Vision analyzer.
            let candidates = Array(assets.prefix(Self.maxPhotos)).map { PhotoItem(asset: $0) }
            composer.status = "Analyzing \(candidates.count) photos..."

            let analyzer = PhotoAnalyzer()
            let scores = await analyzer.analyzeAndRank(candidates) { _ in }

            if Task.isCancelled { return }

            // 3. Keep the best photos (already sorted best-first), preserving
            //    chronological order so the montage reads as a timeline.
            let bestItems = scores
                .prefix(Self.maxPhotos)
                .map(\.item)
                .sorted { ($0.creationDate ?? .distantPast) < ($1.creationDate ?? .distantPast) }

            // 4. Load render-quality images for the chosen photos.
            composer.status = "Loading photos..."
            await loadRenderImages(for: bestItems)

            if Task.isCancelled { return }

            let renderable = bestItems.filter { $0.fullImage != nil || $0.mediaType == .video }
            guard !renderable.isEmpty else {
                composer.error = "Could not load photos to render."
                return
            }

            // 5. Compose the video. SupercutProgressView observes `composer`
            //    and fires onComplete when `isComplete` flips true.
            await composer.compose(
                photos: renderable,
                musicURL: musicURL,
                cutSpeed: speed,
                maxDuration: maxLength
            )
        }
    }

    /// Loads a high-resolution image for each still photo and assigns it to
    /// `fullImage`. Runs on a detached background task so it never blocks the UI,
    /// and reports progress through the composer's status line.
    private func loadRenderImages(for items: [PhotoItem]) async {
        let targetSize = CGSize(width: 1080, height: 1920)
        let total = items.count

        await Task.detached {
            let manager = PHImageManager.default()
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.resizeMode = .exact
            options.isNetworkAccessAllowed = true
            options.isSynchronous = true

            for (index, item) in items.enumerated() {
                if Task.isCancelled { return }
                guard item.fullImage == nil, item.mediaType != .video, let asset = item.asset else { continue }

                manager.requestImage(
                    for: asset,
                    targetSize: targetSize,
                    contentMode: .aspectFit,
                    options: options
                ) { image, _ in
                    if let image { item.fullImage = image }
                }

                if index % 10 == 0 {
                    let loaded = index + 1
                    await MainActor.run {
                        composer.status = "Loading photos... \(loaded)/\(total)"
                    }
                }
            }
        }.value
    }
}

#Preview {
    NavigationStack {
        SupercutSettingsView(
            albumSource: .month(2024, 3),
            photoCount: 47
        )
    }
}
