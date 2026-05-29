# Folico

Folico is a native macOS SwiftUI utility that applies custom folder icons based on folder names.

## MVP

- Choose one or more watched folders.
- Scan direct child folders only.
- Preview matched icon suggestions before applying.
- Deselect or manually override suggested icons.
- Apply icons with AppKit.
- Restore default folder icons from history.
- Store all app data locally in Application Support.

## Development

This repository is a Swift Package with a small executable wrapper and a testable app module.

```sh
swift run Folico
swift test
```

Open the package in Xcode on macOS 14+ for app signing, native Finder icon verification, and release builds.

## Build DMG

On macOS 14+:

```sh
bash scripts/package-dmg.sh
open dist/Folico.dmg
```

The generated app bundle uses bundle identifier `folico.sreerams.in`.

GitHub Actions also builds `Folico.dmg` on every push to `master`. Run the **Build DMG** workflow manually with `publish_release=true` to upload the latest DMG to the `latest` GitHub release.

## CLI

Folico can also run directly against a folder:

```sh
swift run Folico scan ~/Documents
swift run Folico scan ~/Documents --json
swift run Folico apply ~/Documents --folders ~/Documents/Invoices,~/Documents/Photos
swift run Folico restore --folders ~/Documents/Invoices
swift run Folico names ~/Documents
```

`scan` and `names` are read-only. `apply` changes Finder folder icons, and `restore` clears custom folder icons from Folico history.

## MCP

Start the stdio MCP server:

```sh
swift run Folico mcp
```

Available tools:

- `folico_scan_folder`: scan a root folder and return icon suggestions.
- `folico_apply_icons`: apply selected suggestions; requires `confirmApply: true`.
- `folico_restore_icons`: restore icons from history; requires `confirmRestore: true`.
- `folico_suggest_folder_names`: suggest clearer folder names without renaming anything.
- `folico_review_folder_name_plan`: let an agent submit proposed folder names for validation; Folico does not rename folders.

See [docs/MCP.md](docs/MCP.md) for tool inputs, agent safety rules, and example payloads.

## Privacy

Folico only scans folder names inside folders you select. It does not upload your files or read file contents.
