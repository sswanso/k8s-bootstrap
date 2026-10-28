<#
.SYNOPSIS
    Automates the installation of WSL 2 on Windows 11, configures global proxy settings,
    and installs the default Ubuntu WSL image registered under the custom name "breaking-kubernetes".
.DESCRIPTION
    1. Ensures %USERPROFILE%\.wslconfig exists and contains autoProxy=true.
    2. Deep checks Windows Optional Features for WSL & Virtual Machine Platform.
    3. Handles the required Windows reboot cleanly.
    4. Downloads and registers the Ubuntu distribution as "breaking-kubernetes" without launching.
#>

# Ensure running in an elevated administrative PowerShell window
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Error "[ERROR] This script must be run as Administrator! Please right-click PowerShell and select 'Run as Administrator'."
    Exit
}

Write-Host "=========================================================" -ForegroundColor Cyan
Write-Host "   Windows 11 WSL 2 & Proxy Setup: breaking-kubernetes" -ForegroundColor Cyan
Write-Host "=========================================================" -ForegroundColor Cyan

# ---------------------------------------------------------
# Step 1: Check and Configure Global .wslconfig
# ---------------------------------------------------------
$wslConfigPath = Join-Path $env:USERPROFILE ".wslconfig"
Write-Host "`n[1/4] Checking WSL Config File: $wslConfigPath" -ForegroundColor Yellow

$requiredContent = @(
    "[wsl2]"
    "autoProxy=true"
)

if (Test-Path -Path $wslConfigPath) {
    Write-Host "[INFO] Found existing .wslconfig file." -ForegroundColor Green
    $currentContent = Get-Content -Path $wslConfigPath
    
    $hasWsl2Section = $currentContent -match "\[wsl2\]"
    $hasAutoProxy = $currentContent -match "autoProxy\s*=\s*true"
    
    if (-not $hasWsl2Section) {
        Write-Host "[INFO] Adding [wsl2] and autoProxy=true configurations to existing file..." -ForegroundColor Cyan
        Add-Content -Path $wslConfigPath -Value "`n[wsl2]`nautoProxy=true"
    } elseif (-not $hasAutoProxy) {
        Write-Host "[INFO] Found [wsl2] section, but autoProxy=true is missing. Adding it..." -ForegroundColor Cyan
        $newContent = @()
        foreach ($line in $currentContent) {
            $newContent += $line
            if ($line -match "\[wsl2\]") {
                $newContent += "autoProxy=true"
            }
        }
        Set-Content -Path $wslConfigPath -Value $newContent
    } else {
        Write-Host "[SUCCESS] Global .wslconfig is already configured correctly with autoProxy=true." -ForegroundColor Green
    }
} else {
    Write-Host "[INFO] No .wslconfig file found. Creating a new one..." -ForegroundColor Cyan
    New-Item -Path $wslConfigPath -ItemType File -Value ($requiredContent -join "`r`n") -Force | Out-Null
    Write-Host "[SUCCESS] Created $wslConfigPath successfully." -ForegroundColor Green
}

# ---------------------------------------------------------
# Step 2: Deep Verification of WSL Windows Optional Features
# ---------------------------------------------------------
Write-Host "`n[2/4] Verifying WSL System Feature Installation Status..." -ForegroundColor Yellow

# Query true feature state from Windows Online servicing
$wslFeature = Get-WindowsOptionalFeature -Online -FeatureName "Microsoft-Windows-Subsystem-Linux"
$vmFeature = Get-WindowsOptionalFeature -Online -FeatureName "VirtualMachinePlatform"

$wslEnabled = ($wslFeature.State -eq "Enabled")
$vmEnabled = ($vmFeature.State -eq "Enabled")

if ($wslEnabled -and $vmEnabled) {
    Write-Host "[SUCCESS] Windows Features (WSL & Virtual Machine Platform) are fully enabled!" -ForegroundColor Green
    wsl --set-default-version 2 | Out-Null
} else {
    Write-Host "[WARN] WSL Windows Features are missing or incomplete." -ForegroundColor Yellow
    Write-Host "[INFO] Enabling 'Microsoft-Windows-Subsystem-Linux'..." -ForegroundColor Cyan
    Enable-WindowsOptionalFeature -Online -FeatureName "Microsoft-Windows-Subsystem-Linux" -NoRestart | Out-Null
    
    Write-Host "[INFO] Enabling 'VirtualMachinePlatform' (Required for WSL 2)..." -ForegroundColor Cyan
    Enable-WindowsOptionalFeature -Online -FeatureName "VirtualMachinePlatform" -NoRestart | Out-Null

    Write-Host "`n=========================================================" -ForegroundColor Red
    Write-Host "   CRITICAL SYSTEM RESTART REQUIRED                      " -ForegroundColor Red
    Write-Host "Your Windows kernel must be rebooted to activate WSL 2." -ForegroundColor Red
    Write-Host "Please RESTART your computer now." -ForegroundColor Yellow
    Write-Host "After rebooting, open PowerShell as Admin and run this script" -ForegroundColor Yellow
    Write-Host "again to complete the 'breaking-kubernetes' installation." -ForegroundColor Yellow
    Write-Host "=========================================================" -ForegroundColor Red
    Exit
}

# ---------------------------------------------------------
# Step 3: Install & Name default Ubuntu as "breaking-kubernetes"
# ---------------------------------------------------------
$distroName = "breaking-kubernetes"
Write-Host "`n[3/4] Registering Distro: '$distroName'..." -ForegroundColor Yellow

# Check if the custom distro already exists
$existingDistros = wsl --list --quiet 2>$null
if ($existingDistros -match $distroName) {
    Write-Host "[WARN] Distro '$distroName' already exists on this machine!" -ForegroundColor Yellow
    Write-Host "[SUCCESS] Skipping install to preserve existing state. Use 'wsl -d $distroName' to access it." -ForegroundColor Green
} else {
    Write-Host "[INFO] Downloading and installing default Ubuntu image under name '$distroName'..." -ForegroundColor Cyan
    
    try {
        # --no-launch tells WSL to register the distribution quietly in the background 
        # without opening a new console session.
        wsl --install -d Ubuntu --name $distroName --no-launch
        Write-Host "[SUCCESS] Custom distro '$distroName' is successfully installed and registered!" -ForegroundColor Green
    } catch {
        Write-Error "[ERROR] Failed to download/install distro automatically. Check if the Microsoft Store is disabled on your device or if there is a proxy interruption."
        Exit
    }
}

# ---------------------------------------------------------
# Step 4: Verification & Launch Commands
# ---------------------------------------------------------
Write-Host "`n[4/4] Final Environment Scan..." -ForegroundColor Yellow
wsl --list --verbose

Write-Host "`n=========================================================" -ForegroundColor Green
Write-Host "   Environment Registered!                               " -ForegroundColor Green
Write-Host "To enter your isolated workshop container, run:          " -ForegroundColor Green
Write-Host "-->   wsl -d $distroName" -ForegroundColor Yellow
Write-Host "=========================================================" -ForegroundColor Green
