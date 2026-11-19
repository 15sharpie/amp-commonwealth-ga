<#
  Creates an AMP instance from this template through the AMP API, without AMP having to
  fetch the template from a (public) GitHub repo.

  It reads commonwealthga.kvp, inlines the @IncludeJson[...] files, and passes everything to
  ADSModule/CreateInstance as provisioning settings. Uses ..\amp-query.ps1 and the session saved
  by ..\amp-login.ps1.

  Examples:
    .\deploy-to-amp.ps1 -DryRun                      # show what would be sent
    .\deploy-to-amp.ps1                              # create the instance (does not update or start the app)
#>
param(
    [string]$FriendlyName = 'Global Agenda',
    [string]$InstanceName = 'CommonwealthGA01',
    [int]$ManagementPort = 8089,
    [int]$SftpPort = 2232,
    [int]$DatastoreId = 1,
    [string]$AmpQuery = (Join-Path $PSScriptRoot '..\amp-query.ps1'),
    [switch]$DryRun
)
$ErrorActionPreference = 'Stop'
$here = $PSScriptRoot

function Read-Kvp([string]$path) {
    $d = [ordered]@{}
    foreach ($line in Get-Content -LiteralPath $path -Encoding UTF8) {
        if ($line -match '^\s*$' -or $line -match '^\s*#') { continue }
        $i = $line.IndexOf('=')
        if ($i -lt 1) { throw "Bad kvp line: $line" }
        $d[$line.Substring(0, $i)] = $line.Substring($i + 1)
    }
    $d
}

# Template ports.json uses "TCP"/"UDP"/"Both"; provisioning uses the full numeric form.
function Convert-Ports($ports) {
    $proto = @{ TCP = 0; UDP = 1; Both = 2 }
    @($ports | ForEach-Object {
        [ordered]@{
            Protocol       = $proto["$($_.Protocol)"]
            Port           = [int]$_.Port
            Offset         = 0
            Range          = $(if ($_.Range) { [int]$_.Range } else { 1 })
            MinListening   = $(if ($null -ne $_.MinListening) { [int]$_.MinListening } else { 0 })
            RangeSeparator = '-'
            Ref            = $_.Ref
            Name           = $_.Name
            Description    = $_.Description
            IsDelayedOpen  = [bool]$_.IsDelayedOpen
            Hidden         = [bool]$_.Hidden
            ChildPorts     = $null
            Required       = [bool]$_.Required
        }
    })
}

$kvp = Read-Kvp (Join-Path $here 'commonwealthga.kvp')
$settings = [ordered]@{}
foreach ($k in $kvp.Keys) {
    $v = $kvp[$k]
    if ($v -match '^@IncludeJson\[(.+)\]$') {
        $json = Get-Content -LiteralPath (Join-Path $here $Matches[1]) -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($k -eq 'App.Ports') { $json = Convert-Ports $json }
        $v = ConvertTo-Json -InputObject @($json) -Depth 10 -Compress
    }
    $settings["GenericModule.$k"] = $v
}
$settings['GenericModule.Meta.OriginalSource'] = '15sharpie-amp-commonwealth-ga (private, deployed via API)'
$settings['FileManagerPlugin.SFTP.SFTPIPBinding'] = '0.0.0.0'
$settings['FileManagerPlugin.SFTP.SFTPPortNumber'] = "$SftpPort"

# Find the local ADS target and make sure the name is free.
$targets = @(& $AmpQuery ADSModule/GetInstances -Depth 8 | ConvertFrom-Json)
$target = $targets | Select-Object -First 1
$existing = @($targets | ForEach-Object { $_.AvailableInstances })
if ($existing | Where-Object { $_.InstanceName -eq $InstanceName }) { throw "An instance named $InstanceName already exists." }
if ($existing | Where-Object { $_.Port -eq $ManagementPort }) { throw "Management port $ManagementPort is already used." }

$params = @{
    TargetADSInstance  = $target.InstanceId
    NewInstanceId      = [guid]::Empty.ToString()
    Module             = 'GenericModule'
    InstanceName       = $InstanceName
    FriendlyName       = $FriendlyName
    IPBinding          = '0.0.0.0'
    PortNumber         = $ManagementPort
    AdminUsername      = ''
    AdminPassword      = ''
    ProvisionSettings  = $settings
    AutoConfigure      = $false
    PostCreate         = 0      # do nothing: the first update needs a Steam login typed in AMP
    StartOnBoot        = $true
    DisplayImageSource = $settings['GenericModule.Meta.DisplayImageSource']
    TargetDatastore    = $DatastoreId
    Group              = ''
}

if ($DryRun) {
    "Target: $($target.FriendlyName) ($($target.InstanceId))"
    "Instance: $InstanceName / '$FriendlyName', management port $ManagementPort, SFTP $SftpPort, datastore $DatastoreId"
    "Provision settings ($($settings.Count)):"
    $settings.Keys | ForEach-Object { "  $_" }
    "Ports: $($settings['GenericModule.App.Ports'])"
    return
}

& $AmpQuery ADSModule/CreateInstance -Params $params
