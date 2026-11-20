<#
  Makes AMP's Status page fit an instance that runs as a node.

  On a node, login and chat run on the master, so nothing listens on TCP 9000/9001 and AMP shows
  both as "Not Listening". This script changes the instance (not the template):
    - removes the Login and Chat ports from its port list,
    - shows Match Ports as a live count: Listening while at least one match runs on the node,
      Not Listening when the node is idle,
    - sets the Connection Link to the master's login address, where players connect.

  AMP restarts the instance to apply this, which ends every map the node is hosting. The script
  stops if a match looks active (Match Ports listening, or a spawn without a stop in the console
  backlog); -Force skips that check. It starts the app again afterwards.

  Rebuilding the instance's configuration from the template puts the Login and Chat ports back;
  run this again afterwards. Uses ..\amp-query.ps1 and the session saved by ..\amp-login.ps1.

  Examples:
    .\set-node-ports.ps1 -InstanceName GlobalAgenda01 -MasterLogin 203.0.113.10:9000 -DryRun
    .\set-node-ports.ps1 -InstanceName GlobalAgenda01 -MasterLogin 203.0.113.10:9000
#>
param(
    [Parameter(Mandatory)][string]$InstanceName,
    [Parameter(Mandatory)][ValidatePattern('^[^:\s]+:\d{1,5}$')][string]$MasterLogin,
    [string]$AmpQuery = (Join-Path $PSScriptRoot '..\amp-query.ps1'),
    [switch]$Force,
    [switch]$DryRun
)
$ErrorActionPreference = 'Stop'

$targets = @(& $AmpQuery ADSModule/GetInstances -Depth 8 | ConvertFrom-Json)
$inst = $targets.AvailableInstances | Where-Object InstanceName -eq $InstanceName | Select-Object -First 1
if (-not $inst) { throw "No AMP instance named '$InstanceName'." }
$id = $inst.InstanceID

$live = & $AmpQuery ADSModule/GetInstanceLiveSettings -Params @{ instanceId = $id } -Depth 6 | ConvertFrom-Json
$match = @($live.'GenericModule.App.Ports' | ConvertFrom-Json) | Where-Object Ref -eq 'MatchPorts' | Select-Object -First 1
if (-not $match) { throw "'$InstanceName' has no MatchPorts port. Is it a Global Agenda instance?" }
$match.IsDelayedOpen = $false   # a delayed-open port always shows "Waiting" while the app runs
$match.MinListening  = 1

$settings = @{
    'GenericModule.App.Ports'                     = ConvertTo-Json -Compress -Depth 6 -InputObject @($match)
    'GenericModule.App.PrimaryApplicationPortRef' = 'MatchPorts'
    'GenericModule.Meta.EndpointURIFormat'        = $MasterLogin
}

if ($DryRun) {
    "Instance: $InstanceName ($id)"
    $settings.GetEnumerator() | ForEach-Object { "  $($_.Key) = $($_.Value)" }
    return
}

if (-not $Force) {
    $u = & $AmpQuery Core/GetUpdates -Instance $InstanceName -Depth 6 | ConvertFrom-Json
    $running = @{}
    foreach ($e in $u.ConsoleEntries) {
        if ($e.Contents -match '\[node\] spawned instance=(\d+)') { $running[$Matches[1]] = $true }
        if ($e.Contents -match 'MarkStopped: instance_id=(\d+)') { $running.Remove($Matches[1]) }
    }
    $listening = @($u.Ports | Where-Object Port -eq $match.Port | ForEach-Object ListeningCount) | Measure-Object -Sum
    if ($running.Count -or $listening.Sum) {
        throw "A match looks active on the node. Try again when it's empty, or pass -Force."
    }
}

# RebuildConfiguration must stay false: true resets the instance's template metadata.
$r = & $AmpQuery ADSModule/ApplyInstanceConfiguration -Params @{
    InstanceID = $id; Args = $settings; RebuildConfiguration = $false
} -Depth 4 | ConvertFrom-Json
if (-not $r.Status) { throw "AMP refused the change: $($r.Reason)" }

# The instance restarts with the app stopped.
$deadline = (Get-Date).AddMinutes(4); $state = $null
do {
    Start-Sleep -Seconds 8
    try { $state = (& $AmpQuery Core/GetStatus -Instance $InstanceName -Depth 3 | ConvertFrom-Json).State } catch { $state = $null }
} until ($null -ne $state -or (Get-Date) -gt $deadline)
if ($null -eq $state) { throw "The instance didn't come back within 4 minutes. Check it in the panel." }
if ($state -ne 20) { $null = & $AmpQuery Core/Start -Instance $InstanceName -Depth 3; "Started the app." }
"Done: the Status page lists Match Ports and SFTP, and the Connection Link is $MasterLogin."
