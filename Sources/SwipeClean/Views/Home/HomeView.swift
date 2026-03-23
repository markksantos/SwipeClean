import SwiftUI
import Photos

struct HomeView: View {
    @EnvironmentObject private var albumProvider: AlbumProvider
    @EnvironmentObject private var sessionTracker: SessionTracker
    @EnvironmentObject private var deleteManager: DeleteManager

    @State private var showSettings = false
    @State private var navigationPath = NavigationPath()
    @State private var cardsVisible = false
    @State private var animateGradient = false

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
        NavigationStack(path: $navigationPath) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Animated gradient header
                    ZStack {
                        LinearGradient(
                            colors: [
                                Color.blue.opacity(0.15),
                                Color.purple.opacity(0.12),
                                Color.cyan.opacity(0.10)
                            ],
                            startPoint: animateGradient ? .topLeading : .bottomLeading,
                            endPoint: animateGradient ? .bottomTrailing : .topTrailing
                        )
                        .frame(height: 140)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .onAppear {
                            withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true)) {
                                animateGradient.toggle()
                            }
                        }

                        VStack(spacing: 6) {
                            Text("SwipeClean")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                            Text("Swipe left to clean, right to keep")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }

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
                            ForEach(Array(grouped.smart.enumerated()), id: \.element.source) { index, info in
                                AlbumCard(
                                    source: info.source,
                                    photoCount: info.count
                                ) {
                                    navigationPath.append(info)
                                }
                                .opacity(cardsVisible ? 1 : 0)
                                .offset(y: cardsVisible ? 0 : 20)
                                .animation(
                                    .easeOut(duration: 0.4).delay(Double(index) * 0.06),
                                    value: cardsVisible
                                )
                            }
                        }
                    }

                    // User Albums
                    if !grouped.user.isEmpty {
                        sectionHeader("Your Albums")
                        LazyVStack(spacing: 10) {
                            ForEach(Array(grouped.user.enumerated()), id: \.element.source) { index, info in
                                AlbumCard(
                                    source: info.source,
                                    photoCount: info.count
                                ) {
                                    navigationPath.append(info)
                                }
                                .opacity(cardsVisible ? 1 : 0)
                                .offset(y: cardsVisible ? 0 : 20)
                                .animation(
                                    .easeOut(duration: 0.4).delay(Double(grouped.smart.count + index) * 0.06),
                                    value: cardsVisible
                                )
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
            .navigationDestination(for: AlbumSourceInfo.self) { info in
                SwipeView(albumName: info.source.displayName, albumSource: info.source)
                    .environmentObject(deleteManager)
                    .environmentObject(sessionTracker)
            }
        }
        .onAppear {
            // Re-read lifetime stats after returning from a swipe session
            sessionTracker.objectWillChange.send()

            // Fetch sources on a background thread to avoid blocking UI
            Task.detached {
                let sources = albumProvider.fetchAvailableSources()
                await MainActor.run {
                    _ = sources // sources already set inside fetchAvailableSources
                    cardsVisible = true
                }
            }
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
    }
}


#Preview {
    HomeView()
}
