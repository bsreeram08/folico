# Folico CLI Guide

Folico's CLI is the recommended integration surface for AI agents and scripts.

It uses plain commands, prints JSON for agent commands, and requires explicit confirmation before changing Finder icons.

## Quick Start

Scan a folder in human-readable mode:

```sh
folico ~/Documents
```

Ask Folico for an agent-readable icon plan:

```sh
folico agent plan --path ~/Documents
```

Or get raw scan suggestions:

```sh
folico agent scan --path ~/Documents
```

Apply selected suggestions after the user approves them:

```sh
folico agent apply --path ~/Documents --items 1,3 --confirm
```

Configure live behavior, rules, and exclusions:

```sh
folico agent configure-settings --auto-watch true --notify true --auto-apply-new-folder-icons true --learn true
folico agent upsert-rule --label Games --icon game --keywords game,games,gaming --folder-color purple
folico agent add-exclusion --pattern node_modules
```

Restore selected icons:

```sh
folico agent restore-plan --folders ~/Documents/Invoices
folico agent restore --folders ~/Documents/Invoices --confirm
```

## Agent Commands

All `folico agent ...` commands print JSON.

### `folico agent plan`

Creates a non-mutating apply plan.

```sh
folico agent plan --path ~/Documents
folico agent plan --path ~/Documents --items 1,3
folico agent plan --path ~/Documents --folders ~/Documents/Invoices,~/Documents/Photos
folico agent plan --path ~/Documents --icons ~/Documents/Invoices=receipt
```

### `folico agent scan`

Returns raw scan suggestions without creating an apply plan.

```sh
folico agent scan --path ~/Documents
```

### `folico agent apply`

Applies icons. Requires `--confirm`.

```sh
folico agent apply --path ~/Documents --items 1,3 --confirm
```

Agents should show the user the output of `folico agent plan` before running this.

### `folico agent restore-plan`

Creates a non-mutating restore plan.

```sh
folico agent restore-plan
folico agent restore-plan --folders ~/Documents/Invoices
```

### `folico agent restore`

Restores icons. Requires `--confirm`.

```sh
folico agent restore --folders ~/Documents/Invoices --confirm
```

### `folico agent names`

Suggests clearer folder names. This does not rename anything.

```sh
folico agent names --path ~/Documents
```

### `folico agent review-names`

Validates an agent-proposed naming plan. This does not rename anything.

```sh
folico agent review-names --names ~/Documents/client_invoices="Client Invoices"
```

### `folico agent settings`

Returns local settings. Folico does not collect analytics or upload folder data.

```sh
folico agent settings
```

### `folico agent configure-settings`

Updates local toggles.

```sh
folico agent configure-settings --auto-watch true
folico agent configure-settings --notify true
folico agent configure-settings --auto-apply-new-folder-icons true
folico agent configure-settings --generated-fallback true
folico agent configure-settings --learn true
```

### `folico agent rules`

Returns explicit rules, generated fallback rules, available icons, and color names.

```sh
folico agent rules
```

### `folico agent upsert-rule`

Creates or updates a user rule. User rules are stored locally in Folico config.

```sh
folico agent upsert-rule --label Games --icon game --keywords game,games,gaming --folder-color purple
folico agent upsert-rule --label Receipts --icon receipt --keywords receipt,receipts,invoice --path-keywords finance,tax --folder-color green
```

### `folico agent remove-rule`

Removes a user-created rule.

```sh
folico agent remove-rule --id user-games
```

### `folico agent exclusions`

Returns scan/watch exclusions.

```sh
folico agent exclusions
```

### `folico agent add-exclusion`

Adds or re-enables an exclusion pattern.

```sh
folico agent add-exclusion --pattern node_modules
folico agent add-exclusion --pattern .dart_tool
```

### `folico agent set-exclusion`

Enables or disables an exclusion pattern.

```sh
folico agent set-exclusion --pattern node_modules --enabled false
```

### `folico agent remove-exclusion`

Removes a custom exclusion. Built-in exclusions are disabled instead of deleted.

```sh
folico agent remove-exclusion --pattern .dart_tool
```

### `folico agent watched-folders`

Returns locally watched folders.

```sh
folico agent watched-folders
```

### `folico agent watch-folder`

Adds a watched folder.

```sh
folico agent watch-folder --path ~/Documents
```

### `folico agent upsert-generated-rule`

Creates or updates a generated fallback rule.

```sh
folico agent upsert-generated-rule --id generated-games --label "Generated Games" --icon game --keywords game,games,gaming --folder-color purple
```

## Safety Rules for Agents

- Use `folico agent plan` before `folico agent apply`.
- Use `folico agent restore-plan` before `folico agent restore`.
- Do not pass `--confirm` until the user has approved the JSON plan.
- Prefer `--items` or `--folders` for selected changes.
- Never rename folders automatically; `names` and `review-names` are advisory only.
- Do not inspect file contents. Folico's matching uses folder names and path components.
- Keep generated fallback and auto-apply toggles under user control.
- Treat non-zero exit codes as failures.

## Exit Codes

- `0`: success
- `1`: command or validation error
- `2`: command ran but one or more folder operations failed
- `64`: invalid command
