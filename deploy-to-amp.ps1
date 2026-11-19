<#
  Creates a Global Agenda instance through the AMP API, the same way AMP's "Create Instance"
  wizard does (ADSModule/CreateInstanceFromSpec), so the controller fully manages it and it opens
  from the panel.

  AMP must already list this repo under Configuration Repositories, and the app must show up in
  its app list (needs manifest.json at the repo root). Uses ..\amp-query.ps1 and the session saved
  by ..\amp-login.ps1.

  Examples:
    .\deploy-to-amp.ps1 -DryRun     # show which app and target would be used
    .\deploy-to-amp.ps1             # create the instance (does not update or start the app)

  Note: don't build instances with ADSModule/CreateInstance and inline settings instead. Those
  are created "Unmanaged" (ManagementMode 0) and the panel refuses to open them.
#>
param(
    [string]$FriendlyName = 'Global Agenda',
    [string]$AppName = 'Global Agenda (Commonwealth)',
    [int]$DatastoreId = 1,
    [string]$Group = '',
    [string]$AmpQuery = (Join-Path $PSScriptRoot '..\amp-query.ps1'),
    [switch]$DryRun
)
$ErrorActionPreference = 'Stop'

$apps = @(& $AmpQuery ADSModule/GetSupportedAppSummaries -Depth 6 | ConvertFrom-Json)
$app = $apps | Where-Object FriendlyName -eq $AppName | Select-Object -First 1
if (-not $app) {
    throw "AMP doesn't list '$AppName'. Add 15sharpie/amp-commonwealth-ga:main to Configuration Repositories, then run ADSModule/RefreshRemoteConfigStores and ADSModule/RefreshAppCache."
}

$targets = @(& $AmpQuery ADSModule/GetInstances -Depth 8 | ConvertFrom-Json)
$target = $targets | Select-Object -First 1

if ($DryRun) {
    "App: $($app.FriendlyName) ($($app.Id))"
    "Target: $($target.FriendlyName) ($($target.InstanceId)), datastore $DatastoreId"
    "New instance name: '$FriendlyName'"
    return
}

& $AmpQuery ADSModule/CreateInstanceFromSpec -Params @{
    SpecId            = $app.Id
    TargetADSInstance = $target.InstanceId
    FriendlyName      = $FriendlyName
    PostCreate        = 0      # do nothing: the first update needs a Steam login typed in AMP
    StartOnBoot       = $true
    TargetDatastore   = $DatastoreId
    Group             = $Group
}
