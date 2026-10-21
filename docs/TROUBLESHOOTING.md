# Troubleshooting

## Claude installed successfully but still appears missing

Claude's native Windows installer can place `claude.exe` in `%USERPROFILE%\.local\bin` without adding that folder to `PATH`. Version 1.0.5 and newer recognizes the official location and activates it only inside the launcher process. User and machine `PATH` remain unchanged. The persistent PATH behavior existed only in historical version 1.0.4.

## Codex opens before Claude or Kimi setup finishes

The official Codex installer has its own optional “Start Codex now?” prompt. Version 1.0.3 and newer suppresses that internal launch prompt, collects every AI Terminal Deck installation choice first, finishes all selected installers, and asks once before opening any panes.

## An installer reports that `'^'` is an invalid argument

This was a launcher quoting bug in version 1.0.1 and affected all three AI installers. Download version 1.0.2 or newer. The corrected installer commands no longer pass the batch escape character into PowerShell.

## A command is missing

Run:

```console
Launch-AI-Terminal-Deck.bat --check
```

`--check` is report-only. Run the launcher without `--check` to receive an individual installation prompt for each missing CLI. It uses only the official installer URL displayed before the prompt and requires `Y` before running it. Declined or unsuccessful installations are omitted from the adaptive layout; any successfully detected tools still open.

When started by double-click, version 1.0.1 and newer keeps this explanation visible until you press a key. Earlier versions could close the temporary console before the message could be read.

## An installer finished but the tool is still missing

The launcher refreshes its process `PATH` and checks again. If the provider says a terminal restart is required, close AI Terminal Deck and double-click it again. You can also run the provider's command directly in a new PowerShell window to complete first-run login.

Kimi Code expects Git for Windows for normal project use. Install Git separately from its official distribution if Kimi reports that `git` is unavailable.

## The wrong folder opens

Pass the folder explicitly:

```console
Launch-AI-Terminal-Deck.bat "C:\Projects\My Project"
```

The explicit argument overrides `AI_TERMINAL_DECK_WORKDIR` and the default Documents folder.

## Login opens a browser

That is controlled by the individual AI CLI. Complete its official login flow and return to the corresponding pane. AI Terminal Deck never receives the credentials.

## A pane returns to PowerShell

The AI command exited or failed. Its PowerShell host intentionally remains open so the final message is visible. Read the output, run the command again if appropriate, or close the pane.

## Preview shows a surprising command path

Use `Launch-AI-Terminal-Deck.bat --preview [folder]` to inspect every resolved path and layout without prompts, installation, or launching. The first supported `.exe`, `.cmd`, or `.bat` on the effective process PATH is selected; readiness discovery is not a trust or executable-health check. A similarly named file in the current directory is ignored unless that directory is explicitly on PATH. The exact selected path is supplied to each pane; Discovery follows the caller's PATHEXT order and selects only `.exe`, `.cmd`, or `.bat`; `.ps1` wrappers are not selected.

The working directory is supplied as literal data. A preview is tied to its process environment and is not a portable shell command. When an installer has been accepted, the launcher preserves its process PATH while also reading updated user/machine values; no values are persisted by the launcher.
