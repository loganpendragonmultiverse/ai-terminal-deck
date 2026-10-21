# DRAFT ONLY: root must review/authorize transport before any push or execution.
param([Parameter(Mandatory=$true)][ValidateSet(1,2,3)][int]$ToolCount,
 [Parameter(Mandatory=$true)][string]$FrozenAssets,[Parameter(Mandatory=$true)][string]$EvidenceDirectory,[switch]$PreflightOnly)
$ErrorActionPreference='Stop'
if(Test-Path -LiteralPath $EvidenceDirectory){throw 'Evidence directory must be absent'}
New-Item -ItemType Directory -Path $EvidenceDirectory | Out-Null
$proof=[ordered]@{schema=1;status='attempting';source_ref='0721085e5d87139ed4fb326e79f303fedcae974e';case=$ToolCount;native_ui_verified=$false;review_required=$true;image_version=$env:ImageVersion;runner_image=$env:ImageOS;workflow_run=$env:GITHUB_RUN_ID;workflow_head=$env:GITHUB_SHA}
$proof.observer_powershell=$PSVersionTable.PSVersion.ToString();$proof.os=[Environment]::OSVersion.VersionString
$ownedWindow=[IntPtr]::Zero;$qualifiedOwnership=$false;$dpiChanged=$false;$oldDpiContext=[IntPtr]::Zero
try{
Add-Type -AssemblyName UIAutomationClient,UIAutomationTypes,WindowsBase,System.Drawing,System.Windows.Forms
Add-Type -TypeDefinition @'
using System;using System.Collections.Generic;using System.Runtime.InteropServices;
public static class DeckDesktop {
 public delegate bool WindowEnum(IntPtr h,IntPtr l);
 [DllImport("user32.dll",SetLastError=true)] public static extern IntPtr SetThreadDpiAwarenessContext(IntPtr context);
 [DllImport("user32.dll")] public static extern IntPtr GetThreadDpiAwarenessContext();
 [DllImport("user32.dll")] public static extern bool AreDpiAwarenessContextsEqual(IntPtr a,IntPtr b);
 [DllImport("user32.dll")] public static extern uint GetDpiForWindow(IntPtr h);
 [DllImport("wtsapi32.dll",EntryPoint="WTSQuerySessionInformationW")] static extern bool WtsInfo(IntPtr server,int session,int kind,out IntPtr buffer,out uint bytes);
 [DllImport("wtsapi32.dll")] static extern void WTSFreeMemory(IntPtr p);
 public static int SessionState(int id){IntPtr p;uint n;if(!WtsInfo(IntPtr.Zero,id,8,out p,out n))throw new Exception("Session state unavailable");try{if(n<4)throw new Exception("Invalid session state");return Marshal.ReadInt32(p);}finally{WTSFreeMemory(p);}}
 [StructLayout(LayoutKind.Sequential)] public struct Rect {public int Left,Top,Right,Bottom;}
 [DllImport("user32.dll")] public static extern IntPtr GetProcessWindowStation();
 [DllImport("kernel32.dll")] public static extern uint GetCurrentThreadId();
 [DllImport("user32.dll")] public static extern IntPtr GetThreadDesktop(uint id);
 [DllImport("user32.dll",SetLastError=true)] public static extern IntPtr OpenInputDesktop(uint f,bool inherit,uint access);
 [DllImport("user32.dll")] public static extern bool CloseDesktop(IntPtr h);
 [DllImport("user32.dll",EntryPoint="GetUserObjectInformationW",CharSet=CharSet.Unicode,SetLastError=true)]
 static extern bool Info(IntPtr h,int index,IntPtr buffer,uint bytes,out uint needed);
 public static string Name(IntPtr h){uint n;Info(h,2,IntPtr.Zero,0,out n);if(n==0)throw new Exception("Desktop name unavailable");IntPtr b=Marshal.AllocHGlobal((int)n);try{if(!Info(h,2,b,n,out n))throw new Exception("Desktop name failed");return Marshal.PtrToStringUni(b);}finally{Marshal.FreeHGlobal(b);}}
 public static bool VisibleStation(IntPtr h){uint n;IntPtr b=Marshal.AllocHGlobal(12);try{if(!Info(h,1,b,12,out n))throw new Exception("Station flags failed");return (Marshal.ReadInt32(b,8)&1)!=0;}finally{Marshal.FreeHGlobal(b);}}
 [DllImport("user32.dll")] static extern bool EnumWindows(WindowEnum f,IntPtr l);
 [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
 [DllImport("user32.dll")] public static extern bool IsWindow(IntPtr h);
 [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h,out uint pid);
 public static IntPtr[] OwnedWindows(int[] ids){var a=new List<IntPtr>();EnumWindows((h,l)=>{uint p;GetWindowThreadProcessId(h,out p);if(Array.IndexOf(ids,(int)p)>=0&&IsWindowVisible(h))a.Add(h);return true;},IntPtr.Zero);return a.ToArray();}
 [DllImport("dwmapi.dll")] public static extern int DwmGetWindowAttribute(IntPtr h,int a,out Rect r,int bytes);
 [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
 [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
 [DllImport("user32.dll")] public static extern bool PostMessage(IntPtr h,uint m,IntPtr w,IntPtr l);
}
'@
 # Only THIS observer thread changes DPI context; no display/global/persistent setting changes.
 $oldDpiContext=[DeckDesktop]::SetThreadDpiAwarenessContext([IntPtr](-4))
 if($oldDpiContext -eq [IntPtr]::Zero){throw 'Cannot establish observer-thread PMv2 physical coordinates'}
 $dpiChanged=$true
 $proof.dpi_context_before=$oldDpiContext.ToInt64();$proof.dpi_context_requested='PER_MONITOR_AWARE_V2'
 $proof.dpi_context_verified=[DeckDesktop]::AreDpiAwarenessContextsEqual([DeckDesktop]::GetThreadDpiAwarenessContext(),[IntPtr](-4))
 if(-not $proof.dpi_context_verified){throw 'Observer-thread DPI context is not verified PMv2'}
 if([Runtime.InteropServices.RuntimeInformation]::OSArchitecture.ToString() -ne 'X64'){throw 'Transport binds official x64 ZIP only'}
 $proof.user_interactive=[Environment]::UserInteractive;$proof.session_id=[Diagnostics.Process]::GetCurrentProcess().SessionId
 $station=[DeckDesktop]::GetProcessWindowStation();$proof.station=[DeckDesktop]::Name($station);$proof.station_visible=[DeckDesktop]::VisibleStation($station)
 $proof.thread_desktop=[DeckDesktop]::Name([DeckDesktop]::GetThreadDesktop([DeckDesktop]::GetCurrentThreadId()))
 $proof.wts_state=[DeckDesktop]::SessionState($proof.session_id)
 if($proof.wts_state -ne 0){throw 'Current session is not already active; no connection/session changes permitted'}
 $inputDesktop=[DeckDesktop]::OpenInputDesktop(0,$false,1)
 if($inputDesktop -eq [IntPtr]::Zero){throw 'No readable input desktop; no remediation permitted'}
 try{$proof.input_desktop=[DeckDesktop]::Name($inputDesktop)}finally{[void][DeckDesktop]::CloseDesktop($inputDesktop)}
 if(-not $proof.user_interactive -or $proof.session_id -eq 0 -or -not $proof.station_visible -or $proof.station -ne 'WinSta0' -or $proof.input_desktop -ne $proof.thread_desktop){throw 'No existing visible interactive session'}
 if($PreflightOnly){$proof.status='compile-and-desktop-preflight-passed';$proof.compile_only=$true;return}
 # OpenInputDesktop alone is insufficient; actual foreground pixels/live UIA remain mandatory.
 $hashes=@{'Launch-AI-Terminal-Deck.bat'='a519c488a9d06927b8778edcaa7dc8af2363ba52f2c66eab40c3cb8ce8d3141c';'ai-terminal-deck-1.1.0.zip'='447d26b6cebeead04982d49db81c477db0992e15e86a209a01e680130a51cf1f';'SHA256SUMS.txt'='37bf61d3ad9b034f4bcf92fcfe8a0689002b32d4aa89a5639b8bd4023f185b16'}
 foreach($n in $hashes.Keys){if((Get-FileHash -LiteralPath (Join-Path $FrozenAssets $n) -Algorithm SHA256).Hash.ToLowerInvariant() -ne $hashes[$n]){throw ('Frozen asset mismatch: '+$n)}}
 $root=Join-Path ([IO.Path]::GetTempPath()) ('deck-hosted-ui-'+[guid]::NewGuid().ToString('N'));New-Item -ItemType Directory -Path $root | Out-Null;$proof.task_root=$root
 $package=Join-Path $root 'frozen-package';Expand-Archive -LiteralPath (Join-Path $FrozenAssets 'ai-terminal-deck-1.1.0.zip') -DestinationPath $package
 $runner=Join-Path $package 'tests/Invoke-NativeTerminalAcceptance.ps1'
 if((Get-FileHash -LiteralPath $runner -Algorithm SHA256).Hash.ToLowerInvariant() -ne 'a0e65bfd449e5fb00c443ed5107f284d438fcc47de52531459267dbf27b66c88'){throw 'Frozen runner mismatch'}
 # Parse every frozen PowerShell file with the SAME Windows PowerShell parser before executing tests or downloading Terminal.
 $parsed=@()
 foreach($scriptFile in Get-ChildItem -LiteralPath $package -Recurse -File -Filter '*.ps1'){
  $tokens=$null;$errors=$null
  [void][Management.Automation.Language.Parser]::ParseFile($scriptFile.FullName,[ref]$tokens,[ref]$errors)
  if($errors.Count -gt 0){throw ('Frozen PowerShell syntax errors: '+$scriptFile.Name+': '+(($errors | ForEach-Object {$_.ToString()}) -join '; '))}
  $parsed += @{file=$scriptFile.FullName;sha256=(Get-FileHash -LiteralPath $scriptFile.FullName -Algorithm SHA256).Hash}
 }
 $proof.frozen_scripts_parser_passed=$parsed
 $powershell=Join-Path $env:SystemRoot 'System32/WindowsPowerShell/v1.0/powershell.exe'
 & $powershell -NoProfile -File (Join-Path $package 'tests/Test-AITerminalDeck.ps1') 2>&1 | Out-File (Join-Path $EvidenceDirectory 'packaged-tests.log')
 if($LASTEXITCODE -ne 0){throw 'Full packaged tests failed'}
 & $powershell -NoProfile -File (Join-Path $package 'tests/Test-Package.ps1') -ArtifactDirectory $FrozenAssets -VerifyOnly 2>&1 | Out-File (Join-Path $EvidenceDirectory 'package-verify.log')
 if($LASTEXITCODE -ne 0){throw 'Frozen package verification failed'}
 $zip=Join-Path $root 'Microsoft.WindowsTerminal_1.25.2733.0_x64.zip'
 Invoke-WebRequest -Uri 'https://github.com/microsoft/terminal/releases/download/v1.25.2733.0/Microsoft.WindowsTerminal_1.25.2733.0_x64.zip' -OutFile $zip
 if((Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash.ToLowerInvariant() -ne 'bf3ef2012f6c44d8340a4c58125acc9498d19b580f9890dc043cdf831852e796'){throw 'Official portable ZIP mismatch'}
 Expand-Archive -LiteralPath $zip -DestinationPath (Join-Path $root 'terminal');$terminalBin=Join-Path $root 'terminal/terminal-1.25.2733.0'
 $signatures=@(Get-ChildItem -LiteralPath $terminalBin -Recurse -File | Where-Object Extension -in '.exe','.dll' | ForEach-Object {
  $s=Get-AuthenticodeSignature -LiteralPath $_.FullName
  if($s.Status -ne 'Valid' -or $s.SignerCertificate.Subject -notmatch 'O=Microsoft Corporation'){throw ('Microsoft trust failure: '+$_.Name)}
  [pscustomobject]@{file=$_.Name;sha256=(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash;status=$s.Status.ToString();subject=$s.SignerCertificate.Subject;thumbprint=$s.SignerCertificate.Thumbprint;timestamp=$s.TimeStamperCertificate.Subject}
 })
 $signatures | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $EvidenceDirectory 'microsoft-signatures.json')
 $marker=[IO.File]::Open((Join-Path $terminalBin '.portable'),[IO.FileMode]::CreateNew);$marker.Dispose()
 $terminal=Join-Path $terminalBin 'wt.exe';$expectedExe=Join-Path $terminalBin 'WindowsTerminal.exe'
 $before=@(Get-Process WindowsTerminal -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Id);$start=[DateTime]::UtcNow
 $caseDir=Join-Path ([IO.Path]::GetTempPath()) ('deck-hosted-case'+$ToolCount+'-'+[guid]::NewGuid().ToString('N'))
 # Unmodified frozen runner, REAL signed WindowsTerminal, never TerminalCapture.
 & $powershell -NoProfile -File $runner -ArtifactDirectory $package -ExpectedLauncherSHA256 $hashes['Launch-AI-Terminal-Deck.bat'] -TerminalExecutable $terminal -TaskDirectory $caseDir -ToolCount $ToolCount -OpenTerminal 2>&1 | Out-File (Join-Path $EvidenceDirectory 'native-runner.log')
 if($LASTEXITCODE -ne 0){throw 'Frozen runner failed; preserve uncertain window outcome'}
 $machine=Get-Content -LiteralPath (Join-Path $caseDir 'acceptance.json') -Raw | ConvertFrom-Json
 Copy-Item -LiteralPath (Join-Path $caseDir 'acceptance.json') -Destination (Join-Path $EvidenceDirectory 'acceptance.json')
 if(-not $machine.machine_checks_passed -or $machine.native_ui_verified){throw 'Unexpected machine proof state'}
 $deadline=[DateTime]::UtcNow.AddSeconds(30)
 do{
  $processes=@(Get-Process WindowsTerminal -ErrorAction SilentlyContinue | Where-Object {$_.Id -notin $before -and $_.Path -eq $expectedExe -and $_.StartTime.ToUniversalTime() -ge $start})
  $windows=@([DeckDesktop]::OwnedWindows([int[]]@($processes | Select-Object -ExpandProperty Id)))
  if($windows.Count -eq 1){break};Start-Sleep -Milliseconds 200
 }while([DateTime]::UtcNow -lt $deadline)
 if($windows.Count -ne 1){throw 'Cannot identify exactly one new portable Terminal window'}
 $ownedWindow=$windows[0];[uint32]$ownerPid=0;[void][DeckDesktop]::GetWindowThreadProcessId($ownedWindow,[ref]$ownerPid);$owner=Get-Process -Id $ownerPid
 if($owner.Path -ne $expectedExe -or $owner.StartTime.ToUniversalTime() -lt $start -or $ownerPid -in $before -or $owner.SessionId -ne $proof.session_id){throw 'Window ownership binding failed'}
 $proof.owner_pid=$ownerPid;$proof.owner_exe=$owner.Path;$proof.owner_started=$owner.StartTime.ToUniversalTime().ToString('o')
 $proof.owner_hwnd_int64=$ownedWindow.ToInt64();$proof.owner_session_id=$owner.SessionId
 $element=[System.Windows.Automation.AutomationElement]::FromHandle($ownedWindow)
 $proof.uia_root_process_id=$element.Current.ProcessId;$proof.uia_root_native_handle_int32=$element.Current.NativeWindowHandle
 # UIA NativeWindowHandle is Int32; normalize the low32 significant Windows handle bits for IntPtr comparison.
 $proof.uia_root_handle_normalized_int64=([int64]$element.Current.NativeWindowHandle -band [int64]4294967295)
 if($proof.uia_root_process_id -ne $ownerPid -or $proof.uia_root_handle_normalized_int64 -ne ($ownedWindow.ToInt64() -band [int64]4294967295)){throw 'UIA root PID/HWND does not match qualified native window'}

 $condition=New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ClassNameProperty,'TermControl')
 $deadline=[DateTime]::UtcNow.AddSeconds(20)
 do{
  $panes=@($element.FindAll([System.Windows.Automation.TreeScope]::Descendants,$condition) | Where-Object {-not $_.Current.IsOffscreen})
  if($panes.Count -eq $ToolCount){break};Start-Sleep -Milliseconds 200
 }while([DateTime]::UtcNow -lt $deadline)
 if($panes.Count -ne $ToolCount){throw 'Real-Terminal UIA pane count mismatch'}
 $rect=New-Object DeckDesktop+Rect
 if([DeckDesktop]::DwmGetWindowAttribute($ownedWindow,9,[ref]$rect,16) -ne 0){throw 'Physical task-window frame unavailable'}
 if(-not [DeckDesktop]::AreDpiAwarenessContextsEqual([DeckDesktop]::GetThreadDpiAwarenessContext(),[IntPtr](-4))){throw 'Observer thread physical coordinate context changed'}
 $screen=[System.Windows.Forms.SystemInformation]::VirtualScreen;$width=$rect.Right-$rect.Left;$height=$rect.Bottom-$rect.Top
 $proof.physical_frame=@{left=$rect.Left;top=$rect.Top;right=$rect.Right;bottom=$rect.Bottom}
 $proof.physical_screen=@{left=$screen.Left;top=$screen.Top;right=$screen.Right;bottom=$screen.Bottom}
 $proof.target_window_dpi=[DeckDesktop]::GetDpiForWindow($ownedWindow)

 if($width -le 0 -or $height -le 0 -or $rect.Left -lt $screen.Left -or $rect.Top -lt $screen.Top -or $rect.Right -gt $screen.Right -or $rect.Bottom -gt $screen.Bottom){throw 'Task window not wholly on visible screen'}
 $proof.pane_frame_tolerance_pixels=1
 $expected=@(@('Codex','Claude','Kimi')[0..($ToolCount-1)])
 $paneProof=@($panes | Sort-Object {$_.Current.BoundingRectangle.X} | ForEach-Object {
  $p=$_.Current;$text=$_.GetCurrentPattern([System.Windows.Automation.TextPattern]::Pattern)
  $visible=(@($text.GetVisibleRanges() | ForEach-Object {$_.GetText(-1)}) -join '')
  [pscustomobject]@{title=$p.Name;help=$p.HelpText;class=$p.ClassName;offscreen=$p.IsOffscreen;x=$p.BoundingRectangle.X;y=$p.BoundingRectangle.Y;width=$p.BoundingRectangle.Width;height=$p.BoundingRectangle.Height;visible_text=$visible}
 })
 for($i=0;$i -lt $ToolCount;$i++){
  $p=$paneProof[$i];$flat=$p.visible_text.Replace([string][char]13,'').Replace([string][char]10,'')
  foreach($dimension in @($p.x,$p.y,$p.width,$p.height)){if([double]::IsNaN([double]$dimension) -or [double]::IsInfinity([double]$dimension)){throw 'UIA rectangle contains nonfinite coordinates'}}
  if($p.x -lt $rect.Left-1 -or $p.y -lt $rect.Top-1 -or $p.x+$p.width -gt $rect.Right+1 -or $p.y+$p.height -gt $rect.Bottom+1){throw 'UIA pane lies outside physical task-window frame'}

  if($p.title -ne $expected[$i] -or $p.help -ne $expected[$i] -or $p.width -lt 80 -or $p.height -lt 80){throw 'Pane title/help/bounds mismatch'}
  if(-not $flat.Contains('AI Terminal Deck INERT acceptance '+[IO.Path]::GetFileName($caseDir)+' '+$expected[$i].ToLowerInvariant()) -or -not $flat.Contains($machine.working_directory)){throw 'Task ID/tool/literal cwd not visible in live pane text'}
 }
 $span=($paneProof[-1].x+$paneProof[-1].width)-$paneProof[0].x;$mean=$span/$ToolCount
 for($i=0;$i -lt $ToolCount;$i++){
  $p=$paneProof[$i]
  if([Math]::Abs($p.width-$mean) -gt $mean*0.15 -or [Math]::Abs($p.y-$paneProof[0].y) -gt 10 -or [Math]::Abs($p.height-$paneProof[0].height) -gt 10){throw 'Approximately equal aligned columns failed'}
  if($i -gt 0){$gap=$p.x-($paneProof[$i-1].x+$paneProof[$i-1].width);if($gap -lt -2 -or $gap -gt 40){throw 'Pane ordering/gap mismatch'}}
 }
 $proof.panes=$paneProof;$proof.machine_receipt_sha256=(Get-FileHash (Join-Path $EvidenceDirectory 'acceptance.json') -Algorithm SHA256).Hash
 $qualifiedOwnership=$true # Exact executable/PID/start + inert task ID now bind ownership.
 [void][DeckDesktop]::SetForegroundWindow($ownedWindow);Start-Sleep -Milliseconds 500
 if([DeckDesktop]::GetForegroundWindow() -ne $ownedWindow){throw 'Task window not foreground; no offscreen substitute'}
 $captureRect=New-Object DeckDesktop+Rect
 if([DeckDesktop]::DwmGetWindowAttribute($ownedWindow,9,[ref]$captureRect,16) -ne 0){throw 'Capture frame unavailable'}
 foreach($edge in @('Left','Top','Right','Bottom')){if($captureRect.$edge -ne $rect.$edge){throw 'Task window moved/resized after live geometry measurement'}}
 $bitmap=New-Object System.Drawing.Bitmap($width,$height)
 try{
  $graphics=[System.Drawing.Graphics]::FromImage($bitmap)
  try{$graphics.CopyFromScreen($rect.Left,$rect.Top,0,0,(New-Object System.Drawing.Size($width,$height)))}finally{$graphics.Dispose()}
  $png=Join-Path $EvidenceDirectory 'task-window.png';$bitmap.Save($png,[System.Drawing.Imaging.ImageFormat]::Png)
 }finally{$bitmap.Dispose()}
 $proof.screenshot=@{path='task-window.png';sha256=(Get-FileHash $png -Algorithm SHA256).Hash;width=$width;height=$height}
 $proof.live_ui_automated_checks_passed=$true;$proof.status='pending-independent-screenshot-review'
 # Never sets native_ui_verified=true: actual independent image review remains required.
}catch{$proof.status='failed-or-unavailable';$proof.error=$_.Exception.Message;throw}
finally{
 try{
  if($qualifiedOwnership -and [DeckDesktop]::IsWindow($ownedWindow)){
   [uint32]$finalPid=0;[void][DeckDesktop]::GetWindowThreadProcessId($ownedWindow,[ref]$finalPid);$finalProcess=Get-Process -Id $finalPid -ErrorAction Stop
   if($finalPid -ne $proof.owner_pid -or $finalProcess.Path -ne $proof.owner_exe -or $finalProcess.StartTime.ToUniversalTime().ToString('o') -ne $proof.owner_started -or $finalProcess.SessionId -ne $proof.session_id -or [DeckDesktop]::SessionState($proof.session_id) -ne 0){throw 'Final PID/path/start/session ownership changed'}
   # Re-read SAME HWND live task-ID and literal directory immediately before WM_CLOSE.
   $finalElement=[System.Windows.Automation.AutomationElement]::FromHandle($ownedWindow)
   $finalPanes=@($finalElement.FindAll([System.Windows.Automation.TreeScope]::Descendants,$condition) | Where-Object {-not $_.Current.IsOffscreen} | Sort-Object {$_.Current.BoundingRectangle.X})
   if($finalPanes.Count -ne $ToolCount){throw 'Final task-pane identity count changed'}
   for($i=0;$i -lt $ToolCount;$i++){
    $finalPattern=$finalPanes[$i].GetCurrentPattern([System.Windows.Automation.TextPattern]::Pattern)
    $finalText=(@($finalPattern.GetVisibleRanges() | ForEach-Object {$_.GetText(-1)}) -join '').Replace([string][char]13,'').Replace([string][char]10,'')
    if($finalPanes[$i].Current.Name -ne $expected[$i] -or -not $finalText.Contains('AI Terminal Deck INERT acceptance '+[IO.Path]::GetFileName($caseDir)+' '+$expected[$i].ToLowerInvariant()) -or -not $finalText.Contains($machine.working_directory)){throw 'Final live task-ID/title/literal directory ownership changed'}
   }
   $proof.closure_task_identity_revalidated=$true
   [void][DeckDesktop]::PostMessage($ownedWindow,0x0010,[IntPtr]::Zero,[IntPtr]::Zero)
   $until=[DateTime]::UtcNow.AddSeconds(10);while([DeckDesktop]::IsWindow($ownedWindow) -and [DateTime]::UtcNow -lt $until){Start-Sleep -Milliseconds 200}
   $proof.owned_window_closed=(-not [DeckDesktop]::IsWindow($ownedWindow))
  }
 }catch{$proof.owned_window_closed=$false;$proof.closure_skip_reason=$_.Exception.Message}
 if(-not $proof.Contains('owned_window_closed')){$proof.owned_window_closed=$false}
 if($dpiChanged){
  try{
   $restoreResult=[DeckDesktop]::SetThreadDpiAwarenessContext($oldDpiContext)
   $proof.observer_thread_dpi_restored=($restoreResult -ne [IntPtr]::Zero -and [DeckDesktop]::AreDpiAwarenessContextsEqual([DeckDesktop]::GetThreadDpiAwarenessContext(),$oldDpiContext))
  }catch{$proof.observer_thread_dpi_restored=$false;$proof.dpi_restore_error=$_.Exception.Message}
 }
 $proof.finished_utc=[DateTime]::UtcNow.ToString('o')
 $proof | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath (Join-Path $EvidenceDirectory 'native-ui-observation.json') -Encoding UTF8
 # No arbitrary process kill, cleanup, setup or persistent settings remediation.
}
if(-not $proof.owned_window_closed){throw 'Task-window closure unverified'}
