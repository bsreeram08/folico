import SwiftUI

struct WelcomeView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Spacer()

            Image(systemName: "folder.fill.badge.gearshape")
                .font(.system(size: 68, weight: .semibold))
                .foregroundStyle(.blue)

            VStack(alignment: .leading, spacing: 8) {
                Text("Folico")
                    .font(.system(size: 52, weight: .bold))
                Text("Make Finder make sense.")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }

            Text("Choose a folder, preview suggested icons for its child folders, then apply only the changes you approve.")
                .font(.body)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 520, alignment: .leading)

            Text("Folico only scans folder names inside folders you select. It does not upload your files or read file contents.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 560, alignment: .leading)

            Button {
                appState.chooseWatchedFolder()
            } label: {
                Label("Choose Folder", systemImage: "folder.badge.plus")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Spacer()
        }
        .padding(48)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}
