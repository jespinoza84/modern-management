<#
    .SYNOPSIS
        Collects a device's hardware hash and serial number, then submits them to an Azure Function for storage.

    .DESCRIPTION
        Queries the BIOS serial number via the Win32_BIOS CIM class and retrieves the hardware hash from the MDM
        DeviceDetail namespace (MDM_DeviceDetail_Ext01). Both values are sent as a JSON payload to a configured
        Azure Function endpoint via HTTP POST.

        Intended to run on the client device during the Autopilot enrollment process. Exits 0 on success
        (printing the function response as JSON) or 1 on failure (printing the error).

    .NOTES
        Requires administrator privileges to query the MDM CIM namespace.
        Update the Invoke-RestMethod URL with the actual Azure Function endpoint before deployment.
        Set a Proactive Remediation recurrence of 90+ days
#>

$ErrorActionPreference = 'Stop'

try {
    $SerialNumber = (Get-CimInstance -ClassName Win32_BIOS).SerialNumber
    $Hash = (Get-CimInstance -Namespace root/cimv2/mdm/dmmap -Class MDM_DevDetail_Ext01 -Filter "InstanceID='Ext' AND ParentID='./DevDetail'").DeviceHardwareData
    $Headers = New-object "System.Collections.Generic.Dictionary[[String],[String]]"
    $Headers.Add("Content-Type", "application/json")

    $Body = @{
        DeviceSerial = $SerialNumber
        HardwareHash = $Hash
    } | ConvertTo-Json

    $response = Invoke-RestMethod "Path/To/FunctionUrl" -Method POST -Headers $Headers -Body $Body
    $response | ConvertTo-Json
    exit 0
}
catch {
    Write-Output $_
    exit 1
}