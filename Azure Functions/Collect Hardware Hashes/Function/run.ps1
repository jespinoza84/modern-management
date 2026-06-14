
<#
.SYNOPSIS
    Azure Function that stores or updates Autopilot hardware hashes in an Azure Table Storage.

.DESCRIPTION
    Triggered via HTTP, this function accepts a device serial number and hardware hash from
    the request body, then writes them to an Azure Storage Table named 'HardwareHashes'.
    If a record for the serial number already exists, the hash is updated; otherwise a new
    row is inserted. The function authenticates using the Az module's current context and
    targets the subscription/resource group/tenant defined in the configuration variables.

.PARAMETER Incoming
    The HTTP trigger input binding containing the request body (DeviceSerial, HardwareHash).

.PARAMETER TriggerMetadata
    Azure Functions trigger metadata passed by the runtime.
#>

using namespace System.Net

param ($Incoming, $TriggerMetadata)

$SubscriptionId = '<SubscriptionId>'
$ResourceGroup = '<ResourceGroupName>'
$TenantId = '<TenantId>'

# Set Az context for storage account and table
Set-AzContext -SubscriptionId $SubscriptionId -TenantId $TenantId
$StorageAccount = Get-AzStorageAccount -ResourceGroupName $ResourceGroup
$Table = (Get-AzStorageTable -Context $StorageAccount.Context -Name 'HardwareHashes').CloudTable
$PartitionKey = 'HardwareHash'

# Ingest request body
$SerialNumber = $Incoming.Body.DeviceSerial
$HardwareHash = $Incoming.Body.HardwareHash

# Confirm both values exist
if ($SerialNumber -and $HardwareHash) {
    # Check for existing entry
    [string]$Filter = [Microsoft.Azure.Cosmos.Table.TableQuery]::GenerateFilterCondition("SerialNumber", [Microsoft.Azure.Cosmos.Table.QueryComparisons]::Equal, "$SerialNumber")
    $UpdateSerial = Get-AzTableRow -Table $Table -CustomFilter $Filter

    # Update existing entry
    if ($null -ne $UpdateSerial.RowKey) {
        $UpdateSerial.Hash = "$HardwareHash"
        $UpdateSerial | Update-AzTableRow -Table $Table
        $Body = "Updated hash for $SerialNumber"
        Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
                StatusCode = [HttpStatusCode]::OK
                Body       = $Body
            })
    }

    else {
        # If new, create entry
        Add-AzTableRow -Table $Table -PartitionKey $PartitionKey -RowKey ([guid]::NewGuid().ToString()) -Property @{"SerialNumber" = "$SerialNumber"; "Hash" = "$HardwareHash" }
        $Body = "Stored hash for $SerialNumber"
        Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
                StatusCode = [HttpStatusCode]::OK
                Body       = $Body
            })
    }
}
else {
    Write-Output "Missing required input"
    exit 1
}
