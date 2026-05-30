# Folico MCP Guide

Folico includes a stdio MCP server so AI agents can inspect folders, suggest icons, and validate folder naming plans.

For most agents, prefer the simpler CLI contract in [CLI.md](CLI.md). MCP is useful when the host app specifically supports MCP tools.

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

### `folico_get_settings`

Returns Folico's local settings. Folico does not collect analytics or upload folder data.

Input:

```json
{}
```

### `folico_update_settings`

Updates local toggles.

Input:

```json
{
  "autoWatchFolders": true,
  "notifyOnNewItems": true,
  "autoApplyNewFolderIcons": true,
  "applyGeneratedIconsToUnmatchedFolders": false,
  "showMenuBarIcon": true,
  "learnFromManualChoices": true
}
```

### `folico_list_rules`

Returns explicit rules, generated fallback rules, available icons, and color names.

Input:

```json
{}
```

### `folico_upsert_rule`

Creates or updates an explicit local icon rule.

Input:

```json
{
  "label": "Games",
  "keywords": ["game", "games", "gaming"],
  "pathKeywords": ["steam"],
  "iconId": "game",
  "priority": 120,
  "folderColorName": "purple",
  "symbolColorName": "purple"
}
```

### `folico_remove_rule`

Removes a user-created icon rule.

Input:

```json
{
  "id": "user-games"
}
```

### `folico_list_exclusions`

Returns local exclusion patterns.

Input:

```json
{}
```

### `folico_upsert_exclusion`

Creates or re-enables a local exclusion pattern.

Input:

```json
{
  "pattern": "node_modules",
  "isEnabled": true
}
```

### `folico_set_exclusion_enabled`

Enables or disables an exclusion pattern.

Input:

```json
{
  "pattern": "node_modules",
  "isEnabled": false
}
```

### `folico_remove_exclusion`

Removes a custom exclusion pattern. Built-in defaults are disabled instead of deleted.

Input:

```json
{
  "pattern": ".dart_tool"
}
```

### `folico_list_watched_folders`

Returns locally watched folders.

Input:

```json
{}
```

### `folico_add_watched_folder`

Adds a local watched folder.

Input:

```json
{
  "path": "~/Documents"
}
```

### `folico_upsert_generated_rule`

Creates or updates a config-driven generated fallback rule.

Input:

```json
{
  "id": "generated-games",
  "label": "Generated Games",
  "keywords": ["game", "games", "gaming"],
  "pathKeywords": ["steam"],
  "iconId": "game",
  "priority": 75,
  "folderColorName": "purple",
  "symbolColorName": "purple"
}
```

## Agent Safety Rules

- Use `folico_scan_folder` before `folico_apply_icons`.
- Never call `folico_apply_icons` without showing the user the planned changes.
- Never call `folico_restore_icons` without user approval.
- Treat folder name suggestions as advice only; Folico does not rename folders.
- Prefer `folderPaths` for selected changes instead of applying all suggestions.
- Do not inspect file contents. Folico matching uses folder names and path components.
- Keep generated fallback, auto-watch, notifications, and auto-apply behavior under user-controlled toggles.
