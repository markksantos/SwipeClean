import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var albumProvider: AlbumProvider
    @EnvironmentObject private var sessionTracker: SessionTracker
    @EnvironmentObject private var deleteManager: DeleteManager

    @State private var showSettings = false
    @State private var selectedSource: AlbumSourceInfo?

    private var grouped: (smart: [AlbumSourceInfo], user: [AlbumSourceInfo]) {
        var smart: [AlbumSourceInfo] = []
        var user: [AlbumSourceInfo] = []
        for info in albumProvider.sources {
            switch info.source {
            case .album:
                user.append(info)
            default:
                smart.append(info)
            }
        }
        return (smart, user)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Hero stats card
                    StatsCard(
                        photosDeleted: sessionTracker.lifetimeStats.totalDeleted,
                        storageFreed: sessionTracker.lifetimeStats.totalStorageFreed
                    )

                    // Pending deletions shortcut
                    if !deleteManager.trashQueue.isEmpty {
                        NavigationLink {
                            ReviewGridView()
                                .environmentObject(deleteManager)
                        } label: {
                            HStack {
                                Image(systemName: "trash")
                                    .foregroundStyle(.red)
                                Text("\(deleteManager.trashQueue.count) photos queued for deletion")
                                    .font(.subheadline.weight(.medium))
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(14)
                            .background(Color.red.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .buttonStyle(PressDownButtonStyle())
                    }

                    // Section: Choose what to clean
                    Text("Choose what to clean")
                        .font(.title3.weight(.semibold))
                        .padding(.top, 4)

                    // Smart Albums
                    if !grouped.smart.isEmpty {
                        sectionHeader("Smart Albums")
                        LazyVStack(spacing: 10) {
                            ForEach(grouped.smart, id: \.source) { info in
                                AlbumCard(
                                    source: info.source,
                                    photoCount: info.count
                                ) {
                                    selectedSource = info
                                }
                            }
                        }
                    }

                    // User Albums
                    if !grouped.user.isEmpty {
                        sectionHeader("Your Albums")
                        LazyVStack(spacing: 10) {
                            ForEach(grouped.user, id: \.source) { info in
                                AlbumCard(
                                    source: info.source,
                                    photoCount: info.count
                                ) {
                                    selectedSource = info
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 32)
            }
            .refreshable {
                _ = albumProvider.fetchAvailableSources()
            }
            .navigationTitle("SwipeClean")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.body.weight(.medium))
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
                    .environmentObject(sessionTracker)
                    .environmentObject(deleteManager)
            }
            .navigationDestination(item: $selectedSource) { info in
                // SwipeView provided by the Swipe teammate.
                // It expects PhotoLoader, DeleteManager, SessionTracker as EnvironmentObjects.
                // The parent (SwipeCleanApp) should inject PhotoLoader when navigating.
                SwipeViewPlaceholder(source: info.source)
                    .environmentObject(deleteManager)
                    .environmentObject(sessionTracker)
            }
        }
        .onAppear {
            _ = albumProvider.fetchAvailableSources()
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
    }
}

// MARK: - AlbumSourceInfo + Identifiable & Hashable for NavigationDestination

extension AlbumSourceInfo: Identifiable, Hashable {
    var id: AlbumSource { source }

    static func == (lhs: AlbumSourceInfo, rhs: AlbumSourceInfo) -> Bool {
        lhs.source == rhs.source && lhs.count == rhs.count
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(source)
    }
}

// MARK: - Placeholder for SwipeView (will be replaced when integration is ready)

struct SwipeViewPlaceholder: View {
    let source: AlbumSource

    var body: some View {
        Text("SwipeView for \(source.displayName)")
            .navigationTitle(source.displayName)
    }
}

#Preview {
    HomeView()
}
