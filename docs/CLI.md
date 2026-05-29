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

## Safety Rules for Agents

- Use `folico agent plan` before `folico agent apply`.
- Use `folico agent restore-plan` before `folico agent restore`.
- Do not pass `--confirm` until the user has approved the JSON plan.
- Prefer `--items` or `--folders` for selected changes.
- Never rename folders automatically; `names` and `review-names` are advisory only.
- Treat non-zero exit codes as failures.

## Exit Codes

- `0`: success
- `1`: command or validation error
- `2`: command ran but one or more folder operations failed
- `64`: invalid command
