param([string]$Version = "1.1.0")

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

$releaseFiles = @($launcher, $readme, $license, $changelog, $development, $testing)
$releaseFiles += @('CONTRIBUTING.md','CODE_OF_CONDUCT.md','SECURITY.md','SUPPORT.md') | ForEach-Object { Join-Path $projectRoot $_ }
foreach ($required in $releaseFiles) {
    if (-not (Test-Path -LiteralPath $required -PathType Leaf)) { throw "Required release file is missing: $required" }
}

$sourceVersion = [regex]::Match([IO.File]::ReadAllText($launcher), 'AI_TERMINAL_DECK_VERSION=(\d+\.\d+\.\d+)').Groups[1].Value
if ($sourceVersion -ne $Version) { throw "Package version $Version does not match launcher $sourceVersion" }
foreach ($directory in @('docs','tests','scripts')) {
    if (-not (Test-Path -LiteralPath (Join-Path $projectRoot $directory) -PathType Container)) { throw "Missing release guidance directory: $directory" }
}
if (Test-Path -LiteralPath $resolvedOutput) { throw "Output already exists: $resolvedOutput. Preserve or remove your previous generated build explicitly before packaging again." }
New-Item -ItemType Directory -Path $resolvedOutput | Out-Null

$standaloneLauncher = Join-Path $resolvedOutput "Launch-AI-Terminal-Deck.bat"
Copy-Item -LiteralPath $launcher -Destination $standaloneLauncher
$staging = Join-Path $resolvedOutput "ai-terminal-deck-$Version"
New-Item -ItemType Directory -Path $staging | Out-Null
Copy-Item -LiteralPath $releaseFiles -Destination $staging
foreach ($directory in @('docs','tests','scripts')) { Copy-Item -LiteralPath (Join-Path $projectRoot $directory) -Destination $staging -Recurse }

$archive = Join-Path $resolvedOutput "ai-terminal-deck-$Version.zip"
Compress-Archive -Path (Join-Path $staging "*") -DestinationPath $archive -CompressionLevel Optimal
Remove-Item -LiteralPath $staging -Recurse -Force

$hashLines = foreach ($artifact in @($standaloneLauncher, $archive)) {
    $hash = Get-FileHash -LiteralPath $artifact -Algorithm SHA256
    "$($hash.Hash.ToLowerInvariant())  $([System.IO.Path]::GetFileName($artifact))"
}
$hashLines | Set-Content -LiteralPath (Join-Path $resolvedOutput "SHA256SUMS.txt") -Encoding ascii
Get-ChildItem -LiteralPath $resolvedOutput | Select-Object Name, Length
