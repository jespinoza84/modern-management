
<#
.SYNOPSIS
    Updates the Intune minimum OS compliance policy with the N-2 Windows 11 build on Patch Tuesday.

.DESCRIPTION
    Runs on a schedule and exits early if today is not Patch Tuesday. When it is, the script
    authenticates to Microsoft Graph using app-only credentials stored in Azure Key Vault, scrapes
    the Windows 11 release history from Microsoft Learn, identifies the second-latest cumulative
    update released two months prior (N-2) for each major feature version (24H2 and 25H2), and
    patches the Intune device compliance policy's lowestVersion for each build range accordingly.

.PARAMETER daily
    Passed by the Azure Function timer trigger runtime.

.NOTES
    Requires: Microsoft.Graph PowerShell module, ConvertFrom-HtmlTable module, Az.KeyVault module.
    Placeholders <AppId>, <TenantId>, <KeyVault Name>, <Secret Name>, and <PolicyId> must be
    replaced with real values before deployment.
#>

param ($daily)
$ErrorActionPreference = 'Stop'

Import-Module "$PSScriptRoot\..\..\Modules\Functions.psm1" -Force
Write-output "Imported Functions module from $PSScriptRoot\..\..\Modules\Functions.psm1"

try {
    # Check if today is Patch Tuesday. If not, exit.
    if (-not((Get-Date).Day -eq (Get-PatchTuesday).Day)) {
        Write-Output "Not Patch Tuesday"
        exit 0
    }
    else {
        Write-Output "Patch Tuesday ... Running"
    }

    AuthenticateTo-Graph -AppRegistration "AppReg1"

    # Set N-2 months
    $N_Minus_2 = (Get-Date).AddMonths(-2).ToString("yyyy-MM")

    # Grab version history and convert to tables
    $AllBuilds = (Invoke-WebRequest -UseBasicParsing -Uri "https://learn.microsoft.com/en-us/windows/release-health/windows11-release-information")
    $Tables = (ConvertFrom-HtmlTable -Content $AllBuilds -WarningAction Ignore)

    # Parse indices from the build numbers we want
    $24H2_TableIndices = @()
    $25H2_TableIndices = @()
    for ($i = 0; $i -lt $Tables.Count; $i++) {
        if ($Tables[$i].Build -match "26100") {
            $24H2_TableIndices += $i
        }
        elseif ($Tables[$i].Build -match "26200") {
            $25H2_TableIndices += $i
        }
    }
    Write-Output "Identified tables for 24H2: $($24H2_TableIndices -join ",")"
    Write-Output "Identified tables for 25H2: $($25H2_TableIndices -join ",")"

    # Merge tables from identified indices into single tables for each major build
    $24H2 = @()
    $25H2 = @()
    foreach ($index in $24H2_TableIndices) {
        $24H2 += $Tables[$index]
    }
    foreach ($index in $25H2_TableIndices) {
        $25H2 += $Tables[$index]
    }

    Write-Output "Merged tables for 24H2: $($24H2.Count) entries"
    Write-Output "Merged tables for 25H2: $($25H2.Count) entries"

    $AllBuilds = ($24H2, $25H2)
    $NewMinVersions = foreach ($Build in $Allbuilds) {
        # Get builds that are n-2
        $N_Minus_2_Builds = $Build | Where-Object { $_.'Availability Date' -like "$N_Minus_2*" -and $_.'Update Type' -notlike "*oob*" } | Sort-Object -Descending Build

        if ($N_Minus_2_Builds.Count -gt 1) {
            $Version = "10.0.$($N_Minus_2_Builds[1].Build)"
        }
        else {
            $Version = "10.0.$($N_Minus_2_Builds[0].Build)"
        }

        # Major Builds
        switch -wildcard ($version) {
            "*26100*" {
                $MajorBuild = "24H2"
                break
            }
            "*26200*" {
                $MajorBuild = "25H2"
                break
            }
            default {
                throw "Incompatible version found: $Version"
            }
        }

        # Output custom object with new minimum version and major build for use in policy update
        [PSCustomObject]@{
            MajorBuild = $MajorBuild
            Version    = $Version
        }
    }

    Write-Output "Identified new minimum versions: $($NewMinVersions | Format-Table -AutoSize | Out-String)"

    # Partial policy template - in production, this will be larger but the important fields here are the same.
    $policy = '
{
    "id": "<PolicyId>",
    "displayName": "Minimum Windows Version - Auto Updated",
    "description": "Policy to set minimum Windows version. Updated automatically on Patch Tuesday.",
    "osMinimumVersion": "<Version>",
    "validOperatingSystemBuildRanges": [
        {
            "description": "Windows 11 24H2",
            "lowestVersion": "10.0.26100.0",
            "highestVersion": "10.0.26199.9999"
        },
        {
            "description": "Windows 11 25H2",
            "lowestVersion": "10.0.26200.0",
            "highestVersion": "10.0.26299.9999"
        }
    ]
}'

    $Policy = $Policy | ConvertFrom-Json

    # Assign new minimum versions to the policy based on major build
    foreach ($item in $NewMinVersions) {
        switch -wildcard ($item.MajorBuild) {
            "24H2" {
                $Policy.validOperatingSystemBuildRanges[0].lowestVersion = [string]$item.Version
                break
            }
            "25H2" {
                $Policy.validOperatingSystemBuildRanges[1].lowestVersion = [string]$item.Version
                break
            }
            default {
                throw "Error while assigning version to policy"
            }
        }
    }

    $policy = $Policy | ConvertTo-Json -Depth 10

    # Patch to Graph
    Invoke-MgRestMethod -Method PATCH -Uri "https://graph.microsoft.com/beta/deviceManagement/deviceCompliancePolicies/<PolicyId>" -Body $policy -ContentType "application/json"

    <# 
    Use this space for webhook to Power Automate / Teams
    #>
}
catch {
    Write-Error "An error occurred: $_"
    exit 1
}