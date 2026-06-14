# Modern-Management

Scripts and automation for managing Windows devices with Microsoft Intune, Autopilot, and Microsoft Graph.

## Repository layout

| Directory | Description |
|---|---|
| [Azure Functions/](Azure%20Functions/) | Timer- and HTTP-triggered Azure Functions that automate Intune and Autopilot tasks |
| [Compliance Policies/](Compliance%20Policies/) | PowerShell scripts and policy JSON for managing Intune device compliance policies |
| [Graph/](Graph/) | Shared helper modules and reusable wrappers for the Microsoft Graph API |
| [Proactive Remediations/](Proactive%20Remediations/) | Paired detection and remediation scripts deployed via Intune Proactive Remediations |

## Azure Functions

| Function | What it does |
|---|---|
| [Collect Hardware Hashes](Azure%20Functions/Collect%20Hardware%20Hashes/) | Receives Autopilot hardware hashes from devices and stores them in Azure Table Storage |
| [Minimum OS Version](Azure%20Functions/Minimum%20OS%20Version/) | Updates an Intune compliance policy's minimum Windows 11 build to the N-2 patch level on Patch Tuesday |
