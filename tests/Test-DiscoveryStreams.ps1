$ErrorActionPreference='Stop'
$launcher=Join-Path (Split-Path -Parent $PSScriptRoot) 'Launch-AI-Terminal-Deck.bat'
$root=Join-Path ([IO.Path]::GetTempPath()) ('deck-discovery-streams-'+[guid]::NewGuid().ToString('N'))
$cmd=Join-Path $env:SystemRoot 'System32/cmd.exe'
function Assert-Streams([bool]$Condition,[string]$Message){if(-not $Condition){throw $Message}}
New-Item -ItemType Directory -Path $root | Out-Null
try{
 $work=Join-Path $root "Workspace & (round) O'Neil !; %DECK_LITERAL%"
 $shadow=Join-Path $root 'current-directory-shadow'
 $markers=Join-Path $root 'markers'
 New-Item -ItemType Directory -Path $work,$shadow,$markers | Out-Null
 foreach($tool in @('wt.exe','codex.cmd','claude.cmd','kimi.cmd')){
  [IO.File]::WriteAllText((Join-Path $shadow $tool),'@echo SHADOW-EXECUTED>>"%DECK_STREAM_MARKERS%\shadow.txt"')
 }
 $fixtures=@(
  @{name='all';tools=@('wt.exe','codex.cmd','claude.cmd','kimi.cmd');check=0;preview=0},
  @{name='one';tools=@('wt.exe','codex.cmd');check=3;preview=0},
  @{name='no_ai';tools=@('wt.exe');check=3;preview=3},
  @{name='no_wt';tools=@('codex.cmd');check=3;preview=3}
 )
 foreach($fixture in $fixtures){
  $bin=Join-Path $root ("Bin & (round) O'Neil ! "+$fixture.name)
  New-Item -ItemType Directory -Path $bin | Out-Null
  foreach($tool in $fixture.tools){[IO.File]::WriteAllText((Join-Path $bin $tool),'@echo UNEXPECTED-EXECUTION>>"%DECK_STREAM_MARKERS%\provider.txt"')}
  foreach($mode in @('check','preview')){
   $psi=New-Object Diagnostics.ProcessStartInfo
   $psi.FileName=$cmd;$psi.Arguments=('/d /s /c ""'+$launcher+'" --'+$mode+'"')
   $psi.UseShellExecute=$false;$psi.CreateNoWindow=$true;$psi.RedirectStandardOutput=$true;$psi.RedirectStandardError=$true;$psi.WorkingDirectory=$shadow
   $psi.EnvironmentVariables['PATH']=$bin+';'+(Join-Path $env:SystemRoot 'System32')+';'+$env:SystemRoot
   $psi.EnvironmentVariables['PATHEXT']='.EXE;.CMD;.BAT'
   $psi.EnvironmentVariables['AI_TERMINAL_DECK_WORKDIR']=$work
   $psi.EnvironmentVariables['AI_TERMINAL_DECK_SKIP_KNOWN_PATHS']='1'
   $psi.EnvironmentVariables['AI_TERMINAL_DECK_SKIP_INSTALL_PROMPTS']='1'
   $psi.EnvironmentVariables['AI_TERMINAL_DECK_NO_PAUSE']='1'
   $psi.EnvironmentVariables['AI_TERMINAL_DECK_INSTALL_DRY_RUN']='1'
   $psi.EnvironmentVariables['DECK_STREAM_MARKERS']=$markers
   $p=New-Object Diagnostics.Process;$p.StartInfo=$psi
   try{
    [void]$p.Start();$stdout=$p.StandardOutput.ReadToEndAsync();$stderr=$p.StandardError.ReadToEndAsync()
    Assert-Streams ($p.WaitForExit(15000)) 'Owned readonly cmd did not exit within15seconds'
    $output=$stdout.Result;$errorText=$stderr.Result;$exitCode=$p.ExitCode
   }finally{$p.Dispose()}
   Assert-Streams ($exitCode -eq $fixture[$mode]) ($fixture.name+' --'+$mode+' unexpected exit '+$exitCode)
   # PS7's native-stderr semantics must not hide a discovery diagnostic regression.
   # Capture both raw streams independently: neither preference nor 2>&1 can mask it.
   Assert-Streams ($errorText.Length -eq 0) ($fixture.name+' --'+$mode+' wrote native stderr: '+$errorText)
   Assert-Streams (-not $output.Contains($shadow)) 'PATH-only discovery selected implicit current-directory shadow'
   Assert-Streams ($output.Contains($work)) 'Literal starting directory omitted or changed'
   if($fixture.tools -contains 'codex.cmd'){Assert-Streams ($output.Contains((Join-Path $bin 'codex.cmd'))) 'Exact PATH command binding omitted'}
   Assert-Streams (@(Get-ChildItem -LiteralPath $markers -File).Count -eq 0) 'Readiness/preview executed a tool'
  }
 }
 Write-Host 'PASS raw discovery stdout/stderr/exit for all/one/no-AI/no-Terminal paths under the current PowerShell host'
}finally{
 $temp=[IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\')+'\'
 if(-not ([IO.Path]::GetFullPath($root).StartsWith($temp,[StringComparison]::OrdinalIgnoreCase))){throw 'Unsafe test cleanup'}
 if(Test-Path -LiteralPath $root){Remove-Item -LiteralPath $root -Recurse -Force}
}
