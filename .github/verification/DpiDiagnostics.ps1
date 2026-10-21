param([Parameter(Mandatory=$true)][string]$EvidenceDirectory,[switch]$Child,[ValidateSet('atomic','powershell','powershell-winforms')][string]$Variant='atomic')
$ErrorActionPreference='Stop'
if(Test-Path -LiteralPath $EvidenceDirectory){throw 'Evidence directory must be absent'}
New-Item -ItemType Directory -Path $EvidenceDirectory | Out-Null
function Save-DiagnosticReport($Record,[ref]$Primary,[string]$Stem,[string]$RestoreError){
 # Plain scalar error evidence is attempted BEFORE JSON; later reporting errors never replace an earlier primary/restore error.
 $primaryText=if($null -ne $Primary.Value){$Primary.Value.Exception.Message}else{''}
 try{[IO.File]::WriteAllText((Join-Path $EvidenceDirectory ($Stem+'-errors.txt')),('primary_error='+$primaryText+"`nrestore_error="+$RestoreError+"`n"),(New-Object Text.UTF8Encoding($false)))}catch{
  [Console]::Error.WriteLine('Error sidecar write failed: '+$_.Exception.Message)
  if($null -eq $Primary.Value){$Primary.Value=$_}
 }
 try{$Record | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $EvidenceDirectory ($Stem+'.json')) -Encoding UTF8}catch{
  $reportFailure=$_
  try{[IO.File]::WriteAllText((Join-Path $EvidenceDirectory ($Stem+'-report-write-error.txt')),$reportFailure.Exception.Message,(New-Object Text.UTF8Encoding($false)))}catch{[Console]::Error.WriteLine('Report error sidecar write failed: '+$_.Exception.Message)}
  if($null -eq $Primary.Value){$Primary.Value=$reportFailure}
 }
}
if(-not $Child){
 $hostPS=Join-Path $env:SystemRoot 'System32/WindowsPowerShell/v1.0/powershell.exe'
 $results=@();$parentPrimary=$null
 try{
  foreach($case in @('atomic','powershell','powershell-winforms')){
   $destination=Join-Path $EvidenceDirectory $case
   $psi=New-Object Diagnostics.ProcessStartInfo
   $psi.FileName=$hostPS;$psi.Arguments='-NoProfile -NonInteractive -Mta -File "'+$PSCommandPath+'" -Child -Variant '+$case+' -EvidenceDirectory "'+$destination+'"'
   $psi.UseShellExecute=$false;$psi.CreateNoWindow=$true;$psi.RedirectStandardOutput=$true;$psi.RedirectStandardError=$true
   $process=New-Object Diagnostics.Process;$process.StartInfo=$psi;$timedOut=$false
   try{
    [void]$process.Start();$ownedPid=$process.Id;$ownedStart=$process.StartTime.ToUniversalTime().ToString('o')
    $stdout=$process.StandardOutput.ReadToEndAsync();$stderr=$process.StandardError.ReadToEndAsync()
    if(-not $process.WaitForExit(30000)){$timedOut=$true;try{$process.Kill()}catch{if(-not $process.HasExited){throw}};[void]$process.WaitForExit(5000)}
    if(-not $process.HasExited){throw 'Owned diagnostic child did not terminate'}
    $exitCode=$process.ExitCode;$streamErrors=@()
    try{[void]$stdout.Wait(5000)}catch{$streamErrors+=('stdout: '+$_.Exception.Message)}
    try{[void]$stderr.Wait(5000)}catch{$streamErrors+=('stderr: '+$_.Exception.Message)}
    $outComplete=($stdout.Status -eq [Threading.Tasks.TaskStatus]::RanToCompletion)
    $errComplete=($stderr.Status -eq [Threading.Tasks.TaskStatus]::RanToCompletion)
    $out=if($outComplete){$stdout.Result}else{''};$err=if($errComplete){$stderr.Result}else{''}
   }finally{$process.Dispose()}
   [IO.File]::WriteAllText((Join-Path $EvidenceDirectory ($case+'-stdout.txt')),$out,(New-Object Text.UTF8Encoding($false)))
   [IO.File]::WriteAllText((Join-Path $EvidenceDirectory ($case+'-stderr.txt')),$err,(New-Object Text.UTF8Encoding($false)))
   $results+=@{variant=$case;owned_pid=$ownedPid;owned_start_utc=$ownedStart;timed_out=$timedOut;exit_code=$exitCode;stdout_complete=$outComplete;stderr_complete=$errComplete;stream_errors=$streamErrors;incomplete_stream_files_are_empty=$true;report_present=(Test-Path -LiteralPath (Join-Path $destination 'dpi.json'))}
  }
  if(@($results | Where-Object {$_.timed_out -or $_.exit_code -ne 0 -or -not $_.report_present -or -not $_.stdout_complete -or -not $_.stderr_complete}).Count -gt 0){throw 'Diagnostic child incomplete; inspect raw evidence'}
 }catch{$parentPrimary=$_}finally{
  $parentReport=[ordered]@{schema=1;status='diagnostic observations only';parent_powershell=$PSVersionTable.PSVersion.ToString();results=$results;native_ui_verified=$false;no_Terminal_provider_download_capture=$true;child_runtime_ms=30000;owned_shutdown_ms=5000;each_stream_drain_ms=5000}
  Save-DiagnosticReport -Record $parentReport -Primary ([ref]$parentPrimary) -Stem 'children' -RestoreError ''
 }
 if($null -ne $parentPrimary){throw $parentPrimary}
 return
}
$report=[ordered]@{schema=1;variant=$Variant;powershell=$PSVersionTable.PSVersion.ToString();pid=$PID;os=[Environment]::OSVersion.VersionString;native_ui_verified=$false;source_case1_run=39563313410;source_case1_restore=$false;hypothesis_proven=$false;phases=@()}
$old=[IntPtr]::Zero;$primary=$null
try{
 # Load exactly the assembly used by the observer, without touching VirtualScreen until the named variant phase.
 Add-Type -AssemblyName System.Windows.Forms
 Add-Type -TypeDefinition @'
using System;using System.Collections.Generic;using System.Runtime.InteropServices;
public static class DeckDpiDiagnostic {
 [DllImport("kernel32.dll")] static extern uint GetCurrentThreadId();
 [DllImport("user32.dll")] static extern IntPtr GetThreadDpiAwarenessContext();
 [DllImport("user32.dll")] static extern bool IsValidDpiAwarenessContext(IntPtr c);
 [DllImport("user32.dll")] static extern int GetAwarenessFromDpiAwarenessContext(IntPtr c);
 [DllImport("user32.dll")] static extern bool AreDpiAwarenessContextsEqual(IntPtr a,IntPtr b);
 [DllImport("user32.dll",SetLastError=true)] static extern IntPtr SetThreadDpiAwarenessContext(IntPtr c);
 [DllImport("user32.dll")] static extern IntPtr GetDpiAwarenessContextForProcess(IntPtr p);
 [DllImport("shcore.dll")] static extern int GetProcessDpiAwareness(IntPtr p,out int awareness);
 public static Dictionary<string,object> Capture(IntPtr reference){
  var d=new Dictionary<string,object>();IntPtr c=GetThreadDpiAwarenessContext();
  d["native_tid"]=GetCurrentThreadId();d["thread_context"]=c.ToInt64();d["thread_valid"]=IsValidDpiAwarenessContext(c);d["thread_awareness"]=GetAwarenessFromDpiAwarenessContext(c);
  d["reference_context"]=reference.ToInt64();d["reference_valid"]=reference!=IntPtr.Zero&&IsValidDpiAwarenessContext(reference);
  d["equal_to_reference"]=reference==IntPtr.Zero?(object)null:AreDpiAwarenessContextsEqual(c,reference);
  d["equal_to_pmv2"]=AreDpiAwarenessContextsEqual(c,new IntPtr(-4));
  try{IntPtr pc=GetDpiAwarenessContextForProcess(IntPtr.Zero);d["process_context"]=pc.ToInt64();d["process_valid"]=IsValidDpiAwarenessContext(pc);d["process_context_awareness"]=GetAwarenessFromDpiAwarenessContext(pc);}catch(EntryPointNotFoundException e){d["process_context_unavailable"]=e.GetType().Name;}catch(DllNotFoundException e){d["process_context_unavailable"]=e.GetType().Name;}
  try{int a;int hr=GetProcessDpiAwareness(IntPtr.Zero,out a);d["get_process_awareness_hresult"]=hr;d["get_process_awareness_value"]=a;}catch(EntryPointNotFoundException e){d["process_awareness_unavailable"]=e.GetType().Name;}catch(DllNotFoundException e){d["process_awareness_unavailable"]=e.GetType().Name;}
  return d;
 }
 public static Dictionary<string,object> Set(IntPtr desired){
  IntPtr previous=SetThreadDpiAwarenessContext(desired);
  int error=Marshal.GetLastWin32Error(); // Immediate: no intervening P/Invoke. Meaningful as failure evidence only if previous==NULL.
  var d=new Dictionary<string,object>();d["native_tid"]=GetCurrentThreadId();d["requested"]=desired.ToInt64();d["returned_previous"]=previous.ToInt64();d["returned_null"]=previous==IntPtr.Zero;d["immediate_last_error"]=error;d["last_error_relevant"]=previous==IntPtr.Zero;return d;
 }
 public static Dictionary<string,object> Atomic(){
  var d=new Dictionary<string,object>();d["before"]=Capture(IntPtr.Zero);var set=Set(new IntPtr(-4));d["set"]=set;IntPtr old=new IntPtr((long)set["returned_previous"]);
  try{d["after_set"]=Capture(old);}finally{if(old!=IntPtr.Zero){d["restore"]=Set(old);d["after_restore"]=Capture(old);}else{d["restore_not_attempted"]=true;}}
  return d;
 }
}
'@
 if($Variant -eq 'atomic'){
  $report.atomic=[DeckDpiDiagnostic]::Atomic()
 }else{
  $report.phases+=@{phase='before_set';snapshot=[DeckDpiDiagnostic]::Capture([IntPtr]::Zero)}
  $report.set=[DeckDpiDiagnostic]::Set([IntPtr](-4));$old=[IntPtr]([long]$report.set['returned_previous'])
  if($old -eq [IntPtr]::Zero){throw 'SetPMv2 returned NULL; see immediate native result'}
  $report.phases+=@{phase='after_set';snapshot=[DeckDpiDiagnostic]::Capture($old)}
  if($Variant -eq 'powershell-winforms'){
   $report.phases+=@{phase='before_first_VirtualScreen';snapshot=[DeckDpiDiagnostic]::Capture($old)}
   $screen=[System.Windows.Forms.SystemInformation]::VirtualScreen
   $report.screen=@{left=$screen.Left;top=$screen.Top;width=$screen.Width;height=$screen.Height}
   $report.phases+=@{phase='after_first_VirtualScreen';snapshot=[DeckDpiDiagnostic]::Capture($old)}
  }
 }
}catch{$primary=$_;$report.primary_error=$_.Exception.Message}
finally{
 if($old -ne [IntPtr]::Zero){
  try{$report.before_restore=[DeckDpiDiagnostic]::Capture($old);$report.restore=[DeckDpiDiagnostic]::Set($old);$report.after_restore=[DeckDpiDiagnostic]::Capture($old)}catch{$report.restore_error=$_.Exception.Message;if($null -eq $primary){$primary=$_}}
 }
 $report.finished_utc=[DateTime]::UtcNow.ToString('o')
 Save-DiagnosticReport -Record $report -Primary ([ref]$primary) -Stem 'dpi' -RestoreError $report.restore_error
}
if($null -ne $primary){throw $primary}
