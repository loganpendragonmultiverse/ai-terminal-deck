# Inert quoting diagnostic only. Never launches WT/providers or changes persisted settings.
param([Parameter(Mandatory=$true)][string]$FrozenAssets,[Parameter(Mandatory=$true)][string]$EvidenceDirectory)
$ErrorActionPreference='Stop'
if(Test-Path -LiteralPath $EvidenceDirectory){throw 'Fresh evidence destination required'}
New-Item -ItemType Directory -Path $EvidenceDirectory | Out-Null
$report=[ordered]@{schema=1;workflow_head=$env:GITHUB_SHA;run=$env:GITHUB_RUN_ID;powershell=$PSVersionTable.PSVersion.ToString();frozen_product_ref='3a736e15a4f941d4905c7f695e9a6d980cbb1623';native_ui_attempted=$false;records=@()}
$root=Join-Path ([IO.Path]::GetTempPath()) ('deck-inert-quoting-'+[guid]::NewGuid().ToString('N'))
$cmd=Join-Path $env:SystemRoot 'System32/cmd.exe'
$userBefore=[Environment]::GetEnvironmentVariable('PATH','User');$machineBefore=[Environment]::GetEnvironmentVariable('PATH','Machine')
function Capture-Raw([string]$File,[string]$Argument,[string]$FixturePath,[string]$Directory,[string]$Markers,[string]$Shadow){
 $psi=New-Object Diagnostics.ProcessStartInfo
 $psi.FileName=$cmd;$psi.Arguments=('/d /s /c ""'+$File+'" '+$Argument+'"')
 $psi.UseShellExecute=$false;$psi.CreateNoWindow=$true;$psi.RedirectStandardOutput=$true;$psi.RedirectStandardError=$true;$psi.WorkingDirectory=$Shadow
 $psi.EnvironmentVariables['PATH']=$FixturePath
 $psi.EnvironmentVariables['PATHEXT']='.EXE;.CMD;.BAT'
 $psi.EnvironmentVariables['AI_TERMINAL_DECK_WORKDIR']=$Directory
 $psi.EnvironmentVariables['AI_TERMINAL_DECK_SKIP_KNOWN_PATHS']='1'
 $psi.EnvironmentVariables['AI_TERMINAL_DECK_SKIP_INSTALL_PROMPTS']='1'
 $psi.EnvironmentVariables['AI_TERMINAL_DECK_NO_PAUSE']='1'
 $psi.EnvironmentVariables['AI_TERMINAL_DECK_INSTALL_DRY_RUN']='1'
 $psi.EnvironmentVariables['DECK_DIAG_MARKERS']=$Markers
 $p=New-Object Diagnostics.Process;$p.StartInfo=$psi
 try{
  [void]$p.Start()
  $stdout=$p.StandardOutput.ReadToEndAsync();$stderr=$p.StandardError.ReadToEndAsync()
  if(-not $p.WaitForExit(15000)){throw 'Owned inert cmd timed out; no arbitrary process termination or retry'}
  return [pscustomobject]@{arguments=$psi.Arguments;stdout=$stdout.Result;stderr=$stderr.Result;exit_code=$p.ExitCode}
 }finally{$p.Dispose()}
}
try{
 New-Item -ItemType Directory -Path $root | Out-Null;$report.task_root=$root
 $source=Join-Path $FrozenAssets 'Launch-AI-Terminal-Deck.bat'
 if((Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash.ToLowerInvariant() -ne '27f77f8063684d7b3529d4c5fb83e2e358a5378ecf00451f473bc5910a98bfc3'){throw 'Frozen BAT hash mismatch'}
 $bytes=[IO.File]::ReadAllBytes($source);$text=[Text.Encoding]::UTF8.GetString($bytes)
 $line=@($text.Split([char]10) | Where-Object {$_ -like 'for /f *' -and $_.Contains('where.exe')})
 if($line.Count -ne 1 -or -not $line[0].Contains('2^>nul"')){throw 'Unexpected frozen FOR/F query'}
 $originalLine=$line[0].TrimEnd([char]13)
 $removeCaret=$originalLine.Replace('2^>nul"','2>nul"')
 $moveOutside=$originalLine.Replace(' 2^>nul"','" 2^>nul')
 $forms=[ordered]@{frozen=$originalLine;remove_caret_inside_outer_quote=$removeCaret;move_redirection_outside_outer_quote=$moveOutside}
 $report.original_line=$originalLine;$report.variant_lines=$forms
 $work=Join-Path $root "Literal Workspace & (round) O'Neil !; %DECK_LITERAL%"
 $markers=Join-Path $root 'markers';$shadow=Join-Path $root 'shadow'
 New-Item -ItemType Directory -Path $work,$markers,$shadow | Out-Null
 foreach($n in @('wt.exe','codex.cmd','claude.cmd','kimi.cmd')){
  [IO.File]::WriteAllText((Join-Path $shadow $n),'@echo WRONG-CWD-SHADOW>>"%DECK_DIAG_MARKERS%\shadow.executed"')
 }
 $fixtures=@(
  @{name='all';tools=@('wt.exe','codex.cmd','claude.cmd','kimi.cmd');check=0;preview=0},
  @{name='codex_only';tools=@('wt.exe','codex.cmd');check=3;preview=0},
  @{name='no_ai';tools=@('wt.exe');check=3;preview=3},
  @{name='no_wt';tools=@('codex.cmd');check=3;preview=3}
 )
 foreach($variant in $forms.Keys){
  $folder=Join-Path $root $variant;New-Item -ItemType Directory -Path $folder | Out-Null
  $bat=Join-Path $folder 'Launch-AI-Terminal-Deck.bat'
  if($variant -eq 'frozen'){[IO.File]::WriteAllBytes($bat,$bytes)}
  else{[IO.File]::WriteAllText($bat,$text.Replace($originalLine,$forms[$variant]),(New-Object Text.UTF8Encoding($false)))}
  $standalone=Join-Path $folder 'query-only.bat'
  $prefix=$forms[$variant].Substring(0,$forms[$variant].IndexOf(' do '))
  $query='@echo off'+[Environment]::NewLine+'setlocal EnableExtensions DisableDelayedExpansion'+[Environment]::NewLine+'call :query codex'+[Environment]::NewLine+'exit /b 0'+[Environment]::NewLine+':query'+[Environment]::NewLine+$prefix+' do @echo FOUND=%%P'+[Environment]::NewLine+'exit /b 0'+[Environment]::NewLine
  [IO.File]::WriteAllText($standalone,$query,(New-Object Text.UTF8Encoding($false)))
  foreach($fixture in $fixtures){
   $bin=Join-Path $folder ("Bin & (round) O'Neil ! "+$fixture.name);New-Item -ItemType Directory -Path $bin | Out-Null
   foreach($tool in $fixture.tools){[IO.File]::WriteAllText((Join-Path $bin $tool),'@echo UNEXPECTED-EXECUTION>>"%DECK_DIAG_MARKERS%\'+$tool+'.executed"')}
   $path=$bin+';'+(Join-Path $env:SystemRoot 'System32')+';'+$env:SystemRoot
   foreach($mode in @('check','preview')){
    $raw=Capture-Raw $bat ('--'+$mode) $path $work $markers $shadow
    $record=[ordered]@{variant=$variant;fixture=$fixture.name;mode=$mode;bat_sha256=(Get-FileHash -LiteralPath $bat -Algorithm SHA256).Hash;expected_exit=$fixture[$mode];actual=$raw;stderr_empty=($raw.stderr.Length -eq 0);exit_expected=($raw.exit_code -eq $fixture[$mode]);cwd_shadow_excluded=(-not $raw.stdout.Contains($shadow));marker_execution_count=@(Get-ChildItem -LiteralPath $markers -File).Count}
    $report.records+=,[pscustomobject]$record
   }
   $raw=Capture-Raw $standalone '' $path $work $markers $shadow
   $report.records+=,[pscustomobject]@{variant=$variant;fixture=$fixture.name;mode='standalone_query';actual=$raw;stderr_empty=($raw.stderr.Length -eq 0);expected_codex_found=($fixture.tools -contains 'codex.cmd');found_expected=($raw.stdout.Contains((Join-Path $bin 'codex.cmd')) -eq ($fixture.tools -contains 'codex.cmd'));marker_execution_count=@(Get-ChildItem -LiteralPath $markers -File).Count}
  }
 }
 $report.marker_execution_count=@(Get-ChildItem -LiteralPath $markers -File).Count
 if($report.marker_execution_count -ne 0){throw 'Diagnostic unexpectedly executed a marker'}
 $report.user_path_unchanged=([Environment]::GetEnvironmentVariable('PATH','User') -eq $userBefore)
 $report.machine_path_unchanged=([Environment]::GetEnvironmentVariable('PATH','Machine') -eq $machineBefore)
 if(-not $report.user_path_unchanged -or -not $report.machine_path_unchanged){throw 'Persistent PATH changed'}
 $report.status='diagnostic-completed-not-native-acceptance'
}catch{$report.status='diagnostic-failed';$report.error=$_.Exception.Message;throw}
finally{
 $report.finished_utc=[DateTime]::UtcNow.ToString('o')
 $report | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath (Join-Path $EvidenceDirectory 'raw-quoting-diagnostic.json') -Encoding UTF8
 # Preserve all generated task files on runner until its platform-managed disposal; no cleanup here.
}
