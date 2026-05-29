# Folico MCP Guide

Folico includes a stdio MCP server so AI agents can inspect folders, suggest icons, and validate folder naming plans.

Start the server:

```sh
swift run Folico mcp
```

For a built app, use the executable inside the app bundle:

```sh
/Applications/Folico.app/Contents/MacOS/Folico mcp
```

## Tools

### `folico_scan_folder`

Scans direct child folders and returns icon suggestions. This tool is read-only.

Input:

```json
{
  "path": "~/Documents",
  "includeHiddenFolders": false
}
```

### `folico_apply_icons`

Applies suggested or overridden icons. This modifies Finder folder icons and requires explicit confirmation.

Input:

```json
{
  "path": "~/Documents",
  "folderPaths": ["~/Documents/Invoices"],
  "iconOverrides": {
    "~/Documents/Invoices": "receipt"
  },
  "confirmApply": true
}
```

### `folico_restore_icons`

Restores default folder icons for Folico history records. This modifies Finder folder icons and requires explicit confirmation.

Input:

```json
{
  "folderPaths": ["~/Documents/Invoices"],
  "confirmRestore": true
}
```

### `folico_suggest_folder_names`

Suggests clearer folder names based on Folico's rules. This tool is read-only and does not rename folders.

Input:

```json
{
  "path": "~/Documents"
}
```

### `folico_review_folder_name_plan`

Lets an agent submit a proposed path-to-name plan for validation. This tool is read-only and does not rename folders.

Input:

```json
{
  "proposedNames": {
    "~/Documents/client_invoices": "Client Invoices",
    "~/Documents/.old": ".Old"
  }
}
```

## Agent Safety Rules

- Use `folico_scan_folder` before `folico_apply_icons`.
- Never call `folico_apply_icons` without showing the user the planned changes.
- Never call `folico_restore_icons` without user approval.
- Treat folder name suggestions as advice only; Folico does not rename folders.
- Prefer `folderPaths` for selected changes instead of applying all suggestions.
