import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HeaderView(
                title: "History",
                subtitle: "Every folder changed by Folico appears here so it can be restored."
            )

            if appState.config.history.isEmpty {
                EmptyStateView(
                    systemImage: "clock.arrow.circlepath",
                    title: "No icon changes yet",
                    message: "Applied folder icons will appear here with restore actions."
                )
            } else {
                Table(appState.config.history) {
                    TableColumn("Folder") { record in
                        VStack(alignment: .leading, spacing: 3) {
                            Text(record.folderName)
                                .font(.headline)
                            Text(record.folderPath)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        .padding(.vertical, 6)
                    }

                    TableColumn("Icon") { record in
                        IconLabel(iconId: record.appliedIconId)
                    }
                    .width(min: 140, ideal: 170)

                    TableColumn("Applied") { record in
                        Text(record.appliedAt.formatted(date: .abbreviated, time: .shortened))
                            .foregroundStyle(.secondary)
                    }
                    .width(min: 150, ideal: 180)

                    TableColumn("Status") { record in
                        Text(record.status.rawValue.capitalized)
                            .foregroundStyle(record.status == .failed ? .red : .secondary)
                    }
                    .width(100)

                    TableColumn("Actions") { record in
                        HStack {
                            Button {
                                appState.openInFinder(record.folderPath)
                            } label: {
                                Image(systemName: "arrow.up.forward.app")
                            }
                            .help("Open in Finder")

                            Button {
                                appState.restore(record)
                            } label: {
                                Image(systemName: "arrow.uturn.backward.circle")
                            }
                            .disabled(appState.isRestoring || record.status == .restored)
                            .help("Restore default folder icon")
                        }
                        .buttonStyle(.borderless)
                    }
                    .width(96)
                }

                HStack {
                    Spacer()
                    Button(role: .destructive) {
                        appState.restoreAll()
                    } label: {
                        Label(appState.isRestoring ? "Restoring" : "Restore All", systemImage: "arrow.uturn.backward.circle")
                    }
                    .disabled(appState.isRestoring)
                }
            }
        }
        .padding(28)
    }
}
