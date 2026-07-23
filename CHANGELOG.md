# Changelog

All notable changes are documented here. The project follows Semantic Versioning.

## [1.0.3] - 2026-07-23

### Fixed

- Collect all missing-tool installation choices before executing any installer.
- Run the official Codex installer with its supported `CODEX_NON_INTERACTIVE=1` mode so its internal “Start Codex now?” question cannot launch Codex and block Claude or Kimi setup.
- Recheck all tools after the complete setup phase and require a final confirmation before opening the detected panes.

## [1.0.2] - 2026-07-23

### Fixed

- Remove a batch escape character that was passed literally into PowerShell and caused every consented Codex, Claude, and Kimi installer to fail with `A positional parameter cannot be found that accepts argument '^'`.
- Add regression coverage for the exact installer command parsing failure.

## [1.0.1] - 2026-07-23

### Fixed

- Keep dependency, working-directory, and Windows Terminal startup errors visible when the launcher is opened by double-click.
- Add a clear keypress prompt before closing after startup failures.
- Preserve non-interactive test execution through the internal `AI_TERMINAL_DECK_NO_PAUSE` test seam.

### Added

- Detect each supported AI CLI independently and offer a separate, consent-gated official installer for every missing tool.
- Recheck the active `PATH` after installation attempts and immediately continue into the terminal layout when possible.
- Automatically open one, two, or three panes based on the CLIs actually available; two-pane and three-pane layouts divide the window evenly.
- Offer Windows Terminal installation through its Microsoft `winget` package when the required terminal host is missing.
- Keep `--check` strictly read-only with no installation prompts or launches.

## [1.0.0] - 2026-07-23

### Added

- One-file Windows launcher for Codex CLI, Claude Code, and Kimi Code.
- Three approximately equal side-by-side Windows Terminal panes with persistent titles.
- Command availability and working-directory validation before launch.
- Optional command-line or environment-variable working-directory selection.
- `--check`, `--help`, and test-only dry-run behavior.
- Automated Windows tests, release packaging, checksums, CI, and security checks.
