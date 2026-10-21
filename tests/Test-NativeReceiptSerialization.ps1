$ErrorActionPreference='Stop'
$runner=Join-Path $PSScriptRoot 'Invoke-NativeTerminalAcceptance.ps1'
$tokens=$null;$parseErrors=$null
$ast=[Management.Automation.Language.Parser]::ParseFile($runner,[ref]$tokens,[ref]$parseErrors)
if($parseErrors.Count -gt 0){throw 'Native acceptance runner cannot parse'}
# Execute the actual production retention/serialization statements, not a copied normalizer.
$retention=@($ast.FindAll({param($node) $node -is [Management.Automation.Language.AssignmentStatementAst] -and $node.Left.Extent.Text -eq '$observed' -and $node.Operator -eq [Management.Automation.Language.TokenKind]::PlusEquals},$true))
$serialization=@($ast.FindAll({param($node) $node -is [Management.Automation.Language.PipelineAst] -and $node.Extent.Text -match '^\$record\s+\|\s+ConvertTo-Json\s'},$true))
if($retention.Count -ne 1 -or $serialization.Count -ne 1){throw 'Review the receipt regression boundary after a runner refactor'}
$retain=[scriptblock]::Create($retention[0].Extent.Text)
$serialize=[scriptblock]::Create($serialization[0].Extent.Text)
$root=Join-Path ([IO.Path]::GetTempPath()) ('deck-receipt-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $root | Out-Null
try {
    $workdir=Join-Path $root "Workspace & (round) O'Neil !; %DECK_LITERAL%"
    $task=Join-Path $root 'synthetic-receipt'
    New-Item -ItemType Directory -Path $workdir,$task | Out-Null
    $name='codex';$path=Join-Path $root 'codex.txt'
    [IO.File]::WriteAllLines($path,[string[]]@('marker:codex',$workdir))
    $lines=@(Get-Content -LiteralPath $path)
    if($lines.Count -ne 2 -or $lines[0] -ne 'marker:codex' -or $lines[1] -ne $workdir){throw 'Synthetic marker read changed'}
    $extensions=@('PSPath','PSParentPath','PSChildName','PSDrive','PSProvider','ReadCount')
    if($PSVersionTable.PSVersion.Major -eq 5 -and $null -eq $lines[0].PSObject.Properties['PSPath']){throw 'Windows PowerShell fixture did not supply Get-Content metadata'}
    $observed=@()
    . $retain
    if($observed.Count -ne 1 -or $observed[0].lines.Count -ne 2){throw 'Retained marker shape changed'}
    foreach($line in $observed[0].lines) {
        if($line -isnot [string]){throw 'Receipt marker line is not a string'}
        foreach($extension in $extensions){if($null -ne $line.PSObject.Properties[$extension]){throw ('Receipt retained filesystem metadata: '+$extension)}}
    }
    if($observed[0].lines[0] -ne 'marker:codex' -or $observed[0].lines[1] -ne $workdir){throw 'Normalization changed literal marker values'}
    $primary='SYNTHETIC-PRIMARY-MARKER-ERROR'
    $record=[ordered]@{markers=$observed;error=$primary;machine_checks_passed=$false;native_ui_verified=$false;qualification='serialization-regression-only-no-Terminal'}
    . $serialize
    $decoded=[IO.File]::ReadAllText((Join-Path $task 'acceptance.json')) | ConvertFrom-Json
    if($decoded.error -ne $primary -or $decoded.machine_checks_passed -ne $false -or $decoded.native_ui_verified -ne $false){throw 'Receipt serialization lost the primary error or changed qualification'}
    if(@($decoded.markers).Count -ne 1 -or @($decoded.markers[0].lines).Count -ne 2){throw 'Serialized marker shape changed'}
    if($decoded.markers[0].lines[0] -isnot [string] -or $decoded.markers[0].lines[1] -isnot [string] -or $decoded.markers[0].lines[0] -ne 'marker:codex' -or $decoded.markers[0].lines[1] -ne $workdir){throw 'JSON marker lines must be primitive strings with exact literal values'}
    Write-Host 'PASS production receipt statements preserve plain marker strings and the primary error; no Terminal/provider executed'
} finally {
    $temp=[IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\')+'\'
    if(-not ([IO.Path]::GetFullPath($root).StartsWith($temp,[StringComparison]::OrdinalIgnoreCase))){throw 'Unsafe receipt fixture cleanup'}
    if(Test-Path -LiteralPath $root){Remove-Item -LiteralPath $root -Recurse -Force}
}
