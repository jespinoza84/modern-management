# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

PowerShell scripts and Azure Functions for managing Windows devices via Microsoft Intune, Autopilot, and Microsoft Graph. There is no build system, test framework, or package manager — all scripts are deployed manually or via Intune.

## Architecture

### Azure Functions (`Azure Functions/`)

Each subdirectory is a self-contained function:
- `Function/run.ps1` — the function body
- `Function/function.json` — Azure binding config (trigger type, schedule, input/output bindings)

Functions share a single module at `Modules/Functions.psm1`, imported via a relative path two levels up:
```powershell
Import-Module "$PSScriptRoot\..\..\Modules\Functions.psm1" -Force
```
The `Modules/` directory **must be deployed alongside every Function App** that depends on it.

**Authentication pattern:** Azure resources (Storage, Key Vault) are accessed via the Function App's managed identity using `Set-AzContext`. Microsoft Graph is accessed via app registration client credentials — the `AuthenticateTo-Graph` function in `Functions.psm1` retrieves the client secret from Key Vault, exchanges it for a token, and calls `Connect-MgGraph`.

### Proactive Remediations (`Proactive Remediations/`)

Paired detection/remediation `.ps1` scripts deployed via Intune. Some remediations (e.g., Collect Hardware Hashes) have a corresponding Azure Function that receives their output.

### Compliance Policies (`Compliance Policies/`)

Policy JSON and scripts for managing Intune device compliance policies. The Minimum OS Version Azure Function is the primary automation that updates these.

## Placeholders

All scripts contain angle-bracket placeholders that must be replaced before deployment:
- `<SubscriptionId>`, `<TenantId>`, `<ResourceGroupName>` — Azure identifiers
- `<AppId>`, `<KeyVault Name>`, `<Secret Name>` — in `Modules/Functions.psm1` per app registration
- `<PolicyId>` — Intune compliance policy ID in the Minimum OS Version function
- `Path/To/FunctionUrl` — Azure Function HTTP trigger URL in `RunFromClient.ps1`

App registration credentials (`AppReg1`, `AppReg2`, `AppReg3`) are configured in the `AuthenticateTo-Graph` switch block in `Modules/Functions.psm1`.

## PowerShell conventions

- Variables use **PascalCase**: `$SerialNumber`, `$HardwareHash`, `$ResultsOfThisThing`
- Set `$ErrorActionPreference = 'Stop'` at the top of scripts that should halt on any error
- Use `[PSCustomObject]@{}` for structured output rather than hashtables
- Use `Write-Output` (not `Write-Host`) for logging in Azure Functions — output is captured in function logs
- Functions use `Verb-Noun` naming per PowerShell conventions (`Get-PatchTuesday`, `AuthenticateTo-Graph`)
- Include a `.SYNOPSIS` and `.DESCRIPTION` comment block at the top of each script/function
