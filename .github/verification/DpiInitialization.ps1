param([Parameter(Mandatory=$true)][string]$EvidenceDirectory,[switch]$Child,[ValidateSet('assemblies','uia-root','drawing','combined')][string]$Variant='assemblies')
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
  foreach($case in @('assemblies','uia-root','drawing','combined')){
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
$report=[ordered]@{schema=1;variant=$Variant;powershell=$PSVersionTable.PSVersion.ToString();pid=$PID;os=[Environment]::OSVersion.VersionString;native_ui_verified=$false;source_case1_run=39573475788;source_case1_restore=$false;hypothesis_proven=$false;phases=@()}
$old=[IntPtr]::Zero;$initial=[IntPtr]::Zero;$primary=$null
try{
 # All four controls load the SAME complete assembly list as the observer BEFORE the initial DPI snapshot.
 Add-Type -AssemblyName UIAutomationClient,UIAutomationTypes,WindowsBase,System.Drawing,System.Windows.Forms
 Add-Type -TypeDefinition @'
using System;using System.Collections.Generic;using System.Runtime.InteropServices;
public static class DeckDpiDiagnostic {
 [DllImport("kernel32.dll")] static extern uint GetCurrentThreadId();
 [DllImport("kernel32.dll")] static extern uint GetCurrentProcessId();
 [DllImport("kernel32.dll")] static extern IntPtr GetCurrentProcess();
 [DllImport("kernel32.dll",SetLastError=true)] static extern IntPtr OpenProcess(uint access,bool inherit,uint pid);
 [DllImport("kernel32.dll")] static extern bool CloseHandle(IntPtr h);
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
  d["reference_context"]=reference.ToInt64();d["reference_valid"]=reference!=IntPtr.Zero&&IsValidDpiAwarenessContext(reference);d["reference_awareness"]=reference==IntPtr.Zero?-1:GetAwarenessFromDpiAwarenessContext(reference);
  d["equal_to_reference"]=reference==IntPtr.Zero?(object)null:AreDpiAwarenessContextsEqual(c,reference);
  d["equal_to_pmv2"]=AreDpiAwarenessContextsEqual(c,new IntPtr(-4));
  d["null_handle_observation"]=ReadProcess(IntPtr.Zero);
  d["pseudo_self_handle_observation"]=ReadProcess(GetCurrentProcess());
  IntPtr self=OpenProcess(0x1000,false,GetCurrentProcessId());int openError=Marshal.GetLastWin32Error();
  d["real_self_handle_opened"]=self!=IntPtr.Zero;d["real_self_open_error_if_null"]=self==IntPtr.Zero?(object)openError:null;
  if(self!=IntPtr.Zero){try{d["real_self_handle_observation"]=ReadProcess(self);}finally{d["real_self_handle_closed"]=CloseHandle(self);}}
  return d;
 }
 static Dictionary<string,object> ReadProcess(IntPtr handle){
  var d=new Dictionary<string,object>();
  try{IntPtr c=GetDpiAwarenessContextForProcess(handle);d["context"]=c.ToInt64();d["valid"]=IsValidDpiAwarenessContext(c);d["awareness"]=GetAwarenessFromDpiAwarenessContext(c);}catch(EntryPointNotFoundException e){d["context_unavailable"]=e.GetType().Name;}catch(DllNotFoundException e){d["context_unavailable"]=e.GetType().Name;}
  try{int value;d["awareness_hresult"]=GetProcessDpiAwareness(handle,out value);d["awareness_value"]=value;}catch(EntryPointNotFoundException e){d["awareness_unavailable"]=e.GetType().Name;}catch(DllNotFoundException e){d["awareness_unavailable"]=e.GetType().Name;}
  return d;
 }
 public static Dictionary<string,object> Compare(IntPtr initialGetter,IntPtr returnedOld){
  var d=new Dictionary<string,object>();d["native_tid"]=GetCurrentThreadId();d["initial_getter"]=initialGetter.ToInt64();d["initial_getter_awareness"]=GetAwarenessFromDpiAwarenessContext(initialGetter);d["returned_old"]=returnedOld.ToInt64();d["returned_old_awareness"]=GetAwarenessFromDpiAwarenessContext(returnedOld);d["semantically_equal"]=AreDpiAwarenessContextsEqual(initialGetter,returnedOld);return d;
 }
 public static Dictionary<string,object> Set(IntPtr desired){
  IntPtr previous=SetThreadDpiAwarenessContext(desired);
  int error=Marshal.GetLastWin32Error(); // Immediate observation; no documented extended-error contract for SetThreadDpiAwarenessContext.
  var d=new Dictionary<string,object>();d["native_tid"]=GetCurrentThreadId();d["requested"]=desired.ToInt64();d["returned_previous"]=previous.ToInt64();d["returned_null"]=previous==IntPtr.Zero;d["immediate_last_error"]=error;d["extended_error_contract_documented"]=false;return d;
 }

}
'@
 $baseline=[DeckDpiDiagnostic]::Capture([IntPtr]::Zero);$initial=[IntPtr]([long]$baseline['thread_context'])
 $report.phases+=@{phase='before_set';snapshot=$baseline}
 $report.set=[DeckDpiDiagnostic]::Set([IntPtr](-4));$old=[IntPtr]([long]$report.set['returned_previous'])
 if($old -eq [IntPtr]::Zero){throw 'SetPMv2 returned NULL; see immediate native result'}
 $report.phases+=@{phase='after_set';snapshot=[DeckDpiDiagnostic]::Capture($old);old_vs_initial=[DeckDpiDiagnostic]::Compare($initial,$old)}
 if($Variant -in @('uia-root','combined')){
  # Desktop root identity only. Never enumerate descendants or read names, titles, text, values or images.
  $report.phases+=@{phase='before_UIA_root';snapshot=[DeckDpiDiagnostic]::Capture($old);old_vs_initial=[DeckDpiDiagnostic]::Compare($initial,$old)}
  $rootElement=[System.Windows.Automation.AutomationElement]::RootElement
  $report.root_native_handle=$rootElement.Current.NativeWindowHandle
  $report.phases+=@{phase='after_UIA_root_native_handle';snapshot=[DeckDpiDiagnostic]::Capture($old);old_vs_initial=[DeckDpiDiagnostic]::Compare($initial,$old)}
  $rootElement=$null
 }
 if($Variant -in @('drawing','combined')){
  $report.phases+=@{phase='before_memory_Bitmap';snapshot=[DeckDpiDiagnostic]::Capture($old);old_vs_initial=[DeckDpiDiagnostic]::Compare($initial,$old)}
  $bitmap=$null;$graphics=$null;$drawingError=$null
  try{
   $bitmap=New-Object System.Drawing.Bitmap(1,1)
   $report.phases+=@{phase='after_memory_Bitmap';snapshot=[DeckDpiDiagnostic]::Capture($old);old_vs_initial=[DeckDpiDiagnostic]::Compare($initial,$old)}
   $graphics=[System.Drawing.Graphics]::FromImage($bitmap)
   $report.phases+=@{phase='after_memory_Graphics';snapshot=[DeckDpiDiagnostic]::Capture($old);old_vs_initial=[DeckDpiDiagnostic]::Compare($initial,$old)}
  }catch{$drawingError=$_}finally{
   if($null -ne $graphics){try{$graphics.Dispose()}catch{$report.graphics_dispose_error=$_.Exception.Message;if($null -eq $drawingError){$drawingError=$_}}}
   if($null -ne $bitmap){try{$bitmap.Dispose()}catch{$report.bitmap_dispose_error=$_.Exception.Message;if($null -eq $drawingError){$drawingError=$_}}}
  }
  if($null -ne $drawingError){throw $drawingError}
  $report.phases+=@{phase='after_memory_dispose';snapshot=[DeckDpiDiagnostic]::Capture($old);old_vs_initial=[DeckDpiDiagnostic]::Compare($initial,$old)}
 }

}catch{$primary=$_;$report.primary_error=$_.Exception.Message}
finally{
 if($old -ne [IntPtr]::Zero){
  try{$report.before_restore=[DeckDpiDiagnostic]::Capture($old);$report.restore=[DeckDpiDiagnostic]::Set($old);$report.after_restore=[DeckDpiDiagnostic]::Capture($old);$report.old_vs_initial_after_restore=[DeckDpiDiagnostic]::Compare($initial,$old);$report.current_vs_initial_after_restore=[DeckDpiDiagnostic]::Capture($initial)}catch{$report.restore_error=$_.Exception.Message;if($null -eq $primary){$primary=$_}}
 }
 $report.finished_utc=[DateTime]::UtcNow.ToString('o')
 Save-DiagnosticReport -Record $report -Primary ([ref]$primary) -Stem 'dpi' -RestoreError $report.restore_error
}
if($null -ne $primary){throw $primary}
