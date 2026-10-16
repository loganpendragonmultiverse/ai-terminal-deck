# Testing

Run `powershell.exe -NoProfile -File tests/Test-AITerminalDeck.ps1` and `powershell.exe -NoProfile -File scripts/package.ps1` on Windows. The suite includes Test-ReadOnlyCheck.ps1, which instruments a disposable launcher copy to intercept PowerShell operations, builds fake official install paths, and checks success and missing-tool readiness without real registry writes, installers or CLI launches. Existing tests cover help, invalid directories, adaptive dry-run panes and consent sequencing.

## 1.0.5 — 2026-10-16

Verify the packaged ZIP includes README.md, CHANGELOG.md, DEVELOPMENT.md and TESTING.md. Inspect SHA256SUMS.txt and confirm the standalone launcher matches the reviewed source.
