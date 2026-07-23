$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
$launcher = Join-Path $projectRoot "Launch-AI-Terminal-Deck.bat"
$script:passed = 0
$script:failed = 0

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Invoke-Test {
    param([string]$Name, [scriptblock]$Body)
    try {
        & $Body
        Write-Host "PASS $Name"
        $script:passed++
    }
    catch {
        Write-Host "FAIL $Name`: $($_.Exception.Message)" -ForegroundColor Red
        $script:failed++
    }
}

function Invoke-Launcher {
    param(
        [string[]]$Arguments,
        [string]$PathValue,
        [string]$DeckWorkdir,
        [bool]$DryRun = $false
    )

    $savedPath = $env:PATH
    $savedWorkdir = $env:AI_TERMINAL_DECK_WORKDIR
    $savedDryRun = $env:AI_TERMINAL_DECK_DRY_RUN
    try {
        $env:PATH = $PathValue
        $env:AI_TERMINAL_DECK_WORKDIR = $DeckWorkdir
        $env:AI_TERMINAL_DECK_DRY_RUN = if ($DryRun) { "1" } else { $null }
        $output = & "$env:SystemRoot\System32\cmd.exe" /d /c ('"{0}" {1}' -f $launcher, ($Arguments -join " ")) 2>&1
        return [pscustomobject]@{ ExitCode = $LASTEXITCODE; Output = ($output -join "`n") }
    }
    finally {
        $env:PATH = $savedPath
        $env:AI_TERMINAL_DECK_WORKDIR = $savedWorkdir
        $env:AI_TERMINAL_DECK_DRY_RUN = $savedDryRun
    }
}

if (-not (Test-Path -LiteralPath $launcher -PathType Leaf)) { throw "Launcher not found: $launcher" }

$testRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("ai-terminal-deck-tests-" + [guid]::NewGuid().ToString("N"))
$stubBin = Join-Path $testRoot "bin"
$workdir = Join-Path $testRoot "Workspace With Spaces"
New-Item -ItemType Directory -Path $stubBin, $workdir | Out-Null

try {
    foreach ($command in @("wt.exe", "codex.cmd", "claude.cmd", "kimi.cmd")) {
        Set-Content -LiteralPath (Join-Path $stubBin $command) -Value "@exit /b 0" -Encoding ascii
    }
    $controlledPath = "$stubBin;$env:SystemRoot\System32;$env:SystemRoot"

    Invoke-Test "help explains the single launcher" {
        $result = Invoke-Launcher -Arguments @("--help") -PathValue $controlledPath -DeckWorkdir $workdir
        Assert-True ($result.ExitCode -eq 0) "Expected help to exit 0, got $($result.ExitCode)."
        Assert-True ($result.Output -match "three equal Windows Terminal panes") "Help does not explain the layout."
        Assert-True ($result.Output -match "AI_TERMINAL_DECK_WORKDIR") "Help omits the environment override."
    }

    Invoke-Test "readiness check finds all required commands" {
        $result = Invoke-Launcher -Arguments @("--check") -PathValue $controlledPath -DeckWorkdir $workdir
        Assert-True ($result.ExitCode -eq 0) "Expected readiness check to exit 0, got $($result.ExitCode)."
        foreach ($name in @("Windows Terminal", "Codex CLI", "Claude Code", "Kimi Code")) {
            Assert-True ($result.Output -match [regex]::Escape($name)) "Readiness output omits $name."
        }
    }

    Invoke-Test "dry run creates three titled equal-width panes" {
        $quotedWorkdir = '"' + $workdir + '"'
        $result = Invoke-Launcher -Arguments @($quotedWorkdir) -PathValue $controlledPath -DeckWorkdir "" -DryRun $true
        Assert-True ($result.ExitCode -eq 0) "Expected dry run to exit 0, got $($result.ExitCode)."
        Assert-True ($result.Output -match 'new-tab --title "Codex"') "Codex pane is missing."
        Assert-True ($result.Output -match 'split-pane -V -s 0\.666 --title "Claude"') "Claude pane sizing is missing."
        Assert-True ($result.Output -match 'split-pane -V -s 0\.5 --title "Kimi"') "Kimi pane sizing is missing."
        Assert-True ($result.Output -match [regex]::Escape($workdir)) "Working directory with spaces was not preserved."
    }

    Invoke-Test "missing AI command stops before launch" {
        Remove-Item -LiteralPath (Join-Path $stubBin "kimi.cmd")
        $result = Invoke-Launcher -Arguments @("--check") -PathValue $controlledPath -DeckWorkdir $workdir
        Assert-True ($result.ExitCode -eq 3) "Expected missing dependency exit 3, got $($result.ExitCode)."
        Assert-True ($result.Output -match '\[MISSING\] Kimi Code') "Missing Kimi message was not shown."
        Set-Content -LiteralPath (Join-Path $stubBin "kimi.cmd") -Value "@exit /b 0" -Encoding ascii
    }

    Invoke-Test "invalid working directory is rejected" {
        $missingDirectory = Join-Path $testRoot "does-not-exist"
        $quotedMissingDirectory = '"' + $missingDirectory + '"'
        $result = Invoke-Launcher -Arguments @("--check", $quotedMissingDirectory) -PathValue $controlledPath -DeckWorkdir ""
        Assert-True ($result.ExitCode -eq 2) "Expected invalid-directory exit 2, got $($result.ExitCode)."
        Assert-True ($result.Output -match "working directory does not exist") "Invalid-directory explanation is missing."
    }

    Invoke-Test "launcher contains no embedded credentials or network downloads" {
        $content = Get-Content -LiteralPath $launcher -Raw
        Assert-True ($content -notmatch '(?i)(api[_-]?key|token|password)\s*=\s*[^%\s]') "Possible embedded credential assignment found."
        Assert-True ($content -notmatch '(?i)(invoke-webrequest|curl|wget|bitsadmin|certutil)') "Launcher unexpectedly downloads content."
        Assert-True ($content -notmatch '(?i)(remove-item|del\s|erase\s|rmdir\s|rd\s)') "Launcher unexpectedly deletes files."
    }
}
finally {
    if (Test-Path -LiteralPath $testRoot) { Remove-Item -LiteralPath $testRoot -Recurse -Force }
}

Write-Host ""
Write-Host "$script:passed passed, $script:failed failed"
if ($script:failed -gt 0) { exit 1 }
