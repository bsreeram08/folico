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

## Privacy

Folico only scans folder names inside folders you select. It does not upload your files or read file contents.
