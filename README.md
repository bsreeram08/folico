# Folico

Folico is a native macOS SwiftUI utility that applies custom folder icons based on folder names.

## Automatic Generation + AI

Folico works in two layers:

- **Automatic generation:** Folico scans folder names and generates icon suggestions with built-in local rules. No AI or internet is required.
- **AI-assisted workflow:** Any AI agent can call Folico's CLI, read the JSON plan, explain the suggestions, ask for approval, and apply only the approved icons.

That means Folico works by itself, and it also works well with AI agents.

```sh
folico agent plan --path ~/Documents
```

The command above auto-generates a JSON plan. An AI agent can then summarize it and run:

```sh
folico agent apply --path ~/Documents --items 1,3 --confirm
```

## AI Agent Flow

Folico is designed so you can ask an AI agent to organize Finder icons for you.

The agent should:

1. Scan a folder with Folico.
2. Show you the suggested icon changes.
3. Ask which changes you want.
4. Apply only the approved icons.
5. Offer restore commands if you want to undo.

Folico's agent commands are JSON-first, so any coding agent can call them through the shell.

```sh
folico agent scan --path ~/Documents
folico agent plan --path ~/Documents
folico agent apply --path ~/Documents --items 1,3 --confirm
folico agent restore-plan --folders ~/Documents/Invoices
folico agent restore --folders ~/Documents/Invoices --confirm
folico agent names --path ~/Documents
folico agent review-names --names ~/Documents/client_invoices="Client Invoices"
```

`scan`, `plan`, `restore-plan`, `names`, and `review-names` are read-only. `apply` and `restore` require `--confirm`.

## Paste This Into Your AI Agent

Use this prompt with Codex, Claude Code, Cursor, Windsurf, or any agent that can run shell commands:

```text
You are helping me use Folico, a macOS CLI/app that applies folder icons based on folder names.

Use Folico through the CLI. Prefer JSON agent commands.

Core commands:
- folico agent scan --path <folder>
- folico agent plan --path <folder>
- folico agent apply --path <folder> --items <numbers> --confirm
- folico agent restore-plan [--folders <paths>]
- folico agent restore [--folders <paths>] --confirm
- folico agent names --path <folder>
- folico agent review-names --names <path=name,path=name>

Rules:
- Never apply icons before showing me the JSON plan and asking for approval.
- Never run apply or restore without --confirm, and only use --confirm after I approve.
- Prefer selecting specific suggestions with --items or --folders.
- Treat naming suggestions as advice only. Do not rename folders automatically.
- Folico only scans folder names. Do not inspect file contents.
- If a command fails, explain the error and do not retry a mutating command without asking.

Flow:
1. Ask me which folder to scan if I have not provided one.
2. Run: folico agent plan --path <folder>
3. Summarize the suggested icon changes in plain English.
4. Ask which item numbers I want to apply.
5. Run: folico agent apply --path <folder> --items <approved_numbers> --confirm
6. Summarize success/failure results.
7. If I ask to undo, run restore-plan first, then restore only after approval.
```

## MVP Features

- Choose one or more watched folders.
- Scan direct child folders only.
- Preview matched icon suggestions before applying.
- Deselect or manually override suggested icons.
- Apply icons with AppKit.
- Restore default folder icons from history.
- Store all app data locally in Application Support.

## CLI

Folico can also run directly against a folder:

```sh
swift run Folico scan ~/Documents
swift run Folico scan ~/Documents --json
swift run Folico agent scan --path ~/Documents
swift run Folico agent plan --path ~/Documents
swift run Folico agent apply --path ~/Documents --items 1,3 --confirm
swift run Folico apply ~/Documents --folders ~/Documents/Invoices,~/Documents/Photos
swift run Folico restore --folders ~/Documents/Invoices
swift run Folico names ~/Documents
```

`scan` and `names` are read-only. `apply` changes Finder folder icons, and `restore` clears custom folder icons from Folico history.

For AI agents and scripts, prefer the JSON-first agent commands:

```sh
folico agent plan --path ~/Documents
folico agent scan --path ~/Documents
folico agent apply --path ~/Documents --items 1,3 --confirm
folico agent restore-plan --folders ~/Documents/Invoices
folico agent restore --folders ~/Documents/Invoices --confirm
folico agent names --path ~/Documents
folico agent review-names --names ~/Documents/client_invoices="Client Invoices"
```

See [docs/CLI.md](docs/CLI.md) for the stable agent CLI contract.

## Agent Skill File

If your agent supports reusable skills or instruction files, save this as `folico/SKILL.md`:

```markdown
---
name: folico
description: Use Folico to scan macOS folders, suggest icons, apply approved folder icons, restore icons, and review folder naming plans through the CLI.
---

Use Folico through shell commands. Prefer `folico agent ...` commands because they print JSON.

Commands:
- `folico agent scan --path <folder>`: read-only raw suggestions.
- `folico agent plan --path <folder>`: read-only apply plan.
- `folico agent apply --path <folder> --items <numbers> --confirm`: applies approved icons.
- `folico agent restore-plan [--folders <paths>]`: read-only restore plan.
- `folico agent restore [--folders <paths>] --confirm`: restores approved icons.
- `folico agent names --path <folder>`: read-only naming advice.
- `folico agent review-names --names <path=name,path=name>`: validate proposed names.

Safety:
- Show the user the plan before applying.
- Do not use `--confirm` until the user approves.
- Prefer `--items` or `--folders` instead of applying everything.
- Do not rename folders automatically.
- Do not inspect file contents.
- Stop and explain if any mutating command fails.
```

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
