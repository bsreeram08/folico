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
                        let status = displayStatus(for: record)
                        Text(status.rawValue.capitalized)
                            .foregroundStyle(statusColor(for: status))
                    }
                    .width(100)

                    TableColumn("Actions") { record in
                        let isMissing = displayStatus(for: record) == .missing
                        HStack {
                            Button {
                                appState.openInFinder(record.folderPath)
                            } label: {
                                Image(systemName: "arrow.up.forward.app")
                            }
                            .disabled(isMissing)
                            .help("Open in Finder")

                            Button {
                                appState.restore(record)
                            } label: {
                                Image(systemName: "arrow.uturn.backward.circle")
                            }
                            .disabled(appState.isRestoring || record.status == .restored || isMissing)
                            .help("Restore default folder icon")
                        }
                        .buttonStyle(.borderless)
                    }
                    .width(96)
                }

                HStack {
                    Button {
                        appState.clearMissingHistoryRecords()
                    } label: {
                        Label("Clear Missing", systemImage: "trash")
                    }
                    .disabled(!hasMissingRecords)

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

    private var hasMissingRecords: Bool {
        appState.config.history.contains { displayStatus(for: $0) == .missing }
    }

    private func displayStatus(for record: IconChangeRecord) -> IconChangeStatus {
        appState.folderExists(at: record.folderPath) ? record.status : .missing
    }

    private func statusColor(for status: IconChangeStatus) -> Color {
        switch status {
        case .failed:
            .red
        case .missing:
            .orange
        default:
            .secondary
        }
    }
}
