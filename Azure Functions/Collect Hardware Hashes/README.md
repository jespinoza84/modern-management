# Collect Hardware Hashes

Keeps an Azure Table Storage record of Autopilot hardware hashes for every managed device. A proactive remediation script runs on each device and POSTs the device's serial number and hardware hash to an Azure Function, which upserts the data into the table.

## How it works

```
Device (Intune Proactive Remediation)
  └─ RunFromClient.ps1  ──POST──►  Azure Function (run.ps1)
                                        └─ Azure Table Storage (HardwareHashes)
```

1. **RunFromClient.ps1** runs on the device every ~90 days via Intune Proactive Remediation. It reads the BIOS serial number (`Win32_BIOS`) and hardware hash (`MDM_DeviceDetail_Ext01`) and sends them as a JSON payload to the Azure Function endpoint.
2. **run.ps1** (the Azure Function) receives the payload, authenticates against Azure, and looks up the device's serial number in the `HardwareHashes` table.
   - If a matching row exists, the hash is updated.
   - If no row exists, a new entry is inserted with a generated GUID as the row key.

## Files

| File | Purpose |
|---|---|
| `RunFromClient.ps1` | Proactive Remediation script deployed via Intune; collects and submits the hardware hash |
| `Function/run.ps1` | Azure Function body; handles the HTTP request and writes to Table Storage |
| `Function/function.json` | Azure Function binding config; HTTP trigger with function-level auth |

## Prerequisites

- An Azure Storage Account with a Table named **`HardwareHashes`**
- The Azure Function's managed identity (or service principal) must have **Storage Table Data Contributor** on the storage account
- The Az PowerShell module (`Az.Accounts`, `Az.Storage`, `AzTable`) available in the Function runtime
- `RunFromClient.ps1` requires **administrator privileges** on the device to query the MDM CIM namespace

## Deployment

### Azure Function

1. Update the three placeholders at the top of `Function/run.ps1`:

   ```powershell
   $SubscriptionId = '<SubscriptionId>'
   $ResourceGroup  = '<ResourceGroupName>'
   $TenantId       = '<TenantId>'
   ```

2. Deploy `Function/` to your Azure Function App (PowerShell runtime).

### Intune Proactive Remediation

1. Replace the placeholder URL in `RunFromClient.ps1`:

   ```powershell
   $response = Invoke-RestMethod "Path/To/FunctionUrl" -Method POST ...
   ```

   Use the function's HTTP trigger URL from the Azure portal (include the `code=` key parameter if using function-level auth).

2. Create a new Proactive Remediation in Intune:
   - **Detection script**: any script that always returns exit 1 to force the remediation to run
   - **Remediation script**: `RunFromClient.ps1`
   - **Run as**: System (required for MDM CIM namespace access)
   - **Recurrence**: every 90 days (or your preferred interval)

## Table Schema

| Column | Description |
|---|---|
| `PartitionKey` | Always `HardwareHash` |
| `RowKey` | GUID generated at insert time |
| `SerialNumber` | Device BIOS serial number |
| `Hash` | Autopilot hardware hash |
