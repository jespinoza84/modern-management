function Get-PatchTuesday {
  <#
.SYNOPSIS
  Finds the date of the second Tuesday of the current month.
.DESCRIPTION
  Patching is important, but automating updates can be difficult due to patching releases on the second Tuesday of the month.  
  The code below is an example of how to identify the date of the second Tuesday for a given month.
  It's purpose is to use in scripts to schedule maintenance windows for patching.
  The script will output the second Tuesday of the month by default.
  Optionally, you can pass in a week day and an instance count to find what date that day falls on.
.OUTPUTS
  The date of patch Tuesday.
  If given optioaly parameters, it will find the “X” instance of a day of the week.
.EXAMPLE
  Get Patch Tuesday for the month
  Get-PatchTuesday

  Is today Patch Tuesday?
  (get-date).Day -eq (Get-PatchTuesday).day

  Get 5 days after path Tuesday
  (Get-PatchTuesday).AddDays(5)

# Get the 3rd wednesday of the month
Get-PatchTuesday -weekDay Wednesday -findNthDay 3
.NOTES
  Version:        1.0
  Author:         Travis Roberts
  Creation Date:  9/8/2020
  Website         www.ciraltos.com
  Purpose/Change: Function to find the second Tuesday of the month, or the "X" instance of a weekDay in the current month.
  
  ***This script is offered as-is with no warranty, expressed or implied.  Test it before you trust it.***
#>
  [CmdletBinding()]
  Param
  (
    [Parameter(position = 0)]
    [ValidateSet("Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday")]
    [String]$weekDay = 'Tuesday',
    [ValidateRange(0, 5)]
    [Parameter(position = 1)]
    [int]$findNthDay = 2
  )
  # Get the date and find the first day of the month
  # Find the first instance of the given weekday
  [datetime]$today = [datetime]::NOW
  $todayM = $today.Month.ToString()
  $todayY = $today.Year.ToString()
  [datetime]$strtMonth = $todayM + '/1/' + $todayY
  while ($strtMonth.DayofWeek -ine $weekDay ) { $strtMonth = $StrtMonth.AddDays(1) }
  $firstWeekDay = $strtMonth

  # Identify and calculate the day offset
  if ($findNthDay -eq 1) {
    $dayOffset = 0
  }
  else {
    $dayOffset = ($findNthDay - 1) * 7
  }

  # Return date of the day/instance specified
  $patchTuesday = $firstWeekDay.AddDays($dayOffset) 
  return $patchTuesday
}

function AuthenticateTo-Graph {
  <#
.SYNOPSIS
  Authenticates to Microsoft Graph using a client credentials OAuth flow.
.DESCRIPTION
  Retrieves a client secret from Azure Key Vault for the specified app registration,
  then requests an access token from Azure AD using the client credentials grant type.
  The token is converted to a secure string and used to connect via Connect-MgGraph.
  Throws if the connection cannot be established.
.PARAMETER AppRegistration
  The name of the app registration to authenticate with. Must be one of: AppReg1, AppReg2, AppReg3.
  Each registration maps to its own App ID, Tenant ID, Key Vault, and secret name.
.EXAMPLE
  AuthenticateTo-Graph -AppRegistration AppReg1
.NOTES
  Requires the Az.KeyVault and Microsoft.Graph modules.
  The calling identity must have read access to the Key Vault secret and sufficient Graph API permissions.
#>
  param (
    [parameter(Mandatory = $true)]
    [ValidateSet("AppReg1, AppReg2, AppReg3")]
    [string]$AppRegistration
  )

  switch -Wildcard ($AppRegistration) {
    "AppReg1" {
      $AppId = '<AppId>'
      $TenantId = '<TenantId>'
      $KeyVaultName = '<KeyVault Name>'
      $SecretName = '<Secret Name>'
    }
    "AppReg2" {
      $AppId = '<AppId>'
      $TenantId = '<TenantId>'
      $KeyVaultName = '<KeyVault Name>'
      $SecretName = '<Secret Name>'
    }
    "AppReg3" {
      $AppId = '<AppId>'
      $TenantId = '<TenantId>'
      $KeyVaultName = '<KeyVault Name>'
      $SecretName = '<Secret Name>'
    }
  }
  
  $Secret = Get-AzKeyVaultSecret -VaultName $KeyVaultName -Name $SecretName -AsPlainText

  $Body = @{
    Grant_Type    = "client_credentials"
    Scope         = "https://graph.microsoft.com/.default"
    Client_Id     = $AppId
    Client_Secret = $Secret
  }

  $Connection = Invoke-RestMethod -Method POST -Uri "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token" -Body $Body
  $Token = $Connection.access_token
  $SecureToken = ConvertTo-SecureString -String $Token -AsPlainText -Force
  Connect-MgGraph -AccessToken $SecureToken -NoWelcome

  if (Get-MgContext) {
    Write-Output "Successfully authenticated to Microsoft Graph"
  }
  else {
    throw "Failed to authenticate to Microsoft Graph"
  }
}