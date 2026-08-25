param (
    [ValidateSet("Install","Uninstall")]
    [string]$Mode = "Install"
)

Write-Output "===== Script Mode: $Mode ====="

# Common Variables
$SourceRoot   = Split-Path -Parent $MyInvocation.MyCommand.Definition
$SourceFolder = Join-Path $SourceRoot "TS"
$DestFolder   = "C:\AlwaysInternet"
$ScriptToRun  = Join-Path $SourceRoot "SCCM-NetworkTask.ps1"

$TaskFolderName = "Custom"
$TaskName       = "ClientAlwaysOnInternet"

# Connect to Task Scheduler
$service = New-Object -ComObject "Schedule.Service"
$service.Connect()
$rootFolder = $service.GetFolder("\\")

# ============================================================
# INSTALL MODE
# ============================================================
if ($Mode -eq "Install") {

    Write-Output "===== Starting Installation ====="

    # Step 1: Create Destination Folder
    if (!(Test-Path $DestFolder)) {
        Write-Output "Creating folder: $DestFolder"
        New-Item -Path $DestFolder -ItemType Directory -Force | Out-Null
    } else {
        Write-Output "Folder already exists: $DestFolder"
    }

    # Step 2: Validate Source
    if (!(Test-Path $SourceFolder)) {
        Write-Output "ERROR: TS folder not found at $SourceRoot"
        exit 1
    }

    # Step 3: Copy Files
    try {
        Write-Output "Copying TS contents..."
        Copy-Item "$SourceFolder\*" -Destination $DestFolder -Recurse -Force -ErrorAction Stop
        Write-Output "Copy successful."
    }
    catch {
        Write-Output "ERROR: Copy failed. $_"
        exit 1
    }

    # Step 4: Execute Task Creation Script
    if (Test-Path $ScriptToRun) {
        try {
            Write-Output "Running SCCM-NetworkTask.ps1"
            powershell.exe -ExecutionPolicy Bypass -File $ScriptToRun
            Write-Output "Task creation completed."
        }
        catch {
            Write-Output "ERROR: Execution failed. $_"
            exit 1
        }
    } else {
        Write-Output "ERROR: SCCM-NetworkTask.ps1 not found."
        exit 1
    }

    Write-Output "===== Installation Completed ====="
}

# ============================================================
# UNINSTALL MODE
# ============================================================
elseif ($Mode -eq "Uninstall") {

    Write-Output "===== Starting Uninstallation ====="

    # Step 1: Remove Scheduled Task
    try {
        $folder = $service.GetFolder("\$TaskFolderName")

        try {
            $folder.DeleteTask($TaskName, 0)
            Write-Output "Task '$TaskName' removed."
        }
        catch {
            Write-Output "Task not found or already removed."
        }

        # Step 2: Remove Folder if Empty
        try {
            $tasks = $folder.GetTasks(0)

            if ($tasks.Count -eq 0) {
                $rootFolder.DeleteFolder($TaskFolderName, 0)
                Write-Output "Folder '$TaskFolderName' removed."
            } else {
                Write-Output "Folder not empty. Skipping deletion."
            }
        }
        catch {
            Write-Output "Error removing folder: $_"
        }

    }
    catch {
        Write-Output "Task folder does not exist."
    }

    # Step 3: Remove Files
    if (Test-Path $DestFolder) {
        try {
            Remove-Item $DestFolder -Recurse -Force -ErrorAction Stop
            Write-Output "Folder '$DestFolder' deleted."
        }
        catch {
            Write-Output "ERROR: Failed to delete folder. $_"
            exit 1
        }
    } else {
        Write-Output "Folder '$DestFolder' not found."
    }

    # Step 4: Set ClientAlwaysOnInternet to 0
    $RegPath = "HKLM:\SOFTWARE\Microsoft\CCM\Security"
    $RegName = "ClientAlwaysOnInternet"

    try {
        if (!(Test-Path $RegPath)) {
            New-Item -Path $RegPath -Force | Out-Null
        }

        if (Get-ItemProperty -Path $RegPath -Name $RegName -ErrorAction SilentlyContinue) {
            Set-ItemProperty -Path $RegPath -Name $RegName -Value 0
            Write-Output "Registry value '$RegName' set to 0."
        }
        else {
            New-ItemProperty `
                -Path $RegPath `
                -Name $RegName `
                -Value 0 `
                -PropertyType DWord `
                -Force | Out-Null

            Write-Output "Registry value '$RegName' created and set to 0."
        }
    }
    catch {
        Write-Output "ERROR: Failed to update registry. $_"
        exit 1
    }

    # Step 5: Restart SCCM Client Service
    try {
        Restart-Service -Name CcmExec -Force -ErrorAction Stop
        Write-Output "CcmExec service restarted successfully."
    }
    catch {
        Write-Output "ERROR: Failed to restart CcmExec service. $_"
        exit 1
    }

    Write-Output "===== Uninstallation Completed ====="
}

# ============================================================
# INVALID MODE
# ============================================================
else {
    Write-Output "Invalid mode. Use -Mode Install or -Mode Uninstall"
    exit 1
}
