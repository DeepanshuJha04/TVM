# Variables
$folderName   = "Custom"
$taskName     = "ClientAlwaysOnInternet"
$taskXmlPath  = Join-Path $PSScriptRoot "SCCM-NetworkTask.xml"

# Debug (optional for testing)
Write-Host "Using XML Path: $taskXmlPath"

# Connect to Task Scheduler service
$service = New-Object -ComObject "Schedule.Service"
$service.Connect()

$rootFolder = $service.GetFolder("\")

# -----------------------------
# Step 1: Check & Create Folder
# -----------------------------
$folderExists = $true

try {
    $folder = $service.GetFolder("\$folderName")
}
catch {
    $folderExists = $false
}

if (-not $folderExists) {
    try {
        $rootFolder.CreateFolder($folderName) | Out-Null
        Write-Host "Folder '$folderName' created successfully"
    }
    catch {
        Write-Error "Failed to create folder: $_"
        exit 1
    }
}
else {
    Write-Host "Folder '$folderName' already exists"
}

# -----------------------------
# Step 2: Modify XML + Register Task
# -----------------------------
try {
    $folder = $service.GetFolder("\$folderName")

    if (-not (Test-Path $taskXmlPath)) {
        Write-Error "XML file not found: $taskXmlPath"
        exit 1
    }

    # Load and update XML
    [xml]$x = Get-Content $taskXmlPath
    $t = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss")

    $x.Task.RegistrationInfo.Date = $t
    $x.Task.Triggers.TimeTrigger.StartBoundary = $t

    $taskXml = $x.OuterXml

    Write-Host "XML updated with current timestamp: $t"

    # Register or update scheduled task
    $folder.RegisterTask(
        $taskName,
        $taskXml,
        6,      # TASK_CREATE_OR_UPDATE
        $null,
        $null,
        3       # TASK_LOGON_INTERACTIVE_TOKEN
    ) | Out-Null

    Write-Host "Task '$taskName' successfully registered in '\$folderName'"
}
catch {
    Write-Error "Failed to register task: $_"
    exit 1
}
