import SwiftUI
import Photos

// MARK: - CutSpeed

enum CutSpeed: String, CaseIterable, Identifiable {
    case fast
    case medium
    case slow
    case matchBeat

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .fast: return "Fast"
        case .medium: return "Medium"
        case .slow: return "Slow"
        case .matchBeat: return "Match Music Beat"
        }
    }

    /// Seconds each photo is displayed.
    var secondsPerPhoto: Double {
        switch self {
        case .fast: return 0.5
        case .medium: return 1.0
        case .slow: return 2.0
        case .matchBeat: return 0.0 // determined by audio analysis
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
    @State private var isGenerating = false

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
                if cutSpeed == .matchBeat {
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
    }

    // MARK: - Generate

    private func generateSupercut() {
        isGenerating = true
        // TODO: Create SupercutComposer, load photos via PhotoLoader,
        // analyze via PhotoAnalyzer, and navigate to SupercutProgressView.
        // This will be wired up once SupercutComposer and SupercutProgressView are created.
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
