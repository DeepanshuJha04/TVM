#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Silent install/uninstall entry point for the Automated .NET Cleanup deployment.
    Invoked via Install.bat (-Mode Install) or Uninstall.bat (-Mode Uninstall).

.DESCRIPTION
    INSTALL:
      - Copies Deploy-Application.ps1, SCCM-DotNETCleanup-Task.xml, and the
        Files\ folder (containing dotnet-core-uninstall.msi) into
        C:\Automated_dotNET_Cleanup\, preserving the Files\ subfolder structure
      - Locks the folder down so standard users can read/execute but not modify
      - Registers the scheduled task \Custom\Automated_dotNET_Cleanup from the XML
        (fires 1st & 15th of every month, silently, as SYSTEM; StartWhenAvailable
        means a missed run fires automatically the next time the device is online)

    UNINSTALL:
      - Unregisters the scheduled task, removes the \Custom task folder if left
        empty, and deletes C:\Automated_dotNET_Cleanup\ entirely.

    This script produces NO console output and writes NO log files - it
    communicates success/failure purely via process exit code, per SCCM
    silent-install requirements. Exit code is the only signal SCCM reads.

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
$SourceRoot       = Split-Path -Parent $MyInvocation.MyCommand.Definition
$InstallDir       = 'C:\Automated_dotNET_Cleanup'
$ScriptFileName   = 'Deploy-Application.ps1'
$XmlFileName      = 'SCCM-DotNETCleanup-Task.xml'
$FilesFolderName  = 'Files'
$UninstallMsiName = 'dotnet-core-uninstall.msi'
$TaskName         = 'Automated_dotNET_Cleanup'
$TaskFolderName   = 'Custom'
$TaskFolderPath   = "\$TaskFolderName\"

# ============================================================
# INSTALL MODE
# ============================================================
if ($Mode -eq 'Install') {
    try {
        $sourceScript = Join-Path $SourceRoot $ScriptFileName
        $sourceXml    = Join-Path $SourceRoot $XmlFileName
        $sourceFiles  = Join-Path $SourceRoot $FilesFolderName
        $sourceMsi    = Join-Path $sourceFiles $UninstallMsiName

        if (-not (Test-Path -LiteralPath $sourceScript)) { throw "Missing: $sourceScript" }
        if (-not (Test-Path -LiteralPath $sourceXml))    { throw "Missing: $sourceXml" }
        if (-not (Test-Path -LiteralPath $sourceFiles))  { throw "Missing: $sourceFiles" }
        if (-not (Test-Path -LiteralPath $sourceMsi))    { throw "Missing required file: $sourceMsi" }

        # Step 1: Create destination folder
        if (-not (Test-Path -LiteralPath $InstallDir)) {
            New-Item -Path $InstallDir -ItemType Directory -Force | Out-Null
        }

        # Step 2: Copy files (unmodified), preserving Files\ subfolder structure
        Copy-Item -LiteralPath $sourceScript -Destination (Join-Path $InstallDir $ScriptFileName) -Force
        Copy-Item -LiteralPath $sourceXml -Destination (Join-Path $InstallDir $XmlFileName) -Force

        $destFiles = Join-Path $InstallDir $FilesFolderName
        if (-not (Test-Path -LiteralPath $destFiles)) {
            New-Item -Path $destFiles -ItemType Directory -Force | Out-Null
        }
        Copy-Item -Path (Join-Path $sourceFiles '*') -Destination $destFiles -Recurse -Force

        # Confirm the mandatory MSI actually landed on disk
        if (-not (Test-Path -LiteralPath (Join-Path $destFiles $UninstallMsiName))) {
            throw "dotnet-core-uninstall.msi failed to copy to $destFiles"
        }

        # Step 3: Harden NTFS permissions - Admins/SYSTEM full control,
        # standard users read & execute only (no tampering, no deletion)
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
        $xmlContent = Get-Content -LiteralPath (Join-Path $InstallDir $XmlFileName) -Raw -Encoding Unicode
        if ([string]::IsNullOrWhiteSpace($xmlContent)) {
            $xmlContent = Get-Content -LiteralPath (Join-Path $InstallDir $XmlFileName) -Raw
        }
        Register-ScheduledTask -TaskName $TaskName -TaskPath $TaskFolderPath -Xml $xmlContent -Force | Out-Null

        if (-not (Get-ScheduledTask -TaskName $TaskName -TaskPath $TaskFolderPath -ErrorAction SilentlyContinue)) {
            throw "Task registration did not take effect"
        }

        exit 0
    }
    catch {
        exit 1603
    }
}

# ============================================================
# UNINSTALL MODE
# ============================================================
elseif ($Mode -eq 'Uninstall') {
    try {
        # Step 1: Remove the scheduled task
        $task = Get-ScheduledTask -TaskName $TaskName -TaskPath $TaskFolderPath -ErrorAction SilentlyContinue
        if ($task) {
            Unregister-ScheduledTask -TaskName $TaskName -TaskPath $TaskFolderPath -Confirm:$false
        }

        # Step 2: Remove the \Custom task folder if it's now empty
        try {
            $service = New-Object -ComObject 'Schedule.Service'
            $service.Connect()
            $folder = $service.GetFolder("\$TaskFolderName")
            if (($folder.GetTasks(0) | Measure-Object).Count -eq 0) {
                $service.GetFolder('\').DeleteFolder($TaskFolderName, 0)
            }
        }
        catch {
            # Folder already gone or never existed - not fatal
        }

        # Step 3: Remove the local copy entirely (clean slate for re-deployment)
        if (Test-Path -LiteralPath $InstallDir) {
            Remove-Item -LiteralPath $InstallDir -Recurse -Force -ErrorAction Stop
        }

        exit 0
    }
    catch {
        exit 1603
    }
}

# ============================================================
# INVALID MODE
# ============================================================
else {
    exit 1
}
