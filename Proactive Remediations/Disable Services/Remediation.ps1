<#
.SYNOPSIS
    Disables and stops a defined set of Windows services.

.DESCRIPTION
    Intune Proactive Remediation script that runs after the paired detection
    script flags a device as non-compliant. For each service in $Services it
    sets the startup type to Disabled (so the service will not start on the
    next boot) and force-stops it if currently running. Missing services are
    ignored via -ErrorAction SilentlyContinue so the script remains idempotent
    across devices that may not have every service installed.

    Writes "Remediated" and exits 0 on success; on any terminating error it
    writes the error message and exits 1 so Intune reports the remediation as
    failed.
#>

$ErrorActionPreference = 'Stop'

try {
    $Services = (
        "Service1",
        "Service2"
    )

    foreach ($Service in $Services) {
        Set-Service -Name $Service -StartupType Disabled -ErrorAction SilentlyContinue
        Stop-Service -Name $Service -StartupType Disabled -Force -ErrorAction SilentlyContinue
    }

    Write-Output "Remediated"
    exit 0
}
catch {
    Write-Error $_.Exception.Message
    exit 1
}