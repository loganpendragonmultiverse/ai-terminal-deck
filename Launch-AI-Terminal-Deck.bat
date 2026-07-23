@echo off
setlocal EnableExtensions DisableDelayedExpansion

set "AI_TERMINAL_DECK_VERSION=1.0.0"
set "CHECK_ONLY=0"

if /I "%~1"=="--help" goto :help
if /I "%~1"=="-h" goto :help

if /I "%~1"=="--check" (
    set "CHECK_ONLY=1"
    set "WORKDIR=%~2"
) else (
    set "WORKDIR=%~1"
)

if not defined WORKDIR set "WORKDIR=%AI_TERMINAL_DECK_WORKDIR%"
if not defined WORKDIR set "WORKDIR=%USERPROFILE%\Documents"

for %%I in ("%WORKDIR%") do set "WORKDIR=%%~fI"

echo AI Terminal Deck %AI_TERMINAL_DECK_VERSION%
echo Working directory: "%WORKDIR%"
echo.

if not exist "%WORKDIR%\." (
    echo [ERROR] The working directory does not exist.
    echo         Provide an existing folder as the first argument.
    exit /b 2
)

set "MISSING=0"
call :require wt.exe "Windows Terminal"
call :require codex "Codex CLI"
call :require claude "Claude Code"
call :require kimi "Kimi Code"

if "%MISSING%"=="1" (
    echo.
    echo Install the missing command or add it to PATH, then run this launcher again.
    echo Use --check to repeat the readiness check without opening any panes.
    exit /b 3
)

if "%CHECK_ONLY%"=="1" (
    echo.
    echo [READY] All three AI command-line interfaces are available.
    exit /b 0
)

if /I "%AI_TERMINAL_DECK_DRY_RUN%"=="1" (
    echo.
    echo [DRY RUN] Windows Terminal launch command:
    echo wt.exe -w new -M new-tab --title "Codex" --suppressApplicationTitle -d "%WORKDIR%" powershell.exe -NoLogo -NoProfile -NoExit -Command "codex" ; split-pane -V -s 0.666 --title "Claude" --suppressApplicationTitle -d "%WORKDIR%" powershell.exe -NoLogo -NoProfile -NoExit -Command "claude" ; split-pane -V -s 0.5 --title "Kimi" --suppressApplicationTitle -d "%WORKDIR%" powershell.exe -NoLogo -NoProfile -NoExit -Command "kimi"
    exit /b 0
)

start "" wt.exe -w new -M ^
    new-tab --title "Codex" --suppressApplicationTitle -d "%WORKDIR%" powershell.exe -NoLogo -NoProfile -NoExit -Command "codex" ^
    ; split-pane -V -s 0.666 --title "Claude" --suppressApplicationTitle -d "%WORKDIR%" powershell.exe -NoLogo -NoProfile -NoExit -Command "claude" ^
    ; split-pane -V -s 0.5 --title "Kimi" --suppressApplicationTitle -d "%WORKDIR%" powershell.exe -NoLogo -NoProfile -NoExit -Command "kimi"

if errorlevel 1 (
    echo [ERROR] Windows Terminal could not be started.
    exit /b 4
)

exit /b 0

:require
where %~1 >nul 2>&1
if errorlevel 1 (
    echo [MISSING] %~2 ^(%~1^)
    set "MISSING=1"
) else (
    echo [READY]   %~2 ^(%~1^)
)
exit /b 0

:help
echo AI Terminal Deck %AI_TERMINAL_DECK_VERSION%
echo.
echo Opens Codex CLI, Claude Code, and Kimi Code in three equal Windows Terminal panes.
echo.
echo Usage:
echo   Launch-AI-Terminal-Deck.bat [working-directory]
echo   Launch-AI-Terminal-Deck.bat --check [working-directory]
echo   Launch-AI-Terminal-Deck.bat --help
echo.
echo Working-directory priority:
echo   1. Command-line argument
echo   2. AI_TERMINAL_DECK_WORKDIR environment variable
echo   3. %%USERPROFILE%%\Documents
echo.
echo The launcher does not install, authenticate, coordinate, or share data between AI tools.
exit /b 0
