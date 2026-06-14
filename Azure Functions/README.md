# Azure Functions

PowerShell-based Azure Functions for automating Intune and Autopilot management tasks. Each subdirectory is a self-contained function with its own `Function/` deployment folder and README.

## Functions

| Function | Trigger | What it does |
|---|---|---|
| [Collect Hardware Hashes](Collect%20Hardware%20Hashes/) | HTTP (POST) | Receives Autopilot hardware hashes from devices via Intune Proactive Remediation and upserts them into Azure Table Storage |
| [Minimum OS Version](Minimum%20OS%20Version/) | Timer (daily) | On Patch Tuesday, scrapes the Windows 11 release history and updates an Intune device compliance policy's minimum build requirement to the N-2 cumulative update |

## Shared Modules

`Modules/Functions.psm1` contains helpers used across functions:

- **`Get-PatchTuesday`** — returns the date of the second Tuesday of the current month
- **`AuthenticateTo-Graph`** — retrieves a client secret from Azure Key Vault and authenticates to Microsoft Graph via the OAuth 2.0 client credentials flow

Functions import this module using a relative path (`..\..\Modules\Functions.psm1`), so the `Modules/` directory must be deployed alongside any Function App that depends on it.

## Prerequisites

- Azure Function App with a PowerShell runtime
- Azure Key Vault for storing app registration client secrets
- The Function App's managed identity granted appropriate roles on dependent resources (Key Vault, Storage, etc.)

See each function's README for its specific prerequisites and deployment steps.
