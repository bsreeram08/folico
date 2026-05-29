# Contributing to Folico

Thanks for helping make Finder a little easier to scan.

## Local Setup

Folico is a Swift Package targeting macOS 14+.

```sh
git clone git@github.com:bsreeram08/folico.git
cd folico
swift test
swift run Folico
```

Build a local DMG on macOS:

```sh
bash scripts/package-dmg.sh
open dist/Folico.dmg
```

## Development Guidelines

- Keep Folico safe by default: no automatic icon changes without preview or explicit confirmation.
- Do not add file content scanning. Folico should work from folder names only.
- Keep restore behavior visible and reliable.
- Prefer small focused PRs.
- Add tests for rule matching, scanning, persistence, CLI parsing, and MCP behavior when touching those areas.

## Useful Commands

```sh
swift test
swift run Folico ~/Documents
swift run Folico agent plan --path ~/Documents
swift run Folico scan ~/Documents --json
swift run Folico mcp
```

## Pull Requests

Before opening a PR:

- Run `swift test` on macOS.
- Confirm the app launches with `swift run Folico`.
- For icon apply/restore changes, manually test against a throwaway folder.
- Note whether the change affects CLI, MCP, or the macOS UI.

## Release Builds

The `Build DMG` GitHub Actions workflow builds `dist/Folico.dmg` on macOS. Manual runs can publish the DMG to the `latest` release.
