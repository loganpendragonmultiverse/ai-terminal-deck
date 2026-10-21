$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$launcher = Join-Path $projectRoot 'Launch-AI-Terminal-Deck.bat'
$testRoot = Join-Path ([IO.Path]::GetTempPath()) ('deck-native-binding-' + [guid]::NewGuid().ToString('N'))
$bin = Join-Path $testRoot "Tool Bin With Spaces & (round) O'Neil !"
$workdir = Join-Path $testRoot "Workspace & (round) O'Neil !; %DECK_NOT_AN_ENVIRONMENT_VARIABLE%"
$capture = Join-Path $testRoot 'terminal-capture.log'
$markerDir = Join-Path $testRoot 'markers'
$keys = @('PATH','PATHEXT','AI_TERMINAL_DECK_WORKDIR','AI_TERMINAL_DECK_SKIP_KNOWN_PATHS','AI_TERMINAL_DECK_SKIP_INSTALL_PROMPTS','AI_TERMINAL_DECK_NO_PAUSE','AI_TERMINAL_DECK_DRY_RUN','AI_TERMINAL_DECK_INSTALL_DRY_RUN','AI_TERMINAL_DECK_TEST_CAPTURE','AI_TERMINAL_DECK_TEST_MARKERS')
$saved = @{}
foreach ($key in $keys) { $saved[$key] = [Environment]::GetEnvironmentVariable($key, 'Process') }
$userPathBefore = [Environment]::GetEnvironmentVariable('PATH', 'User')
$machinePathBefore = [Environment]::GetEnvironmentVariable('PATH', 'Machine')
function Require([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
try {
    New-Item -ItemType Directory -Path $bin,$workdir,$markerDir | Out-Null
    $compiler = Join-Path $env:SystemRoot 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
    if (-not (Test-Path -LiteralPath $compiler -PathType Leaf)) { throw 'The Windows .NET Framework C# compiler is required for native binding fixtures.' }
    & $compiler /nologo /target:exe ('/out:' + (Join-Path $bin 'wt.exe')) (Join-Path $PSScriptRoot 'TerminalCapture.cs')
    if ($LASTEXITCODE -ne 0) { throw 'Cannot compile the inert capture fixture.' }
    foreach ($name in @('codex','claude','kimi')) {
        $body = '@echo marker:' + $name + '> "%AI_TERMINAL_DECK_TEST_MARKERS%\' + $name + '.txt"' + "`r`n" + '@cd >> "%AI_TERMINAL_DECK_TEST_MARKERS%\' + $name + '.txt"' + "`r`n@exit /b 0`r`n"
        [IO.File]::WriteAllText((Join-Path $bin ($name + '.cmd')), $body)
    }
    [IO.File]::WriteAllText((Join-Path $workdir 'codex.cmd'), '@echo incorrect-current-directory-command> "%AI_TERMINAL_DECK_TEST_MARKERS%\WRONG.txt"' + "`r`n")
    $env:PATH = "$bin;$env:SystemRoot\System32;$env:SystemRoot"
    $env:PATHEXT = '.EXE;.CMD;.BAT'
    $env:AI_TERMINAL_DECK_WORKDIR = $workdir
    $env:AI_TERMINAL_DECK_SKIP_KNOWN_PATHS = '1'
    $env:AI_TERMINAL_DECK_SKIP_INSTALL_PROMPTS = $null
    $env:AI_TERMINAL_DECK_NO_PAUSE = '1'
    $env:AI_TERMINAL_DECK_DRY_RUN = $null
    $env:AI_TERMINAL_DECK_INSTALL_DRY_RUN = $null
    $env:AI_TERMINAL_DECK_TEST_CAPTURE = $capture
    $env:AI_TERMINAL_DECK_TEST_MARKERS = $markerDir
    Push-Location -LiteralPath $workdir
    try {
        $line = '""' + $launcher + '" --preview"'
        $preview = & "$env:SystemRoot\System32\cmd.exe" /d /s /c $line 2>&1
        Require ($LASTEXITCODE -eq 0) "Preview failed: $preview"
        Require (-not (Test-Path -LiteralPath $capture)) 'Preview invoked a terminal.'
        Require (@(Get-ChildItem -LiteralPath $markerDir).Count -eq 0) 'Preview invoked a tool.'
        Require (($preview -join "`n") -notmatch 'Install .*now|Press any key') 'Preview prompted.'
        foreach ($name in @('codex','claude','kimi')) {
            Require (($preview -join "`n").Contains((Join-Path $bin ($name + '.cmd')))) "Preview did not disclose the exact $name command."
        }
        Move-Item -LiteralPath (Join-Path $bin 'kimi.cmd') -Destination (Join-Path $bin 'kimi.held')
        $partial = & "$env:SystemRoot\System32\cmd.exe" /d /s /c ('""' + $launcher + '" --preview"') 2>&1
        Require ($LASTEXITCODE -eq 0) "A two-tool public preview failed: $partial"
        Require (($partial -join "`n") -notmatch 'Install .*now|Press any key|Opening .*pane') 'A partial preview prompted or claimed a launch.'
        Require (-not (Test-Path -LiteralPath $capture)) 'A partial preview invoked a terminal.'
        Move-Item -LiteralPath (Join-Path $bin 'kimi.held') -Destination (Join-Path $bin 'kimi.cmd')
        # A batch invoker avoids a second PowerShell/native-string quoting layer;
        # cmd expands the directory environment value once as a quoted argument.
        $argumentInvoker = Join-Path $testRoot 'arguments.bat'
        [IO.File]::WriteAllText($argumentInvoker, '@echo off' + "`r`n" + '"' + $launcher + '" --preview "%AI_TERMINAL_DECK_WORKDIR%"' + "`r`n")
        $explicit = & "$env:SystemRoot\System32\cmd.exe" /d /s /c ('""' + $argumentInvoker + '""') 2>&1
        Require ($LASTEXITCODE -eq 0) "Literal explicit directory argument failed: $explicit"
        [IO.File]::WriteAllText($argumentInvoker, '@echo off' + "`r`n" + '"' + $launcher + '" --preview "%AI_TERMINAL_DECK_WORKDIR%" extra' + "`r`n")
        $extra = & "$env:SystemRoot\System32\cmd.exe" /d /s /c ('""' + $argumentInvoker + '""') 2>&1
        Require ($LASTEXITCODE -eq 2) "Extra arguments were not rejected: $extra"
        $line = '""' + $launcher + '""'
        $result = & "$env:SystemRoot\System32\cmd.exe" /d /s /c $line 2>&1
        Require ($LASTEXITCODE -eq 0) "Native command-binding launch failed: $result"
        $deadline = [DateTime]::UtcNow.AddSeconds(30)
        while (-not (Test-Path -LiteralPath $capture) -and [DateTime]::UtcNow -lt $deadline) { Start-Sleep -Milliseconds 200 }
        Require (Test-Path -LiteralPath $capture) 'The capture executable did not finish.'
        $record = Get-Content -LiteralPath $capture
        Require ($record -contains 'PANES:3') 'Three pane commands were not delivered.'
        Require (@($record | Where-Object { $_ -like 'EXIT:*' -and $_ -ne 'EXIT:0' }).Count -eq 0) "A real PowerShell pane command failed: $record"
        foreach ($name in @('codex','claude','kimi')) {
            $lines = Get-Content -LiteralPath (Join-Path $markerDir ($name + '.txt'))
            Require ($lines[0] -eq ('marker:' + $name)) "Wrong $name command executed."
            Require ($lines[1] -eq $workdir) "The $name pane received the wrong literal working directory: $($lines[1])"
        }
        Require (-not (Test-Path -LiteralPath (Join-Path $markerDir 'WRONG.txt'))) 'A current-directory command shadowed PATH discovery.'
        Write-Host 'PASS native cmd/Windows PowerShell binding: exact commands, literal paths, three panes; terminal itself remains a fixture'
    } finally { Pop-Location }
    Require ([Environment]::GetEnvironmentVariable('PATH','User') -eq $userPathBefore) 'User PATH was changed.'
    Require ([Environment]::GetEnvironmentVariable('PATH','Machine') -eq $machinePathBefore) 'Machine PATH was changed.'
} finally {
    foreach ($key in $keys) { [Environment]::SetEnvironmentVariable($key,$saved[$key],'Process') }
    $temp = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\') + '\'
    if (-not ([IO.Path]::GetFullPath($testRoot).StartsWith($temp,[StringComparison]::OrdinalIgnoreCase))) { throw 'Unsafe fixture cleanup path.' }
    if (Test-Path -LiteralPath $testRoot) { Remove-Item -LiteralPath $testRoot -Recurse -Force }
}
