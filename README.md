# AI Terminal Deck

AI Terminal Deck detects Codex CLI, Claude Code, and Kimi Code, offers consent-based guided installation for anything missing, and opens the available tools together in one maximized Windows Terminal window. It is a single, reviewable batch file for people who want independent access to multiple AI coding agents without installing another dashboard or orchestration service.

**Candidate status:** 1.1.0, exact command binding and non-interactive preview. Publication and Gold qualification require the documented native acceptance gates.

## Three-minute setup

### Requirements

- Windows 10 or Windows 11
- [Windows Terminal](https://github.com/microsoft/terminal)
- At least one of the `codex`, `claude`, or `kimi` commands, either already installed or accepted during guided setup

Download `Launch-AI-Terminal-Deck.bat` from the [latest release](https://github.com/loganpendragonmultiverse/ai-terminal-deck/releases/latest). Run a readiness check from Command Prompt or PowerShell:

```console
Launch-AI-Terminal-Deck.bat --check
Launch-AI-Terminal-Deck.bat --preview "C:\Projects\My Project"
```

Double-click the file. It checks Windows Terminal and all three AI CLIs, collects your choices for every missing component, and only then runs the selected official installers one at a time. After rechecking the results, it shows a final confirmation before opening every available AI tool in `%USERPROFILE%\Documents`. Every installation requires a separate `Y` response; declining is allowed.

To use a specific project folder:

```console
Launch-AI-Terminal-Deck.bat "C:\Projects\My Project"
```

Each pane remains interactive. Click a pane to talk to that agent, resize panes with Windows Terminal controls, and close any pane you do not need. One installed AI opens one pane, two open equal halves, and all three open approximately equal columns.

## What opens

| Pane | Command | Purpose |
| --- | --- | --- |
| Left | `codex` | Codex CLI |
| Center | `claude` | Claude Code |
| Right | `kimi` | Kimi Code |

Only detected tools receive panes, in the order Codex, Claude, then Kimi. A two-tool layout uses equal halves. For three tools, the first vertical split gives the new region two thirds of the window and splitting that region in half produces approximately equal columns.

## Guided installation

The default double-click flow can offer these official Windows installers:

- Codex CLI: `https://chatgpt.com/codex/install.ps1`
- Claude Code: `https://claude.ai/install.ps1`
- Kimi Code: `https://code.kimi.com/kimi-code/install.ps1`
- Windows Terminal, when needed: Microsoft package `Microsoft.WindowsTerminal` through `winget`

The source is printed before every prompt. Nothing is installed unless the user answers `Y`. All choices are collected before any installer starts. The Codex installer runs in its supported non-interactive mode so its optional internal "Start Codex now?" prompt cannot interrupt Claude and Kimi setup. After all selected installers return, the launcher rechecks availability and asks once before opening the panes. `--check` never prompts, installs, or launches. `--preview [folder]` also shows the exact discovered command paths and the available one-, two-, or three-pane layout without installation prompts, installers, or terminal/tool launches. Preview exits 0 for a usable layout (Windows Terminal plus at least one tool); readiness still requires all three tools and exits 3 when any dependency is missing. Invalid directories/extra arguments exit 2. Kimi Code also expects Git for Windows for normal project use; the launcher reports that dependency but does not install Git.

Discovery considers `.exe`, `.cmd`, and `.bat` files in the process PATH plus the known folders below. It does not implicitly search the current working directory; a current-directory PATH entry remains an explicit caller choice. Each pane invokes the exact discovered path using Windows PowerShell without a user profile. Literal folder/command values travel in inherited process environment variables rather than being inserted into PowerShell source text. A PATH file is only discovered, not executed or authenticated, by readiness/preview.

The launcher also recognizes each publisher's official Windows install folder. In particular, Claude may install to `%USERPROFILE%\.local\bin` without registering that folder in `PATH`; AI Terminal Deck activates it only inside the launcher's process. It never persists changes to the user or machine `PATH`.

## Accounts and login

AI Terminal Deck does not log in, copy credentials, or connect provider accounts. Each CLI owns its authentication:

- Codex offers ChatGPT subscription login or OpenAI API-key setup and reuses valid Codex authentication already stored for the Windows user.
- Claude opens its own browser login on first launch and supports Claude.ai Pro, Max, Team, Enterprise, Console, or configured enterprise cloud providers.
- Kimi starts unconfigured until `/login` connects a Kimi Code account or `/provider` configures another supported provider.

Saved credentials remain provider-specific. Logging into one pane never logs into either of the others.

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

This is a starting directory, not a filesystem sandbox. Each CLI can navigate to another folder or use an absolute path when its own permission mode allows it. AI Terminal Deck does not grant extra access; review each tool's approval or autonomous-access setting. For the narrowest scope, launch the BAT with a specific project folder and avoid unrestricted modes when they are unnecessary.

## Privacy and safety

- The launcher contains no analytics, telemetry, API keys, or credential storage.
- Network access occurs only after explicit consent to run one of the displayed official installers.
- Authentication is handled independently by each installed AI CLI.
- The launcher checks every supported command, offers guided setup for missing ones, refreshes its process `PATH`, and checks again before opening Windows Terminal.
- An invalid working directory stops with an explanation instead of silently falling back elsewhere.
- Startup and dependency errors remain visible until you press a key, including when the launcher is opened by double-click.
- AI Terminal Deck does not relay prompts, responses, credentials, or files between agents.

All three agents receive the same starting directory. They can safely discuss or inspect that directory independently, but simultaneous edits to one Git checkout can conflict. Use separate Git worktrees or give write access to only one agent at a time.

## Scope and limitations

- Windows only; the launcher depends on `wt.exe` and Windows batch scripting.
- It arranges one to three independent interfaces. It does not coordinate agents or merge their answers.
- It can launch official installers only after individual confirmation. It does not silently install, update, uninstall, or authenticate any AI tool.
- It does not install Git for Windows, which Kimi Code expects for normal use.
- It does not manage subscriptions, usage limits, model selection, or login sessions.
- If an AI process exits, its pane remains at PowerShell so an error message can still be read. A successful launch exit means the window request was submitted; it does not prove provider readiness, authentication, or successful startup.
- Readiness/preview do not execute provider commands or prove that discovered files are healthy executables. Discovery follows the caller's PATHEXT order and selects only `.exe`, `.cmd`, or `.bat`; `.ps1` wrappers are not selected, and changing a file after discovery is outside this utility's control.
- The generated preview relies on this process's displayed/discovered paths and inherited variables; it is a diagnostic, not a portable command to paste into another environment.
- Very narrow displays may be more comfortable with one or two panes or separate tabs.

## Development and verification

The launcher has no runtime dependencies beyond Windows and the programs it starts. Run the PowerShell test suite and build the release files with:

```powershell
powershell.exe -NoProfile -File tests/Test-AITerminalDeck.ps1
powershell.exe -NoProfile -File scripts/package.ps1
```

Tests use temporary inert commands and never install or authenticate real AI services. Native command-binding tests execute actual Windows cmd/Windows PowerShell against markers while Windows Terminal is a capture fixture; that proves argument/environment binding, not a real Terminal window. Gold additionally requires the separate real-Windows-Terminal acceptance in TESTING.md. The ZIP includes all linked guidance, tests and packaging scripts; the standalone BAT remains the only runtime file. See [DEVELOPMENT.md](DEVELOPMENT.md), [security notes](docs/SAFETY.md), and [CONTRIBUTING.md](CONTRIBUTING.md).

## Maintenance and contributions

The project is maintained as a focused Windows utility. Bug fixes, accessibility improvements, clearer diagnostics, and narrowly scoped layout options are welcome through reviewed pull requests. Agent orchestration, credential management, bundled third-party clients, and silent or unattended software installation are outside the present scope.

## License

MIT License. Copyright 2026 Logan Pendragon Multiverse.

## More open-source projects

This project is part of the [Logan Pendragon Forge open-source collection](https://www.loganpendragonforge.com/open-source/). Browse the catalog for other released tools, source repositories, live demos, and downloads.
