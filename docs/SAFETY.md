# Safety boundaries

AI Terminal Deck is a process launcher, not an agent coordinator.

## Local behavior

The batch file checks the requested folder and resolves four command names through Windows `where` restricted to the effective process PATH: `wt.exe`, `codex`, `claude`, and `kimi`. It offers a separate yes/no installation prompt for anything missing, prints the official source first, refreshes its process `PATH`, and asks Windows Terminal to open only the detected AI commands in that folder. It writes no configuration or credential files.

The only launcher-initiated network activity is an installation the user explicitly accepts. The allowlisted sources are OpenAI's `https://chatgpt.com/codex/install.ps1`, Anthropic's `https://claude.ai/install.ps1`, Moonshot AI's `https://code.kimi.com/kimi-code/install.ps1`, and Microsoft's `Microsoft.WindowsTerminal` package through `winget`. Review the displayed source and answer `N` if you prefer to install manually. `--check` is always report-only.

## Concurrent editing

Each AI process can inspect and modify files according to its own permissions. Giving multiple autonomous tools the same writable Git checkout can cause overwritten changes, misleading diffs, competing builds, and inconsistent conclusions.

Use one of these patterns:

- Only one pane writes; the others review read-only.
- Point panes at separate repositories.
- Create a separate Git worktree and branch for every writing agent.

Review diffs, tests, and commits before merging work from any agent.

## Command resolution

The launcher intentionally uses supported `.exe`, `.cmd`, and `.bat` files found on the effective process `PATH`, including process-only known publisher paths. It displays and binds the exact selected path; readiness and preview do not execute these files. Verify the installations you trust with `where codex`, `where claude`, and `where kimi`. A malicious executable earlier on `PATH` is outside the launcher's ability to distinguish from the intended CLI. After an accepted installer returns, the launcher retains its existing process `PATH` and appends current Windows machine/user values before checking again. It never writes those persistent values. Literal working-directory and command paths are carried as process data rather than interpolated into PowerShell source.
