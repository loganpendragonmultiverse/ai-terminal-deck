param(
    [Parameter(Mandatory=$true)][string]$EvidenceDirectory,
    [string]$FixtureDirectory,
    [switch]$Child,
    [ValidateSet('raw','normalized')][string]$Variant='raw',
    [ValidateSet('success','invalid-marker','post-marker-error')][string]$Scenario='success',
    [ValidateSet(1,3)][int]$ToolCount=1
)
$ErrorActionPreference='Stop'
function Plain([string]$Text) { return [string]::new($Text.ToCharArray()) }
function Hash-Text([string]$Text) {
    $sha=[Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($Text)))).Replace('-','').ToLowerInvariant() } finally { $sha.Dispose() }
}
function Write-Plain([string]$Path,[string]$Text) { [IO.File]::WriteAllText($Path,$Text,(New-Object Text.UTF8Encoding($false))) }
if ([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT) { throw 'Windows-only inert serialization diagnostic' }
$evidence=[IO.Path]::GetFullPath($EvidenceDirectory)
if (Test-Path -LiteralPath $evidence) { throw 'Evidence directory must be absent' }
New-Item -ItemType Directory -Path $evidence | Out-Null

if ($Child) {
    # Schema-equivalent synthetic receipt, never an actual native acceptance record.
    # Both variants read the SAME files/values; only retained string metadata differs.
    if(-not $FixtureDirectory){throw 'A shared synthetic fixture directory is required'}
    $fixture=[IO.Path]::GetFullPath($FixtureDirectory)
    $workdir=Join-Path $fixture "Workspace & (round) O'Neil !; %DECK_LITERAL%"
    $markers=Join-Path $fixture 'markers'
    $selected=@(@('codex','claude','kimi')[0..($ToolCount-1)])
    $userBefore=[Environment]::GetEnvironmentVariable('PATH','User')
    $machineBefore=[Environment]::GetEnvironmentVariable('PATH','Machine')
    $record=[ordered]@{
        user_path_before_sha256=(Hash-Text $userBefore);machine_path_before_sha256=(Hash-Text $machineBefore)
        runner_version='1.0.0';runner_sha256=(Get-FileHash -LiteralPath $PSCommandPath -Algorithm SHA256).Hash.ToLowerInvariant()
        launcher_sha256=('0'*64);started_utc='2026-10-21T00:00:00.0000000Z';os=[Environment]::OSVersion.VersionString
        powershell=$PSVersionTable.PSVersion.ToString();terminal_path=(Join-Path $fixture 'not-executed/wt.exe')
        terminal_version='synthetic-not-executed';task_directory=$fixture;expected_tools=$selected;working_directory=$workdir
        real_terminal_requested=$false;machine_checks_passed=$false;native_ui_verified=$false
        qualification='serialization-fixture-not-native-acceptance'
    }
    $record.preview_exit_code=0;$record.preview='synthetic preview '+$workdir
    $record.check_exit_code=if($ToolCount -eq 3){0}else{3};$record.readiness='synthetic readiness'
    $record.launch_exit_code=0;$record.launch_output='synthetic launch output; nothing was launched'
    $primary=$null;$serializationFailure=$null;$metadataFailure=$null;$recordWriteFailure=$null;$secondaryEvidenceErrors=@();$rawMetadata=@();$retainedMetadata=@()
    try {
        $observed=@()
        foreach($name in $selected) {
            $path=Join-Path $markers ($name+'.txt')
            $lines=@(Get-Content -LiteralPath $path)
            # Preserve the production read and exact assertion before normalization.
            if($lines.Count -ne 2 -or $lines[0] -ne ('marker:'+$name) -or $lines[1] -ne $workdir){throw "Incorrect marker or literal working directory: $name"}
            $retained=if($Variant -eq 'normalized'){@($lines | ForEach-Object {[string]::new($_.ToCharArray())})}else{$lines}
            foreach($line in $lines) {$rawMetadata+=@($line.PSObject.Properties | Where-Object {$_.Name -in @('PSPath','PSParentPath','PSChildName','PSDrive','PSProvider','ReadCount')} | ForEach-Object {Plain $_.Name})}
            foreach($line in $retained) {$retainedMetadata+=@($line.PSObject.Properties | Where-Object {$_.Name -in @('PSPath','PSParentPath','PSChildName','PSDrive','PSProvider','ReadCount')} | ForEach-Object {Plain $_.Name})}
            $observed+=@{tool=$name;path=$path;sha256=(Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant();lines=$retained}
        }
        if(@(Get-ChildItem -LiteralPath $markers -Filter '*.txt').Count -ne $ToolCount){throw 'An unselected marker executed.'}
        $record.markers=$observed
        if($Scenario -eq 'post-marker-error'){throw 'SERIALIZATION-DIAGNOSTIC-PRIMARY-SENTINEL'}
        $record.user_path_after_sha256=Hash-Text ([string][Environment]::GetEnvironmentVariable('PATH','User'))
        $record.machine_path_after_sha256=Hash-Text ([string][Environment]::GetEnvironmentVariable('PATH','Machine'))
        $record.user_path_unchanged=([Environment]::GetEnvironmentVariable('PATH','User') -eq $userBefore)
        $record.machine_path_unchanged=([Environment]::GetEnvironmentVariable('PATH','Machine') -eq $machineBefore)
        if(-not $record.user_path_unchanged -or -not $record.machine_path_unchanged){throw 'Persistent PATH changed.'}
        $record.machine_checks_passed=$true
        $record.ui_required='Inspect ONLY the new window containing this task ID. Record one window, expected pane count/titles, approximately equal columns, literal marker directories, a task-window-only screenshot/hash, and closure of only this test window before another layout case. Do not qualify Gold from markers alone.'
    } catch {
        $primary=$_
        $record.error=Plain $_.Exception.Message
        # Preserve the primary before the potentially failing finally serializer.
        try {Write-Plain (Join-Path $evidence 'primary-error.txt') $record.error} catch {$secondaryEvidenceErrors+=Plain $_.Exception.Message}
    } finally {
        $record.finished_utc='2026-10-21T00:00:00.0000000Z'
        $metadata=[ordered]@{variant=$Variant;scenario=$Scenario;tool_count=$ToolCount;raw_extended_names=$rawMetadata;retained_extended_names=$retainedMetadata;primary_error=if($primary){Plain $primary.Exception.Message}else{$null};diagnostic_only=$true;no_terminal_execution=$true}
        try {
            Write-Plain (Join-Path $evidence 'metadata.json') ($metadata | ConvertTo-Json -Depth 5)
            $control=[ordered]@{}
            foreach($key in $record.Keys) {
                if($key -eq 'markers') {
                    $control[$key]=@($record[$key] | ForEach-Object {[ordered]@{tool=$_.tool;path=$_.path;sha256=$_.sha256;lines=@($_.lines | ForEach-Object {[string]::new($_.ToCharArray())})}})
                } else {$control[$key]=$record[$key]}
            }
            Write-Plain (Join-Path $evidence 'plain-control.json') ($control | ConvertTo-Json -Depth 10)
        } catch {
            $metadataFailure=$_
            try {Write-Plain (Join-Path $evidence 'metadata-error.txt') (Plain $_.Exception.Message)} catch {$secondaryEvidenceErrors+=Plain $_.Exception.Message}
        }
        # Metadata/control reporting cannot prevent this actual serializer probe.
        try {$json=$record | ConvertTo-Json -Depth 10} catch {
            $serializationFailure=$_
            try {Write-Plain (Join-Path $evidence 'serialization-error.txt') (Plain $_.Exception.Message)} catch {$secondaryEvidenceErrors+=Plain $_.Exception.Message}
        }
        if(-not $serializationFailure) {
            try {Write-Plain (Join-Path $evidence 'record.json') $json} catch {
                $recordWriteFailure=$_
                try {Write-Plain (Join-Path $evidence 'record-write-error.txt') (Plain $_.Exception.Message)} catch {$secondaryEvidenceErrors+=Plain $_.Exception.Message}
            }
        }
    }
    # Preserve the primary error if final serialization also failed.
    if($primary){throw $primary}
    if($serializationFailure){throw $serializationFailure}
    if($metadataFailure){throw $metadataFailure}
    if($recordWriteFailure){throw $recordWriteFailure}
    if($secondaryEvidenceErrors.Count -gt 0){throw ($secondaryEvidenceErrors -join '; ')}
    exit 0
}

$hostExecutable=[Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
$beforeUser=Hash-Text ([string][Environment]::GetEnvironmentVariable('PATH','User'))
$beforeMachine=Hash-Text ([string][Environment]::GetEnvironmentVariable('PATH','Machine'))
$results=@();$normalizedPassed=$true
$cases=@(@{scenario='success';count=1},@{scenario='success';count=3},@{scenario='invalid-marker';count=1},@{scenario='post-marker-error';count=1})
foreach($case in $cases) {
    $fixture=Join-Path $evidence ('fixture-'+$case.scenario+'-'+$case.count)
    $workdir=Join-Path $fixture "Workspace & (round) O'Neil !; %DECK_LITERAL%"
    $markers=Join-Path $fixture 'markers'
    New-Item -ItemType Directory -Path $workdir,$markers | Out-Null
    foreach($name in @(@('codex','claude','kimi')[0..($case.count-1)])) {
        $first=if($case.scenario -eq 'invalid-marker' -and $name -eq 'codex'){'incorrect-marker'}else{'marker:'+$name}
        [IO.File]::WriteAllLines((Join-Path $markers ($name+'.txt')),[string[]]@($first,$workdir))
    }
}
foreach($variantName in @('raw','normalized')) { foreach($case in $cases) {
    $caseDirectory=Join-Path $evidence ($variantName+'-'+$case.scenario+'-'+$case.count)
    $psi=New-Object Diagnostics.ProcessStartInfo
    $psi.FileName=$hostExecutable
    $fixture=Join-Path $evidence ('fixture-'+$case.scenario+'-'+$case.count)
    $psi.Arguments='-NoProfile -NonInteractive -File "'+$PSCommandPath+'" -EvidenceDirectory "'+$caseDirectory+'" -FixtureDirectory "'+$fixture+'" -Child -Variant '+$variantName+' -Scenario '+$case.scenario+' -ToolCount '+$case.count
    $psi.UseShellExecute=$false;$psi.CreateNoWindow=$true;$psi.RedirectStandardOutput=$true;$psi.RedirectStandardError=$true
    $process=New-Object Diagnostics.Process;$process.StartInfo=$psi
    $watch=[Diagnostics.Stopwatch]::StartNew();$timedOut=$false
    try {
        [void]$process.Start();$ownedPid=$process.Id;$ownedStart=$process.StartTime.ToUniversalTime().ToString('o')
        $stdout=$process.StandardOutput.ReadToEndAsync();$stderr=$process.StandardError.ReadToEndAsync()
        if(-not $process.WaitForExit(30000)) {
            $timedOut=$true
            # Only this Process reference's newly started diagnostic child; no tree/UI kill.
            try {$process.Kill()} catch {if(-not $process.HasExited){throw}}
            [void]$process.WaitForExit(5000)
        }
        if(-not $process.HasExited){throw 'Owned diagnostic child did not terminate'}
        $exitCode=$process.ExitCode
        Write-Plain ($caseDirectory+'-stdout.txt') $stdout.Result
        Write-Plain ($caseDirectory+'-stderr.txt') $stderr.Result
    } finally {$watch.Stop();$process.Dispose()}
    $expectedError=if($case.scenario -eq 'invalid-marker'){'Incorrect marker or literal working directory: codex'}elseif($case.scenario -eq 'post-marker-error'){'SERIALIZATION-DIAGNOSTIC-PRIMARY-SENTINEL'}else{$null}
    $primarySurfaced=if($expectedError){$stderr.Result.Contains($expectedError)}else{$true}
    $recordPath=Join-Path $caseDirectory 'record.json';$recordOK=$false;$roundTripOK=$false;$receiptError=$null
    if(Test-Path -LiteralPath $recordPath) {
        try {
            $parsed=[IO.File]::ReadAllText($recordPath) | ConvertFrom-Json
            $recordOK=($parsed.native_ui_verified -eq $false -and $parsed.real_terminal_requested -eq $false -and $parsed.machine_checks_passed -eq ($case.scenario -eq 'success') -and $parsed.error -eq $expectedError)
            $roundTripOK=$true
            if($case.scenario -ne 'invalid-marker') {
                if(@($parsed.markers).Count -ne $case.count){$roundTripOK=$false}
                foreach($marker in $parsed.markers){if(@($marker.lines).Count -ne 2 -or $marker.lines[0] -isnot [string] -or $marker.lines[1] -isnot [string] -or $marker.lines[0] -ne ('marker:'+$marker.tool) -or $marker.lines[1] -ne $parsed.working_directory){$roundTripOK=$false}}
            }
        } catch {$receiptError=Plain $_.Exception.Message}
    }
    $primaryPath=Join-Path $caseDirectory 'primary-error.txt';$primaryText=if(Test-Path -LiteralPath $primaryPath){[IO.File]::ReadAllText($primaryPath)}else{$null}
    $serializationPath=Join-Path $caseDirectory 'serialization-error.txt';$serializationText=if(Test-Path -LiteralPath $serializationPath){[IO.File]::ReadAllText($serializationPath)}else{$null}
    $metadataPath=Join-Path $caseDirectory 'metadata-error.txt';$metadataText=if(Test-Path -LiteralPath $metadataPath){[IO.File]::ReadAllText($metadataPath)}else{$null}
    $writePath=Join-Path $caseDirectory 'record-write-error.txt';$writeText=if(Test-Path -LiteralPath $writePath){[IO.File]::ReadAllText($writePath)}else{$null}
    $controlPath=Join-Path $caseDirectory 'plain-control.json';$controlHash=if(Test-Path -LiteralPath $controlPath){(Get-FileHash -LiteralPath $controlPath -Algorithm SHA256).Hash.ToLowerInvariant()}else{$null}
    $expectedExit=if($case.scenario -eq 'success'){$exitCode -eq 0}else{$exitCode -ne 0}
    $ok=(-not $timedOut -and $expectedExit -and $recordOK -and $roundTripOK -and $primarySurfaced -and $primaryText -eq $expectedError -and -not $serializationText -and -not $metadataText -and -not $writeText -and $controlHash)
    if($variantName -eq 'normalized' -and -not $ok){$normalizedPassed=$false}
    $results+=@{variant=$variantName;scenario=$case.scenario;tool_count=$case.count;owned_pid=$ownedPid;owned_start_utc=$ownedStart;duration_ms=$watch.ElapsedMilliseconds;timed_out=$timedOut;exit_code=$exitCode;expected_exit_observed=$expectedExit;record_schema_ok=$recordOK;plain_string_roundtrip_ok=$roundTripOK;primary_error_surfaced=$primarySurfaced;primary_error=$primaryText;serialization_error=$serializationText;metadata_error=$metadataText;record_write_error=$writeText;record_read_error=$receiptError;plain_control_sha256=$controlHash;case_passed=[bool]$ok}
} }
$controls=@()
foreach($case in $cases) {
    $pair=@($results | Where-Object {$_.scenario -eq $case.scenario -and $_.tool_count -eq $case.count})
    $equal=($pair.Count -eq 2 -and $pair[0].plain_control_sha256 -and $pair[0].plain_control_sha256 -eq $pair[1].plain_control_sha256)
    $controls+=@{scenario=$case.scenario;tool_count=$case.count;same_plain_record_values=[bool]$equal}
    if(-not $equal){$normalizedPassed=$false}
}
$afterUser=Hash-Text ([string][Environment]::GetEnvironmentVariable('PATH','User'))
$afterMachine=Hash-Text ([string][Environment]::GetEnvironmentVariable('PATH','Machine'))
$summary=[ordered]@{schema=1;status='inert-serialization-diagnostic-not-native-acceptance';record_kind='schema-equivalent synthetic record; actual failed receipt unavailable';metadata_hypothesis='unproven; review paired controls and actual failures';powershell=$PSVersionTable.PSVersion.ToString();host_executable=$hostExecutable;script_sha256=(Get-FileHash -LiteralPath $PSCommandPath -Algorithm SHA256).Hash.ToLowerInvariant();results=$results;paired_plain_controls=$controls;normalized_cases_passed=$normalizedPassed;raw_case_nonpass_observed=(@($results | Where-Object {$_.variant -eq 'raw' -and -not $_.case_passed}).Count -gt 0);raw_serializer_failure_observed=(@($results | Where-Object {$_.variant -eq 'raw' -and $_.serialization_error}).Count -gt 0);raw_timeout_observed=(@($results | Where-Object {$_.variant -eq 'raw' -and $_.timed_out}).Count -gt 0);user_path_before_sha256=$beforeUser;user_path_after_sha256=$afterUser;machine_path_before_sha256=$beforeMachine;machine_path_after_sha256=$afterMachine;native_ui_verified=$false;no_terminal_execution=$true;finished_utc=[DateTime]::UtcNow.ToString('o')}
Write-Plain (Join-Path $evidence 'diagnostic-result.json') ($summary | ConvertTo-Json -Depth 8)
if($beforeUser -ne $afterUser -or $beforeMachine -ne $afterMachine){throw 'Persistent PATH changed'}
if(-not $normalizedPassed){throw 'Normalization candidate did not pass every serialization case; inspect preserved evidence'}
Write-Host ('Inert serialization diagnostic retained: '+$evidence+'; no native acceptance inferred')
