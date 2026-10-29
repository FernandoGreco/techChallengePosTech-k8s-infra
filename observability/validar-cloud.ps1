param(
    [string]$PrivateCommandPath = (Join-Path $env:TEMP 'grafana-tc3-install.private.txt'),
    [string]$LogsReadTokenPath,
    [string]$EvidencePath
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'grafana-private.ps1')
$access = Get-Tc3GrafanaAccess -PrivateCommandPath $PrivateCommandPath
$cluster = 'kubernetes-admin-kubernetes'
$results = [System.Collections.Generic.List[object]]::new()
$logsReadToken = if ($LogsReadTokenPath) { [IO.File]::ReadAllText((Resolve-Path -LiteralPath $LogsReadTokenPath).Path).Trim() } else { $access.Token }

function Invoke-CloudRead {
    param([string]$Uri, [string]$User, [string]$Token = $access.Token)
    $auth = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($User + ':' + $Token))
    try {
        $body = Invoke-RestMethod -Uri $Uri -Headers @{ Authorization = "Basic $auth" } -TimeoutSec 15 -ErrorAction Stop
        return @{ Status = 200; Body = $body }
    } catch {
        $statusCode = if ($_.Exception.Response) { [int]$_.Exception.Response.StatusCode } else { 0 }
        $errorBody = [string]$_.ErrorDetails.Message
        $category = if ($errorBody -match 'invalid scope|missing scope|insufficient.*scope|logs:read|metrics:read') { 'missing_read_scope' } elseif ($errorBody -match 'invalid.*(credential|token)|authentication') { 'authentication' } else { 'http_error' }
        return @{ Status = $statusCode; Body = $null; Category = $category }
    } finally { $auth = $null }
}

try {
    $queries = [ordered]@{
        node_count = "count(count by (node) (kube_node_info{cluster=`"$cluster`"}))"
        node_cpu_series = "count(node_cpu_seconds_total{cluster=`"$cluster`"})"
        node_memory_series = "count(node_memory_MemAvailable_bytes{cluster=`"$cluster`"})"
        pod_cpu_series = "count(container_cpu_usage_seconds_total{cluster=`"$cluster`",container!=`"`"})"
        pod_memory_series = "count(container_memory_working_set_bytes{cluster=`"$cluster`",container!=`"`"})"
        latest_metric_timestamp = "max(timestamp(kube_node_info{cluster=`"$cluster`"}))"
    }
    $metricsBase = $access.MetricsUrl -replace '/push$', ''
    foreach ($query in $queries.GetEnumerator()) {
        $read = Invoke-CloudRead -Uri ($metricsBase + '/api/v1/query?query=' + [Uri]::EscapeDataString($query.Value)) -User $access.MetricsUser
        $series = @($read.Body.data.result)
        $value = if ($read.Status -eq 200 -and $series.Count -gt 0 -and $series[0]) { [string]$series[0].value[1] } else { $null }
        $results.Add([pscustomobject]@{ check = $query.Key; http = $read.Status; value = $value })
        if ($read.Status -in @(401, 403)) { break }
    }
    $logsBase = $access.LogsUrl -replace '/push$', ''
    $logQueries = [ordered]@{
        pod_logs = "{cluster=`"$cluster`",namespace=`"grafana-monitoring`",job!=`"integrations/kubernetes/eventhandler`"}"
        kubernetes_events = "{cluster=`"$cluster`",job=`"integrations/kubernetes/eventhandler`"}"
    }
    foreach ($query in $logQueries.GetEnumerator()) {
        $read = Invoke-CloudRead -Uri ($logsBase + '/query_range?query=' + [Uri]::EscapeDataString($query.Value) + '&limit=10&since=10m&direction=backward') -User $access.LogsUser -Token $logsReadToken
        $entryCount = 0
        $latestNs = [decimal]0
        foreach ($stream in @($read.Body.data.result)) {
            foreach ($entry in @($stream.values)) {
                if ($entry -and $entry.Count -ge 2) {
                    $entryCount++
                    if ([decimal]$entry[0] -gt $latestNs) { $latestNs = [decimal]$entry[0] }
                }
            }
        }
        $latest = if ($latestNs -gt 0) { [DateTimeOffset]::FromUnixTimeSeconds([long][Math]::Floor($latestNs / 1000000000)).UtcDateTime.ToString('o') } else { $null }
        $results.Add([pscustomobject]@{ check = $query.Key; http = $read.Status; entries = $entryCount; latest_utc = $latest; error_category = $read.Category })
    }
    $metricChecks = @($results.ToArray() | Where-Object { $_.check -notin @('pod_logs', 'kubernetes_events') })
    $metricsPassed = @($metricChecks | Where-Object { $_.http -ne 200 -or -not $_.value -or [double]$_.value -le 0 }).Count -eq 0
    $latestMetric = $metricChecks | Where-Object check -eq 'latest_metric_timestamp'
    $metricAge = if ($latestMetric.value) { [Math]::Floor([DateTimeOffset]::UtcNow.ToUnixTimeSeconds() - [double]$latestMetric.value) } else { $null }
    $metricsPassed = $metricsPassed -and $null -ne $metricAge -and $metricAge -ge 0 -and $metricAge -le 180
    $logChecks = @($results.ToArray() | Where-Object { $_.check -in @('pod_logs', 'kubernetes_events') })
    $logsPassed = @($logChecks | Where-Object { $_.http -ne 200 -or $_.entries -le 0 }).Count -eq 0
    $report = [pscustomobject]@{ checked_utc = [DateTime]::UtcNow.ToString('o'); cluster = $cluster; metrics_received = $metricsPassed; metric_age_seconds = $metricAge; logs_and_events_read_verified = $logsPassed; checks = @($results.ToArray()) }
    $safeJson = $report | ConvertTo-Json -Depth 6
    if ($safeJson.Contains($access.Token) -or ($logsReadToken -and $safeJson.Contains($logsReadToken))) { throw 'Falha na verificação de sigilo.' }
    if ($EvidencePath) { $safeJson | Set-Content -LiteralPath $EvidencePath -Encoding UTF8 }
    Write-Output $safeJson
} finally {
    $access.Clear()
    $logsReadToken = $null
}
