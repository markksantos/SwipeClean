import SwiftUI
import MediaPlayer
import AVFoundation
import UniformTypeIdentifiers

// MARK: - MusicSource

enum MusicSource: String, CaseIterable, Identifiable {
    case none
    case appleMusic
    case files

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .none: return "No Music"
        case .appleMusic: return "Apple Music"
        case .files: return "From Files"
        }
    }

    var iconName: String {
        switch self {
        case .none: return "speaker.slash"
        case .appleMusic: return "music.note"
        case .files: return "folder"
        }
    }
}

// MARK: - MusicPickerModel

final class MusicPickerModel: ObservableObject {
    @Published var selectedSource: MusicSource = .none
    @Published var selectedTrackURL: URL?
    @Published var selectedTrackName: String?

    private var audioPlayer: AVAudioPlayer?

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
