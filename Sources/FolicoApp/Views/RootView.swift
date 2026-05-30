import SwiftUI

public struct RootView: View {
    @EnvironmentObject private var appState: AppState

    public init() {}

    public var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider()
            detailView
                .padding(.top, 24)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .background(Color(nsColor: .windowBackgroundColor))
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

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(AppSection.allCases) { section in
                SidebarButton(
                    section: section,
                    isSelected: appState.selectedSection == section
                ) {
                    appState.selectedSection = section
                }
            }

            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.top, 38)
        .padding(.bottom, 18)
        .frame(width: 220)
        .background(Color(nsColor: .underPageBackgroundColor).opacity(0.48))
    }

    @ViewBuilder
    private var detailView: some View {
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
}

private struct SidebarButton: View {
    let section: AppSection
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: section.systemImage)
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 18)

                Text(section.title)
                    .font(.headline)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(width: 192, alignment: .leading)
            .background(
                isSelected ? Color.secondary.opacity(0.28) : Color.clear,
                in: RoundedRectangle(cornerRadius: 8)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(section.title)
    }
}
