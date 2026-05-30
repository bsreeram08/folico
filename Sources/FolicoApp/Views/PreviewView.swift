import SwiftUI

struct PreviewView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HeaderView(
                title: "Preview",
                subtitle: "Review suggested folder icons before Folico applies anything."
            )

            if appState.previewItems.isEmpty {
                EmptyStateView(
                    systemImage: "eye",
                    title: "No suggestions yet",
                    message: appState.config.watchedFolders.isEmpty
                        ? "Add a watched folder before scanning for matching folder icons."
                        : "Scan watched folders to preview matching folder icons."
                ) {
                    if appState.config.watchedFolders.isEmpty {
                        Button {
                            appState.selectedSection = .folders
                            appState.chooseWatchedFolder()
                        } label: {
                            Label("Add Folder", systemImage: "folder.badge.plus")
                        }
                        .buttonStyle(.borderedProminent)
                    } else {
                        Button {
                            appState.scanNow()
                        } label: {
                            Label(appState.isScanning ? "Scanning" : "Scan Now", systemImage: "arrow.clockwise")
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(appState.isScanning)
                    }
                }
            } else {
                Table(appState.previewItems) {
                    TableColumn("") { item in
                        Toggle("", isOn: Binding(
                            get: { item.isSelected },
                            set: { appState.setPreviewSelection(item, isSelected: $0) }
                        ))
                        .labelsHidden()
                    }
                    .width(36)

                    TableColumn("Folder") { item in
                        VStack(alignment: .leading, spacing: 3) {
                            Text(item.folder.name)
                                .font(.headline)
                            Text(item.folder.path)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        .padding(.vertical, 6)
                    }

                    TableColumn("Suggested Icon") { item in
                        IconLabel(iconId: item.match.iconId)
                    }
                    .width(min: 150, ideal: 180)

                    TableColumn("Rule") { item in
                        VStack(alignment: .leading, spacing: 3) {
                            Text(item.match.ruleLabel)
                            Text(item.match.source == .manualOverride ? "Override" : "\(Int(item.match.confidence * 100))% match")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .width(min: 120, ideal: 150)

                    TableColumn("Status") { item in
                        StatusPill(status: item.status)
                    }
                    .width(110)

                    TableColumn("Change") { item in
                        Menu {
                            ForEach(BuiltInIcons.all) { icon in
                                Button {
                                    appState.overrideIcon(for: item, iconId: icon.id)
                                } label: {
                                    Label(icon.label, systemImage: icon.symbolName)
                                }
                            }
                        } label: {
                            Image(systemName: "paintpalette")
                        }
                        .menuStyle(.borderlessButton)
                        .help("Change icon")
                    }
                    .width(72)
                }

                HStack {
                    Text("\(appState.matchedCount) selected")
                        .foregroundStyle(.secondary)

                    Spacer()

                    Button {
                        appState.ignoreSelectedPreviewItems()
                    } label: {
                        Label("Ignore Selected", systemImage: "eye.slash")
                    }
                    .disabled(appState.matchedCount == 0 || appState.isApplying)

                    Button {
                        appState.applySelectedIcons()
                    } label: {
                        Label(appState.isApplying ? "Applying" : "Apply Icons", systemImage: "checkmark.circle")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(appState.matchedCount == 0 || appState.isApplying)
                }
            }
        }
        .padding(28)
    }
}
