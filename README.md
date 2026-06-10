🛡️ .NET Enterprise Cleanup & Remediation Tool
Enterprise-grade PowerShell solution for automated .NET lifecycle management, vulnerability remediation, and security compliance.

________________________________________
📖 Overview
The .NET Enterprise Cleanup & Remediation Tool is a PowerShell-based enterprise remediation solution designed to automatically discover, evaluate, and remove:

✅ End-of-Life (EOL) .NET Versions
✅ Organizationally Unapproved .NET Versions
✅ Obsolete Patch Versions of Supported Releases
✅ .NET SDKs
✅ .NET Runtimes
✅ Windows Desktop Runtimes
✅ ASP.NET Core Shared Frameworks
✅ ASP.NET Core Runtime Components
✅ Host FX Resolvers
✅ Hosting Bundles
✅ Windows Server Hosting Packages
✅ Orphaned Filesystem Artifacts
✅ Stale Registry Entries

Designed specifically for:
•	🖥️ Microsoft Configuration Manager (SCCM/MECM)
•	☁️ Microsoft Intune
•	🔐 Vulnerability Management Teams
•	🛡️ Security Operations Teams
•	⚙️ Platform Engineering Teams
•	🏢 Enterprise Server Environments
________________________________________

🎯 Why This Tool Exists
Modern vulnerability scanners frequently identify outdated and unsupported .NET installations, including:
•	Qualys
•	Microsoft Defender Vulnerability Management
•	Tenable
•	Rapid7 InsightVM
•	Nessus

Manual remediation of .NET runtimes across hundreds or thousands of endpoints is:
❌ Time consuming
❌ Error prone
❌ Difficult to audit
❌ Inconsistent across teams
This tool provides a standardized, auditable, and scalable remediation process.

________________________________________

🚀 Key Features
🔍 Comprehensive Discovery
Automatically discovers:
•	.NET SDKs
•	.NET Runtimes
•	Windows Desktop Runtimes
•	ASP.NET Core Shared Frameworks
•	ASP.NET Core Runtime Components
•	Host FX Resolvers
•	Hosting Bundles
•	Windows Server Hosting Components
Supports:
•	x64 Installations
•	x86 Installations
•	Per-Machine Installations
•	Per-User Installations
________________________________________

🛡️ Vulnerability Remediation
Removes:
•	EOL .NET Versions
•	Organizationally Unapproved Versions
•	Unsupported Components
•	Obsolete Patch Releases
Example:
Installed:
8.0.12
8.0.16
8.0.18

Retained:
8.0.18

Removed:
8.0.12
8.0.16
________________________________________

⚙️ Multi-Stage Uninstall Engine
The script attempts removal using multiple methods:
🥇 Method 1 – Microsoft .NET Uninstall Tool
Uses:
dotnet-core-uninstall.msi
Example:
remove 6.0.36 --runtime --x64 --yes
________________________________________
🥈 Method 2 – MSI Uninstall
msiexec /x {GUID} /qn /norestart
________________________________________
🥉 Method 3 – Native Uninstall Strings
Uses uninstall commands registered by Microsoft installers.
________________________________________
🧹 Deep Cleanup
Removes orphaned remnants from:
C:\Program Files\dotnet
C:\Program Files (x86)\dotnet
C:\ProgramData\dotnet
Including:
•	SDK Folders
•	Runtime Folders
•	ASP.NET Components
•	Desktop Runtime Components
•	Stale Registry Entries
________________________________________
🔄 Script Workflow
The script executes through a structured remediation pipeline:
PHASE 1  - Script Initialization
PHASE 2  - Pre-Cleanup Validation
PHASE 3  - Product Discovery
PHASE 4  - Version Analysis
PHASE 5  - Target Selection
PHASE 6  - Uninstall Tool Detection
PHASE 7  - Uninstall Execution
PHASE 8  - Filesystem Cleanup
PHASE 9  - Registry Cleanup
PHASE 10 - Post-Cleanup Validation
PHASE 11 - Execution Summary
________________________________________
📊 Example Execution
Products Discovered: 44

Products Targeted: 23

Examples:

Microsoft .NET Runtime - 5.0.17
Microsoft .NET Runtime - 6.0.36
Microsoft .NET Runtime - 7.0.20

Microsoft ASP.NET Core Shared Framework 6.0.36

Microsoft .NET Host FX Resolver 6.0.36

Windows Server Hosting Packages
________________________________________
📝 Enterprise Logging
The script includes detailed phase-based logging with timestamps.
Example:
2026-06-11 04:01:05 [19968] PHASE 5 - TARGET SELECTION

2026-06-11 04:01:05 [19968] Total discovered products: 44

2026-06-11 04:01:05 [19968] Products targeted for removal: 23

2026-06-11 04:01:05 [19968] TARGET:
Microsoft .NET Runtime - 6.0.36 (x64)
________________________________________
📂 Log Locations
SCCM Devices
C:\Windows\CCM\Logs\DotNetCleanup.log
Non-SCCM Devices
%TEMP%\DotNetCleanup.log
________________________________________
🔧 Configuration
Single Maintenance Variable
The entire remediation scope is controlled by a single variable:
$eolOrUnapprovedMajorVersions =
[System.Collections.Generic.HashSet[int]]@(1,2,3,5,6,7)
________________________________________
Example
When .NET 8 reaches End-of-Life:
$eolOrUnapprovedMajorVersions =
[System.Collections.Generic.HashSet[int]]@(1,2,3,5,6,7,8)
No additional code changes should normally be required.
________________________________________
📅 Recommended Execution Schedule
Monthly
Recommended execution frequency:
Once Per Month
Best practice:
✅ After Microsoft Patch Tuesday
✅ After Vulnerability Scanning Cycles
✅ Following Critical Security Advisories
This keeps supported .NET versions current while automatically removing superseded releases.
________________________________________
📤 Exit Codes
Exit Code	Description
✅ 0	Success
❌ 1	Failure
🔄 3010	Success – Reboot Required
Fully compatible with:
•	SCCM
•	MECM
•	Intune
•	Enterprise Software Distribution Platforms
________________________________________
🔒 Security Benefits
✔ Reduces Vulnerability Exposure
✔ Removes Unsupported Software
✔ Eliminates Version Sprawl
✔ Improves Compliance Posture
✔ Simplifies Patch Management
✔ Provides Full Auditability
✔ Supports Enterprise-Scale Remediation
________________________________________
🎯 Intended Use Cases
•	Vulnerability Remediation
•	Security Hardening
•	Monthly Maintenance Activities
•	SCCM ADR Deployments
•	Compliance Enforcement
•	Server Lifecycle Management
•	Workstation Lifecycle Management
•	Enterprise .NET Governance
________________________________________
⭐ Maintenance Philosophy
One Variable. One Update. Full Control.
Administrators only need to maintain:
$eolOrUnapprovedMajorVersions
This design keeps long-term ownership simple, predictable, and audit-friendly.
________________________________________
📌 Recommended Deployment
Deployment Type : SCCM Application / Package
Execution Mode  : SYSTEM
Schedule        : Monthly
Visibility      : Hidden
User Interaction: None
Logging         : Enabled
________________________________________
Built for Enterprise Security Operations, Vulnerability Management, and Platform Engineering Teams.
