# Grafana Cloud Lightweight — configuração

## Componentes

Release grafana-cloud, namespace grafana-monitoring e cluster
kubernetes-admin-kubernetes. Helm 3.22.1; chart k8s-monitoring 4.5.5.
A configuração versionada está em
[grafana-lightweight.values.yaml](grafana-lightweight.values.yaml).

Sinais habilitados explicitamente:

- clusterMetrics e hostMetrics.linuxHosts: estado, CPU/memória de nós e Pods.
- podLogsViaLoki: logs dos containers.
- clusterEvents: eventos Kubernetes com clustering.

Fleet paralelo, Beyla, profiling, OpenCost, Kepler e SDK Injector estão
desabilitados. Não há Grafana/Prometheus/Loki Server local.
Metrics Server permanece para HPA e kubectl top.

## Recursos

Seis Pods permanentes: dois Alloy, dois Node Exporter, kube-state-metrics e Alloy
Operator. Cada Alloy possui um reloader.

| Container | Quantidade | Requests CPU/memória | Limits CPU/memória |
| --- | ---: | --- | --- |
| Alloy | 2 | 100m / 128Mi | 500m / 512Mi |
| Reloader | 2 | 10m / 16Mi | 50m / 64Mi |
| Node Exporter | 2 | 20m / 32Mi | 100m / 64Mi |
| kube-state-metrics | 1 | 50m / 64Mi | 200m / 128Mi |
| Alloy Operator | 1 | 20m / 64Mi | 200m / 128Mi |

Requests totais: 330m/480Mi. Soma dos limits: 1700m/1536Mi, distribuídos entre nós,
sem Jobs transitórios. Não são garantia de consumo ou capacidade futura.
A [coleta registrada](../evidencias/2026-10-27-grafana-cluster.txt) informa saúde e
uso instantâneo.

## Segurança e permissões

Alloy lê arquivos de host como root, sem modo privilegiado, capabilities ou
hostPID/hostNetwork. Usa /var/log e /var/lib/alloy.
Node Exporter utiliza mounts/rede de host do chart.
O taint do Control Plane é preservado; agentes por nó têm toleration.

Operator limitado ao namespace, createClusterRoles=false.
[grafana-rbac.yaml](grafana-rbac.yaml) fornece leitura para descoberta,
métricas/eventos e acesso a um Secret específico.
As [verificações registradas](../evidencias/2026-10-27-grafana-rbac.txt) são
seletivas e não constituem auditoria completa de RBAC.

O TLS de laboratório do kubelet deve ser revisto para produção. TLS com o Cloud
permanece validado na configuração. Secret Base64/RBAC não significa criptografia
do conteúdo no etcd.

## Credenciais e instalação

Secret Opaque grafana-cloud-credentials: metrics-username, logs-username, password
e entradas TLS ca/cert/key. Values referenciam Secret existente; nenhum token é
passado ao Helm ou incorporado ao release.

1. Confirmar contexto, dois nós Ready, capacidade e ausência de release concorrente.
2. Revisar endpoints, stack e identidade dos helpers para o ambiente de destino.
3. Criar namespace e credenciais somente com autorização.
4. Utilizar criar-credenciais.ps1 com parâmetros privados. O helper transmite o
   objeto por stdin/SSH e falha se o Secret existir, sem rotação implícita.
5. Copiar instalar-monitoramento.sh, grafana-rbac.yaml e values para uma pasta no
   Control Plane.
6. Com autorização, executar bash instalar-monitoramento.sh nessa pasta. Instala
   Helm com verificação SHA256, aplica RBAC e aguarda os agentes.

Não executar diretamente o comando privado do assistente para duplicar o release.
Não remover CRD/RBAC/Secret ou namespace sem revisão de escopo.
A [reprodução e validação](VERIFICAR-GRAFANA-CLOUD.md) detalha os parâmetros.

## Validação dos sinais

- Pods/DaemonSets saudáveis: verificar-coleta.sh.
- Métricas no destino: validar-cloud.ps1 ou consulta no portal.
- Logs/eventos: consulta Loki; se faltar logs:read, identificar a limitação e
  validar manualmente sem confundir leitura negada com falha de escrita.

Últimos 15 minutos, ajustando labels para o ambiente:

```logql
{cluster="kubernetes-admin-kubernetes",namespace="oficina-tc3",container="api"}
{cluster="kubernetes-admin-kubernetes",job="integrations/kubernetes/eventhandler"}
```

A existência de Pods Ready não comprova ingestão. O
[catálogo de evidências](../evidencias/INDEX.md) identifica métricas por API e
logs/eventos por confirmação manual. Traces, latência por rota e indicadores de
negócio exigem instrumentação específica.

Referências: [chart oficial](https://github.com/grafana/k8s-monitoring-helm),
[eventos Kubernetes](https://grafana.com/docs/alloy/latest/reference/components/loki/loki.source.kubernetes_events/).
