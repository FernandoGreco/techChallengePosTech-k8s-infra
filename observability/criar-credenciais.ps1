param(
    [Parameter(Mandatory = $true)][string]$SshKeyPath,
    [string]$ControlPlane = '44.206.227.188',
    [string]$SshExecutable = 'C:\Program Files\Git\usr\bin\ssh.exe',
    [string]$PrivateCommandPath = (Join-Path $env:TEMP 'grafana-tc3-install.private.txt')
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'grafana-private.ps1')
$access = Get-Tc3GrafanaAccess -PrivateCommandPath $PrivateCommandPath
try {
    $values = @{ 'metrics-username' = $access.MetricsUser; 'logs-username' = $access.LogsUser; password = $access.Token; ca = ''; cert = ''; key = '' }
    $data = @{}
    foreach ($entry in $values.GetEnumerator()) {
        $data[$entry.Key] = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes([string]$entry.Value))
    }
    $payload = @{ apiVersion = 'v1'; kind = 'Secret'; metadata = @{ name = 'grafana-cloud-credentials'; namespace = 'grafana-monitoring' }; type = 'Opaque'; data = $data } | ConvertTo-Json -Depth 6 -Compress
    # Namespace deve existir. Create falha se o Secret existir: não rotacionar
    # credenciais silenciosamente. Sem apply/last-applied com dados privados.
    $payload | & $SshExecutable -i $SshKeyPath -o StrictHostKeyChecking=yes -o UpdateHostKeys=no -o BatchMode=yes -o ConnectTimeout=5 "ubuntu@$ControlPlane" 'kubectl --context=kubernetes-admin@kubernetes create -f -'
    if ($LASTEXITCODE -ne 0) { throw 'Secret não criado; verificar existência e acesso, sem imprimir dados.' }
} finally {
    $access.Clear()
    if ($values) { $values.Clear() }
    if ($data) { $data.Clear() }
    $payload = $null
}
