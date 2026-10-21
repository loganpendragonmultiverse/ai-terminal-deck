param(
    [Parameter(Mandatory=$true)][string]$ArtifactDirectory,
    [Parameter(Mandatory=$true)][ValidatePattern('^[0-9a-fA-F]{64}$')][string]$ExpectedLauncherSHA256,
    [Parameter(Mandatory=$true)][string]$TerminalExecutable,
    [Parameter(Mandatory=$true)][string]$TaskDirectory,
    [Parameter(Mandatory=$true)][ValidateSet(1,2,3)][int]$ToolCount,
    [switch]$OpenTerminal
)
$ErrorActionPreference = 'Stop'
$runnerVersion = '1.0.0'
if ([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT) { throw 'An independently verified interactive Windows desktop is required.' }
$launcher = Join-Path ([IO.Path]::GetFullPath($ArtifactDirectory)) 'Launch-AI-Terminal-Deck.bat'
$actualHash = (Get-FileHash -LiteralPath $launcher -Algorithm SHA256).Hash.ToLowerInvariant()
if ($actualHash -ne $ExpectedLauncherSHA256.ToLowerInvariant()) { throw 'Launcher hash does not match the frozen reviewed packet.' }
$terminal = [IO.Path]::GetFullPath($TerminalExecutable)
if ([IO.Path]::GetFileName($terminal) -ine 'wt.exe' -or -not (Test-Path -LiteralPath $terminal -PathType Leaf)) { throw 'Supply the verified installed Windows Terminal wt.exe path.' }
$task = [IO.Path]::GetFullPath($TaskDirectory)
$temp = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\') + '\'
if (-not $task.StartsWith($temp,[StringComparison]::OrdinalIgnoreCase) -or (Test-Path -LiteralPath $task)) { throw 'TaskDirectory must be a new child of Windows TEMP.' }
$terminalBin = Split-Path -Parent $terminal
$hostBins = @($terminalBin, (Join-Path $env:SystemRoot 'System32'), (Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0'))
# Refuse a broad application-alias folder containing provider clients. No provider
# executable is copied, executed, installed, authenticated or inspected for secrets.
foreach ($directory in $hostBins) {
    foreach ($name in @('codex','claude','kimi')) {
        foreach ($extension in @('exe','cmd','bat','com','ps1')) {
            if (Test-Path -LiteralPath (Join-Path $directory ($name + '.' + $extension))) { throw "Provider command present in a host directory; use the actual isolated Terminal package directory: $directory" }
        }
    }
}
New-Item -ItemType Directory -Path $task | Out-Null
$bin = Join-Path $task "Marker Bin & (round) O'Neil !"
$workdir = Join-Path $task "Workspace & (round) O'Neil !; %DECK_LITERAL%"
$markers = Join-Path $task 'markers'
New-Item -ItemType Directory -Path $bin,$workdir,$markers | Out-Null
$id = [IO.Path]::GetFileName($task)
if ($id -notmatch '^[a-zA-Z0-9_-]+$') { throw 'Use only letters, digits, underscore or hyphen in the task directory basename.' }
$selected = @('codex','claude','kimi')[0..($ToolCount - 1)]
foreach ($name in $selected) {
    $body = '@echo AI Terminal Deck INERT acceptance %DECK_ACCEPTANCE_ID% ' + $name + "`r`n" + '@echo marker:' + $name + '> "%DECK_ACCEPTANCE_MARKERS%\' + $name + '.txt"' + "`r`n" + '@cd >> "%DECK_ACCEPTANCE_MARKERS%\' + $name + '.txt"' + "`r`n@cd`r`n@exit /b 0`r`n"
    [IO.File]::WriteAllText((Join-Path $bin ($name + '.cmd')), $body)
}
$keys = @('PATH','PATHEXT','AI_TERMINAL_DECK_WORKDIR','AI_TERMINAL_DECK_SKIP_KNOWN_PATHS','AI_TERMINAL_DECK_SKIP_INSTALL_PROMPTS','AI_TERMINAL_DECK_NO_PAUSE','AI_TERMINAL_DECK_DRY_RUN','AI_TERMINAL_DECK_INSTALL_DRY_RUN','DECK_ACCEPTANCE_ID','DECK_ACCEPTANCE_MARKERS')
$saved = @{}
foreach ($key in $keys) { $saved[$key] = [Environment]::GetEnvironmentVariable($key,'Process') }
$userBefore = [Environment]::GetEnvironmentVariable('PATH','User')
$machineBefore = [Environment]::GetEnvironmentVariable('PATH','Machine')
$record = [ordered]@{runner_version=$runnerVersion;runner_sha256=(Get-FileHash -LiteralPath $PSCommandPath -Algorithm SHA256).Hash.ToLowerInvariant();launcher_sha256=$actualHash;started_utc=[DateTime]::UtcNow.ToString('o');os=[Environment]::OSVersion.VersionString;powershell=$PSVersionTable.PSVersion.ToString();terminal_path=$terminal;terminal_version=(Get-Item -LiteralPath $terminal).VersionInfo.FileVersion;task_directory=$task;expected_tools=$selected;working_directory=$workdir;real_terminal_requested=[bool]$OpenTerminal;machine_checks_passed=$false;native_ui_verified=$false;qualification='blocked-pending-native-UI-observation'}
try {
    $env:PATH = (@($bin) + $hostBins + @($env:SystemRoot)) -join ';'
    $env:PATHEXT = '.EXE;.CMD;.BAT'
    $env:AI_TERMINAL_DECK_WORKDIR = $workdir
    $env:AI_TERMINAL_DECK_SKIP_KNOWN_PATHS = '1'
    $env:AI_TERMINAL_DECK_SKIP_INSTALL_PROMPTS = '1'
    $env:AI_TERMINAL_DECK_NO_PAUSE = '1'
    $env:AI_TERMINAL_DECK_DRY_RUN = $null
    $env:AI_TERMINAL_DECK_INSTALL_DRY_RUN = '1'
    $env:DECK_ACCEPTANCE_ID = $id
    $env:DECK_ACCEPTANCE_MARKERS = $markers
    $preview = & "$env:SystemRoot\System32\cmd.exe" /d /s /c ('""' + $launcher + '" --preview"') 2>&1
    $record.preview_exit_code = $LASTEXITCODE; $record.preview = $preview -join "`n"
    if ($record.preview_exit_code -ne 0) { throw 'Isolated preview did not find a usable layout.' }
    foreach ($name in $selected) {
        if (-not $record.preview.Contains((Join-Path $bin ($name + '.cmd')))) { throw "Preview did not bind the inert $name marker." }
    }
    if ($record.preview -match 'Install .*now|Press any key|Opening .*pane') { throw 'Preview prompted or claimed a launch.' }
    if (@(Get-ChildItem -LiteralPath $markers).Count -ne 0) { throw 'Preview executed a marker.' }
    $check = & "$env:SystemRoot\System32\cmd.exe" /d /s /c ('""' + $launcher + '" --check"') 2>&1
    $record.check_exit_code = $LASTEXITCODE; $record.readiness = $check -join "`n"
    $expectedCheck = if ($ToolCount -eq 3) { 0 } else { 3 }
    if ($record.check_exit_code -ne $expectedCheck -or @(Get-ChildItem -LiteralPath $markers).Count -ne 0) { throw 'Readiness status or no-execution boundary failed.' }
    if (-not $OpenTerminal) { throw 'Read-only preflight complete; rerun in a NEW task directory with -OpenTerminal only after desktop scope is verified.' }
    $output = & "$env:SystemRoot\System32\cmd.exe" /d /s /c ('""' + $launcher + '""') 2>&1
    $record.launch_exit_code = $LASTEXITCODE; $record.launch_output = $output -join "`n"
    if ($record.launch_exit_code -ne 0) { throw 'Launcher did not submit the native Terminal window request.' }
    $deadline = [DateTime]::UtcNow.AddSeconds(45)
    while (@(Get-ChildItem -LiteralPath $markers -Filter '*.txt').Count -lt $ToolCount -and [DateTime]::UtcNow -lt $deadline) { Start-Sleep -Milliseconds 200 }
    $observed = @()
    foreach ($name in $selected) {
        $path = Join-Path $markers ($name + '.txt')
        $lines = @(Get-Content -LiteralPath $path)
        if ($lines.Count -ne 2 -or $lines[0] -ne ('marker:' + $name) -or $lines[1] -ne $workdir) { throw "Incorrect marker or literal working directory: $name" }
        $observed += @{tool=$name;path=$path;sha256=(Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant();lines=$lines}
    }
    if (@(Get-ChildItem -LiteralPath $markers -Filter '*.txt').Count -ne $ToolCount) { throw 'An unselected marker executed.' }
    $record.markers = $observed
    $record.user_path_unchanged = ([Environment]::GetEnvironmentVariable('PATH','User') -eq $userBefore)
    $record.machine_path_unchanged = ([Environment]::GetEnvironmentVariable('PATH','Machine') -eq $machineBefore)
    if (-not $record.user_path_unchanged -or -not $record.machine_path_unchanged) { throw 'Persistent PATH changed.' }
    $record.machine_checks_passed = $true
    $record.ui_required = 'Inspect ONLY the new window containing this task ID. Record one window, expected pane count/titles, approximately equal columns, literal marker directories, a task-window-only screenshot/hash, and closure of only this test window before another layout case. Do not qualify Gold from markers alone.'
} catch {
    $record.error = $_.Exception.Message
    throw
} finally {
    foreach ($key in $keys) { [Environment]::SetEnvironmentVariable($key,$saved[$key],'Process') }
    $record.finished_utc = [DateTime]::UtcNow.ToString('o')
    $record | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $task 'acceptance.json') -Encoding UTF8
    Write-Host "Acceptance evidence retained in $task. No cleanup or provider operation was performed."
}
