# Security Policy

Folico modifies Finder folder icons, so safety matters more than cleverness.

## Supported Versions

Security fixes target the `master` branch until Folico has versioned releases.

## Reporting a Vulnerability

Open a private security advisory on GitHub or email the maintainer listed on the GitHub profile.

Please include:

- macOS version
- Folico version or commit SHA
- Steps to reproduce
- Whether folder contents, names, permissions, or icon metadata were affected

## Safety Boundaries

Folico should never:

- Delete files
- Rename folders automatically
- Move folders
- Upload folder data
- Read file contents for matching
- Apply icons without explicit user or tool confirmation
