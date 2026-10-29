# Grafana Cloud — pré-instalação

Consulta real em 27/10/2026, aproximadamente 08:55 de São Paulo (11:55 UTC).

- Contexto: `kubernetes-admin@kubernetes`.
- API: `https://172.31.87.121:6443`.
- Dois nós Ready, Kubernetes v1.34.12.
- Helm não encontrado no PATH local nem no PATH do usuário ubuntu no control plane.
- Inventário de deployments, daemonsets e statefulsets: sem workloads Grafana,
  Alloy, Prometheus, Loki ou kube-state-metrics.

| Nó | CPU observada | Memória observada | Requests CPU | Requests memória |
| --- | --- | --- | --- | --- |
| Control plane | 146m (7%) | 1805Mi (48%) | 1100m (55%) | 240Mi (6%) |
| Worker | 50m (2%) | 755Mi (20%) | 450m (22%) | 232Mi (6%) |

Cada nó oferece 2 CPUs e aproximadamente 3,64 GiB de memória alocável.
MemoryPressure, DiskPressure e PIDPressure: False nos dois nós.
Control plane mantém taint NoSchedule; não remover para acomodar coletores.
Disco raiz do control plane: 19G total, 14G disponíveis, 25% utilizado.

Esses dados são uma fotografia de uso, não uma garantia de capacidade futura.
O orçamento final depende do chart/version e dos valores gerados pelo Grafana.
Preferir modo Lightweight, métricas, logs e eventos; revisar requests/limits,
tolerations dos agentes por nó e componentes opcionais antes da instalação.

Pendentes: receber configuração gerada por canal local seguro, fixar versões,
renderizar e revisar recursos sem revelar Secrets, obter aprovação para instalar
Helm e o release, validar envio e recebimento no Grafana Cloud.

Nenhum componente foi instalado nesta etapa. Nenhum token foi recebido ou salvo.
