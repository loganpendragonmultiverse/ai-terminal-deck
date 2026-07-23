# Safety boundaries

AI Terminal Deck is a process launcher, not an agent coordinator.

## Local behavior

The batch file checks the requested folder and resolves four command names through Windows `where`: `wt.exe`, `codex`, `claude`, and `kimi`. It then asks Windows Terminal to open three PowerShell processes in that folder. The launcher performs no network requests and writes no configuration or credential files.

## Concurrent editing

Each AI process can inspect and modify files according to its own permissions. Giving multiple autonomous tools the same writable Git checkout can cause overwritten changes, misleading diffs, competing builds, and inconsistent conclusions.

Use one of these patterns:

- Only one pane writes; the others review read-only.
- Point panes at separate repositories.
- Create a separate Git worktree and branch for every writing agent.

Review diffs, tests, and commits before merging work from any agent.

## Command resolution

The launcher intentionally uses the commands found on the current `PATH`. Verify the installations you trust with `where codex`, `where claude`, and `where kimi`. A malicious executable earlier on `PATH` is outside the launcher's ability to distinguish from the intended CLI.
