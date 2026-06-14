# Minimum OS Version

Keeps an Intune device compliance policy's minimum Windows 11 build requirement current by automatically setting it to the N-2 cumulative update on Patch Tuesday. A timer-triggered Azure Function runs daily, exits early on non-Patch-Tuesday days, and on Patch Tuesday scrapes the Windows 11 release history, identifies the second-latest build from two months prior for each supported feature version, and patches the compliance policy via Microsoft Graph.

## How it works

```
Timer Trigger (daily @ 22:00 UTC)
  └─ run.ps1
       ├─ [exit if not Patch Tuesday]
       ├─ Azure Key Vault  ──────────────────►  Client secret
       ├─ Microsoft Graph (auth)
       ├─ Microsoft Learn  ──────────────────►  Windows 11 release history
       └─ Microsoft Graph (PATCH)  ──────────►  Intune Compliance Policy
```

1. **Timer check** — the function runs daily but immediately exits if the current day is not Patch Tuesday (determined by `Get-PatchTuesday` from the shared `Modules/Functions.psm1`).
2. **Authentication** — the script calls `AuthenticateTo-Graph -AppRegistration "AppReg1"` from the shared `Modules/Functions.psm1`. That function looks up the app's credentials (App ID, Tenant ID, Key Vault name, and secret name) by registration name, retrieves the client secret from Azure Key Vault, and obtains a Graph API access token via the OAuth 2.0 client credentials flow before connecting via `Connect-MgGraph`.
3. **Version scraping** — the Windows 11 release history page on Microsoft Learn is fetched and parsed into build tables. Rows are grouped by major feature version (24H2 = build `26100.x`, 25H2 = build `26200.x`).
4. **N-2 selection** — for each major version, cumulative updates released exactly two months prior are filtered (out-of-band updates are excluded). The builds are sorted descending and the second-highest is chosen when more than one exists, giving the N-2 patch level.
5. **Policy update** — the Intune device compliance policy is PATCHed via Graph, updating the `lowestVersion` in each `validOperatingSystemBuildRanges` entry to the newly calculated N-2 build.

## Files

| File | Purpose |
|---|---|
| `Function/run.ps1` | Azure Function body; checks for Patch Tuesday, calculates N-2 builds, and patches the compliance policy |
| `Function/function.json` | Azure Function binding config; daily timer trigger at 22:00 UTC |

## Prerequisites

- An Intune device compliance policy with `validOperatingSystemBuildRanges` configured for Windows 11 24H2 and 25H2
- An Entra app registration with the **`DeviceManagementConfiguration.ReadWrite.All`** Graph API permission (application type)
- The app registration's client secret stored in an **Azure Key Vault**
- The Azure Function's managed identity must have **Key Vault Secrets User** on the Key Vault
- PowerShell modules available in the Function runtime: `Microsoft.Graph`, `ConvertFrom-HtmlTable`, `Az.KeyVault`
- The shared `Modules/Functions.psm1` (two levels up from the Function directory) containing `Get-PatchTuesday` and `AuthenticateTo-Graph`

## Deployment

1. In `Modules/Functions.psm1`, fill in the `AppReg1` credentials inside the `AuthenticateTo-Graph` switch block:

   ```powershell
   "AppReg1" {
       $AppId        = '<AppId>'         # Entra app registration (client) ID
       $TenantId     = '<TenantId>'      # Entra tenant ID
       $KeyVaultName = '<KeyVault Name>' # Azure Key Vault name
       $SecretName   = '<Secret Name>'   # Key Vault secret holding the client secret
   }
   ```

   In `Function/run.ps1`, replace `<PolicyId>` in both the policy JSON template and the PATCH URI:

   ```powershell
   "id": "<PolicyId>",
   Invoke-MgRestMethod ... -Uri "...deviceCompliancePolicies/<PolicyId>"
   ```

2. Deploy `Function/` to your Azure Function App (PowerShell runtime).

3. Ensure the `Modules/` directory is deployed alongside the Function App so the relative import path (`..\..\Modules\Functions.psm1`) resolves correctly.

## Policy Schema

The function patches the following fields on the compliance policy:

| Field | Description |
|---|---|
| `validOperatingSystemBuildRanges[].lowestVersion` | Set to `10.0.<N-2 build>` for each feature version |
| `validOperatingSystemBuildRanges[].highestVersion` | Unchanged; set manually to cap each feature version range (e.g. `10.0.26199.9999` for 24H2) |
