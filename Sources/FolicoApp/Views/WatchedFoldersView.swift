import SwiftUI

struct WatchedFoldersView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Group {
            if appState.config.watchedFolders.isEmpty {
                WelcomeView()
            } else {
                VStack(alignment: .leading, spacing: 18) {
                    HeaderView(
                        title: "Watched Folders",
                        subtitle: "Folico scans direct child folders and prepares a preview before anything changes."
                    )

                    if let status = appState.statusMessage {
                        StatusBanner(message: status, systemImage: "info.circle")
                    }

                    Table(appState.config.watchedFolders) {
                        TableColumn("Folder") { folder in
                            VStack(alignment: .leading, spacing: 3) {
                                Text(folder.name)
                                    .font(.headline)
                                Text(folder.path)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                            .padding(.vertical, 6)
                        }

                        TableColumn("Last Scan") { folder in
                            Text(folder.lastScanAt?.formatted(date: .abbreviated, time: .shortened) ?? "Not scanned")
                                .foregroundStyle(.secondary)
                        }
                        .width(min: 150, ideal: 180)

                        TableColumn("Matches") { folder in
                            Text("\(folder.lastMatchedCount)")
                                .foregroundStyle(.secondary)
                        }
                        .width(80)

                        TableColumn("Actions") { folder in
                            HStack {
                                Button {
                                    appState.openInFinder(folder.path)
                                } label: {
                                    Image(systemName: "arrow.up.forward.app")
                                }
                                .help("Open in Finder")

                                Button(role: .destructive) {
                                    appState.removeWatchedFolder(folder)
                                } label: {
                                    Image(systemName: "trash")
                                }
                                .help("Remove watched folder")
                            }
                            .buttonStyle(.borderless)
                        }
                        .width(96)
                    }

                    HStack {
                        Button {
                            appState.chooseWatchedFolder()
                        } label: {
                            Label("Add Folder", systemImage: "plus")
                        }

                        Spacer()

                        Button {
                            appState.scanNow()
                        } label: {
                            Label(appState.isScanning ? "Scanning" : "Scan Now", systemImage: "arrow.clockwise")
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(appState.isScanning)
                    }
                }
                .padding(28)
            }
        }
    }
}
