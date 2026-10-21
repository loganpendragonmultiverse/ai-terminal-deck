param([Parameter(Mandatory=$true)][string]$SourceDirectory,[Parameter(Mandatory=$true)][string]$EvidenceDirectory)
$ErrorActionPreference='Stop'
$source=[IO.Path]::GetFullPath($SourceDirectory);$evidence=[IO.Path]::GetFullPath($EvidenceDirectory)
if(Test-Path -LiteralPath $evidence){throw 'Evidence directory must be absent'}
New-Item -ItemType Directory -Path $evidence | Out-Null
$runner=Join-Path $source 'tests/Invoke-NativeTerminalAcceptance.ps1'
$test=Join-Path $source 'tests/Test-NativeReceiptSerialization.ps1'
$runnerBytes=[IO.File]::ReadAllBytes($runner);$testBytes=[IO.File]::ReadAllBytes($test)
$runnerBefore=(Get-FileHash -LiteralPath $runner -Algorithm SHA256).Hash
$testBefore=(Get-FileHash -LiteralPath $test -Algorithm SHA256).Hash
$new='        $observed += @{tool=$name;path=$path;sha256=(Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant();lines=@($lines | ForEach-Object { [string]::new($_.ToCharArray()) })}'
$old='        $observed += @{tool=$name;path=$path;sha256=(Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant();lines=$lines}'
$text=[IO.File]::ReadAllText($runner)
if(($text.Split([string[]]@($new),[StringSplitOptions]::None)).Count -ne 2){throw 'Reviewed normalization statement must occur exactly once'}
$mutated=$text.Replace($new,$old)
$fixture=Join-Path ([IO.Path]::GetTempPath()) ('deck-receipt-control-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $fixture | Out-Null
$hostExecutable=[Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
$results=@()
try {
    foreach($variant in @('reviewed','old-expression')) {
        $directory=Join-Path $fixture $variant;New-Item -ItemType Directory -Path $directory | Out-Null
        $copyRunner=Join-Path $directory 'Invoke-NativeTerminalAcceptance.ps1';$copyTest=Join-Path $directory 'Test-NativeReceiptSerialization.ps1'
        if($variant -eq 'reviewed'){[IO.File]::WriteAllBytes($copyRunner,$runnerBytes)}else{[IO.File]::WriteAllText($copyRunner,$mutated,(New-Object Text.UTF8Encoding($false)))}
        [IO.File]::WriteAllBytes($copyTest,$testBytes)
        $psi=New-Object Diagnostics.ProcessStartInfo
        $psi.FileName=$hostExecutable;$psi.Arguments='-NoProfile -NonInteractive -File "'+$copyTest+'"'
        $psi.UseShellExecute=$false;$psi.CreateNoWindow=$true;$psi.RedirectStandardOutput=$true;$psi.RedirectStandardError=$true
        $process=New-Object Diagnostics.Process;$process.StartInfo=$psi;$watch=[Diagnostics.Stopwatch]::StartNew();$timedOut=$false
        try {
            [void]$process.Start();$ownedPid=$process.Id;$ownedStart=$process.StartTime.ToUniversalTime().ToString('o')
            $out=$process.StandardOutput.ReadToEndAsync();$err=$process.StandardError.ReadToEndAsync()
            if(-not $process.WaitForExit(15000)){$timedOut=$true;try{$process.Kill()}catch{if(-not $process.HasExited){throw}};[void]$process.WaitForExit(5000)}
            if(-not $process.HasExited){throw 'Owned negative-control child did not terminate'}
            $exitCode=$process.ExitCode;$stdout=$out.Result;$stderr=$err.Result
        } finally {$watch.Stop();$process.Dispose()}
        [IO.File]::WriteAllText((Join-Path $evidence ($variant+'-stdout.txt')),$stdout,(New-Object Text.UTF8Encoding($false)))
        [IO.File]::WriteAllText((Join-Path $evidence ($variant+'-stderr.txt')),$stderr,(New-Object Text.UTF8Encoding($false)))
        $passed=if($variant -eq 'reviewed'){-not $timedOut -and $exitCode -eq 0 -and $stdout.Contains('PASS production receipt statements')}else{-not $timedOut -and $exitCode -ne 0 -and $stderr.Contains('Receipt retained filesystem metadata:') -and -not $stdout.Contains('PASS production receipt statements')}
        $results+=@{variant=$variant;passed=$passed;timed_out=$timedOut;exit_code=$exitCode;duration_ms=$watch.ElapsedMilliseconds;owned_pid=$ownedPid;owned_start_utc=$ownedStart;runner_sha256=(Get-FileHash -LiteralPath $copyRunner -Algorithm SHA256).Hash.ToLowerInvariant();test_sha256=(Get-FileHash -LiteralPath $copyTest -Algorithm SHA256).Hash.ToLowerInvariant()}
    }
} finally {
    $temp=[IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\')+'\'
    if(-not ([IO.Path]::GetFullPath($fixture).StartsWith($temp,[StringComparison]::OrdinalIgnoreCase))){throw 'Unsafe owned control fixture cleanup'}
    if(Test-Path -LiteralPath $fixture){Remove-Item -LiteralPath $fixture -Recurse -Force}
}
$unchanged=((Get-FileHash -LiteralPath $runner -Algorithm SHA256).Hash -eq $runnerBefore -and (Get-FileHash -LiteralPath $test -Algorithm SHA256).Hash -eq $testBefore)
$record=[ordered]@{schema=1;status='receipt-regression-positive-and-old-expression-negative-control';powershell=$PSVersionTable.PSVersion.ToString();source_runner_sha256=$runnerBefore.ToLowerInvariant();source_test_sha256=$testBefore.ToLowerInvariant();source_bytes_unchanged=$unchanged;results=$results;native_ui_verified=$false;no_Terminal_or_provider_or_network=$true;finished_utc=[DateTime]::UtcNow.ToString('o')}
$record | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $evidence 'negative-control.json') -Encoding UTF8
if(-not $unchanged -or @($results | Where-Object {-not $_.passed}).Count -gt 0){throw 'Receipt positive/negative control failed; inspect retained evidence'}
Write-Host 'PASS actual receipt regression accepts reviewed expression and rejects old retained-metadata expression; no Terminal executed'
