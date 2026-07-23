# Development record

Version 1.0.0 implements the complete initial scope: one dependency-free batch launcher, explicit dependency and directory checks, a fixed equal-width three-pane Windows Terminal layout, optional working-directory selection, persistent pane titles, readiness/help commands, and a dry-run seam for automated verification.

The launcher deliberately does not install AI clients, store credentials, coordinate models, transmit data between panes, create Git worktrees, or make assumptions about subscription and model configuration. Those boundaries keep the public artifact small, auditable, and useful with independently maintained CLIs.

Windows Terminal is the layout engine. PowerShell hosts each AI process with `-NoExit` so authentication or startup errors remain visible after a CLI exits. The launcher supplies a common working directory but warns users not to allow concurrent writes in one checkout.

CodeQL does not analyze Windows batch files. The repository therefore uses Windows-native behavior tests, release artifact hashing, secret-pattern checks, destructive-command checks, and GitHub secret scanning as the language-appropriate security verification.
