import SwiftUI

public struct RootView: View {
    @EnvironmentObject private var appState: AppState

    public init() {}

    public var body: some View {
        NavigationSplitView {
            List(AppSection.allCases, selection: $appState.selectedSection) { section in
                Label(section.title, systemImage: section.systemImage)
                    .tag(section)
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 210)
        } detail: {
            Group {
                switch appState.selectedSection {
                case .folders:
                    WatchedFoldersView()
                case .preview:
                    PreviewView()
                case .history:
                    HistoryView()
                case .settings:
                    SettingsView()
                }
            }
            .toolbar {
                ToolbarItemGroup {
                    Button {
                        appState.chooseWatchedFolder()
                    } label: {
                        Label("Choose Folder", systemImage: "folder.badge.plus")
                    }
                    .help("Choose folders for Folico to scan")

                    Button {
                        appState.scanNow()
                    } label: {
                        Label("Scan Now", systemImage: "arrow.clockwise")
                    }
                    .disabled(appState.config.watchedFolders.isEmpty || appState.isScanning)
                    .help("Scan watched folders")
                }
            }
        }
    }
}
