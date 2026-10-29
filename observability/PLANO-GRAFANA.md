# Grafana Cloud Lightweight — instalação executada

Instalado com autorização em 27/10/2026: Helm 3.22.1 no diretório do usuário
ubuntu, chart k8s-monitoring 4.5.5, release grafana-cloud, revisão 2.
Namespace grafana-monitoring; contexto kubernetes-admin@kubernetes;
cluster kubernetes-admin-kubernetes (nome derivado do contexto pelo comando original).

## Coleta explícita, sem Fleet

O comando privado não foi executado. A consulta autenticada GetConfig revelou
auto-observação e Beyla, sem eventos Kubernetes ou coleta completa solicitada.
Fleet foi desabilitado apenas neste release, sem modificar pipelines da conta.
Os destinos reais foram obtidos da API autenticada, não deduzidos pela região.

[grafana-lightweight.values.yaml](grafana-lightweight.values.yaml) habilita:

- clusterMetrics e hostMetrics.linuxHosts: estado, CPU e memória de nós/pods.
- podLogsViaLoki: arquivos de logs dos containers/pods.
- clusterEvents: eventos, com clustering para distribuir a coleta.

Não habilitar coleta Fleet paralela dos mesmos sinais.

## Recursos e permissões

Seis pods: dois Alloy, dois Node Exporter, kube-state-metrics e Alloy Operator.
Cada Alloy tem um reloader. Sem Beyla, profiling, OpenCost, Kepler, SDK Injector,
Grafana Server, Loki Server ou Prometheus Server. Metrics Server preservado.

| Container | Quantidade | Requests CPU/memória | Limits CPU/memória |
| --- | ---: | --- | --- |
| Alloy | 2 | 100m / 128Mi | 500m / 512Mi |
| Reloader, sidecar | 2 | 10m / 16Mi | 50m / 64Mi |
| Node Exporter | 2 | 20m / 32Mi | 100m / 64Mi |
| kube-state-metrics | 1 | 50m / 64Mi | 200m / 128Mi |
| Alloy Operator | 1 | 20m / 64Mi | 200m / 128Mi |

Total: requests 330m/480Mi; soma dos limits 1700m/1536Mi, distribuídos entre nós,
sem contar jobs transitórios. Consumo final observado: cerca de 32m/268Mi.

Alloy lê logs como root, sem modo privilegiado, capabilities, hostPID/hostNetwork.
Usa /var/log e /var/lib/alloy. Node Exporter usa mounts/rede de host do chart.
Taint do control plane preservado, com toleration nos agentes por nó.

Operator limitado ao namespace, createClusterRoles=false. O arquivo
[grafana-rbac.yaml](grafana-rbac.yaml) pré-cria descoberta/métricas/eventos de
leitura e acesso a um único Secret. Testes reais comprovaram:

- Operator não pode criar deployments em default ou ClusterRoles.
- Coletor não pode listar Secrets de todos os namespaces.
- Coletor pode ler seu próprio Secret.

O chart usa TLS de laboratório para kubelet; não representa configuração de
produção. TLS com Grafana Cloud permanece validado.

## Credenciais e reprodução

Secret Opaque grafana-cloud-credentials: metrics-username, logs-username,
password e entradas TLS vazias ca/cert/key. Transmitido por stdin/SSH sem
Secret last-applied, token em argumentos, values, ConfigMaps ou release Helm.
Secret é Base64 e RBAC; não implica criptografia no etcd. A chave SSH original
e sua ACL não foram alteradas. Arquivo privado original permanece no TEMP local.

Para instalação autorizada em ambiente equivalente:

1. Verificar contexto, dois nós Ready e ausência de releases/nomes concorrentes.
2. Criar namespace grafana-monitoring.
3. Executar criar-credenciais.ps1 com os caminhos privados. Extrai campos em
   memória; falha se Secret já existir, sem rotação silenciosa.
4. Copiar instalar-monitoramento.sh, grafana-rbac.yaml e
   grafana-lightweight.values.yaml para uma mesma pasta no control plane.
5. Executar bash instalar-monitoramento.sh. Baixa/verifica Helm por SHA256
   quando necessário; aplica RBAC, faz upgrade/install com versão fixada e
   aguarda também o DaemonSet criado pelo Operator.

Não executar Terraform, mudar SGs ou recriar EC2 para instalar monitoramento.
Não remover CRD/RBAC/Secret ou namespace sem escopo e autorização.

## Evidências e confirmação manual concluída

- Seis pods Running/Ready; dois nós Ready; Metrics Server True.
- API Prometheus Cloud HTTP 200: dois nós únicos, séries CPU/memória de nós e
  pods e amostras recentes. Séries transitórias da atualização convergiram.
- Dois peers Alloy; filas métricas vazias, zero amostras com falha.
- Leitura de logs de arquivos confirmada; Loki respondeu HTTP 204 aos lotes,
  sem retries ou perdas nos contadores. Comprova aceitação do envio combinado.
- Consulta Loki: HTTP 401, falta de logs:read. Não é falha de escrita.
  Posteriormente o usuário confirmou no portal logs reais, 74 eventos e
  Created/Started do pod de teste. A leitura no destino está validada manualmente;
  os resultados históricos da API permanecem inalterados.
- O componente de eventos não fornece contador específico de debug. Sua
  ausência não significa falha de coleta.

Grafana > Explore, selecionar Loki, últimos 15 minutos. Logs de pods:

    {cluster="kubernetes-admin-kubernetes",namespace="grafana-monitoring",job!="integrations/kubernetes/eventhandler"}

Eventos:

    {cluster="kubernetes-admin-kubernetes",job="integrations/kubernetes/eventhandler"}

Confirmar horários recentes e capturar telas sem segredos. Se vazio, informar
qual consulta para diagnóstico. Não inferir ingestão apenas por pods Ready.

Para facilitar a prova, foi criado um único pod temporário de validação no
namespace de monitoramento (smoke-test.yaml). Às 10:12:53 de São Paulo ele
produziu o marcador JSON tc3-observability-check e eventos Scheduled/Pulled/
Created/Started; encerra após 120 segundos e não foi excluído. Consultas específicas:

    {cluster="kubernetes-admin-kubernetes",pod="tc3-observability-check"} |= "tc3-observability-check"

    {cluster="kubernetes-admin-kubernetes",job="integrations/kubernetes/eventhandler"} |= "tc3-observability-check"

Validação final às 10:14:31: métricas no destino com 8 segundos de defasagem;
lint Helm, sintaxe de 13 scripts Bash e 3 PowerShell e verificação de sigilo passaram.

validar-cloud.ps1 salva contagens/timestamps e distingue métricas recebidas de
leitura Loki não confirmada. Aceita LogsReadTokenPath opcional, sem ampliar
permissões. verificar-coleta.sh consulta saúde e consumo sem imprimir Secrets.
Evidências sanitizadas em ../evidencias/2026-10-27-grafana-*.

Referências: [chart oficial](https://github.com/grafana/k8s-monitoring-helm),
[eventos e debug](https://grafana.com/docs/alloy/latest/reference/components/loki/loki.source.kubernetes_events/).
