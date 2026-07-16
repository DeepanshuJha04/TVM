param(
    [switch]$RemoveUserData
)

$ErrorActionPreference = "SilentlyContinue"
$ProgressPreference = "SilentlyContinue"

$script:Failure = $false
$systemDrive = $env:SystemDrive
$profileListPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList"
$uninstallSubKeys = @(
    "Software\Microsoft\Windows\CurrentVersion\Uninstall",
    "Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
)

function Resolve-EnvPath {
    param([string]$Path)
    if (:IsNullOrWhiteSpace($Path)) { return $null }
    return :ExpandEnvironmentVariables($Path)
}

function Test-TargetPath {
    param([string]$Path)

    if (:IsNullOrWhiteSpace($Path)) { return $false }

    try {
        $fullPath = [System.IO.Path]::GetFullPath($Path.TrimEnd("\"))
    } catch {
        return $false
    }

    $pattern = ("^{0}\\Users\\[^\\]+\\AppData\\Local\\Programs\\Microsoft VS Code$" -f :Escape($systemDrive))
    return ($fullPath -match $pattern)
}

function Test-VSCodeFolder {
    param([string]$Path)

    if (-not (Test-TargetPath -Path $Path)) { return $false }
    if (-not (Test-Path -LiteralPath $Path -PathType Container)) { return $false }

    $codeExe = Join-Path $Path "Code.exe"
    $uninsExe = Join-Path $Path "unins000.exe"

    if (Test-Path -LiteralPath $codeExe -PathType Leaf) {
        $productName = (Get-Item -LiteralPath $codeExe).VersionInfo.ProductName
        if ($productName -like "*Visual Studio Code*" -or $productName -like "*Code*") {
            return $true
        }
    }

    if (Test-Path -LiteralPath $uninsExe -PathType Leaf) {
        return $true
    }

    return $false
}

function Split-UninstallCommand {
    param([string]$CommandLine)

    if (:IsNullOrWhiteSpace($CommandLine)) { return $null }

    $trimmed = $CommandLine.Trim()

    if ($trimmed -match '^\s*"([^"]+)"\s*(.*)$') {
        return [pscustomobject]@{
            FilePath = $matches[1]
            Arguments = $matches[2]
        }
    }

    if ($trimmed -match '^\s*([^\s]+\.exe)\s*(.*)$') {
        return [pscustomobject]@{
            FilePath = $matches[1]
            Arguments = $matches[2]
        }
    }

    return $null
}

function Stop-VSCodeProcesses {
    param([string]$InstallPath)

    $normalized = $InstallPath.TrimEnd("\") + "\"

    Get-Process -Name "Code" | ForEach-Object {
        $processPath = $null
        try {
            $processPath = $_.MainModule.FileName
        } catch {
            $processPath = $null
        }

        if ($processPath -and $processPath.StartsWith($normalized, [System.StringComparison]::OrdinalIgnoreCase)) {
            try {
                Stop-Process -Id $_.Id -Force
            } catch {
                $script:Failure = $true
            }
        }
    }
}

function Invoke-UninstallCommand {
    param(
        [string]$CommandLine,
        [string]$InstallPath
    )

    $parsed = Split-UninstallCommand -CommandLine $CommandLine
    if (-not $parsed) { return $false }

    $filePath = Resolve-EnvPath -Path $parsed.FilePath
    if (-not $filePath) { return $false }

    if (-not (Test-Path -LiteralPath $filePath -PathType Leaf)) { return $false }

    $allowed = $false

    if ($filePath.StartsWith($InstallPath.TrimEnd("\") + "\", [System.StringComparison]::OrdinalIgnoreCase)) {
        $allowed = $true
    }

    if (-not $allowed) { return $false }

    $arguments = $parsed.Arguments

    if ($filePath -match 'unins\d*\.exe$') {
        if ($arguments -notmatch '/VERYSILENT' -and $arguments -notmatch '/SILENT') {
            $arguments = "$arguments /VERYSILENT"
        }
        if ($arguments -notmatch '/NORESTART') {
            $arguments = "$arguments /NORESTART"
        }
        if ($arguments -notmatch '/SUPPRESSMSGBOXES') {
            $arguments = "$arguments /SUPPRESSMSGBOXES"
        }
    }

    try {
        $process = Start-Process -FilePath $filePath -ArgumentList $arguments -Wait -PassThru -WindowStyle Hidden
        if ($null -ne $process.ExitCode -and $process.ExitCode -ne 0) {
            return $false
        }
        return $true
    } catch {
        return $false
    }
}

function Get-RegistryUninstallEntries {
    param(
        [string]$HiveRoot,
        [string]$InstallPath
    )

    $entries = @()

    foreach ($subKey in $uninstallSubKeys) {
        $basePath = "Registry::$HiveRoot\$subKey"

        if (-not (Test-Path -LiteralPath $basePath)) { continue }

        Get-ChildItem -LiteralPath $basePath | ForEach-Object {
            $itemPath = $_.PSPath
            $props = Get-ItemProperty -LiteralPath $itemPath

            $displayName = [string]$props.DisplayName
            $installLocation = Resolve-EnvPath -Path ([string]$props.InstallLocation)
            $uninstallString = Resolve-EnvPath -Path ([string]$props.UninstallString)
            $quietUninstallString = Resolve-EnvPath -Path ([string]$props.QuietUninstallString)

            $match = $false

            if ($displayName -match '^Microsoft Visual Studio Code' -or $displayName -match '^Visual Studio Code') {
                if ($installLocation -and $installLocation.TrimEnd("\").Equals($InstallPath.TrimEnd("\"), [System.StringComparison]::OrdinalIgnoreCase)) {
                    $match = $true
                }

                if ($uninstallString -and $uninstallString -like "*Microsoft VS Code*") {
                    $match = $true
                }

                if ($quietUninstallString -and $quietUninstallString -like "*Microsoft VS Code*") {
                    $match = $true
                }
            }

            if ($match) {
                $entries += [pscustomobject]@{
                    RegistryPath = $itemPath
                    DisplayName = $displayName
                    InstallLocation = $installLocation
                    UninstallString = $uninstallString
                    QuietUninstallString = $quietUninstallString
                }
            }
        }
    }

    return $entries
}

function Remove-InstallFolder {
    param([string]$InstallPath)

    if (-not (Test-TargetPath -Path $InstallPath)) { return }

    if (Test-Path -LiteralPath $InstallPath -PathType Container) {
        try {
            Remove-Item -LiteralPath $InstallPath -Recurse -Force
        } catch {
            Start-Sleep -Seconds 3
            try {
                Remove-Item -LiteralPath $InstallPath -Recurse -Force
            } catch {
                $script:Failure = $true
            }
        }
    }
}

function Remove-UserData {
    param([string]$ProfilePath)

    if (-not $RemoveUserData) { return }
    if (-not $ProfilePath) { return }
    if (-not $ProfilePath.StartsWith("$systemDrive\Users\", [System.StringComparison]::OrdinalIgnoreCase)) { return }

    $targets = @(
        (Join-Path $ProfilePath "AppData\Roaming\Code"),
        (Join-Path $ProfilePath ".vscode")
    )

    foreach ($target in $targets) {
        if (Test-Path -LiteralPath $target) {
            try {
                Remove-Item -LiteralPath $target -Recurse -Force
            } catch {
                $script:Failure = $true
            }
        }
    }
}

function Remove-RegistryEntries {
    param($Entries)

    foreach ($entry in $Entries) {
        if ($entry.RegistryPath) {
            try {
                Remove-Item -LiteralPath $entry.RegistryPath -Recurse -Force
            } catch {
                $script:Failure = $true
            }
        }
    }
}

$profiles = @()

Get-ChildItem -LiteralPath $profileListPath | ForEach-Object {
    $sid = $_.PSChildName
    $props = Get-ItemProperty -LiteralPath $_.PSPath
    $profilePath = Resolve-EnvPath -Path ([string]$props.ProfileImagePath)

    if ($sid -match '^S-1-5-21-' -and $profilePath -and $profilePath.StartsWith("$systemDrive\Users\", [System.StringComparison]::OrdinalIgnoreCase)) {
        $profiles += [pscustomobject]@{
            Sid = $sid
            ProfilePath = $profilePath
        }
    }
}

foreach ($profile in $profiles) {
    $installPath = Join-Path $profile.ProfilePath "AppData\Local\Programs\Microsoft VS Code"

    if (-not (Test-VSCodeFolder -Path $installPath)) {
        continue
    }

    Stop-VSCodeProcesses -InstallPath $installPath

    $hiveName = $profile.Sid
    $loadedByScript = $false
    $hiveRoot = "HKEY_USERS\$hiveName"

    if (-not (Test-Path -LiteralPath "Registry::HKEY_USERS\$hiveName")) {
        $ntUserDat = Join-Path $profile.ProfilePath "NTUSER.DAT"
        if (Test-Path -LiteralPath $ntUserDat -PathType Leaf) {
            $tempHiveName = "VSCodeRemove_$($profile.Sid -replace '[^A-Za-z0-9]', '_')"
            $loadResult = Start-Process -FilePath "$env:SystemRoot\System32\reg.exe" -ArgumentList @("load", "HKU\$tempHiveName", $ntUserDat) -Wait -PassThru -WindowStyle Hidden
            if ($loadResult.ExitCode -eq 0) {
                $hiveName = $tempHiveName
                $hiveRoot = "HKEY_USERS\$hiveName"
                $loadedByScript = $true
            }
        }
    }

    $entries = @()

    if (Test-Path -LiteralPath "Registry::HKEY_USERS\$hiveName") {
        $entries = Get-RegistryUninstallEntries -HiveRoot $hiveRoot -InstallPath $installPath
    }

    $uninstalled = $false

    foreach ($entry in $entries) {
        if ($entry.QuietUninstallString) {
            if (Invoke-UninstallCommand -CommandLine $entry.QuietUninstallString -InstallPath $installPath) {
                $uninstalled = $true
                break
            }
        }
    }

    if (-not $uninstalled) {
        foreach ($entry in $entries) {
            if ($entry.UninstallString) {
                if (Invoke-UninstallCommand -CommandLine $entry.UninstallString -InstallPath $installPath) {
                    $uninstalled = $true
                    break
                }
            }
        }
    }

    if (-not $uninstalled) {
        $unins = Join-Path $installPath "unins000.exe"
        if (Test-Path -LiteralPath $unins -PathType Leaf) {
            try {
                $process = Start-Process -FilePath $unins -ArgumentList "/VERYSILENT /NORESTART /SUPPRESSMSGBOXES" -Wait -PassThru -WindowStyle Hidden
                if ($null -eq $process.ExitCode -or $process.ExitCode -eq 0) {
                    $uninstalled = $true
                }
            } catch {
                $uninstalled = $false
            }
        }
    }

    if (-not $uninstalled) {
        if (Test-VSCodeFolder -Path $installPath) {
            $uninstalled = $true
        }
    }

    if ($uninstalled) {
        Start-Sleep -Seconds 3
        Remove-RegistryEntries -Entries $entries
        Remove-InstallFolder -InstallPath $installPath
        Remove-UserData -ProfilePath $profile.ProfilePath
    } else {
        $script:Failure = $true
    }

    if ($loadedByScript) {
        :Collect()
        :WaitForPendingFinalizers()
        Start-Sleep -Seconds 2
        Start-Process -FilePath "$env:SystemRoot\System32\reg.exe" -ArgumentList @("unload", "HKU\$hiveName") -Wait -PassThru -WindowStyle Hidden | Out-Null
    }

    if (Test-Path -LiteralPath $installPath) {
        $remainingItems = Get-ChildItem -LiteralPath $installPath -Force
        if ($remainingItems) {
            $script:Failure = $true
        }
    }
}

if ($script:Failure) {
    exit 1
}

exit 0
