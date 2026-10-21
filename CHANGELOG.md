# Changelog

All notable changes are documented here. The project follows Semantic Versioning.

## [1.1.0]

- Fix quoted discovery redirection that emitted spurious where.exe errors and stopped Windows PowerShell 5.1 verification.
- Assert separate raw stdout/stderr and exit statuses; run the full suite in Windows PowerShell 5.1 and PowerShell 7.
- Require stable numeric release tags, repeat the credential scan and pin maintained release actions.

- Add public, non-interactive layout preview with exact discovered command paths.
- Bind pane commands to supported PATH files and ignore implicit current-directory matches.
- Preserve literal working directories and process-specific PATH values without persistent writes.
- Add real cmd/Windows PowerShell command-binding regression fixtures; real Windows Terminal UI acceptance remains a separate release gate.
- Correct historical persistent-PATH claims and bundle linked guidance/tests in the ZIP.
- Reject mismatched package versions and existing output directories.

## [1.0.5] - 2026-10-16

### Fixed

Official install-folder discovery now changes only the launcher's process PATH. Readiness checks never persist user or machine environment settings, prompt, install, or launch tools, including missing-tool and invalid-directory paths. Persistent PATH repair has been removed; users can configure their environment separately if they want a permanent change. Synthetic Windows fixtures intercept every PowerShell environment/installer/launch operation and use fake official install folders.

## [1.0.4] - 2026-07-23

### Fixed

- Recognize Claude Code at its official Windows location, `%USERPROFILE%\.local\bin\claude.exe`, even when the upstream installer does not update `PATH`.
- Activate known official Codex, Claude, and Kimi install folders before every detection pass.
- Add Claude's verified official install folder to the user `PATH` so new terminals can invoke `claude` directly.

### Documented

- Clarify provider-specific login behavior and that AI Terminal Deck never shares credentials.
- Clarify that the selected working directory is a starting folder, not a filesystem sandbox.

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
