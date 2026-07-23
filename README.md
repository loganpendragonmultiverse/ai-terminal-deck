# AI Terminal Deck

AI Terminal Deck opens Codex CLI, Claude Code, and Kimi Code together in one maximized Windows Terminal window with three equal side-by-side panes. It is a single, reviewable batch file for people who want independent access to multiple AI coding agents without installing another dashboard or orchestration service.

**Release status:** 1.0.0, complete initial Windows release.

## Three-minute setup

### Requirements

- Windows 10 or Windows 11
- [Windows Terminal](https://github.com/microsoft/terminal)
- The `codex`, `claude`, and `kimi` commands installed and available on `PATH`

Download `Launch-AI-Terminal-Deck.bat` from the [latest release](https://github.com/loganpendragonmultiverse/ai-terminal-deck/releases/latest). Run a readiness check from Command Prompt or PowerShell:

```console
Launch-AI-Terminal-Deck.bat --check
```

Double-click the file to open all three tools in `%USERPROFILE%\Documents`, or provide a project folder:

```console
Launch-AI-Terminal-Deck.bat "C:\Projects\My Project"
```

Each pane remains interactive. Click a pane to talk to that agent, resize panes with Windows Terminal controls, and close any pane you do not need.

## What opens

| Pane | Command | Purpose |
| --- | --- | --- |
| Left | `codex` | Codex CLI |
| Center | `claude` | Claude Code |
| Right | `kimi` | Kimi Code |

The first vertical split gives the new region two thirds of the window. Splitting that focused region in half produces three approximately equal columns.

## Choose the working directory

The launcher uses the first available value:

1. A folder passed as the first command-line argument.
2. The `AI_TERMINAL_DECK_WORKDIR` environment variable.
3. `%USERPROFILE%\Documents`.

For a persistent personal default:

```powershell
[Environment]::SetEnvironmentVariable("AI_TERMINAL_DECK_WORKDIR", "C:\Projects", "User")
```

Open a new terminal after changing a user environment variable.

## Privacy and safety

- The launcher contains no analytics, telemetry, network downloads, API keys, or credential storage.
- Authentication is handled independently by each installed AI CLI.
- The launcher checks every required command before opening Windows Terminal.
- An invalid working directory stops with an explanation instead of silently falling back elsewhere.
- AI Terminal Deck does not relay prompts, responses, credentials, or files between agents.

All three agents receive the same starting directory. They can safely discuss or inspect that directory independently, but simultaneous edits to one Git checkout can conflict. Use separate Git worktrees or give write access to only one agent at a time.

## Scope and limitations

- Windows only; the launcher depends on `wt.exe` and Windows batch scripting.
- It arranges three independent interfaces. It does not coordinate agents or merge their answers.
- It does not install Codex CLI, Claude Code, Kimi Code, Git, or Windows Terminal.
- It does not manage subscriptions, usage limits, model selection, or login sessions.
- If an AI process exits, its pane remains at PowerShell so an error message can still be read.
- Very narrow displays may be more comfortable with two panes or separate tabs; version 1.0.0 intentionally provides one fixed three-pane layout.

## Development and verification

The launcher has no runtime dependencies beyond Windows and the programs it starts. Run the PowerShell test suite and build the release files with:

```powershell
powershell.exe -NoProfile -File tests/Test-AITerminalDeck.ps1
powershell.exe -NoProfile -File scripts/package.ps1
```

The tests use temporary stub commands and dry-run mode; they do not launch or authenticate real AI services. See [DEVELOPMENT.md](DEVELOPMENT.md), [security notes](docs/SAFETY.md), and [CONTRIBUTING.md](CONTRIBUTING.md).

## Maintenance and contributions

The project is maintained as a focused Windows utility. Bug fixes, accessibility improvements, clearer diagnostics, and narrowly scoped layout options are welcome through reviewed pull requests. Agent orchestration, credential management, bundled third-party clients, and automatic software installation are outside the present scope.

## License

MIT License. Copyright 2026 Logan Pendragon Multiverse.
