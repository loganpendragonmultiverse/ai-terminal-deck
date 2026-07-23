@echo off
setlocal EnableExtensions DisableDelayedExpansion

set "AI_TERMINAL_DECK_VERSION=1.0.2"
set "CHECK_ONLY=0"
set "INSTALL_ATTEMPTED=0"

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
    call :wait_to_close
    exit /b 2
)

call :detect_tools

if "%CHECK_ONLY%"=="1" goto :check_result

if "%WT_READY%"=="0" call :offer_windows_terminal
if "%CODEX_READY%"=="0" call :offer_codex
if "%CLAUDE_READY%"=="0" call :offer_claude
if "%KIMI_READY%"=="0" call :offer_kimi

if "%INSTALL_ATTEMPTED%"=="1" (
    echo.
    echo Refreshing this launcher's PATH and checking again...
    call :refresh_path
    call :detect_tools
)

if "%WT_READY%"=="0" (
    echo.
    echo [ERROR] Windows Terminal is required to create the pane layout.
    echo         Install it, then run this launcher again.
    call :wait_to_close
    exit /b 3
)

call :select_tools
if "%TOOL_COUNT%"=="0" (
    echo.
    echo [ERROR] No supported AI CLI is currently available.
    echo         Install at least one of Codex CLI, Claude Code, or Kimi Code.
    call :wait_to_close
    exit /b 3
)

echo.
echo Opening %TOOL_COUNT% installed AI CLI pane^(s^) in Windows Terminal...
if /I "%AI_TERMINAL_DECK_DRY_RUN%"=="1" goto :dry_run
goto :launch

:check_result
if "%WT_READY%"=="1" if "%CODEX_READY%"=="1" if "%CLAUDE_READY%"=="1" if "%KIMI_READY%"=="1" (
    echo.
    echo [READY] Windows Terminal and all three AI CLIs are available.
    exit /b 0
)
echo.
echo Readiness check only: no installation prompts were shown.
echo Run the launcher without --check for guided setup and an adaptive layout.
call :wait_to_close
exit /b 3

:launch
if "%TOOL_COUNT%"=="1" (
    start "" wt.exe -w new -M new-tab --title "%FIRST_TITLE%" --suppressApplicationTitle -d "%WORKDIR%" powershell.exe -NoLogo -NoProfile -NoExit -Command "%FIRST_COMMAND%"
) else if "%TOOL_COUNT%"=="2" (
    start "" wt.exe -w new -M new-tab --title "%FIRST_TITLE%" --suppressApplicationTitle -d "%WORKDIR%" powershell.exe -NoLogo -NoProfile -NoExit -Command "%FIRST_COMMAND%" ^; split-pane -V -s 0.5 --title "%SECOND_TITLE%" --suppressApplicationTitle -d "%WORKDIR%" powershell.exe -NoLogo -NoProfile -NoExit -Command "%SECOND_COMMAND%"
) else (
    start "" wt.exe -w new -M new-tab --title "%FIRST_TITLE%" --suppressApplicationTitle -d "%WORKDIR%" powershell.exe -NoLogo -NoProfile -NoExit -Command "%FIRST_COMMAND%" ^; split-pane -V -s 0.666 --title "%SECOND_TITLE%" --suppressApplicationTitle -d "%WORKDIR%" powershell.exe -NoLogo -NoProfile -NoExit -Command "%SECOND_COMMAND%" ^; split-pane -V -s 0.5 --title "%THIRD_TITLE%" --suppressApplicationTitle -d "%WORKDIR%" powershell.exe -NoLogo -NoProfile -NoExit -Command "%THIRD_COMMAND%"
)
if errorlevel 1 (
    echo [ERROR] Windows Terminal could not be started.
    call :wait_to_close
    exit /b 4
)
exit /b 0

:dry_run
echo [DRY RUN] Windows Terminal launch command:
if "%TOOL_COUNT%"=="1" echo wt.exe -w new -M new-tab --title "%FIRST_TITLE%" --suppressApplicationTitle -d "%WORKDIR%" powershell.exe -NoLogo -NoProfile -NoExit -Command "%FIRST_COMMAND%"
if "%TOOL_COUNT%"=="2" echo wt.exe -w new -M new-tab --title "%FIRST_TITLE%" --suppressApplicationTitle -d "%WORKDIR%" powershell.exe -NoLogo -NoProfile -NoExit -Command "%FIRST_COMMAND%" ; split-pane -V -s 0.5 --title "%SECOND_TITLE%" --suppressApplicationTitle -d "%WORKDIR%" powershell.exe -NoLogo -NoProfile -NoExit -Command "%SECOND_COMMAND%"
if "%TOOL_COUNT%"=="3" echo wt.exe -w new -M new-tab --title "%FIRST_TITLE%" --suppressApplicationTitle -d "%WORKDIR%" powershell.exe -NoLogo -NoProfile -NoExit -Command "%FIRST_COMMAND%" ; split-pane -V -s 0.666 --title "%SECOND_TITLE%" --suppressApplicationTitle -d "%WORKDIR%" powershell.exe -NoLogo -NoProfile -NoExit -Command "%SECOND_COMMAND%" ; split-pane -V -s 0.5 --title "%THIRD_TITLE%" --suppressApplicationTitle -d "%WORKDIR%" powershell.exe -NoLogo -NoProfile -NoExit -Command "%THIRD_COMMAND%"
exit /b 0

:detect_tools
echo Checking installed commands...
call :detect wt.exe WT_READY "Windows Terminal"
call :detect codex CODEX_READY "Codex CLI"
call :detect claude CLAUDE_READY "Claude Code"
call :detect kimi KIMI_READY "Kimi Code"
exit /b 0

:detect
where %~1 >nul 2>&1
if errorlevel 1 (
    set "%~2=0"
    echo [MISSING] %~3 ^(%~1^)
) else (
    set "%~2=1"
    echo [READY]   %~3 ^(%~1^)
)
exit /b 0

:offer_windows_terminal
if /I "%AI_TERMINAL_DECK_SKIP_INSTALL_PROMPTS%"=="1" exit /b 0
echo.
echo Windows Terminal is missing.
echo Installer: Microsoft winget package Microsoft.WindowsTerminal
call :confirm "Install Windows Terminal now?"
if "%CONFIRMED%"=="0" exit /b 0
where winget >nul 2>&1
if errorlevel 1 (
    echo [ERROR] winget is unavailable. Install Windows Terminal from Microsoft Store.
    exit /b 0
)
set "INSTALL_ATTEMPTED=1"
winget install --id Microsoft.WindowsTerminal -e --accept-source-agreements --accept-package-agreements
if errorlevel 1 echo [WARNING] Windows Terminal installation did not complete successfully.
exit /b 0

:offer_codex
if /I "%AI_TERMINAL_DECK_SKIP_INSTALL_PROMPTS%"=="1" exit /b 0
echo.
echo Codex CLI is missing.
echo Official installer: https://chatgpt.com/codex/install.ps1
call :confirm "Install Codex CLI now?"
if "%CONFIRMED%"=="0" exit /b 0
set "INSTALL_ATTEMPTED=1"
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "irm 'https://chatgpt.com/codex/install.ps1' | iex"
if errorlevel 1 echo [WARNING] Codex CLI installation did not complete successfully.
exit /b 0

:offer_claude
if /I "%AI_TERMINAL_DECK_SKIP_INSTALL_PROMPTS%"=="1" exit /b 0
echo.
echo Claude Code is missing.
echo Official installer: https://claude.ai/install.ps1
call :confirm "Install Claude Code now?"
if "%CONFIRMED%"=="0" exit /b 0
set "INSTALL_ATTEMPTED=1"
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "irm 'https://claude.ai/install.ps1' | iex"
if errorlevel 1 echo [WARNING] Claude Code installation did not complete successfully.
exit /b 0

:offer_kimi
if /I "%AI_TERMINAL_DECK_SKIP_INSTALL_PROMPTS%"=="1" exit /b 0
echo.
echo Kimi Code is missing.
echo Official installer: https://code.kimi.com/kimi-code/install.ps1
echo Kimi Code also requires Git for Windows for normal use.
call :confirm "Install Kimi Code now?"
if "%CONFIRMED%"=="0" exit /b 0
set "INSTALL_ATTEMPTED=1"
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "irm 'https://code.kimi.com/kimi-code/install.ps1' | iex"
if errorlevel 1 echo [WARNING] Kimi Code installation did not complete successfully.
exit /b 0

:confirm
set "CONFIRMED=0"
choice /C YN /N /M "%~1 [Y/N] "
if errorlevel 2 exit /b 0
if errorlevel 1 set "CONFIRMED=1"
exit /b 0

:refresh_path
for /f "usebackq delims=" %%P in (`powershell.exe -NoProfile -Command "[Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [Environment]::GetEnvironmentVariable('Path','User')"`) do set "PATH=%%P"
exit /b 0

:select_tools
set "TOOL_COUNT=0"
if "%CODEX_READY%"=="1" call :add_tool "Codex" "codex"
if "%CLAUDE_READY%"=="1" call :add_tool "Claude" "claude"
if "%KIMI_READY%"=="1" call :add_tool "Kimi" "kimi"
exit /b 0

:add_tool
set /a TOOL_COUNT+=1
if "%TOOL_COUNT%"=="1" (
    set "FIRST_TITLE=%~1"
    set "FIRST_COMMAND=%~2"
)
if "%TOOL_COUNT%"=="2" (
    set "SECOND_TITLE=%~1"
    set "SECOND_COMMAND=%~2"
)
if "%TOOL_COUNT%"=="3" (
    set "THIRD_TITLE=%~1"
    set "THIRD_COMMAND=%~2"
)
exit /b 0

:wait_to_close
echo.
echo Press any key to close this window.
if /I "%AI_TERMINAL_DECK_NO_PAUSE%"=="1" exit /b 0
pause >nul
exit /b 0

:help
echo AI Terminal Deck %AI_TERMINAL_DECK_VERSION%
echo.
echo Detects Codex CLI, Claude Code, and Kimi Code, offers guided installation
echo for missing tools, and opens the installed tools in one to three Windows
echo Terminal panes.
echo.
echo Usage:
echo   Launch-AI-Terminal-Deck.bat [working-directory]
echo   Launch-AI-Terminal-Deck.bat --check [working-directory]
echo   Launch-AI-Terminal-Deck.bat --help
echo.
echo --check reports readiness without prompting to install or opening panes.
echo Every installation requires an explicit Y response.
echo Authentication remains inside each provider's CLI after it opens.
echo Startup errors remain visible until you press a key.
exit /b 0
