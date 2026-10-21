# Testing

Run `powershell.exe -NoProfile -File tests/Test-AITerminalDeck.ps1` and `powershell.exe -NoProfile -File scripts/package.ps1` on Windows. The suite includes Test-ReadOnlyCheck.ps1, which instruments a disposable launcher copy to intercept PowerShell operations, builds fake official install paths, and checks success and missing-tool readiness without real registry writes, installers or CLI launches. Existing tests cover help, invalid directories, adaptive dry-run panes and consent sequencing.

## 1.0.5 — 2026-10-16

Verify the packaged ZIP includes README.md, CHANGELOG.md, DEVELOPMENT.md and TESTING.md. Inspect SHA256SUMS.txt and confirm the standalone launcher matches the reviewed source.

## 1.1.0 native command-binding regression

The full suite invokes `tests/Test-NativeCommandBinding.ps1`. It compiles a temporary .NET Framework capture executable as `wt.exe`, creates inert `.cmd` markers, and executes the launcher through actual Windows cmd and Windows PowerShell. Assertions cover exact PATH binding despite current-directory shadow commands, punctuation/space/literal-percent working directories, three delivered pane commands, process-only PATH behavior, and public preview without prompts or side effects. This does not qualify the actual Windows Terminal UI. No provider executables, installations or authentication are used.

## Required native Windows Terminal acceptance

Use a verified interactive Windows 10/11 desktop and the exact reviewed candidate artifact/hash supplied in the task acceptance packet. Run the full packaged tests, validate the package checksums/content against that commit, inspect existing tool discovery read-only, then open one task-owned real Windows Terminal window with inert isolated CLI markers. Verify one-, two-, and three-pane layouts, pane titles, literal working directories, and exact marker execution; confirm provider commands/installers/login and persistent environment writes never occur. Only close the task-owned window. Record OS/PowerShell/Terminal versions, artifact hashes, commands, marker output, UI observations/screenshots and before/after environment hashes. If the desktop/Terminal is unavailable, scope cannot be isolated, or UI evidence is missing, keep Gold/release blocked.

The release ZIP includes these instructions, docs, tests and scripts. Run extracted artifacts outside any source checkout. Each packaging run requires a new/absent `dist` directory; a requested version must match the launcher version.
