.NET Enterprise Cleanup Tool
A PowerShell script designed for enterprise deployment (e.g., via SCCM) that silently discovers and forcefully uninstalls End-of-Life (EOL) .NET SDKs, Runtimes, and ASP.NET Shared Frameworks, as well as outdated patch versions of supported .NET major releases.

⚙️ How It Works
This script automates the tedious process of cleaning up outdated Microsoft .NET environments on Windows machines. It operates through a multi-pass approach to ensure thorough removal:

Discovery: Scans system and user registry hives (HKLM and HKU) to inventory all installed .NET SDKs, Desktop Runtimes, Hosting Bundles, and ASP.NET Core Shared Frameworks.

Targeting: Calculates which versions to remove based on an explicit EOL list and automatically flags older patch versions of currently supported major releases for removal.

Execution : If provided alongside the script, it temporarily installs the official dotnet-core-uninstall.msi tool to handle the bulk of the uninstalls safely.

Execution (Fallbacks): For components the official tool misses or if the tool isn't available, it falls back to native uninstall strings (msiexec), direct folder deletion (for ASP.NET Shared Frameworks), and WMI/CIM invocation for "ghost" MSI entries.

Deep Clean: Sweeps the C:\Program Files\dotnet directory and registry for leftover orphaned folders and keys, removing them forcefully.

Reporting: Tracks failures globally and exits with 0 for complete success or 1 if any uninstall operation failed, allowing deployment tools like SCCM to queue retries.

⚠️ Prerequisites & Important Notes
Permissions: The script contains a hard stop at the beginning; it will immediately Exit 1 if not run with local Administrator privileges.

Dependencies: For optimal performance, the official Microsoft dotnet-core-uninstall.msi file should be placed in the exact same directory as this script. The script will automatically install it, use it, and cleanly uninstall it at the end.

Safety: It uses an intelligent deduplication tracker and determines the highest installed patch version for supported releases. This ensures it doesn't accidentally break active development environments by uninstalling required, up-to-date SDKs.

🛠️ Configuration (Future Updates)
To update the script when a currently supported version of .NET (e.g., .NET 8) reaches its End-of-Life, you only need to modify the $explicitEolMajorVersions variable located near the top of the script.

Current Configuration:
PowerShell
$explicitEolMajorVersions           = [System.Collections.Generic.HashSet[int]]@(1, 2, 3, 5, 6, 7)
How to update it:
Simply add the new major version integer to the comma-separated list inside the parentheses. For example, when .NET 8 reaches EOL, change it to:

PowerShell
$explicitEolMajorVersions           = [System.Collections.Generic.HashSet[int]]@(1, 2, 3, 5, 6, 7, 8)
