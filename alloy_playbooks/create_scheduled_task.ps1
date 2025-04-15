<#
.SYNOPSIS
Creates scheduled task to export installed software info
#>

# Run this script as Administrator

# Configuration
$scriptPath = "C:\scripts\get_installed_software.ps1"
$taskName = "Export Installed Software"

# Verify admin rights
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Warning "Please run this script as Administrator"
    exit 1
}

# Create directories if missing
if (-not (Test-Path -Path "C:\scripts")) {
    New-Item -ItemType Directory -Path "C:\scripts" -Force | Out-Null
}

if (-not (Test-Path -Path "C:\metrics")) {
    New-Item -ItemType Directory -Path "C:\metrics" -Force | Out-Null
}

# Create task action
$action = New-ScheduledTaskAction `
    -Execute "powershell.exe" `
    -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`""

# Create task trigger (runs daily at 3 AM)
$trigger = New-ScheduledTaskTrigger `
    -Daily `
    -At 3am

# Configure task settings
$settings = New-ScheduledTaskSettingsSet `
    -StartWhenAvailable `
    -DontStopOnIdleEnd `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries

# Create task principal (run as SYSTEM)
$principal = New-ScheduledTaskPrincipal `
    -UserId "NT AUTHORITY\SYSTEM" `
    -LogonType ServiceAccount `
    -RunLevel Highest

# Register the task
try {
    Register-ScheduledTask `
        -TaskName $taskName `
        -Action $action `
        -Trigger $trigger `
        -Settings $settings `
        -Principal $principal `
        -Force
    
    Write-Host "Successfully created scheduled task '$taskName'" -ForegroundColor Green
    
    # Verify task creation
    $task = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
    if ($task) {
        Write-Host "Task configuration:"
        $task | Format-List *
    } else {
        Write-Warning "Task creation verification failed"
    }
} catch {
    Write-Error "Failed to create task: $_"
    exit 1
}
