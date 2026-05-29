import SwiftUI

public struct SettingsView: View {
    @EnvironmentObject private var appState: AppState

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HeaderView(
                title: "Settings",
                subtitle: "Keep Folico conservative while you tune matching behavior."
            )

            Form {
                Toggle("Exclude hidden folders", isOn: Binding(
                    get: { appState.config.settings.excludeHiddenFolders },
                    set: { value in
                        appState.config.settings.excludeHiddenFolders = value
                        try? appState.storage.save(appState.config)
                    }
                ))

                Toggle("Enable developer folder rules", isOn: Binding(
                    get: { appState.config.settings.enableDeveloperRules },
                    set: { value in
                        appState.config.settings.enableDeveloperRules = value
                        try? appState.storage.save(appState.config)
                    }
                ))

                Toggle("Auto watch folders", isOn: .constant(false))
                    .disabled(true)

                Toggle("Show menu bar icon", isOn: .constant(false))
                    .disabled(true)
            }
            .formStyle(.grouped)

            VStack(alignment: .leading, spacing: 8) {
                Text("Default Exclusions")
                    .font(.headline)
                FlowLayout(items: appState.config.exclusions.filter(\.isEnabled).map(\.pattern))
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Build from Source")
                    .font(.headline)
                Text("Repository: \(BuildInfo.repository)")
                    .foregroundStyle(.secondary)
                Text("Bundle ID: \(BuildInfo.bundleIdentifier)")
                    .foregroundStyle(.secondary)
                Text("Commands: \(BuildInfo.sourceCommands)")
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            Divider()

            HStack {
                Button {
                    appState.resetSettings()
                } label: {
                    Label("Reset Settings", systemImage: "arrow.counterclockwise")
                }

                Spacer()

                Button(role: .destructive) {
                    appState.restoreAll()
                } label: {
                    Label("Restore All Folder Icons", systemImage: "arrow.uturn.backward.circle")
                }
                .disabled(appState.config.history.isEmpty || appState.isRestoring)
            }

            Spacer()
        }
        .padding(28)
    }
}
