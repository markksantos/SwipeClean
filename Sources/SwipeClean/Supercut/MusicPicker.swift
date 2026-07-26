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

@MainActor
final class MusicPickerModel: ObservableObject {
    @Published var selectedSource: MusicSource = .none
    @Published var selectedTrackURL: URL?
    @Published var selectedTrackName: String?
    /// Set when a pick could not be used, so the sheet can explain why instead of
    /// appearing to ignore the tap.
    @Published var pickerMessage: String?

    /// Security-scoped URL currently being held open, so access is balanced.
    private var scopedURL: URL?

    deinit {
        scopedURL?.stopAccessingSecurityScopedResource()
    }

    // MARK: - Apple Music

    /// The Apple Music picker is presented via UIViewControllerRepresentable;
    /// the delegate callback lands here.
    func handleAppleMusicSelection(_ mediaItem: MPMediaItem) {
        // Apple Music tracks that are streamed or DRM-protected have no
        // `assetURL`, and AVFoundation cannot read them. Assigning nil left the
        // sheet with no selection and no Done button, so picking such a song
        // looked like the app had simply ignored it.
        guard let url = mediaItem.assetURL else {
            pickerMessage = """
                That song is protected by Apple Music and can't be added to a video. \
                Pick a song you own, or choose an audio file from Files.
                """
            return
        }

        releaseScopedURL()
        pickerMessage = nil
        selectedTrackURL = url
        selectedTrackName = mediaItem.title ?? "Apple Music Track"
        selectedSource = .appleMusic
    }

    // MARK: - Files

    /// Takes ownership of a security-scoped URL from the document picker.
    func handleFileSelection(_ url: URL) {
        releaseScopedURL()

        // A file picked outside the app's container stays readable only while
        // access is held open, and the previous code opened it without ever
        // closing it — leaking one scope per pick.
        guard url.startAccessingSecurityScopedResource() else {
            pickerMessage = "That file couldn't be opened. Try copying it into Files first."
            return
        }

        scopedURL = url
        pickerMessage = nil
        selectedTrackURL = url
        selectedTrackName = url.lastPathComponent
        selectedSource = .files
    }

    // MARK: - Clear

    func clearSelection() {
        releaseScopedURL()
        pickerMessage = nil
        selectedSource = .none
        selectedTrackURL = nil
        selectedTrackName = nil
    }

    private func releaseScopedURL() {
        scopedURL?.stopAccessingSecurityScopedResource()
        scopedURL = nil
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

                if let message = model.pickerMessage {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.orange)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                        .padding(.top, 12)
                }

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
            // Was a "Change" button with an empty action — interactive-looking and
            // inert. Re-picking is what the button below the row already does, so
            // this slot clears the selection instead.
            Button("Remove", role: .destructive) {
                model.clearSelection()
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
                MainActor.assumeIsolated { model.handleAppleMusicSelection(item) }
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
            // The model opens and closes the security scope itself so the two
            // halves stay in one place.
            if let url = urls.first {
                MainActor.assumeIsolated { model.handleFileSelection(url) }
            }
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {}
    }
}
