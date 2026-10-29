# Evidências reais — produção

Fechamento em **29/10/2026**. Conta AWS `207975764067`, região `us-east-1`, perfil
local `default`. A coleta posterior ao Apply foi somente de leitura.

[README](../README.md) · [Homologação](EVIDENCIAS-HOMOLOG.md) · [CI/CD e requisitos](CI-CD.md)

## Resultado do GitHub Actions

- Execução: [Terraform Deploy — 40876235431](https://github.com/felipevrds/techChallengePosTech-k8s-infra/actions/runs/40876235431).
- Repositório: fork `felipevrds/techChallengePosTech-k8s-infra`.
- Branch: `main`; evento `workflow_dispatch`, solicitação `action=apply`.
- Commit: `f730def77cd47d27e41235d4dbf1b2be423ef4d4`.
- Início: `2026-10-29T12:47:46Z`; encerramento registrado: `2026-10-29T13:03:26Z`.
- Resultado consultado pela API às `13:09Z`: **completed / success**.

| Etapa | Resultado confirmado pela API |
| --- | --- |
| Required CI / Validate infrastructure | success |
| Check requested operation | success |
| Confirmação da conta Academy antes do Plan | success |
| Plan e resumo sanitizado | success |
| Criptografia e upload do plano salvo | success |
| Aprovação production-apply | Espera protegida observada antes da liberação; nenhum bypass realizado pelo executor |
| Verificação das proteções e do artefato após a espera | success |
| Revalidação das credenciais AWS | success |
| Apply only the saved reviewed plan | success; job executado de 13:02:43Z a 13:03:25Z |
| Validação SSH opcional do workflow | skipped; não comprova Kubernetes |

Resumo do plano conferido antes da aprovação e novamente no job Apply:

```json
{"create":6,"update":0,"delete":0,"replace":0,"unchanged":0}
```

O log público do job confirma a aplicação do plano salvo. O log privado de
Terraform, o plano binário, a chave de criptografia e o state não foram
publicados nem copiados para este documento.

## Recursos confirmados diretamente na AWS

Consultas iniciadas em `2026-10-29T13:10:37Z`, após confirmação da conta por STS.

| Recurso | Identificação / resultado |
| --- | --- |
| Control Plane | `i-01c88236610aa5c7f`, running, t3.medium, x86_64 |
| Worker | `i-0c8414ff65026bcae`, running, t3.medium, x86_64 |
| Checks das duas EC2 | System: ok; Instance: ok; Attached EBS: ok |
| Volume do Control Plane | `vol-079bfdcc483860ec2`, gp3, 20 GiB, in-use, **encrypted=true** |
| Volume do Worker | `vol-0dddc753e1a8a8136`, gp3, 20 GiB, in-use, **encrypted=true** |
| Security Group próprio | `sg-0c56293d122ed23df`, tags Environment=production |
| Regra interna | Todos os protocolos entre membros do próprio SG de produção |
| Regra SSH | TCP/22 para um CIDR /32; sem abertura pública irrestrita |
| Regra de saída | Todos os protocolos para 0.0.0.0/0 |

Os seis recursos Terraform são as duas instâncias, o SG e três regras de rede.
Os volumes raiz são blocos das instâncias; não são dois recursos adicionais na
contagem do Plan. As duas EC2 foram lançadas às `13:03:11Z` e possuem tags de
produção. Elas utilizam VPC/subnet/Key Pair existentes, sem adotar as EC2 de homolog.
Endereços IP e CIDR pessoal foram omitidos por não serem necessários à avaliação.

## Backend e isolamento

| Verificação S3 | Resultado de HeadObject/HeadBucket |
| --- | --- |
| Bucket | `fiap-tc3-k8s-tfstate-207975764067`, região us-east-1, proprietário esperado confirmado |
| Chave de produção | `production/terraform.tfstate`, existente |
| Metadados de produção | LastModified `2026-10-29T13:03:24Z`; 37774 bytes; AES256 |
| Chave de homologação | `homolog/terraform.tfstate`, existente e independente |
| Preservação de homologação | LastModified permanece `2026-10-28T17:29:16Z`; 38033 bytes; mesmos recursos e cluster revalidado |

Somente metadados foram consultados; nenhum conteúdo do state foi baixado.
O isolamento é de recursos EC2/SG e chaves de state, **não de conta ou VPC**.
Os dois ambientes compartilham orçamento, quotas, VPC, subnet e Key Pair.
O Apply inicial bem-sucedido não comprova ausência futura de drift.

## Identidade SSH confirmada por canal AWS

Em 29/10/2026, às `14:01Z`, STS confirmou novamente a conta esperada e
DescribeInstances identificou os dois hosts de produção running. Os endereços
atuais foram utilizados apenas para conexão; podem mudar em ciclos do Lab.

A ausência inicial de confiança era local: as novas EC2 ainda não constavam no
arquivo known_hosts existente. Não era evidência de falha de autenticação ou do
serviço SSH. A primeira leitura do console não retornou informação utilizável
pela CLI; com codificação UTF-8 no processo, GetConsoleOutput com `--latest`
forneceu os registros de inicialização às `14:05:50Z` e `14:05:52Z`.
Nenhum log completo de console foi publicado.

| Instância | Fingerprint ED25519 obtida do console AWS |
| --- | --- |
| Control Plane i-01c88236610aa5c7f | `SHA256:Zc3cPu1iiCAQujNnajffnqcIOsvw7AL83tjmExmhq6A` |
| Worker i-0c8414ff65026bcae | `SHA256:T3wVGRULQwGxoEJkR26JAPImfGPQKDn5sUFdEi+aDuw` |

Os consoles também registram o término do cloud-init. As chaves públicas
ED25519 apresentadas pela rede foram obtidas com `ssh-keyscan -T 5 -t ed25519`
e suas fingerprints SHA-256 foram comparadas em memória com os valores do canal
AWS autenticado. **Houve correspondência exata nas duas instâncias.** O keyscan
isolado não foi utilizado como prova de identidade.

Somente as duas chaves públicas verificadas foram colocadas em known_hosts
temporário fora do repositório. O SSH utilizou `StrictHostKeyChecking=yes`,
`UpdateHostKeys=no`, `HostKeyAlgorithms=ssh-ed25519`, `BatchMode=yes`,
`ConnectTimeout=5` e `ConnectionAttempts=1`. A chave privada autorizada foi lida
somente pelo SSH; conteúdo e permissões permaneceram intactos. O arquivo público
temporário foi removido após as consultas, e o known_hosts original não mudou.

## Kubernetes de produção: consulta real por SSH

**Diagnóstico antes da correção.** O bloco abaixo preserva a consulta de 14:12Z.
O resultado final após o bootstrap autorizado está na seção seguinte.

Consultas em `2026-10-29T14:12:34Z` no Control Plane e `14:12:38Z` no Worker.
SSH autenticado funcionou nos dois hosts, sem modificações remotas.

| Verificação | Control Plane | Worker |
| --- | --- | --- |
| cloud-init status | done | done |
| containerd | active | active |
| kubelet | active | inactive |
| /etc/kubernetes/kubelet.conf | PRESENT | ABSENT |
| Associação observada em get nodes | Ready, v1.34.13 | Não aparece |

O contexto no Control Plane é `kubernetes-admin@kubernetes`. Foram executados:

```bash
kubectl --request-timeout=10s get nodes -o wide
kubectl --request-timeout=10s get pods -A
kubectl --request-timeout=10s get hpa -A
kubectl --request-timeout=10s get deployments -A
kubectl --request-timeout=10s -n kube-system get daemonset calico-node
kubectl --request-timeout=10s -n kube-system get deployment calico-kube-controllers
kubectl --request-timeout=10s -n kube-system get deployment metrics-server
kubectl --request-timeout=10s get apiservice v1beta1.metrics.k8s.io
kubectl --request-timeout=10s top nodes
```

Extratos das saídas reais, com endereços e nomes efêmeros omitidos:

```text
ROLE            STATUS   VERSION
control-plane   Ready    v1.34.13

NAMESPACE     DEPLOYMENT               READY
kube-system   calico-kube-controllers   1/1
kube-system   coredns                   2/2

DAEMONSET     DESIRED   CURRENT   READY
calico-node   1         1         1

get hpa -A: No resources found
Error from server (NotFound): deployments.apps "metrics-server" not found
Error from server (NotFound): apiservices.apiregistration.k8s.io "v1beta1.metrics.k8s.io" not found
error: Metrics API not available
```

`get pods -A` mostrou nove Pods de kube-system Running/Ready, sem reinícios
na consulta: Calico controller, um agente Calico, dois CoreDNS, etcd, API Server,
controller-manager, kube-proxy e scheduler. Não foram encontrados workloads
NestJS/PostgreSQL ou Grafana Alloy nessa listagem.

O retorno final do comando remoto no Control Plane foi 1 porque `top nodes`
não encontrou Metrics API, **não por falha de SSH**. No Worker, as consultas
terminaram com retorno 0; isso não altera o fato de o kubelet estar inativo.

**Naquele instante, o Control Plane estava inicializado, mas o cluster ainda
não atendia ao critério de dois nós Ready.** Calico funcionava no único nó associado.
Metrics Server está ausente; não há HPA configurado nem métricas para HPA.
Nenhuma escalabilidade de produção foi testada. As provas de HPA em homologação
não são atribuídas a este ambiente.

O código de cloud-init prepara o Worker sem executar join, e instala Metrics
Server somente na etapa pós-join de outro script. O workflow Terraform não
executa essa etapa, Helm ou deploy NestJS. Essa limitação do fluxo é consistente
com o estado remoto observado, sem provar qualquer falha adicional de rede.

As correções de join, TLS, Metrics Server e HPA foram posteriormente autorizadas
e executadas conforme o registro a seguir. Não houve Terraform, alteração AWS ou
escrita em homologação nessa etapa.

## Conclusão do bootstrap e HPA de produção

Data: **29/10/2026**. Fonte primária adicional:
[saídas reais de Kubernetes, HPA e preservação de homologação](../evidencias/2026-10-29-producao-kubernetes-hpa.txt).
Coleta final de produção às `15:52:02Z`; conferência de homologação às `15:48:24Z`.

### Causa e correção reproduzível

Não ocorreu uma tentativa malsucedida de join no cloud-init: o template do Worker
apenas instala os componentes e encerra. A etapa SSH de associação existia no
deploy legado, restrito a homologação, e não era executada pelo workflow Terraform.
As duas versões kubeadm/kubelet conferidas eram v1.34.13 e a conexão TCP privada
Worker → API:6443 passou. Não foi necessária mudança de Security Group ou EC2.

O novo [bootstrap-production.mjs](../scripts/bootstrap-production.mjs) é uma etapa
explícita pós-Apply, com guard de conta, região, IDs/tags e SSH confiável. Foi
usado token de dez minutos, enviado por JoinConfiguration no stdin, com CA fixada,
e revogado ao término. Não houve impressão nem gravação local do token. A
reexecução versionada reconheceu Worker já registrado e terminou PASS sem novo join.

O [init-control-plane.sh](../modules/ec2/user-data/init-control-plane.sh) deixou
de persistir comando de join em home, limita o token inicial e omite sua impressão
em futuros boots. Não foi reexecutado nos hosts existentes. O procedimento de
reprodução está em [BOOTSTRAP-PRODUCAO.md](BOOTSTRAP-PRODUCAO.md).

### Nós, Calico e TLS

| Critério | Resultado final comprovado |
| --- | --- |
| Control Plane / Worker | Ambos Ready, Kubernetes v1.34.13 |
| Calico | DaemonSet 2 desejados / 2 Ready; um agente Running em cada nó |
| Metrics Server | Deployment 1/1 Ready, versão v0.8.0 |
| API v1beta1.metrics.k8s.io | Available=True |
| kubectl top nodes | CPU/memória disponíveis para os dois nós |
| Consumo final CP / Worker | 144m / 56m CPU; 1054Mi / 573Mi memória, leitura instantânea |

Os kubelets passaram a solicitar certificados de serviço via serverTLSBootstrap.
Somente os dois CSRs de nós verificados foram aprovados, após validar signer,
usuário, grupos, usages, assinatura, CN/O e SAN DNS/IP exatos. Os dois certificados
foram validados por OpenSSL contra a CA e o IP de cada nó.

O Metrics Server verifica a CA dos kubelets com kubelet-certificate-authority;
**não utiliza kubelet-insecure-tls**. Seu próprio certificado de serviço tem SAN
DNS e assinatura da CA do cluster. A APIService possui caBundle e verificação TLS
habilitada; false pode ser omitido na serialização JSON do Kubernetes.
Readiness e `top nodes` passaram com essas verificações ativas nos dois caminhos.
O certificado do serviço vence em `2027-10-29T15:08:41Z`; renovação e revisão dos
CSRs futuros estão descritas no guia de bootstrap.

### Teste HPA sintético real: 1→2→1

O laboratório reutiliza o manifesto existente por componente Kustomize, mantendo
os arquivos de homologação. Escopo exclusivo: `production-hpa-lab`.

- Workload cpu-demo por digest; Service ClusterIP; request 100m/32Mi e limit 300m/128Mi.
- HPA autoscaling/v2, CPU alvo 50%, mínimo 1 / máximo 2; estabilização de descida de 30 s.
- Gerador em Pod separado: quatro clientes, 120 s, deadline de 150 s; limite total
  de 100m CPU/64Mi; timeout HTTP de dois segundos; nenhum banco ou NestJS acessado.
- Período do teste concluído: `15:44:23Z` a `15:47:25Z`, incluindo observação da descida.

| Fase | Observação real |
| --- | --- |
| Antes da carga | Deployment 1/1; CPU do HPA 1% / alvo 50% |
| Durante a carga | CPU observada 57% / 50%; Deployment 2/2; evento SuccessfulRescale para 2 |
| Após encerrar a carga | Deployment 1/1; CPU 1% / 50%; evento SuccessfulRescale para 1 |
| Gerador | Job concluiu e foi removido; consulta final sem Jobs no namespace |

O teste foi executado com [run.sh](../tests/production-hpa/run.sh), usando a árvore
tests com [Kustomization de entrada](../tests/kustomization.yaml),
[componente de produção](../tests/production-hpa/kustomization.yaml) e
[Job limitado](../tests/production-hpa/load-job.yaml). O primeiro acompanhamento
por watch de rollout excedeu seu limite antes de criar carga; foi substituído
por consultas curtas. Não foi necessário alterar o workload para obter a escala.

Os contadores originais dos quatro clientes foram **234 requisições concluídas e
132 falhas por timeout**. Eles foram preservados; este teste não demonstra HTTP
sem erros, desempenho de NestJS ou SLO. Ele comprova a reação do HPA à CPU do
workload sintético. Não atribuir a produção os 9.986 HTTP/zero erros confirmados
manualmente no teste distinto da aplicação em homologação.

O campo REPLICAS do HPA apresentou atraso em consultas intermediárias; a prontidão
do Deployment, os eventos de escala e a consulta final confirmaram 1→2→1. Nenhum
teste adicional foi executado para substituir os contadores obtidos.

### Preservação e limites

A leitura de homologação às 15:48Z confirmou os dois nós v1.34.12 Ready, Calico
2/2, API de métricas disponível e NestJS/PostgreSQL 1/1. Instâncias, volumes, SG e
metadados do state permaneceram iguais; LastModified `2026-10-28T17:29:16Z`.
Nenhum recurso AWS, state ou workload de homologação foi alterado.

**Produção atende agora aos critérios Kubernetes de dois nós Ready, CNI, métricas
e autoscaling sintético comprovados.** O workload de teste permanece em uma réplica
para consulta; a carga foi encerrada. NestJS, banco e Grafana Alloy não foram
implantados em produção por esta etapa e continuam como escopo separado.

### Verificação dos arquivos locais

Foram aprovados 23 testes Node e cinco testes Python de segurança CSR, incluindo
signer/usuário/grupos, SANs adicionais ou multilinha e assinatura inválida.
Actionlint e schema Kubernetes 1.34 aprovaram o workflow e os cinco recursos
renderizados do laboratório/Job. O bootstrap versionado também passou na
reexecução real. Os runs históricos identificam seus próprios commits; os checks
do PR de entrega identificam separadamente a validação remota destes ajustes.

## Reproduzir somente a validação

Com credenciais locais válidas, confirmar a conta antes das demais consultas:

```bash
test "$(aws sts get-caller-identity --profile default --region us-east-1 \
  --query Account --output text)" = "207975764067" || exit 1

aws ec2 describe-instances --profile default --region us-east-1 \
  --filters Name=tag:Environment,Values=production \
  --query 'Reservations[].Instances[].{Id:InstanceId,State:State.Name,Type:InstanceType,Architecture:Architecture}'

aws ec2 describe-instance-status --profile default --region us-east-1 \
  --instance-ids i-01c88236610aa5c7f i-0c8414ff65026bcae \
  --include-all-instances \
  --query 'InstanceStatuses[].{Id:InstanceId,System:SystemStatus.Status,Instance:InstanceStatus.Status,EBS:AttachedEbsStatus.Status}'

aws ec2 describe-volumes --profile default --region us-east-1 \
  --filters Name=attachment.instance-id,Values=i-01c88236610aa5c7f,i-0c8414ff65026bcae \
  --query 'Volumes[].{Id:VolumeId,Encrypted:Encrypted,GiB:Size,Type:VolumeType,State:State}'

aws ec2 describe-security-groups --profile default --region us-east-1 \
  --group-ids sg-0c56293d122ed23df \
  --query 'SecurityGroups[].{Id:GroupId,Ingress:IpPermissions,Egress:IpPermissionsEgress}'

aws s3api head-object --profile default --region us-east-1 \
  --bucket fiap-tc3-k8s-tfstate-207975764067 \
  --key production/terraform.tfstate --expected-bucket-owner 207975764067 \
  --query '{LastModified:LastModified,Bytes:ContentLength,Encryption:ServerSideEncryption}'
```

Não usar `get-object` ou `terraform state pull` para reproduzir esta evidência.
Comandos acima não executam Plan/Apply/Destroy. Para consulta Kubernetes, usar
o [procedimento SSH de leitura](EVIDENCIAS-HOMOLOG.md#reproduzir-somente-a-validação)
somente após validar a identidade dos hosts. A verificação acima comprovou as
chaves nesta coleta, sem criar confiança persistente. IPs mudam em ciclos do Lab.

Critério AWS aprovado: duas EC2 próprias running/checks ok, volumes criptografados,
SG separado, state correto e homolog preservada. Critério Kubernetes aprovado
após bootstrap autorizado: dois nós Ready, Calico 2/2, Metrics Server com TLS e
HPA sintético 1→2→1. O sucesso do Apply isoladamente não conclui esse bootstrap.
