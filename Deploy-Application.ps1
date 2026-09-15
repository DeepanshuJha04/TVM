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

powershell.exe -Command "& { & '.\Deploy-Application.ps1' -AllowRebootPassThru; Exit $LastExitCode }"

.EXAMPLE

powershell.exe -Command "& { & '.\Deploy-Application.ps1' -DeploymentType 'Uninstall'; Exit $LastExitCode }"

.EXAMPLE

Deploy-Application.exe -DeploymentType "Install" -DeployMode "Silent"

.INPUTS

None

You cannot pipe objects to this script.

.OUTPUTS

None

This script does not generate any output.

.NOTES

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
    [String]$appScriptDate = '14/09/2026'
    [String]$appScriptAuthor = 'HCL APF'
    [String]$sourceFolder = 'C:\Windows\'							  
	[String]$logFolder = $sourceFolder+'logs\'
    [String]$logFile = ''
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

    If ($deploymentType -ine 'Uninstall' -and $deploymentType -ine 'Repair') {
        ##*===============================================
        ##* PRE-INSTALLATION
        ##*===============================================
        [String]$installPhase = 'Pre-Installation'

        ## Show Welcome Message, close Internet Explorer if required, allow up to 3 deferrals, verify there is enough disk space to complete the install, and persist the prompt
        #Show-InstallationWelcome -CloseApps 'iexplore' -AllowDefer -DeferTimes 3 -CheckDiskSpace -PersistPrompt

        ## Show Progress Message (with the default message)
        ##Show-InstallationProgress

        ##If(Get-InstalledApplication -ProductCode '{AC76BA86-7AD7-1033-7B44-AC0F074E4100}')
        ##{
         ##Execute-MSI -Action Uninstall -Path '{AC76BA86-7AD7-1033-7B44-AC0F074E4100}'
        ##}

        ## <Perform Pre-Installation tasks here>
        

        ##*===============================================
        ##* INSTALLATION
        ##*===============================================
        [String]$installPhase = 'Installation'

        ## Handle Zero-Config MSI Installations
        If ($useDefaultMsi) {
            [Hashtable]$ExecuteDefaultMSISplat = @{ Action = 'Install'; Path = $defaultMsiFile }; If ($defaultMstFile) {
                $ExecuteDefaultMSISplat.Add('Transform', $defaultMstFile)
            }
            Execute-MSI @ExecuteDefaultMSISplat; If ($defaultMspFiles) {
                $defaultMspFiles | ForEach-Object { Execute-MSI -Action 'Patch' -Path $_ }
            }
        }


        ## <Perform Installation tasks here>

        $SourceRoot       = "$Dirfiles\"
        $InstallDir       = "C:\Automated_dotNET_Cleanup"
        $ScriptFileName   = "dotNET_Cleanup.ps1"
        $XmlFileName      = "SCCM-DotNETCleanup-Task.xml"
        $FilesFolderName  = "Files"
        $UninstallMsiName = "dotnet-core-uninstall.msi"
        $TaskName         = "Automated_dotNET_Cleanup"
        $TaskFolderName   = "Custom"
        $TaskFolderPath   = "\$TaskFolderName\"
        
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
Try{   
    
        ## EXECUTE-MSI (INSTALLATION)
        ## Executes msiexec.exe to perform the following actions for MSI & MSP files and MSI product codes: install, uninstall, patch, repair, active setup.
        ## Example: Execute-MSI  -Action 'Install' -Path "$Dirfiles\XXXXX.msi" -Transform "$Dirfiles\XXXXX.mst" -Parameters ""
        #WriteLogFile " $installPhase : $appName installation started"
        #$ReturnCode = Execute-MSI -Action 'Install' -Path "$Dirfiles\XXXXX.msi" -Parameters "ALLUSERS=1 /l*v $logFolder$appPkgName_$installPhase.log REBOOT=ReallySuppress /qn" -PassThru
        #$ExitCode = $ReturnCode.ExitCode
        #WriteLogFile " $installPhase : $appName installation completed with exit code: $ExitCode"

        ## EXECUTE-PROCESS (INSTALLATION)
        ## Execute a process with optional arguments, working directory, window style.
        ## Example: Execute-Process -Path "$Dirfiles\setup.exe" -Parameters '/S' -WindowStyle 'Hidden'


}

Catch
{
        #WriteLogFile "Installation is failed with exit code :$ExitCode" -Source 'Installation'
       # $ExitCode = $ReturnCode.ExitCode
       # exit-script -Exitcode $ExitCode
}


        ##*===============================================
        ##* POST-INSTALLATION
        ##*===============================================
       [String]$installPhase = 'Post-Installation'

        ## <Perform Post-Installation tasks here>

         
         
Try{  
        ## IMPORT REG-FILE
		## Example: Execute-Process -FilePath “reg.exe” -Parameters “import $dirSupportFiles\test.reg” -PassThru
		# WriteLogFile " $installPhase : Import REG-File"
		# Execute-Process -FilePath “reg.exe” -Parameters “import $dirFile\test.reg” -PassThru
        
		## SET-REGISTRYKEY
		## Creates a registry key name, value, and value data; it sets the same if it already exists.
		## Example: Set-RegistryKey -Key 'HKEY_LOCAL_MACHINE\SOFTWARE' -Name 'Application' -Type 'Dword' -Value '1'
		# WriteLogFile " $installPhase : Set REG-Key"
		# Set-RegistryKey [-Key] <String> [[-Name] <String>] [[-Value] <Object>] [[-Type] {Unknown | String | ExpandString | Binary | DWord | MultiString | QWord | None}] [[-SID] <String>]

		## INVOKE-HKCUREGISTRYSETTINGSFORALLUSERS
		## Set current user registry settings for all current users and any new users in the future
		## Example: Set-RegistryKey -Key 'HKCU\Software\Microsoft\Office\14.0\Common' -Name 'qmenable' -Value 0 -Type DWord -SID $UserProfile.SID
		# WriteLogFile " $installPhase : Invoke HKCU for all users"
		# $HKCURegistrySettings = {Set-RegistryKey -Key 'HKCU\Software\Microsoft\Office\14.0\Common' -Name 'qmenable' -Value '0' -Type 'DWord' -SID $UserProfile.SID}
		# Invoke-HKCURegistrySettingsForAllUsers -RegistrySettings $HKCURegistrySettings

		## COPY-FILE
		## Copy a file or group of files to a destination path.
		## Example: Copy-File -Path "$dirSupportFiles\MyApp.ini" -Destination "$envWindir\MyApp.ini"
		# WriteLogFile " $installPhase : Copy File"
		# Copy-File "$Dirfiles\<Filename>" -Destination "<Path\Filename>"

        <# or 
        $ProfilePaths = Get-UserProfiles | Select-Object -ExpandProperty 'ProfilePath'
        ForEach ($Path in $ProfilePaths)
        {
            $testPath = Test-Path "$Path\AppData\Roaming\Notepad++"
            if ($testpath)
            {
              Copy-File -path "$dirFiles\config.xml" -destination "$path\AppData\Roaming\Notepad++\config.xml" -Recurse
            }
            else{
               New-Item -ItemType Directory -Force -Path "$path\AppData\Roaming\Notepad++"
               Copy-File -path "$dirFiles\config.xml" -destination "$path\AppData\Roaming\Notepad++\config.xml" -Recurse
                }
	    }#>
        
        

        
        

        ## COPY-FOLDER
        


		## CREATE FIREWALL-RULE
		## Example: New-NetFirewallRule -DisplayName "Allow Authenticated Messenger" -Direction Inbound -Program "C:\Program Files (x86)\Messenger\msmsgs.exe" -Profile Domain -Action Allow
		# WriteLogFile " $installPhase : Windows Firewall"
		# New-NetFirewallRule -DisplayName "" -Direction Inbound -Program "" -Profile Domain -Action Allow

		## DELETE-DESKTOP-SHORTCUT
		## Remove unneeded Desktop Shortcut
		## Example: Remove-Item -Path "$env:PUBLIC\desktop\xxx.lnk"
		# WriteLogFile " $installPhase : Delete Shortcut"
		# Remove-Item -Path "$env:PUBLIC\desktop\xxx.lnk"

        <#    OR

        $FileToCheck =	"$EnvPublic\Desktop\Autodesk Desktop App.lnk"
		If (Test-Path $FileToCheck){
			Remove-File -path "$EnvPublic\Desktop\Autodesk Desktop App.lnk"
			}

        $FileToCheck = "$EnvProgramData\Microsoft\Windows\Start Menu\Programs\Autodesk\Uninstall Tool.lnk"
		If (Test-Path $FileToCheck){
			Remove-File -path "$EnvProgramData\Microsoft\Windows\Start Menu\Programs\Autodesk\Uninstall Tool.lnk"
			}

        #>

        ## REMOVE-FILE
        ## Removes one or more items from a given path on the filesystem.
        ## Example: 'C:\Windows\Downloaded Program Files\Temp.inf'
        # if (Test-Path -Path "C:\PATH") {
		#    WriteLogFile " $installPhase : Remove File"
        #    Remove-File [-Path] <String> [[-ContinueOnError] <Boolean>] [<CommonParameters>]
        # }

        ## REMOVE-FOLDER
        ## Remove folder and files if they exist.
        ## Example: Remove-Folder -Path "$envWinDir\Downloaded Program Files"
        # if (Test-Path -Path "C:\PATH") {
		#    WriteLogFile " $installPhase : Remove Folder"
        #    Remove-Folder [-Path] <String> [[-ContinueOnError] <Boolean>] [<CommonParameters>]
        #    Remove-Folder -Path "$env:ProgramFiles\Notepad++"
        # }

        <#  or
        $ProfilePaths = Get-UserProfiles | Select-Object -ExpandProperty 'ProfilePath'
        ForEach ($Path in $ProfilePaths) {
        $testPath = Test-Path "$Path\AppData\Roaming\Notepad++"
        if ($testpath)
        {
        Remove-Folder -Path "$path\AppData\Roaming\Notepad++" -ContinueOnError $true   
        }
	    }  
        #>

		## EXECUTE-PROCESSASUSER
		## Execute a process with a logged in user account, by using a scheduled task, to provide interaction with user in the SYSTEM context.
		## Example: Execute-ProcessAsUser -Path "$PSHOME\powershell.exe" -Parameters "-Command & { & `"C:\Test\Script.ps1`"; Exit `$LastExitCode }" -Wait
		# WriteLogFile " $installPhase : Execute Process as User"
		# Execute-ProcessAsUser [[-UserName] <String>] [-Path] <String> [[-Parameters] <String>] [-SecureParameters] [[-RunLevel] <String>] [-Wait] [-PassThru] [[-ContinueOnError] <Boolean>]
        
		## SET-ITEMPERMISSION
		## Allow you to easily change permissions on files or folders
		## Example: Set-ItemPermission -Path "C:\Temp" -User "DOMAIN\John", "BUILTIN\Utilisateurs" -Permission FullControl -Inheritance ObjectInherit,ContainerInherit
		# $Path = 'C:\FOLDERNAME'
		# WriteLogFile " $installPhase : Set-Permission for Path: $Path"
		# Set-ItemPermission -Path "$Path" -User "BUILTIN\Users" -Permission FullControl -Inheritance ObjectInherit,ContainerInherit -Method Add
        # Execute-Process -Path "$envSystem32Directory\iCacls.exe" -Parameters """$envProgramFilesX86\Adobe\test 2.1.5.0"" /Q /grant:r Users:(OI)(CI)M"

        ##DRIVERS INSTALL:
       
       #DPINST:
        #Execute-Process -Path "$dirFiles\driver\64\eng\DPInst.exe" -Parameters "/U `"$envWinDir\System32\DriverStore\FileRepository\brprca80.inf_amd64_fb43851a75d52d81\brprca80.inf`" /S"

       #PNPUTIL UTILITY:
        #Execute-Process -Path "$envWinDir\System32\pnputil.exe" -Parameters "/add-driver `"$dirFiles\driver\64\eng\*.inf`" /install"

           
        #Certificate INSTALL
         #Execute-Process -Path "certutil.exe" -Parameters "-f -addstore Root `"$dirFiles\File.cer`""	
        
        #IMport certificate:
        #Import-Certificate -Filepath "$dirFiles\File.cer" -CertStoreLocation cert:\LocalMachine\Root


       ## WriteLogFile "installation completed successfully"
        ##writeLogFile "------------------------------------------------------------------------------"
}


Catch
{
      ##WriteLogFile "Post-Installation is failed with exit code :$ExitCode" -Source 'Installation'
     ## $ExitCode = $ReturnCode.ExitCode
     ## exit-script -Exitcode $ExitCode
}
    }

    ElseIf ($deploymentType -ieq 'Uninstall') {
        ##*===============================================
        ##* PRE-UNINSTALLATION
        ##*===============================================
        [String]$installPhase = 'Pre-Uninstallation'

        ## Show Welcome Message, close Internet Explorer with a 60 second countdown before automatically closing
        

        ## Show Progress Message (with the default message)
        ##Show-InstallationProgress

        ## <Perform Pre-Uninstallation tasks here>
        
        
        
        ##*===============================================
        ##* UNINSTALLATION
        ##*===============================================
        [String]$installPhase = 'Uninstallation'

        ## Handle Zero-Config MSI Uninstallations
        If ($useDefaultMsi) {
            [Hashtable]$ExecuteDefaultMSISplat = @{ Action = 'Uninstall'; Path = $defaultMsiFile }; If ($defaultMstFile) {
                $ExecuteDefaultMSISplat.Add('Transform', $defaultMstFile)
            }
            Execute-MSI @ExecuteDefaultMSISplat
        }

        ## <Perform Uninstallation tasks here>
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
        
        
        

Try{
        ## Executes msiexec.exe to perform the following actions for MSI & MSP files and MSI product codes: install, uninstall, patch, repair, active setup.
        ## Example: Execute-MSI  -Action 'Install' -Path "$Dirfiles\XXXXX.msi" -Tansform "$Dirfiles\XXXXX.mst" -Parameters "ALLUSERS=1 /l*v $logFolder$appPkgName"
        # WriteLogFile " $installPhase : $appName uninstallation started"
        # $ReturnCode = Execute-MSI -Action 'Uninstall' -Path "$MSIProductCode" -Parameters "/l*v $logFolder$appPkgName_$installPhase.log REBOOT=ReallySuppress /qn" -PassThru
        # $ExitCode = $ReturnCode.ExitCode
        # WriteLogFile " $installPhase : $appName uninstallation completed with exit code: $ExitCode"

        ## EXECUTE-PROCESS (UNINSTALL)
        ## Execute a process with optional arguments, working directory, window style.
        ## Example: Execute-Process -Path "C:\Program Files (x86)\xxxx\uninst.exe" -Parameters '/S' -WindowStyle 'Hidden'

      
                
}

  
Catch
{
     ## WriteLogFile "unInstallation is failed with exit code :$ExitCode" -Source 'unInstallation'
     ## $ExitCode = $ReturnCode.ExitCode
      ##exit-script -Exitcode $ExitCode
}
        ##*===============================================
        ##* POST-UNINSTALLATION
        ##*===============================================
        [String]$installPhase = 'Post-Uninstallation'

        ## <Perform Post-Uninstallation tasks here>

          
Try{
		
        ## REMOVE-FILE
        ## Removes one or more items from a given path on the filesystem.
        ## Example: 'C:\Windows\Downloaded Program Files\Temp.inf'
        # if (Test-Path -Path "C:\PATH") {
		#    WriteLogFile " $installPhase : Remove File"
        #    Remove-File [-Path] <String> [[-ContinueOnError] <Boolean>] [<CommonParameters>]
        # }

        ## REMOVE-FOLDER
        ## Remove folder and files if they exist.
        ## Example: Remove-Folder -Path "$envWinDir\Downloaded Program Files"
        # if (Test-Path -Path "C:\PATH") {
		#    WriteLogFile " $installPhase : Remove Folder"
        #    Remove-Folder [-Path] <String> [[-ContinueOnError] <Boolean>] [<CommonParameters>]
        #    Remove-Folder -Path "$env:ProgramFiles\Notepad++"
        # }

        <#  or #>
        

        ## REMOVE-EMPTY FOLDER
        #$OfficeDIR = "$envProgramFiles\Microsoft Office"
        #If( (Get-ChildItem "$OfficeDIR" | Measure-Object).Count -eq 0) { Remove-folder -path "$OfficeDIR" }

        <#  OR
        If( (Get-ChildItem "$envProgramFiles\Microsoft Office" | Measure-Object).Count -eq 0) { Remove-folder -path "$envProgramFiles\Microsoft Office" }
        #>

        
        

        ## REMOVE-REGISTRYKEY
        ## Deletes the specified registry key or value.
        ## Example: Remove-RegistryKey -Key 'HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\RunOnce'
        # WriteLogFile " $installPhase : Remove Reg-Key"
        # Remove-RegistryKey [-Key] <String> [[-Name] <String>] [-Recurse] [[-SID] <String>] [[-ContinueOnError] <Boolean>] [<CommonParameters>]

        ## REMOVE-FIREWALL-RULE
        ## Remove existing Firewall Rule.
        ## Example: Remove-NetFirewallRule -DisplayName "<Rule Name>"
        # WriteLogFile " $installPhase : Remove Firewall Rule"
        # Remove-NetFirewallRule -DisplayName "RULE_NAME"

        ## DELETE-DESKTOP-SHORTCUT
        ## Remove unneeded Desktop Shortcut
        ## Example: Remove-Item -Path "$env:PUBLIC\desktop\xxx.lnk"
        # WriteLogFile " $installPhase : Delete Shortcut"
        # Remove-Item -Path "$env:PUBLIC\desktop\xxx.lnk"

        ##DRIVERS UNINSTALL:
        
        ##DPINST       
         #Execute-Process -Path "$dirFiles\driver\64\eng\DPInst.exe" -Parameters "/U `"$envWinDir\System32\DriverStore\FileRepository\brprca80.inf_amd64_fb43851a75d52d81\brprca80.inf`" /S" 
        
        ##PNPUTIL UTILITY:
         #Execute-Process -Path 'PnPutil.exe' -Parameters "/delete-driver `"$envWinDir\System32\DriverStore\FileRepository\ftdibus.inf_amd64_e2e1704048854979\ftdibus.INF`""

        ##Remove Certificate:
        #Execute-Process -Path "$envWinDir\System32\certutil.exe" -Parameters " -delstore CertificateNAME" -Passthru
       
       ## STOP-Service
       #Stop-Process -Name AutodeskDesktopApp -Force
		
       ## WriteLogFile "UnInstallation completed successfully with exit code :$ExitCode" 

}

Catch
{
     ## WriteLogFile "Post-unInstallation is failed with exit code :$ExitCode" -Source 'unInstallation'
     ## $ExitCode = $ReturnCode.ExitCode
     ## exit-script -Exitcode $ExitCode
     }
    }
    ElseIf ($deploymentType -ieq 'Repair') {
        ##*===============================================
        ##* PRE-REPAIR
        ##*===============================================
        [String]$installPhase = 'Pre-Repair'

        ## Show Welcome Message, close Internet Explorer with a 60 second countdown before automatically closing
        #Show-InstallationWelcome -CloseApps 'iexplore' -CloseAppsCountdown 60

        ## Show Progress Message (with the default message)
       ## Show-InstallationProgress

        ## <Perform Pre-Repair tasks here>

        ##*===============================================
        ##* REPAIR
        ##*===============================================
        [String]$installPhase = 'Repair'

        ## Handle Zero-Config MSI Repairs
        If ($useDefaultMsi) {
            [Hashtable]$ExecuteDefaultMSISplat = @{ Action = 'Repair'; Path = $defaultMsiFile; }; If ($defaultMstFile) {
                $ExecuteDefaultMSISplat.Add('Transform', $defaultMstFile)
            }
            Execute-MSI @ExecuteDefaultMSISplat
        }
        ## <Perform Repair tasks here>
          ## EXECUTE-MSI (REPAIR)
     Try{
        ## Executes msiexec.exe to perform the following actions for MSI & MSP files and MSI product codes: install, uninstall, patch, repair, active setup.
        ## Example: Execute-MSI -Action 'Repair' -Path '{PRODUCT-CODE}' -Parameters '/l*v $logFolder$appPkgName' -PassThru
        # WriteLogFile " $installPhase : $appName repair started"
        # $ReturnCode = Execute-MSI -Action 'Repair' -Path "$MSIProductCode" -Parameters "/l*v $logFolder$appPkgName_$installPhase.log REBOOT=ReallySuppress /qn" -PassThru
        # $ExitCode = $ReturnCode.ExitCode
        # WriteLogFile " $installPhase : $appName repair completed with exit code: $ExitCode"
        }

        Catch
      {
       
      #WriteLogFile "Repair is failed with exit code :$ExitCode" -Source 'Repair'
      #$ExitCode = $ReturnCode.ExitCode
      #exit-script -Exitcode $ExitCode
      
      }
        ##*===============================================
        ##* POST-REPAIR
        ##*===============================================
        [String]$installPhase = 'Post-Repair'

        ## <Perform Post-Repair tasks here>


    }
    ##*===============================================
    ##* END SCRIPT BODY
    ##*===============================================

    ## Call the Exit-Script function to perform final cleanup operations
    Exit-Script -ExitCode $mainExitCode
}
Catch {
    ##[Int32]$mainExitCode = 60001
    ##[String]$mainErrorMessage = "$(Resolve-Error)"
   ## Write-Log -Message $mainErrorMessage -Severity 3 -Source $deployAppScriptFriendlyName
   ## Show-DialogBox -Text $mainErrorMessage -Icon 'Stop'
   ## Exit-Script -ExitCode $mainExitCode
}
