import SwiftUI

public struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var newExclusionPattern = ""
    @State private var newRuleLabel = ""
    @State private var newRuleKeywords = ""
    @State private var newRulePathKeywords = ""
    @State private var newRuleIconID = "folder"
    @State private var newRuleColorName = "blue"

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HeaderView(
                    title: "Settings",
                    subtitle: "Keep Folico conservative while you tune matching behavior."
                )

                VStack(spacing: 0) {
                    SettingsToggleRow("Exclude hidden folders", isOn: Binding(
                        get: { appState.config.settings.excludeHiddenFolders },
                        set: { appState.setExcludeHiddenFolders($0) }
                    ))

                    SettingsToggleRow("Enable developer folder rules", isOn: Binding(
                        get: { appState.config.settings.enableDeveloperRules },
                        set: { appState.setEnableDeveloperRules($0) }
                    ))

                    SettingsToggleRow("Auto watch folders", isOn: Binding(
                        get: { appState.config.settings.autoWatchFolders },
                        set: { appState.setAutoWatchFolders($0) }
                    ))

                    SettingsToggleRow("Show menu bar icon", isOn: Binding(
                        get: { appState.config.settings.showMenuBarIcon },
                        set: { appState.setShowMenuBarIcon($0) }
                    ))

                    SettingsToggleRow("Notify for new files and folders", isOn: Binding(
                        get: { appState.config.settings.notifyOnNewItems },
                        set: { appState.setNotifyOnNewItems($0) }
                    ))

                    SettingsToggleRow("Apply icons to new folders", isOn: Binding(
                        get: { appState.config.settings.autoApplyNewFolderIcons },
                        set: { appState.setAutoApplyNewFolderIcons($0) }
                    ))

                    SettingsToggleRow("Generate fallback icons for unmatched folders", isOn: Binding(
                        get: { appState.config.settings.applyGeneratedIconsToUnmatchedFolders },
                        set: { appState.setApplyGeneratedIconsToUnmatchedFolders($0) }
                    ))

                    SettingsToggleRow("Learn from manual icon choices", isOn: Binding(
                        get: { appState.config.settings.learnFromManualChoices },
                        set: { appState.setLearnFromManualChoices($0) }
                    ), showsDivider: false)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(.secondary.opacity(0.10), in: RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 8) {
                    Text("Privacy")
                        .font(.headline)
                    Text("Folico runs locally. It does not collect analytics, upload folder names, send file paths, or read file contents.")
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Rules")
                        .font(.headline)

                    VStack(alignment: .leading, spacing: 10) {
                        TextField("Rule label", text: $newRuleLabel)
                            .textFieldStyle(.roundedBorder)

                        TextField("Keywords, comma separated", text: $newRuleKeywords)
                            .textFieldStyle(.roundedBorder)

                        TextField("Path keywords, comma separated", text: $newRulePathKeywords)
                            .textFieldStyle(.roundedBorder)

                        HStack(spacing: 12) {
                            Picker("Icon", selection: $newRuleIconID) {
                                ForEach(BuiltInIcons.all) { icon in
                                    Label(icon.label, systemImage: icon.symbolName)
                                        .tag(icon.id)
                                }
                            }
                            .pickerStyle(.menu)

                            Picker("Color", selection: $newRuleColorName) {
                                ForEach(FolderIconStyle.availableColorNames, id: \.self) { color in
                                    Text(color.capitalized).tag(color)
                                }
                            }
                            .pickerStyle(.menu)

                            Spacer()

                            Button {
                                addUserRule()
                            } label: {
                                Label("Add Rule", systemImage: "plus")
                            }
                            .disabled(trimmedNewRuleLabel.isEmpty || parsedNewRuleKeywords.isEmpty)
                        }
                    }
                    .padding(16)
                    .background(.secondary.opacity(0.10), in: RoundedRectangle(cornerRadius: 8))

                    VStack(spacing: 0) {
                        if appState.userRules.isEmpty {
                            Text("No user rules yet.")
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 10)
                        } else {
                            ForEach(appState.userRules) { rule in
                                UserRuleRow(rule: rule) {
                                    appState.removeUserRule(rule)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 4)
                    .background(.secondary.opacity(0.10), in: RoundedRectangle(cornerRadius: 8))
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Exclusions")
                        .font(.headline)

                    HStack(spacing: 8) {
                        TextField("Folder name or path component", text: $newExclusionPattern)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit(addCustomExclusion)

                        Button {
                            addCustomExclusion()
                        } label: {
                            Label("Add", systemImage: "plus")
                        }
                        .disabled(trimmedNewExclusionPattern.isEmpty)
                    }

                    VStack(spacing: 0) {
                        ForEach(sortedExclusions) { exclusion in
                            ExclusionRow(
                                exclusion: exclusion,
                                isDefault: FolderExclusion.isDefaultPattern(exclusion.pattern),
                                isEnabled: Binding(
                                    get: {
                                        appState.config.exclusions.first(where: { $0.id == exclusion.id })?.isEnabled ?? false
                                    },
                                    set: {
                                        appState.setExclusion(exclusion, isEnabled: $0)
                                    }
                                )
                            ) {
                                appState.removeExclusion(exclusion)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 4)
                    .background(.secondary.opacity(0.10), in: RoundedRectangle(cornerRadius: 8))
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
            }
            .padding(28)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }

    private var trimmedNewExclusionPattern: String {
        newExclusionPattern.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedNewRuleLabel: String {
        newRuleLabel.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var parsedNewRuleKeywords: [String] {
        parseCSV(newRuleKeywords)
    }

    private var parsedNewRulePathKeywords: [String] {
        parseCSV(newRulePathKeywords)
    }

    private var sortedExclusions: [FolderExclusion] {
        appState.config.exclusions.sorted {
            $0.pattern.localizedCaseInsensitiveCompare($1.pattern) == .orderedAscending
        }
    }

    private func addCustomExclusion() {
        let pattern = trimmedNewExclusionPattern
        guard !pattern.isEmpty else { return }
        appState.addExclusion(pattern: pattern)
        newExclusionPattern = ""
    }

    private func addUserRule() {
        appState.addUserRule(
            label: trimmedNewRuleLabel,
            keywords: parsedNewRuleKeywords,
            pathKeywords: parsedNewRulePathKeywords,
            iconId: newRuleIconID,
            folderColorName: newRuleColorName,
            symbolColorName: newRuleColorName
        )
        if appState.statusMessage?.hasPrefix("Rules need") != true {
            newRuleLabel = ""
            newRuleKeywords = ""
            newRulePathKeywords = ""
            newRuleIconID = "folder"
            newRuleColorName = "blue"
        }
    }

    private func parseCSV(_ value: String) -> [String] {
        value
            .split(separator: ",")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}

private struct SettingsToggleRow: View {
    let title: String
    let isOn: Binding<Bool>
    let showsDivider: Bool

    init(_ title: String, isOn: Binding<Bool>, showsDivider: Bool = true) {
        self.title = title
        self.isOn = isOn
        self.showsDivider = showsDivider
    }

    var body: some View {
        VStack(spacing: 0) {
            Button {
                isOn.wrappedValue.toggle()
            } label: {
                HStack(spacing: 12) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Spacer(minLength: 16)
                    Toggle(title, isOn: isOn)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .allowsHitTesting(false)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.vertical, 11)

            if showsDivider {
                Divider()
            }
        }
    }
}

private struct UserRuleRow: View {
    let rule: FolderIconRule
    let onRemove: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            IconLabel(iconId: rule.iconId)
                .frame(width: 130, alignment: .leading)

            VStack(alignment: .leading, spacing: 4) {
                Text(rule.label)
                    .font(.headline)

                Text(rule.keywords.joined(separator: ", "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                if let pathKeywords = rule.pathKeywords, !pathKeywords.isEmpty {
                    Text("Paths: \(pathKeywords.joined(separator: ", "))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 12)

            Button(role: .destructive) {
                onRemove()
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .help("Remove user rule")
        }
        .padding(.vertical, 10)

        Divider()
    }
}

private struct ExclusionRow: View {
    let exclusion: FolderExclusion
    let isDefault: Bool
    let isEnabled: Binding<Bool>
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Toggle(isOn: isEnabled) {
                HStack(spacing: 8) {
                    Text(exclusion.pattern)
                        .font(.headline)
                    if isDefault {
                        Text("Built-in")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(.secondary.opacity(0.14), in: Capsule())
                    }
                }
            }
            .toggleStyle(.switch)

            Spacer(minLength: 12)

            Button(role: isDefault ? nil : .destructive) {
                onRemove()
            } label: {
                Image(systemName: isDefault ? "minus.circle" : "trash")
            }
            .buttonStyle(.borderless)
            .help(isDefault ? "Disable built-in exclusion" : "Remove custom exclusion")
        }
        .padding(.vertical, 9)

        Divider()
    }
}
