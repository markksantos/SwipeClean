import SwiftUI
import MediaPlayer
import AVFoundation
import UniformTypeIdentifiers

// MARK: - MusicSource

enum MusicSource: String, CaseIterable, Identifiable {
    case none
    case appleMusic
    case files
    case pixabay

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .none: return "No Music"
        case .appleMusic: return "Apple Music"
        case .files: return "From Files"
        case .pixabay: return "Free Library"
        }
    }

    var iconName: String {
        switch self {
        case .none: return "speaker.slash"
        case .appleMusic: return "music.note"
        case .files: return "folder"
        case .pixabay: return "waveform"
        }
    }
}

// MARK: - PixabayTrack

struct PixabayTrack: Identifiable, Codable {
    let id: Int
    let title: String
    let duration: Int       // seconds
    let audioURL: String    // download URL (from "audio" field)
    let tags: String

    enum CodingKeys: String, CodingKey {
        case id, title, duration, tags
        case audioURL = "audio"
    }
}

// MARK: - Pixabay API Response

private struct PixabayMusicResponse: Codable {
    let hits: [PixabayTrack]
}

// MARK: - MusicPickerModel

final class MusicPickerModel: ObservableObject {
    @Published var selectedSource: MusicSource = .none
    @Published var selectedTrackURL: URL?
    @Published var selectedTrackName: String?
    @Published var pixabayTracks: [PixabayTrack] = []
    @Published var isLoadingTracks = false

    /// Placeholder Pixabay API key. Replace with a real key before shipping.
    private static let pixabayAPIKey = "YOUR_PIXABAY_API_KEY"

    private var audioPlayer: AVAudioPlayer?

    // MARK: - Pixabay

    /// Fetch tracks from the Pixabay music API.
    func fetchPixabayTracks(query: String = "upbeat") async {
        await MainActor.run { isLoadingTracks = true }
        defer { Task { @MainActor in isLoadingTracks = false } }

        let sanitized = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        guard let url = URL(string: "https://pixabay.com/api/?key=\(Self.pixabayAPIKey)&q=\(sanitized)&category=music") else { return }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(PixabayMusicResponse.self, from: data)
            await MainActor.run { pixabayTracks = response.hits }
        } catch {
            print("Pixabay fetch error: \(error)")
        }
    }

    /// Download a Pixabay track to a temp file and set selectedTrackURL.
    func downloadTrack(_ track: PixabayTrack) async {
        guard let remoteURL = URL(string: track.audioURL) else { return }

        do {
            let (tempURL, _) = try await URLSession.shared.download(from: remoteURL)
            let dest = FileManager.default.temporaryDirectory.appendingPathComponent("\(track.id).mp3")
            try? FileManager.default.removeItem(at: dest)
            try FileManager.default.moveItem(at: tempURL, to: dest)

            await MainActor.run {
                selectedTrackURL = dest
                selectedTrackName = track.title
                selectedSource = .pixabay
            }
        } catch {
            print("Download error: \(error)")
        }
    }

    // MARK: - Preview Playback

    func previewTrack(url: URL) {
        stopPreview()
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.play()
        } catch {
            print("Preview error: \(error)")
        }
    }

    func stopPreview() {
        audioPlayer?.stop()
        audioPlayer = nil
    }

    // MARK: - Apple Music

    /// The Apple Music picker is presented via UIViewControllerRepresentable;
    /// the delegate callback sets selectedTrackURL.
    func handleAppleMusicSelection(_ mediaItem: MPMediaItem) {
        selectedTrackURL = mediaItem.assetURL
        selectedTrackName = mediaItem.title ?? "Apple Music Track"
        selectedSource = .appleMusic
    }

    // MARK: - Files

    /// The document picker is presented via UIViewControllerRepresentable;
    /// the delegate callback sets selectedTrackURL.
    func handleFileSelection(_ url: URL) {
        selectedTrackURL = url
        selectedTrackName = url.lastPathComponent
        selectedSource = .files
    }

    // MARK: - Clear

    func clearSelection() {
        stopPreview()
        selectedSource = .none
        selectedTrackURL = nil
        selectedTrackName = nil
    }
}

// MARK: - MusicPickerView

struct MusicPickerView: View {
    @ObservedObject var model: MusicPickerModel
    @Environment(\.dismiss) var dismiss

    @State private var searchQuery = "upbeat"
    @State private var showAppleMusicPicker = false
    @State private var showFilePicker = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Source selector
                Picker("Source", selection: $model.selectedSource) {
                    ForEach(MusicSource.allCases) { source in
                        Label(source.displayName, systemImage: source.iconName)
                            .tag(source)
                    }
                }
                .pickerStyle(.segmented)
                .padding()

                Divider()

                // Content based on selected source
                Group {
                    switch model.selectedSource {
                    case .none:
                        noMusicView
                    case .appleMusic:
                        appleMusicView
                    case .files:
                        filesView
                    case .pixabay:
                        pixabayView
                    }
                }
                .frame(maxHeight: .infinity)
            }
            .navigationTitle("Choose Music")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if model.selectedTrackURL != nil {
                        Button("Done") { dismiss() }
                            .fontWeight(.semibold)
                    }
                }
            }
        }
    }

    // MARK: - No Music

    private var noMusicView: some View {
        VStack(spacing: 16) {
            Image(systemName: "speaker.slash")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("No music will be added to the supercut.")
                .foregroundStyle(.secondary)
            Button("Confirm No Music") {
                model.clearSelection()
                dismiss()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    // MARK: - Apple Music

    private var appleMusicView: some View {
        VStack(spacing: 16) {
            if let name = model.selectedTrackName, model.selectedSource == .appleMusic {
                selectedTrackRow(name: name)
            }

            Button {
                showAppleMusicPicker = true
            } label: {
                Label("Choose from Apple Music", systemImage: "music.note")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .padding(.horizontal)

            Spacer()
        }
        .padding(.top)
        .sheet(isPresented: $showAppleMusicPicker) {
            AppleMusicPickerRepresentable(model: model)
        }
    }

    // MARK: - Files

    private var filesView: some View {
        VStack(spacing: 16) {
            if let name = model.selectedTrackName, model.selectedSource == .files {
                selectedTrackRow(name: name)
            }

            Button {
                showFilePicker = true
            } label: {
                Label("Choose Audio File", systemImage: "folder")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .padding(.horizontal)

            Spacer()
        }
        .padding(.top)
        .sheet(isPresented: $showFilePicker) {
            AudioDocumentPickerRepresentable(model: model)
        }
    }

    // MARK: - Pixabay

    private var pixabayView: some View {
        VStack(spacing: 0) {
            HStack {
                TextField("Search free music...", text: $searchQuery)
                    .textFieldStyle(.roundedBorder)
                Button("Search") {
                    Task { await model.fetchPixabayTracks(query: searchQuery) }
                }
                .buttonStyle(.bordered)
            }
            .padding()

            if model.isLoadingTracks {
                Spacer()
                ProgressView("Loading tracks...")
                Spacer()
            } else if model.pixabayTracks.isEmpty {
                Spacer()
                Text("Search for free music tracks")
                    .foregroundStyle(.secondary)
                Spacer()
            } else {
                List(model.pixabayTracks) { track in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(track.title)
                                .font(.body.weight(.medium))
                                .lineLimit(1)
                            Text(formatDuration(track.duration))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        // Preview button
                        Button {
                            if let url = URL(string: track.audioURL) {
                                model.previewTrack(url: url)
                            }
                        } label: {
                            Image(systemName: "play.circle")
                                .font(.title2)
                        }
                        .buttonStyle(.plain)

                        // Select button
                        Button("Select") {
                            Task { await model.downloadTrack(track) }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    .padding(.vertical, 4)
                }
                .listStyle(.plain)
            }
        }
        .onAppear {
            if model.pixabayTracks.isEmpty {
                Task { await model.fetchPixabayTracks(query: searchQuery) }
            }
        }
        .onDisappear {
            model.stopPreview()
        }
    }

    // MARK: - Helpers

    private func selectedTrackRow(name: String) -> some View {
        HStack {
            Image(systemName: "music.note")
                .foregroundStyle(.tint)
            Text(name)
                .font(.body.weight(.medium))
                .lineLimit(1)
            Spacer()
            Button("Change") {
                // User can re-pick within the current source
            }
            .font(.caption)
        }
        .padding()
        .background(Color.accentColor.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .padding(.horizontal)
    }

    private func formatDuration(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }
}

// MARK: - Apple Music Picker (UIViewControllerRepresentable)

struct AppleMusicPickerRepresentable: UIViewControllerRepresentable {
    @ObservedObject var model: MusicPickerModel

    func makeCoordinator() -> Coordinator { Coordinator(model: model) }

    func makeUIViewController(context: Context) -> MPMediaPickerController {
        let picker = MPMediaPickerController(mediaTypes: .music)
        picker.delegate = context.coordinator
        picker.allowsPickingMultipleItems = false
        picker.showsCloudItems = false
        picker.prompt = "Choose a song for your supercut"
        return picker
    }

    func updateUIViewController(_ uiViewController: MPMediaPickerController, context: Context) {}

    final class Coordinator: NSObject, MPMediaPickerControllerDelegate {
        let model: MusicPickerModel

        init(model: MusicPickerModel) { self.model = model }

        func mediaPicker(_ mediaPicker: MPMediaPickerController, didPickMediaItems mediaItemCollection: MPMediaItemCollection) {
            if let item = mediaItemCollection.items.first {
                model.handleAppleMusicSelection(item)
            }
            mediaPicker.dismiss(animated: true)
        }

        func mediaPickerDidCancel(_ mediaPicker: MPMediaPickerController) {
            mediaPicker.dismiss(animated: true)
        }
    }
}

// MARK: - Audio Document Picker (UIViewControllerRepresentable)

struct AudioDocumentPickerRepresentable: UIViewControllerRepresentable {
    @ObservedObject var model: MusicPickerModel

    func makeCoordinator() -> Coordinator { Coordinator(model: model) }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let audioTypes: [UTType] = [.audio, .mp3, .mpeg4Audio, .wav, .aiff]
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: audioTypes)
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let model: MusicPickerModel

        init(model: MusicPickerModel) { self.model = model }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            if let url = urls.first {
                // Start accessing security-scoped resource
                guard url.startAccessingSecurityScopedResource() else { return }
                model.handleFileSelection(url)
            }
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {}
    }
}
