param([string]$ArtifactDirectory, [switch]$VerifyOnly)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem
$root = Split-Path -Parent $PSScriptRoot
$launcher = Join-Path $root 'Launch-AI-Terminal-Deck.bat'
$version = [regex]::Match([IO.File]::ReadAllText($launcher), 'AI_TERMINAL_DECK_VERSION=(\d+\.\d+\.\d+)').Groups[1].Value
$dist = if ($ArtifactDirectory) { [IO.Path]::GetFullPath($ArtifactDirectory) } else { Join-Path $root 'dist' }
$archive = Join-Path $dist "ai-terminal-deck-$version.zip"
$zip = [IO.Compression.ZipFile]::OpenRead($archive)
try {
    $required = @('Launch-AI-Terminal-Deck.bat','README.md','CHANGELOG.md','DEVELOPMENT.md','TESTING.md','LICENSE')
    foreach ($directory in @('docs','tests','scripts')) {
        $required += Get-ChildItem -LiteralPath (Join-Path $root $directory) -File -Recurse | ForEach-Object { $_.FullName.Substring($root.Length + 1).Replace('\','/') }
    }
    foreach ($relative in $required) {
        $entry = $zip.GetEntry($relative)
        if ($null -eq $entry) { throw "Missing packaged guidance/source: $relative" }
        $stream = $entry.Open(); $memory = New-Object IO.MemoryStream
        try { $stream.CopyTo($memory); $bytes = $memory.ToArray() } finally { $stream.Dispose(); $memory.Dispose() }
        $expected = [IO.File]::ReadAllBytes((Join-Path $root $relative))
        if ([Convert]::ToBase64String($bytes) -ne [Convert]::ToBase64String($expected)) { throw "Packaged bytes differ: $relative" }
    }
} finally { $zip.Dispose() }
if ((Get-FileHash -LiteralPath $launcher).Hash -ne (Get-FileHash -LiteralPath (Join-Path $dist 'Launch-AI-Terminal-Deck.bat')).Hash) { throw 'Standalone launcher differs from source.' }
$before = @{}
foreach ($line in Get-Content -LiteralPath (Join-Path $dist 'SHA256SUMS.txt')) {
    if ($line -notmatch '^([0-9a-f]{64})  ([^/\\]+)$') { throw "Invalid checksum line: $line" }
    $path = Join-Path $dist $Matches[2]
    $hash = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($hash -ne $Matches[1]) { throw "Checksum differs: $path" }
    $before[$path] = $hash
}
if (-not $VerifyOnly) {
foreach ($requestedVersion in @($version,'0.0.0')) {
    $refused = $false
    try { & (Join-Path $root 'scripts/package.ps1') -Version $requestedVersion } catch { $refused = $true }
    if (-not $refused) { throw 'Packaging overwrote an existing output or accepted a mismatched version.' }
}
}
foreach ($path in $before.Keys) {
    if ((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant() -ne $before[$path]) { throw "Refused packaging modified an artifact: $path" }
}
Write-Host "PASS packaged launcher, complete guidance/tests, checksums and refusal safety ($version)"
