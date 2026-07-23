# Troubleshooting

## A command is missing

Run:

```console
Launch-AI-Terminal-Deck.bat --check
```

Install the missing official CLI or correct `PATH`, open a new terminal, and repeat the check. The launcher stops before opening panes when any required command is unavailable.

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
