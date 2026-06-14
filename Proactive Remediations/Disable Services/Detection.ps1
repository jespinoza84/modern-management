<#
.SYNOPSIS
    Intune Proactive Remediation detection script that checks whether a defined
    set of Windows services are stopped and disabled.

.DESCRIPTION
    Iterates over the services listed in $Services and inspects each one:
    - If the service is present, it is considered compliant only when its
        Status is 'Stopped' AND its StartType is 'Disabled'.
    - If the service is not present on the device, it is treated as compliant
        (there is nothing to disable).

    As soon as a service is found running or not set to Disabled, the script
    writes "Remediate" and exits 1, signaling Intune to run the paired
    Remediation script. If every service is compliant (or absent), it reports
    the compliant count and exits 0.

    An optional manufacturer-scoping block (commented out below) can be enabled
    to restrict the check to a specific OEM such as Dell, HP, or Lenovo.
#>

<# Uncomment this block if you want to scope to a specific manufacturer - Dell, HP, Lenovo etc.
$Win32BIOS = (Get-CimInstance -ClassName Win32_BIOS)
$Manufacturer = $Win32BIOS.Manufacturer

if ($Manufacturer -notlike "*dell*"){
    Write-Output "Not a Dell device"
    exit 0
}
#>

$Compliant = 0
$Services = (
    "Service1",
    "Service2"
)

foreach ($Service in $Services) {
    $ServiceInfo = Get-Service -Name $Service -ErrorAction SilentlyContinue
    if ($ServiceInfo) {
        # Found - Confirm status
        if ($ServiceInfo.Status -ne 'Stopped' -or $ServiceInfo.StartType -ne 'Disabled') {
            Write-Output "Remediate"
            exit 1
        }
        else {
            $Compliant++
        }
    }
    else {
        $Compliant++
    }
}

Write-Output "$Compliant services compliant"
exit 0