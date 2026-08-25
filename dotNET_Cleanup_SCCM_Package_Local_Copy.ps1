#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Single install/uninstall entry point for the Automated .NET Cleanup deployment.
    Invoked via Install.bat (-Mode Install) or Uninstall.bat (-Mode Uninstall).

.DESCRIPTION
    INSTALL:
      - Copies Automated_Cleanup_Script_for_Outdated_dotNET.ps1 (+ the task XML,
        + dotnet-core-uninstall.msi if present) into C:\Automated_dotNET_Cleanup\
      - Locks the folder down so standard users can read/execute but not modify
      - Registers the scheduled task \Custom\Automated_dotNET_Cleanup from the XML
        (fires 1st & 15th of every month, silently, as SYSTEM; StartWhenAvailable
        means a missed run fires automatically the next time the device is online)
      - Writes an install marker (InstallInfo.json) for SCCM detection

    UNINSTALL:
      - Simple, complete rollback: unregisters the scheduled task, removes the
        \Custom task folder if it's left empty, and deletes C:\Automated_dotNET_Cleanup\
        entirely. Use this to stop the schedule on a device or to clear the way
        for pushing an updated package.

.NOTES
    Run context : SYSTEM (SCCM default for Package/Program or Application deployments)
    Exit codes  : 0 = success | 1603 = failure (standard SCCM/MSI convention)
#>

param(
    [ValidateSet('Install', 'Uninstall')]
    [string]$Mode = 'Install'
)

$ErrorActionPreference = 'Stop'

# ------------------------------------------------------------------
# Common variables
# ------------------------------------------------------------------
$SourceRoot      = Split-Path -Parent $MyInvocation.MyCommand.Definition
$InstallDir      = 'C:\Automated_dotNET_Cleanup'
$ScriptFileName  = 'Automated_Cleanup_Script_for_Outdated_dotNET.ps1'
$XmlFileName     = 'SCCM-DotNETCleanup-Task.xml'
$OptionalMsiName = 'dotnet-core-uninstall.msi'
$TaskName        = 'Automated_dotNET_Cleanup'
$TaskFolderName  = 'Custom'
$TaskFolderPath  = "\$TaskFolderName\"
$MarkerFile      = Join-Path $InstallDir 'InstallInfo.json'
$PackageVersion  = '1.0.0'

# Log outside C:\Automated_dotNET_Cleanup so uninstall (which deletes that
# folder) never wipes out its own log
$LogDir  = if (Test-Path "$env:windir\CCM\Logs") { "$env:windir\CCM\Logs" } else { $env:TEMP }
$LogFile = Join-Path $LogDir ("dotNETCleanup_{0}_{1}.log" -f $Mode, (Get-Date -Format 'yyyyMMdd_HHmmss'))

function Write-Log {
    param([string]$Message, [string]$Level = 'INFO')
    $line = "[{0}] [{1}] {2}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Level, $Message
    Write-Output $line
    try { Add-Content -Path $LogFile -Value $line -ErrorAction SilentlyContinue } catch {}
}

Write-Log "===== Script Mode: $Mode ====="

# ============================================================
# INSTALL MODE
# ============================================================
if ($Mode -eq 'Install') {
    try {
        Write-Log "===== Starting Installation (package v$PackageVersion) ====="
        Write-Log "Running as: $([Security.Principal.WindowsIdentity]::GetCurrent().Name)"

        $sourceScript = Join-Path $SourceRoot $ScriptFileName
        $sourceXml    = Join-Path $SourceRoot $XmlFileName
        $sourceMsi    = Join-Path $SourceRoot $OptionalMsiName

        if (-not (Test-Path -LiteralPath $sourceScript)) { throw "Cleanup script not found: $sourceScript" }
        if (-not (Test-Path -LiteralPath $sourceXml))    { throw "Task XML not found: $sourceXml" }

        # Step 1: Create destination folder
        if (-not (Test-Path -LiteralPath $InstallDir)) {
            Write-Log "Creating folder: $InstallDir"
            New-Item -Path $InstallDir -ItemType Directory -Force | Out-Null
        }
        else {
            Write-Log "Folder already exists: $InstallDir"
        }

        # Step 2: Copy files (unmodified)
        Write-Log "Copying '$ScriptFileName' to '$InstallDir'"
        Copy-Item -LiteralPath $sourceScript -Destination (Join-Path $InstallDir $ScriptFileName) -Force

        Write-Log "Copying '$XmlFileName' to '$InstallDir' (kept for reference/audit)"
        Copy-Item -LiteralPath $sourceXml -Destination (Join-Path $InstallDir $XmlFileName) -Force

        if (Test-Path -LiteralPath $sourceMsi) {
            Write-Log "Found $OptionalMsiName - copying to '$InstallDir'"
            Copy-Item -LiteralPath $sourceMsi -Destination (Join-Path $InstallDir $OptionalMsiName) -Force
        }
        else {
            Write-Log "$OptionalMsiName not shipped with this package - cleanup script will use its direct MSI/registry fallback method"
        }

        # Step 3: Harden NTFS permissions - Admins/SYSTEM full control,
        # standard users read & execute only (no tampering, no deletion)
        Write-Log "Hardening NTFS permissions on '$InstallDir'"
        $acl = Get-Acl -LiteralPath $InstallDir
        $acl.SetAccessRuleProtection($true, $false)
        $acl.Access | ForEach-Object { $acl.RemoveAccessRule($_) | Out-Null }
        @(
            New-Object System.Security.AccessControl.FileSystemAccessRule('NT AUTHORITY\SYSTEM', 'FullControl', 'ContainerInherit,ObjectInherit', 'None', 'Allow')
            New-Object System.Security.AccessControl.FileSystemAccessRule('BUILTIN\Administrators', 'FullControl', 'ContainerInherit,ObjectInherit', 'None', 'Allow')
            New-Object System.Security.AccessControl.FileSystemAccessRule('BUILTIN\Users', 'ReadAndExecute', 'ContainerInherit,ObjectInherit', 'None', 'Allow')
        ) | ForEach-Object { $acl.AddAccessRule($_) }
        Set-Acl -LiteralPath $InstallDir -AclObject $acl

        # Step 4: Register the scheduled task from XML
        Write-Log "Registering scheduled task '$TaskFolderPath$TaskName'"
        $xmlContent = Get-Content -LiteralPath (Join-Path $InstallDir $XmlFileName) -Raw -Encoding Unicode
        if ([string]::IsNullOrWhiteSpace($xmlContent)) {
            $xmlContent = Get-Content -LiteralPath (Join-Path $InstallDir $XmlFileName) -Raw
        }
        Register-ScheduledTask -TaskName $TaskName -TaskPath $TaskFolderPath -Xml $xmlContent -Force | Out-Null

        $registered = Get-ScheduledTask -TaskName $TaskName -TaskPath $TaskFolderPath -ErrorAction Stop
        Write-Log "Task registered successfully. State: $($registered.State)"

        # Step 5: Write install marker for SCCM detection
        [ordered]@{
            PackageVersion = $PackageVersion
            InstalledOn    = (Get-Date).ToString('o')
            InstalledBy    = [Security.Principal.WindowsIdentity]::GetCurrent().Name
            TaskName       = $TaskName
            TaskPath       = $TaskFolderPath
            ScriptPath     = (Join-Path $InstallDir $ScriptFileName)
        } | ConvertTo-Json | Set-Content -LiteralPath $MarkerFile -Encoding UTF8

        Write-Log "===== Installation Completed ====="
        exit 0
    }
    catch {
        Write-Log "INSTALL FAILED: $($_.Exception.Message)" -Level 'ERROR'
        exit 1603
    }
}

# ============================================================
# UNINSTALL MODE
# ============================================================
elseif ($Mode -eq 'Uninstall') {
    try {
        Write-Log "===== Starting Uninstallation ====="

        # Step 1: Remove the scheduled task
        $task = Get-ScheduledTask -TaskName $TaskName -TaskPath $TaskFolderPath -ErrorAction SilentlyContinue
        if ($task) {
            Unregister-ScheduledTask -TaskName $TaskName -TaskPath $TaskFolderPath -Confirm:$false
            Write-Log "Task '$TaskName' removed."
        }
        else {
            Write-Log "Task not found or already removed."
        }

        # Step 2: Remove the \Custom task folder if it's now empty
        try {
            $service = New-Object -ComObject 'Schedule.Service'
            $service.Connect()
            $folder = $service.GetFolder("\$TaskFolderName")
            if (($folder.GetTasks(0) | Measure-Object).Count -eq 0) {
                $service.GetFolder('\').DeleteFolder($TaskFolderName, 0)
                Write-Log "Folder '\$TaskFolderName' removed (was empty)."
            }
            else {
                Write-Log "Folder '\$TaskFolderName' still has other tasks - leaving it in place."
            }
        }
        catch {
            Write-Log "Task folder '\$TaskFolderName' does not exist or is already gone."
        }

        # Step 3: Remove the local copy entirely (clean slate for re-deployment)
        if (Test-Path -LiteralPath $InstallDir) {
            Remove-Item -LiteralPath $InstallDir -Recurse -Force -ErrorAction Stop
            Write-Log "Folder '$InstallDir' deleted."
        }
        else {
            Write-Log "Folder '$InstallDir' not found - nothing to delete."
        }

        Write-Log "===== Uninstallation Completed ====="
        exit 0
    }
    catch {
        Write-Log "UNINSTALL FAILED: $($_.Exception.Message)" -Level 'ERROR'
        exit 1603
    }
}

# ============================================================
# INVALID MODE
# ============================================================
else {
    Write-Log "Invalid mode. Use -Mode Install or -Mode Uninstall" -Level 'ERROR'
    exit 1
}
