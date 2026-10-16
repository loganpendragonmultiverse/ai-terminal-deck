param([string]$Version = "1.0.5")

$ErrorActionPreference = "Stop"
if ($Version -notmatch '^\d+\.\d+\.\d+$') { throw "Version must be numeric major.minor.patch" }
$projectRoot = Split-Path -Parent $PSScriptRoot
$resolvedOutput = [System.IO.Path]::GetFullPath((Join-Path $projectRoot "dist"))
if (-not ($resolvedOutput.StartsWith(([IO.Path]::GetFullPath($projectRoot).TrimEnd("\") + "\"), [StringComparison]::OrdinalIgnoreCase))) { throw "Unsafe package output path" }
$launcher = Join-Path $projectRoot "Launch-AI-Terminal-Deck.bat"
$readme = Join-Path $projectRoot "README.md"
$license = Join-Path $projectRoot "LICENSE"
$changelog = Join-Path $projectRoot "CHANGELOG.md"
$development = Join-Path $projectRoot "DEVELOPMENT.md"
$testing = Join-Path $projectRoot "TESTING.md"

foreach ($required in @($launcher, $readme, $license, $changelog, $development, $testing)) {
    if (-not (Test-Path -LiteralPath $required -PathType Leaf)) { throw "Required release file is missing: $required" }
}

if (Test-Path -LiteralPath $resolvedOutput) { Remove-Item -LiteralPath $resolvedOutput -Recurse -Force }
New-Item -ItemType Directory -Path $resolvedOutput | Out-Null

$standaloneLauncher = Join-Path $resolvedOutput "Launch-AI-Terminal-Deck.bat"
Copy-Item -LiteralPath $launcher -Destination $standaloneLauncher
$staging = Join-Path $resolvedOutput "ai-terminal-deck-$Version"
New-Item -ItemType Directory -Path $staging | Out-Null
Copy-Item -LiteralPath $launcher, $readme, $license, $changelog, $development, $testing -Destination $staging

$archive = Join-Path $resolvedOutput "ai-terminal-deck-$Version.zip"
Compress-Archive -Path (Join-Path $staging "*") -DestinationPath $archive -CompressionLevel Optimal
Remove-Item -LiteralPath $staging -Recurse -Force

$hashLines = foreach ($artifact in @($standaloneLauncher, $archive)) {
    $hash = Get-FileHash -LiteralPath $artifact -Algorithm SHA256
    "$($hash.Hash.ToLowerInvariant())  $([System.IO.Path]::GetFileName($artifact))"
}
$hashLines | Set-Content -LiteralPath (Join-Path $resolvedOutput "SHA256SUMS.txt") -Encoding ascii
Get-ChildItem -LiteralPath $resolvedOutput | Select-Object Name, Length
