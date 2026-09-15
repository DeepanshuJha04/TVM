<#
.SYNOPSIS

PSApppDeployToolkit - This script performs the installation or uninstallation of an application(s).

.DESCRIPTION

- The script is provided as a template to perform an install or uninstall of an application(s).
- The script either performs an "Install" deployment type or an "Uninstall" deployment type.
- The install deployment type is broken down into 3 main sections/phases: Pre-Install, Install, and Post-Install.

The script dot-sources the AppDeployToolkitMain.ps1 script which contains the logic and functions required to install or uninstall an application.

PSApppDeployToolkit is licensed under the GNU LGPLv3 License - (C) 2023 PSAppDeployToolkit Team (Sean Lillis, Dan Cunningham and Muhammad Mashwani).

This program is free software: you can redistribute it and/or modify it under the terms of the GNU Lesser General Public License as published by the
Free Software Foundation, either version 3 of the License, or any later version. This program is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License
for more details. You should have received a copy of the GNU Lesser General Public License along with this program. If not, see <http://www.gnu.org/licenses/>.

.PARAMETER DeploymentType

The type of deployment to perform. Default is: Install.

.PARAMETER DeployMode

Specifies whether the installation should be run in Interactive, Silent, or NonInteractive mode. Default is: Interactive. Options: Interactive = Shows dialogs, Silent = No dialogs, NonInteractive = Very silent, i.e. no blocking apps. NonInteractive mode is automatically set if it is detected that the process is not user interactive.

.PARAMETER AllowRebootPassThru

Allows the 3010 return code (requires restart) to be passed back to the parent process (e.g. SCCM) if detected from an installation. If 3010 is passed back to SCCM, a reboot prompt will be triggered.

.PARAMETER TerminalServerMode

Changes to "user install mode" and back to "user execute mode" for installing/uninstalling applications for Remote Desktop Session Hosts/Citrix servers.

.PARAMETER DisableLogging

Disables logging to file for the script. Default is: $false.

.EXAMPLE

powershell.exe -Command "& { & '.\Deploy-Application.ps1' -DeployMode 'Silent'; Exit $LastExitCode }"

.EXAMPLE

powershell.exe -Command "& { & '.\Deploy-Application.ps1' -DeploymentType 'Uninstall' -DeployMode 'Silent'; Exit $LastExitCode }"

.INPUTS

None

You cannot pipe objects to this script.

.OUTPUTS

None

This script does not generate any output.

.NOTES

Deploys the twice-monthly Automated .NET Cleanup scheduled task.

- Installs:  C:\Automated_dotNET_Cleanup\dotNET_Cleanup.ps1
             C:\Automated_dotNET_Cleanup\SCCM-DotNETCleanup-Task.xml   (kept for reference/audit)
             C:\Automated_dotNET_Cleanup\Files\dotnet-core-uninstall.msi
- Registers: Scheduled task \Custom\Automated_dotNET_Cleanup from the XML
             (fires 1st & 15th of every month, silently, as SYSTEM;
             StartWhenAvailable means a missed run fires automatically
             the next time the device is back online)
- Uninstalls: unregisters the task and deletes C:\Automated_dotNET_Cleanup\ entirely

Toolkit Exit Code Ranges:
- 60000 - 68999: Reserved for built-in exit codes in Deploy-Application.ps1, Deploy-Application.exe, and AppDeployToolkitMain.ps1
- 69000 - 69999: Recommended for user customized exit codes in Deploy-Application.ps1
- 70000 - 79999: Recommended for user customized exit codes in AppDeployToolkitExtensions.ps1

.LINK

https://psappdeploytoolkit.com
#>


[CmdletBinding()]
Param (
    [Parameter(Mandatory = $false)]
    [ValidateSet('Install', 'Uninstall', 'Repair')]
    [String]$DeploymentType = 'Install',
    [Parameter(Mandatory = $false)]
    [ValidateSet('Interactive', 'Silent', 'NonInteractive')]
    [String]$DeployMode = 'Interactive',
    [Parameter(Mandatory = $false)]
    [switch]$AllowRebootPassThru = $false,
    [Parameter(Mandatory = $false)]
    [switch]$TerminalServerMode = $false,
    [Parameter(Mandatory = $false)]
    [switch]$DisableLogging = $false
)

Try {
    ## Set the script execution policy for this process
    Try {
        Set-ExecutionPolicy -ExecutionPolicy 'ByPass' -Scope 'Process' -Force -ErrorAction 'Stop'
    }
    Catch {
    }

    ##*===============================================
    ##* VARIABLE DECLARATION
    ##*===============================================
    ## Variables: Application
    [String]$appVendor = 'Automated_dotNET_Cleanup'
    [String]$appName = 'Automated_dotNET_Cleanup'
    [String]$appVersion = '1.0'
    [String]$appArch = 'x64'
    [String]$appLang = 'EN'
    [String]$appRevision = '01'
    [String]$appScriptVersion = '1.0.0'
    [String]$appScriptDate = '15/09/2026'
    [String]$appScriptAuthor = 'HCL APF'
    ##*===============================================
    ## Variables: Install Titles (Only set here to override defaults set by the toolkit)
    [String]$installName = 'Automatic_Removal_of_Obsolete_EOL_Unapproved_dotNET_Components_TSKSCH'
    [String]$installTitle = 'Automatic_Removal_of_Obsolete_EOL_Unapproved_dotNET_Components_TSKSCH'

    ##* Do not modify section below
    #region DoNotModify

    ## Variables: Exit Code
    [Int32]$mainExitCode = 0

    ## Variables: Script
    [String]$deployAppScriptFriendlyName = 'Deploy Application'
    [Version]$deployAppScriptVersion = [Version]'3.9.3'
    [String]$deployAppScriptDate = '02/05/2023'
    [Hashtable]$deployAppScriptParameters = $PsBoundParameters

    ## Variables: Environment
    If (Test-Path -LiteralPath 'variable:HostInvocation') {
        $InvocationInfo = $HostInvocation
    }
    Else {
        $InvocationInfo = $MyInvocation
    }
    [String]$scriptDirectory = Split-Path -Path $InvocationInfo.MyCommand.Definition -Parent

    ## Dot source the required App Deploy Toolkit Functions
    Try {
        [String]$moduleAppDeployToolkitMain = "$scriptDirectory\AppDeployToolkit\AppDeployToolkitMain.ps1"
        If (-not (Test-Path -LiteralPath $moduleAppDeployToolkitMain -PathType 'Leaf')) {
            Throw "Module does not exist at the specified location [$moduleAppDeployToolkitMain]."
        }
        If ($DisableLogging) {
            . $moduleAppDeployToolkitMain -DisableLogging
        }
        Else {
            . $moduleAppDeployToolkitMain
        }
    }
    Catch {
        If ($mainExitCode -eq 0) {
            [Int32]$mainExitCode = 60008
        }
        Write-Error -Message "Module [$moduleAppDeployToolkitMain] failed to load: `n$($_.Exception.Message)`n `n$($_.InvocationInfo.PositionMessage)" -ErrorAction 'Continue'
        ## Exit the script, returning the exit code to SCCM
        If (Test-Path -LiteralPath 'variable:HostInvocation') {
            $script:ExitCode = $mainExitCode; Exit
        }
        Else {
            Exit $mainExitCode
        }
    }

    #endregion
    ##* Do not modify section above
    ##*===============================================
    ##* END VARIABLE DECLARATION
    ##*===============================================

    ##*===============================================
    ##* DEPLOYMENT-SPECIFIC VARIABLES
    ##*===============================================
    ## $dirFiles is set by AppDeployToolkitMain.ps1 to "<script folder>\Files"
    [String]$dotNetScriptName  = 'dotNET_Cleanup.ps1'
    [String]$taskXmlName       = 'SCCM-DotNETCleanup-Task.xml'
    [String]$uninstallMsiName  = 'dotnet-core-uninstall.msi'
    [String]$installDir        = 'C:\Automated_dotNET_Cleanup'
    [String]$taskName          = 'Automated_dotNET_Cleanup'
    [String]$taskFolderName    = 'Custom'
    [String]$taskFolderPath    = "\$taskFolderName\"

    ## dotnet-core-uninstall.msi sits alone directly in \Files, which would
    ## otherwise trigger PSADT's zero-config MSI auto-install (it treats a
    ## lone MSI in \Files as "the application" and silently installs it via
    ## Execute-MSI). That MSI is a supporting tool consumed later by
    ## dotNET_Cleanup.ps1, not the thing being deployed here, so zero-config
    ## handling is explicitly disabled.
    $useDefaultMsi = $false

    ##*===============================================
    ##* DEPLOYMENT FUNCTIONS
    ##*===============================================
    Function Install-DotNetCleanupPackage {
        $sourceScript = Join-Path $dirFiles $dotNetScriptName
        $sourceXml    = Join-Path $dirFiles $taskXmlName
        $sourceMsi    = Join-Path $dirFiles $uninstallMsiName

        If (-not (Test-Path -LiteralPath $sourceScript)) { Throw "Missing: $sourceScript" }
        If (-not (Test-Path -LiteralPath $sourceXml))    { Throw "Missing: $sourceXml" }
        If (-not (Test-Path -LiteralPath $sourceMsi))    { Throw "Missing required file: $sourceMsi" }

        ## Step 1: Create destination folder
        If (-not (Test-Path -LiteralPath $installDir)) {
            New-Item -Path $installDir -ItemType Directory -Force | Out-Null
        }

        ## Step 2: Copy files (unmodified). The MSI goes into a Files\
        ## subfolder on the endpoint too, matching what dotNET_Cleanup.ps1
        ## expects relative to itself.
        Copy-Item -LiteralPath $sourceScript -Destination (Join-Path $installDir $dotNetScriptName) -Force
        Copy-Item -LiteralPath $sourceXml -Destination (Join-Path $installDir $taskXmlName) -Force

        $destFilesDir = Join-Path $installDir 'Files'
        If (-not (Test-Path -LiteralPath $destFilesDir)) {
            New-Item -Path $destFilesDir -ItemType Directory -Force | Out-Null
        }
        Copy-Item -LiteralPath $sourceMsi -Destination (Join-Path $destFilesDir $uninstallMsiName) -Force

        If (-not (Test-Path -LiteralPath (Join-Path $destFilesDir $uninstallMsiName))) {
            Throw "$uninstallMsiName failed to copy to $destFilesDir"
        }

        ## Step 3: Harden NTFS permissions - Admins/SYSTEM full control,
        ## standard users read & execute only (no tampering, no deletion)
        $acl = Get-Acl -LiteralPath $installDir
        $acl.SetAccessRuleProtection($true, $false)
        $acl.Access | ForEach-Object { $acl.RemoveAccessRule($_) | Out-Null }
        @(
            New-Object System.Security.AccessControl.FileSystemAccessRule('NT AUTHORITY\SYSTEM', 'FullControl', 'ContainerInherit,ObjectInherit', 'None', 'Allow')
            New-Object System.Security.AccessControl.FileSystemAccessRule('BUILTIN\Administrators', 'FullControl', 'ContainerInherit,ObjectInherit', 'None', 'Allow')
            New-Object System.Security.AccessControl.FileSystemAccessRule('BUILTIN\Users', 'ReadAndExecute', 'ContainerInherit,ObjectInherit', 'None', 'Allow')
        ) | ForEach-Object { $acl.AddAccessRule($_) }
        Set-Acl -LiteralPath $installDir -AclObject $acl

        ## Step 4: Register the scheduled task from XML
        $xmlContent = Get-Content -LiteralPath (Join-Path $installDir $taskXmlName) -Raw -Encoding Unicode
        If ([string]::IsNullOrWhiteSpace($xmlContent)) {
            $xmlContent = Get-Content -LiteralPath (Join-Path $installDir $taskXmlName) -Raw
        }
        Register-ScheduledTask -TaskName $taskName -TaskPath $taskFolderPath -Xml $xmlContent -Force | Out-Null

        If (-not (Get-ScheduledTask -TaskName $taskName -TaskPath $taskFolderPath -ErrorAction SilentlyContinue)) {
            Throw 'Task registration did not take effect'
        }
    }

    Function Uninstall-DotNetCleanupPackage {
        ## Step 1: Remove the scheduled task
        $task = Get-ScheduledTask -TaskName $taskName -TaskPath $taskFolderPath -ErrorAction SilentlyContinue
        If ($task) {
            Unregister-ScheduledTask -TaskName $taskName -TaskPath $taskFolderPath -Confirm:$false
        }

        ## Step 2: Remove the \Custom task folder if it's now empty
        Try {
            $service = New-Object -ComObject 'Schedule.Service'
            $service.Connect()
            $folder = $service.GetFolder("\$taskFolderName")
            If (($folder.GetTasks(0) | Measure-Object).Count -eq 0) {
                $service.GetFolder('\').DeleteFolder($taskFolderName, 0)
            }
        }
        Catch {
            ## Folder already gone or never existed - not fatal
        }

        ## Step 3: Remove the local copy entirely (clean slate for re-deployment)
        If (Test-Path -LiteralPath $installDir) {
            Remove-Item -LiteralPath $installDir -Recurse -Force -ErrorAction Stop
        }
    }

    If ($deploymentType -ine 'Uninstall' -and $deploymentType -ine 'Repair') {
        ##*===============================================
        ##* INSTALLATION
        ##*===============================================
        [String]$installPhase = 'Installation'

        Try {
            Install-DotNetCleanupPackage
        }
        Catch {
            [Int32]$mainExitCode = 69001
            Throw
        }
    }
    ElseIf ($deploymentType -ieq 'Uninstall') {
        ##*===============================================
        ##* UNINSTALLATION
        ##*===============================================
        [String]$installPhase = 'Uninstallation'

        Try {
            Uninstall-DotNetCleanupPackage
        }
        Catch {
            [Int32]$mainExitCode = 69002
            Throw
        }
    }
    ElseIf ($deploymentType -ieq 'Repair') {
        ##*===============================================
        ##* REPAIR
        ##*===============================================
        [String]$installPhase = 'Repair'

        Try {
            Try { Uninstall-DotNetCleanupPackage } Catch { }
            Install-DotNetCleanupPackage
        }
        Catch {
            [Int32]$mainExitCode = 69003
            Throw
        }
    }
    ##*===============================================
    ##* END SCRIPT BODY
    ##*===============================================

    ## Call the Exit-Script function to perform final cleanup operations
    Exit-Script -ExitCode $mainExitCode
}
Catch {
    [Int32]$mainExitCode = If ($mainExitCode -ne 0) { $mainExitCode } Else { 69099 }
    Try {
        Exit-Script -ExitCode $mainExitCode
    }
    Catch {
        Exit $mainExitCode
    }
}
