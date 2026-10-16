$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
$launcher = Join-Path $projectRoot "Launch-AI-Terminal-Deck.bat"
$testRoot = Join-Path ([IO.Path]::GetTempPath()) ("deck-readonly-" + [guid]::NewGuid().ToString("N"))
$fixtureProfile = Join-Path $testRoot "Fake Profile"
$fixtureLocal = Join-Path $testRoot "Fake Local"
$stubBin = Join-Path $testRoot "bin"
$log = Join-Path $testRoot "operations.log"
$instrumented = Join-Path $testRoot "launcher.bat"
$saved = @{}
foreach ($key in @("PATH", "USERPROFILE", "LOCALAPPDATA", "AI_TERMINAL_DECK_WORKDIR", "AI_TERMINAL_DECK_NO_PAUSE", "AI_TERMINAL_DECK_SKIP_KNOWN_PATHS")) {
    $saved[$key] = [Environment]::GetEnvironmentVariable($key, "Process")
}
try {
    $claudeBin = Join-Path $fixtureProfile ".local\bin"
    $kimiBin = Join-Path $fixtureProfile ".kimi-code\bin"
    $codexBin = Join-Path $fixtureLocal "Programs\OpenAI\Codex\bin"
    New-Item -ItemType Directory -Path $stubBin, $claudeBin, $kimiBin, $codexBin | Out-Null
    # Never execute provider, installer or environment commands. Intercept every
    # PowerShell invocation in a temporary launcher copy and record it instead.
    $content = [IO.File]::ReadAllText($launcher).Replace("powershell.exe", "call powershell-stub.cmd")
    [IO.File]::WriteAllText($instrumented, $content)
    foreach ($file in @((Join-Path $stubBin "wt.exe"), (Join-Path $claudeBin "claude.exe"), (Join-Path $kimiBin "kimi.exe"), (Join-Path $codexBin "codex.exe"))) {
        [IO.File]::WriteAllText($file, "synthetic detection-only fixture")
    }
    [IO.File]::WriteAllText((Join-Path $stubBin "powershell-stub.cmd"), "@echo intercepted>>""$log""`r`n@exit /b 0`r`n")
    $env:USERPROFILE = $fixtureProfile
    $env:LOCALAPPDATA = $fixtureLocal
    $env:AI_TERMINAL_DECK_WORKDIR = $testRoot
    $env:AI_TERMINAL_DECK_NO_PAUSE = "1"
    $env:AI_TERMINAL_DECK_SKIP_KNOWN_PATHS = $null
    $env:PATH = "$stubBin;$env:SystemRoot\System32;$env:SystemRoot"
    $beforePath = $env:PATH
    $command = '""' + $instrumented + '" --check"'
    $result = & "$env:SystemRoot\System32\cmd.exe" /d /s /c $command 2>&1
    if ($LASTEXITCODE -ne 0) { throw "Known official paths were not detected: $result" }
    if (Test-Path -LiteralPath $log) { throw "Readiness invoked a PowerShell environment/installer/launch operation" }
    if ($env:PATH -ne $beforePath) { throw "Process PATH escaped the launcher" }
    if (($result -join "`n") -match "Install .*now|Press any key|Opening .*pane") { throw "Readiness prompted or launched" }
    Remove-Item -LiteralPath (Join-Path $kimiBin "kimi.exe")
    $result = & "$env:SystemRoot\System32\cmd.exe" /d /s /c $command 2>&1
    if ($LASTEXITCODE -ne 3) { throw "Missing tool must return 3" }
    if (Test-Path -LiteralPath $log) { throw "Missing-tool readiness invoked a side effect" }
    if (($result -join "`n") -match "Install .*now|Press any key|Opening .*pane") { throw "Missing-tool readiness prompted or launched" }
    Write-Host "PASS official-path discovery and missing-tool checks are read-only"
}
finally {
    foreach ($key in $saved.Keys) { [Environment]::SetEnvironmentVariable($key, $saved[$key], "Process") }
    # The generated absolute path is a child of the Windows temp directory.
    $temp = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd("\") + "\"
    if (-not ([IO.Path]::GetFullPath($testRoot).StartsWith($temp, [StringComparison]::OrdinalIgnoreCase))) { throw "Unsafe cleanup path" }
    if (Test-Path -LiteralPath $testRoot) { Remove-Item -LiteralPath $testRoot -Recurse -Force }
}
