# Função de apoio: não imprime nem persiste credenciais. Não executar o comando
# recebido; apenas extrair os campos esperados e consultar a API autenticada.
function Get-Tc3GrafanaAccess {
    param([string]$PrivateCommandPath)
    $privateText = [IO.File]::ReadAllText($PrivateCommandPath)
    $fields = @{}
    foreach ($fieldName in @('username', 'password')) {
        $pattern = 'collectorCommon\.alloy\.remoteConfig\.auth\.' + $fieldName + '=(?:"([^"]+)"|''([^'']+)''|([^\s"'']+))'
        $match = [regex]::Match($privateText, $pattern)
        $fields[$fieldName] = ($match.Groups[1..3] | Where-Object Success | Select-Object -First 1).Value
        if (-not $fields[$fieldName]) { throw 'Formato do arquivo privado não reconhecido.' }
    }
    $auth = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($fields.username + ':' + $fields.password))
    $payload = @{
        id = 'grafana-cloud-kubernetes-admin-kubernetes-grafana-monitoring-alloy-daemon-ip-172-31-87-121'
        localAttributes = @{
            cluster = 'kubernetes-admin-kubernetes'; platform = 'kubernetes'
            source = 'k8s-monitoring'; workloadType = 'daemonset'
            presets = 'small,host-storage,clustered,filesystem-log-reader,daemonset'
            'service-discovery' = 'true'
        }
    } | ConvertTo-Json -Compress
    try {
        $remote = Invoke-RestMethod -Method Post -Uri 'https://fleet-management-prod-015.grafana.net/collector.v1.CollectorService/GetConfig' -Headers @{ Authorization = "Basic $auth"; 'Connect-Protocol-Version' = '1' } -ContentType 'application/json' -Body $payload -TimeoutSec 15 -ErrorAction Stop
    } catch {
        throw 'Não foi possível consultar os identificadores de destino; resposta privada omitida.'
    }
    $access = @{ Token = $fields.password }
    foreach ($entry in @(@('Metrics', '/api/prom/push'), @('Logs', '/loki/api/v1/push'))) {
        $pattern = 'url\s*=\s*"(https://[a-zA-Z0-9.-]+\.grafana\.net' + [regex]::Escape($entry[1]) + ')"[\s\S]{0,600}?username\s*=\s*"([^"\r\n]+)"'
        $destination = [regex]::Match([string]$remote.content, $pattern)
        if (-not $destination.Success) { throw 'Destino não identificado; detalhes privados omitidos.' }
        $access[$entry[0] + 'Url'] = $destination.Groups[1].Value
        $access[$entry[0] + 'User'] = $destination.Groups[2].Value
    }
    $privateText = $null
    $auth = $null
    $remote = $null
    $fields.Clear()
    return $access
}
