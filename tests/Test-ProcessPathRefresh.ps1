$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$task = Join-Path ([IO.Path]::GetTempPath()) ('deck-path-refresh-' + [guid]::NewGuid().ToString('N'))
$markerBin = Join-Path $task 'Process-only tools & (quoted)'
$harness = Join-Path $task 'refresh.bat'
$capture = Join-Path $task 'process-path.txt'
$savedPath = $env:PATH
$savedCapture = $env:DECK_PATH_CAPTURE
$userBefore = [Environment]::GetEnvironmentVariable('PATH','User')
$machineBefore = [Environment]::GetEnvironmentVariable('PATH','Machine')
try {
    New-Item -ItemType Directory -Path $markerBin | Out-Null
    $source = [IO.File]::ReadAllText((Join-Path $root 'Launch-AI-Terminal-Deck.bat'))
    # Exercise the actual read-only refresh subroutine with real Windows
    # PowerShell, bypassing installer branches only in this disposable harness.
    $text = '@setlocal EnableExtensions DisableDelayedExpansion' + "`r`n@goto :acceptance_refresh`r`n" + $source + "`r`n:acceptance_refresh`r`ncall :refresh_path`r`n" + 'powershell.exe -NoProfile -Command "[IO.File]::WriteAllText($env:DECK_PATH_CAPTURE,$env:PATH)"' + "`r`nexit /b %errorlevel%`r`n"
    [IO.File]::WriteAllText($harness,$text)
    $controlled = '"' + $markerBin + '";' + "$env:SystemRoot\System32;$env:SystemRoot\System32\WindowsPowerShell\v1.0;$env:SystemRoot"
    $env:PATH = $controlled
    $env:DECK_PATH_CAPTURE = $capture
    $output = & "$env:SystemRoot\System32\cmd.exe" /d /s /c ('""' + $harness + '""') 2>&1
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $capture)) { throw "Native process PATH refresh failed: $output" }
    $value = [IO.File]::ReadAllText($capture)
    if (-not $value.StartsWith($controlled + ';',[StringComparison]::Ordinal)) { throw 'Refresh discarded process-only PATH entries or their ordering.' }
    if ($env:PATH -ne $controlled) { throw 'The child PATH change escaped to its parent.' }
    if ([Environment]::GetEnvironmentVariable('PATH','User') -ne $userBefore -or [Environment]::GetEnvironmentVariable('PATH','Machine') -ne $machineBefore) { throw 'Refresh changed persistent PATH.' }
    Write-Host 'PASS actual Windows PowerShell refresh retains quoted process PATH and never persists environment changes'
} finally {
    $env:PATH = $savedPath
    $env:DECK_PATH_CAPTURE = $savedCapture
    $temp = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\') + '\'
    if (-not ([IO.Path]::GetFullPath($task).StartsWith($temp,[StringComparison]::OrdinalIgnoreCase))) { throw 'Unsafe fixture cleanup path.' }
    if (Test-Path -LiteralPath $task) { Remove-Item -LiteralPath $task -Recurse -Force }
}
