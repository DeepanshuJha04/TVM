$ErrorActionPreference = "SilentlyContinue"
$ProgressPreference = "SilentlyContinue"
$script:Failure = $false
$systemDrive = $env:SystemDrive
$profileListPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList"
$uninstallSubKeys = @(
    "Software\Microsoft\Windows\CurrentVersion\Uninstall",
    "Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
)

function Get-RegexReplacement {
    param([string]$Value)

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return ""
    }

    return ($Value -replace '\$', '$$')
}

function Resolve-EnvPath {
    param(
        [string]$Path,
        [string]$ProfilePath
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return $null
    }

    $resolvedPath = $Path

    if (-not [string]::IsNullOrWhiteSpace($ProfilePath)) {
        $localAppData = Join-Path $ProfilePath "AppData\Local"
        $roamingAppData = Join-Path $ProfilePath "AppData\Roaming"

        $resolvedPath = $resolvedPath -ireplace [regex]::Escape("%USERPROFILE%"), (Get-RegexReplacement -Value $ProfilePath)
        $resolvedPath = $resolvedPath -ireplace [regex]::Escape("%LOCALAPPDATA%"), (Get-RegexReplacement -Value $localAppData)
        $resolvedPath = $resolvedPath -ireplace [regex]::Escape("%APPDATA%"), (Get-RegexReplacement -Value $roamingAppData)
    }

    $resolvedPath = $resolvedPath -ireplace [regex]::Escape("%SystemDrive%"), (Get-RegexReplacement -Value $systemDrive)

    return [System.Environment]::ExpandEnvironmentVariables($resolvedPath)
}

function Test-TargetPath {
    param([string]$Path)

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return $false
    }

    try {
        $fullPath = [System.IO.Path]::GetFullPath($Path.TrimEnd("\"))
    } catch {
        return $false
    }

    $pattern = ("^{0}\\Users\\[^\\]+\\AppData\\Local\\Programs\\Microsoft VS Code$" -f [regex]::Escape($systemDrive))
    return ($fullPath -match $pattern)
}

function Test-VSCodeFolder {
    param([string]$Path)

    if (-not (Test-TargetPath -Path $Path)) {
        return $false
    }

    if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
        return $false
    }

    $codeExe = Join-Path $Path "Code.exe"
    $uninsExe = Join-Path $Path "unins000.exe"

    if (Test-Path -LiteralPath $codeExe -PathType Leaf) {
        try {
            $versionInfo = (Get-Item -LiteralPath $codeExe).VersionInfo

            if ($versionInfo.ProductName -like "*Visual Studio Code*" -or $versionInfo.FileDescription -like "*Visual Studio Code*") {
                return $true
            }
        } catch {
        }
    }

    if (Test-Path -LiteralPath $uninsExe -PathType Leaf) {
        return $true
    }

    return $false
}

function Split-UninstallCommand {
    param([string]$CommandLine)

    if ([string]::IsNullOrWhiteSpace($CommandLine)) {
        return $null
    }

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

    $normalizedInstallPath = $InstallPath.TrimEnd("\") + "\"

    Get-Process -Name "Code" | ForEach-Object {
        $processPath = $null

        try {
            $processPath = $_.MainModule.FileName
        } catch {
            $processPath = $null
        }

        if ($processPath -and $processPath.StartsWith($normalizedInstallPath, [System.StringComparison]::OrdinalIgnoreCase)) {
            try {
                Stop-Process -Id $_.Id -Force
            } catch {
                $script:Failure = $true
            }
        }
    }
}

function Invoke-VSCodeUninstallCommand {
    param(
        [string]$CommandLine,
        [string]$InstallPath,
        [string]$ProfilePath
    )

    $parsed = Split-UninstallCommand -CommandLine $CommandLine

    if (-not $parsed) {
        return $false
    }

    $filePath = Resolve-EnvPath -Path $parsed.FilePath -ProfilePath $ProfilePath

    if ([string]::IsNullOrWhiteSpace($filePath)) {
        return $false
    }

    if (-not (Test-Path -LiteralPath $filePath -PathType Leaf)) {
        return $false
    }

    $normalizedInstallPath = $InstallPath.TrimEnd("\") + "\"

    if (-not $filePath.StartsWith($normalizedInstallPath, [System.StringComparison]::OrdinalIgnoreCase)) {
        return $false
    }

    $arguments = [string]$parsed.Arguments

    if ($filePath -match 'unins\d*\.exe$') {
        $silentSwitchPattern = '/VERYSILENT|/SILENT|/SUPPRESSMSGBOXES|/NORESTART|/NOCANCEL|/NORESTARTAPPLICATIONS'
        $arguments = ($arguments -split '\s+' | Where-Object { $_ -and ($_ -notmatch $silentSwitchPattern) }) -join ' '
        $arguments = "$arguments /VERYSILENT /SUPPRESSMSGBOXES /NORESTART /NOCANCEL".Trim()
    }

    try {
        $process = Start-Process -FilePath $filePath -ArgumentList $arguments.Trim() -Wait -PassThru -WindowStyle Hidden

        if ($null -eq $process.ExitCode -or $process.ExitCode -eq 0) {
            return $true
        }

        return $false
    } catch {
        return $false
    }
}

function Get-RegistryUninstallEntries {
    param(
        [string]$HiveName,
        [string]$InstallPath,
        [string]$ProfilePath
    )

    $entries = @()

    foreach ($subKey in $uninstallSubKeys) {
        $basePath = "Registry::HKEY_USERS\$HiveName\$subKey"

        if (-not (Test-Path -LiteralPath $basePath)) {
            continue
        }

        Get-ChildItem -LiteralPath $basePath | ForEach-Object {
            $itemPath = $_.PSPath
            $props = Get-ItemProperty -LiteralPath $itemPath
            $displayName = [string]$props.DisplayName
            $installLocation = Resolve-EnvPath -Path ([string]$props.InstallLocation) -ProfilePath $ProfilePath
            $uninstallString = Resolve-EnvPath -Path ([string]$props.UninstallString) -ProfilePath $ProfilePath
            $quietUninstallString = Resolve-EnvPath -Path ([string]$props.QuietUninstallString) -ProfilePath $ProfilePath
            $matched = $false

            if ($displayName -match '^Microsoft Visual Studio Code' -or $displayName -match '^Visual Studio Code') {
                if ($installLocation -and $installLocation.TrimEnd("\").Equals($InstallPath.TrimEnd("\"), [System.StringComparison]::OrdinalIgnoreCase)) {
                    $matched = $true
                }

                if ($uninstallString -and $uninstallString -like "*\AppData\Local\Programs\Microsoft VS Code\*") {
                    $matched = $true
                }

                if ($quietUninstallString -and $quietUninstallString -like "*\AppData\Local\Programs\Microsoft VS Code\*") {
                    $matched = $true
                }
            }

            if ($matched) {
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

function Remove-RegistryEntries {
    param($Entries)

    foreach ($entry in $Entries) {
        if ($entry.RegistryPath -and (Test-Path -LiteralPath $entry.RegistryPath)) {
            try {
                Remove-Item -LiteralPath $entry.RegistryPath -Recurse -Force
            } catch {
                $script:Failure = $true
            }
        }
    }
}

function Remove-KnownVSCodeAppArtifacts {
    param([string]$InstallPath)

    if (-not (Test-TargetPath -Path $InstallPath)) {
        return
    }

    if (-not (Test-Path -LiteralPath $InstallPath -PathType Container)) {
        return
    }

    $knownItems = @(
        "Code.exe",
        "unins000.exe",
        "unins000.dat",
        "unins000.msg",
        "bin",
        "locales",
        "policies",
        "resources",
        "tools",
        "swiftshader",
        "Code.VisualElementsManifest.xml",
        "chrome_100_percent.pak",
        "chrome_200_percent.pak",
        "d3dcompiler_47.dll",
        "ffmpeg.dll",
        "icudtl.dat",
        "libEGL.dll",
        "libGLESv2.dll",
        "resources.pak",
        "snapshot_blob.bin",
        "v8_context_snapshot.bin",
        "vk_swiftshader.dll",
        "vk_swiftshader_icd.json",
        "vulkan-1.dll"
    )

    foreach ($item in $knownItems) {
        $target = Join-Path $InstallPath $item

        if (Test-Path -LiteralPath $target) {
            try {
                Remove-Item -LiteralPath $target -Recurse -Force
            } catch {
                $script:Failure = $true
            }
        }
    }

    try {
        $remainingItems = Get-ChildItem -LiteralPath $InstallPath -Force

        if (-not $remainingItems) {
            Remove-Item -LiteralPath $InstallPath -Force
        }
    } catch {
        $script:Failure = $true
    }
}

function Get-UserProfiles {
    $profiles = @()

    Get-ChildItem -LiteralPath $profileListPath | ForEach-Object {
        $sid = $_.PSChildName
        $props = Get-ItemProperty -LiteralPath $_.PSPath
        $profilePath = Resolve-EnvPath -Path ([string]$props.ProfileImagePath) -ProfilePath $null

        if ($sid -match '^S-1-5-21-' -and $profilePath -and $profilePath.StartsWith("$systemDrive\Users\", [System.StringComparison]::OrdinalIgnoreCase)) {
            if (Test-Path -LiteralPath $profilePath -PathType Container) {
                $profiles += [pscustomobject]@{
                    Sid = $sid
                    ProfilePath = $profilePath
                }
            }
        }
    }

    return $profiles
}

$profiles = Get-UserProfiles

foreach ($profile in $profiles) {
    $installPath = Join-Path $profile.ProfilePath "AppData\Local\Programs\Microsoft VS Code"

    if (-not (Test-VSCodeFolder -Path $installPath)) {
        continue
    }

    Stop-VSCodeProcesses -InstallPath $installPath

    $hiveName = $profile.Sid
    $loadedByScript = $false

    if (-not (Test-Path -LiteralPath "Registry::HKEY_USERS\$hiveName")) {
        $ntUserDat = Join-Path $profile.ProfilePath "NTUSER.DAT"

        if (Test-Path -LiteralPath $ntUserDat -PathType Leaf) {
            $tempHiveName = "VSCodeRemove_$($profile.Sid -replace '[^A-Za-z0-9]', '_')"
            $loadProcess = Start-Process -FilePath "$env:SystemRoot\System32\reg.exe" -ArgumentList @("load", "HKU\$tempHiveName", $ntUserDat) -Wait -PassThru -WindowStyle Hidden

            if ($loadProcess.ExitCode -eq 0) {
                $hiveName = $tempHiveName
                $loadedByScript = $true
            }
        }
    }

    $entries = @()

    if (Test-Path -LiteralPath "Registry::HKEY_USERS\$hiveName") {
        $entries = Get-RegistryUninstallEntries -HiveName $hiveName -InstallPath $installPath -ProfilePath $profile.ProfilePath
    }

    foreach ($entry in $entries) {
        if ($entry.QuietUninstallString) {
            if (Invoke-VSCodeUninstallCommand -CommandLine $entry.QuietUninstallString -InstallPath $installPath -ProfilePath $profile.ProfilePath) {
                break
            }
        }
    }

    if (Test-Path -LiteralPath $installPath -PathType Container) {
        foreach ($entry in $entries) {
            if ($entry.UninstallString) {
                if (Invoke-VSCodeUninstallCommand -CommandLine $entry.UninstallString -InstallPath $installPath -ProfilePath $profile.ProfilePath) {
                    break
                }
            }
        }
    }

    if (Test-Path -LiteralPath $installPath -PathType Container) {
        $uninsExe = Join-Path $installPath "unins000.exe"

        if (Test-Path -LiteralPath $uninsExe -PathType Leaf) {
            try {
                Start-Process -FilePath $uninsExe -ArgumentList "/VERYSILENT /SUPPRESSMSGBOXES /NORESTART /NOCANCEL" -Wait -PassThru -WindowStyle Hidden | Out-Null
            } catch {
            }
        }
    }

    Start-Sleep -Seconds 3

    Remove-RegistryEntries -Entries $entries

    if (Test-Path -LiteralPath $installPath -PathType Container) {
        Remove-KnownVSCodeAppArtifacts -InstallPath $installPath
    }

    if ($loadedByScript) {
        [System.GC]::Collect()
        [System.GC]::WaitForPendingFinalizers()
        Start-Sleep -Seconds 2
        Start-Process -FilePath "$env:SystemRoot\System32\reg.exe" -ArgumentList @("unload", "HKU\$hiveName") -Wait -PassThru -WindowStyle Hidden | Out-Null
    }

    $codeExeCheck = Join-Path $installPath "Code.exe"

    if (Test-Path -LiteralPath $codeExeCheck -PathType Leaf) {
        $script:Failure = $true
    }
}

if ($script:Failure) {
    exit 1
}

exit 0
