# Evidências reais — homologação

Coleta de fechamento: **29/10/2026**, conta AWS `207975764067`, região
`us-east-1`, perfil local `default`. As consultas desta coleta foram somente de
leitura, sem Terraform Plan/Apply, carga ou alterações no cluster.

[README](../README.md) · [Produção](EVIDENCIAS-PRODUCAO.md) · [CI/CD e requisitos](CI-CD.md)

## Identificação e preservação

| Item | Evidência de 29/10/2026 |
| --- | --- |
| Control Plane | `i-0ceda6c6a818b75ac`, running, t3.medium |
| Worker | `i-0f93be0748f23792c`, running, t3.medium |
| Checks EC2 | System, Instance e Attached EBS: ok nas duas instâncias |
| Volumes | Os mesmos dois volumes gp3 de 20 GiB; in-use; criptografia false, preservada |
| Security Group | `sg-0254447694931863a`, distinto do de produção |
| Rede | Comunicação interna por referência ao próprio SG; SSH limitado a /32; saída permitida |
| Backend | `fiap-tc3-k8s-tfstate-207975764067`, chave `homolog/terraform.tfstate` |
| State — metadados | LastModified `2026-10-28T17:29:16Z`, 38033 bytes, AES256 |

As consultas AWS ocorreram a partir de `2026-10-29T13:10:37Z`. IDs de instâncias,
volumes, SG, configuração observada e metadados do state coincidem com o registro
anterior ao Apply de produção. O LastModified do state de homologação não avançou.
O conteúdo do state não foi baixado. A preservação do funcionamento do cluster foi
verificada também por SSH; não se baseia apenas no sucesso do Terraform.

## Plan e Apply — fontes primárias recuperadas

| Execução | Data UTC | Resultado comprovado |
| --- | --- | --- |
| [40729596822](https://github.com/felipevrds/techChallengePosTech-k8s-infra/actions/runs/40729596822) | 28/10/2026 | Push em homolog; CI, Plan e job **Apply reviewed saved plan**: success |
| [40802453584](https://github.com/felipevrds/techChallengePosTech-k8s-infra/actions/runs/40802453584) | 29/10/2026 | Revalidação manual; CI e Plan: success; Apply: skipped |

O primeiro run utiliza o commit `13c31cc9fcc072dbb1172b52523d99b351a14c21`;
o segundo, `f4b53cdd1dbf7d3ae943750416622fd5299f75bc`.
Os resumos sanitizados recuperados dos jobs de ambos confirmam:

```json
{"create":0,"update":0,"delete":0,"replace":0,"unchanged":6}
```

Isso comprova Apply sem diferenças naquele momento. Não significa que essas EC2
tenham sido criadas por esse run. A revalidação Plan-only não é apresentada como
um segundo Apply. Nenhuma dessas execuções foi repetida nesta coleta.

## Kubernetes — consulta atual por SSH

Consulta em `2026-10-29T13:22:34Z`, com `StrictHostKeyChecking=yes`,
`UpdateHostKeys=no`, `BatchMode=yes` e chave de host já confiável.
O alias de host confiável identifica o Control Plane histórico; endereços de
conexão e caminho da chave privada foram omitidos deste documento.

Comandos executados: `cloud-init status`, `systemctl is-active containerd kubelet`,
`kubectl config current-context`, `kubectl get nodes -o wide`,
`kubectl get pods -A`, consultas de Calico/Metrics Server/APIService,
`kubectl get hpa -A`, `kubectl top nodes` e consultas do namespace da demonstração.

Extratos das saídas reais; colunas de endereços e nomes efêmeros foram omitidas:

```text
cloud-init: status: done
containerd: active
kubelet: active
context: kubernetes-admin@kubernetes

ROLE            STATUS   VERSION
control-plane   Ready    v1.34.12
worker          Ready    v1.34.12

RESOURCE                    READY
calico-node                 2/2
calico-kube-controllers     1/1
metrics-server             1/1
v1beta1.metrics.k8s.io      Available=True

NAMESPACE     HPA           TARGET       MIN   MAX   REPLICAS
hpa-lab       cpu-demo      1% / 50%     1     4     1
oficina-tc3   oficina-api   6% / 70%     1     2     1

ROLE            CPU     MEMORY
control-plane   193m    2049Mi
worker          115m    1653Mi
```

`kubectl get pods -A` mostrou Calico, CoreDNS, componentes do Control Plane,
Metrics Server, os seis Pods permanentes de observabilidade, NestJS e PostgreSQL
Running/Ready. O Pod de verificação de observabilidade e o Pod do Job Prisma v3
estavam Completed. A consulta não executou carga.

No namespace `oficina-tc3`, Active:

| Recurso | Resultado atual |
| --- | --- |
| Deployment oficina-api | 1/1 disponível |
| Deployment postgres-demo | 1/1 disponível |
| Services oficina-api / postgres-demo | ClusterIP, portas 3000 / 5432 |
| Job oficina-schema-demo-v3 | Complete, 1/1; duração registrada de 15 s |
| Jobs Prisma v1 / v2 | Failed históricos, preservados; não reexecutados |

Os reinícios acumulados após ciclos anteriores do Lab continuam visíveis nos
originais. Running/Ready atual não significa ausência histórica de reinícios.
PostgreSQL usa `emptyDir`: não é RDS nem armazenamento persistente. Não foi feita
nova consulta SQL nem verificação de persistência dos dados nesta coleta.

## Evidências anteriores reaproveitadas

| Evidência | Origem e alcance |
| --- | --- |
| [Kubernetes/HPA sintético](../evidencias/2026-10-27-kubernetes-hpa.txt) | Coleta de 27/10: escala 1→4→1, alvo CPU 50%; contém eventos SuccessfulRescale |
| [HPA da aplicação](../evidencias/HPA-APLICACAO.md) | Configuração 1–2, CPU alvo 70%; escala 1→2 e 9.986 HTTP bem-sucedidos/zero erros são **confirmação manual** |
| [NestJS, schema e Swagger](../evidencias/tc3-deploy-resultado-local.json) | Coleta de 28/10: Job v3 Complete, dez tabelas, sem seed; Swagger e Swagger JSON HTTP 200; rota sem token HTTP 401 |
| [Métricas no Cloud](../evidencias/tc3-deploy-observabilidade-local.json) | Séries CPU/memória recebidas; não comprova traces |
| [Logs/eventos](../evidencias/2026-10-27-grafana-validacao-manual.md) | Confirmação manual no Loki: logs reais e 74 eventos |
| [Logs NestJS no destino](../evidencias/tc3-deploy-loki-confirmacao-manual-local.json) | Confirmação manual em 28/10, sem captura; leitura automatizada tinha limitação de scope |

No teste HPA da API, o gerador executou dentro do Pod. Os 9.986 HTTP não são
saída bruta coletada nesta validação, não pertencem ao HPA sintético e **não
constituem benchmark independente**. Swagger, tabelas e recebimento Cloud não
foram novamente testados; os registros acima mantêm suas datas e limitações.

## Reproduzir somente a validação

Primeiro confirmar a conta; depois usar os comandos AWS de leitura descritos em
[Produção](EVIDENCIAS-PRODUCAO.md#reproduzir-somente-a-validação), trocando o filtro
de ambiente para `homolog` e a chave S3 para `homolog/terraform.tfstate`.

Após obter endereço atual e identidade de host por canal confiável, definir
localmente `SSH_PRIVATE_KEY_PATH`, `SSH_KNOWN_HOSTS`, `SSH_HOST_ALIAS` e
`CONTROL_PLANE_HOST`, sem colocá-los no Git. No Git Bash:

```bash
ssh -i "$SSH_PRIVATE_KEY_PATH" \
  -o StrictHostKeyChecking=yes -o UpdateHostKeys=no \
  -o BatchMode=yes -o ConnectTimeout=5 -o ConnectionAttempts=1 \
  -o "UserKnownHostsFile=\"$SSH_KNOWN_HOSTS\"" \
  -o "HostKeyAlias=$SSH_HOST_ALIAS" "ubuntu@$CONTROL_PLANE_HOST" \
  'test "$(kubectl config current-context)" = kubernetes-admin@kubernetes &&
   kubectl get nodes -o wide && kubectl get pods -A &&
   kubectl get hpa -A && kubectl top nodes'
```

Critérios: dois nós Ready, Pods essenciais Ready, API de métricas disponível,
HPA com métricas e workloads da demonstração disponíveis. Essa consulta não
comprova novo scale-up; não executar carga para reproduzir apenas a leitura.
