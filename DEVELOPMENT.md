# Development record

Version 1.0.4 activates publisher-standard install paths before detection. This repairs Claude's successful native install at `%USERPROFILE%\.local\bin\claude.exe` when the upstream installer leaves the directory absent from `PATH`; the launcher also persists that exact verified folder in the user `PATH`. Documentation now distinguishes provider-specific authentication and starting-directory selection from filesystem permissions.

Version 1.0.3 separates selection, installation, and launch. The launcher records every missing-component choice before running installers, forces the official Codex script's supported non-interactive mode to suppress its internal “Start Codex now?” prompt, completes every selected installer, refreshes `PATH`, rechecks availability, and requests final confirmation before opening panes. `AI_TERMINAL_DECK_INSTALL_DRY_RUN=1` is an internal test seam for exercising the complete interactive sequence without invoking provider installers.

Version 1.0.2 corrects the three PowerShell installer command lines. A caret used to escape the pipe was unnecessary inside the quoted `-Command` argument and reached PowerShell as a literal positional argument. Regression tests now reject `^| iex` and require all three allowlisted installer commands to use a directly parsed `| iex` pipeline.

Version 1.0.1 fixes Explorer double-click error visibility and adds guided setup with adaptive layouts. Startup failures now display a clear keypress prompt before the temporary console closes. Missing components receive individual yes/no prompts that identify the official installer source; declined or unsuccessful tools are omitted. The launcher refreshes its process `PATH`, detects the resulting availability, and opens one, two, or three panes.

Automated tests suppress the interactive pause through `AI_TERMINAL_DECK_NO_PAUSE=1`, suppress installer prompts through `AI_TERMINAL_DECK_SKIP_INSTALL_PROMPTS=1`, and preview terminal commands through `AI_TERMINAL_DECK_DRY_RUN=1`. These variables are internal verification seams and do not change ordinary use.

Version 1.0.0 implements the complete initial scope: one dependency-free batch launcher, explicit dependency and directory checks, a fixed equal-width three-pane Windows Terminal layout, optional working-directory selection, persistent pane titles, readiness/help commands, and a dry-run seam for automated verification.

The launcher installs nothing silently or without a separate affirmative response. It does not store credentials, coordinate models, transmit data between panes, create Git worktrees, install Kimi's Git dependency, or make assumptions about subscription and model configuration. Those boundaries keep the public artifact small, auditable, and useful with independently maintained CLIs.

Windows Terminal is the layout engine. PowerShell hosts each AI process with `-NoExit` so authentication or startup errors remain visible after a CLI exits. The launcher supplies a common working directory but warns users not to allow concurrent writes in one checkout.

CodeQL does not analyze Windows batch files. The repository therefore uses Windows-native behavior tests, release artifact hashing, secret-pattern checks, destructive-command checks, official-installer allowlist checks, and GitHub secret scanning as the language-appropriate security verification.
