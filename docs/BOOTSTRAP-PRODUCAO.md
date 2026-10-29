# Bootstrap Kubernetes de produção após Terraform

O Apply provisiona EC2, rede própria e cloud-init. O Worker recebe os binários,
mas não possui um token de outro nó para fazer join sozinho. O workflow Terraform
não executa a etapa SSH existente no deploy legado de homologação. Por isso,
Apply bem-sucedido não significa dois nós Ready.

O procedimento abaixo é separado do Terraform e requer autorização para modificar
Kubernetes. Não executa Terraform, não muda AWS, não importa state e não acessa
homologação. [Resultados reais](EVIDENCIAS-PRODUCAO.md) · [Checklist](CI-CD.md).

## Pré-requisitos e identidade

- AWS CLI, Node.js, SSH; perfil local temporário válido em us-east-1.
- Duas EC2 running com tags Environment=production e Role correspondente.
- cloud-init concluído, containerd ativo e versões kubeadm coincidentes.
- Worker com acesso privado à porta 6443 do Control Plane.
- Hosts SSH já verificados por canal confiável; known_hosts fora do Git.
- Nos nós: Python 3, PyYAML e OpenSSL, já presentes no Ubuntu usado na implantação.

O script falha se conta, região, instâncias ou tags divergirem. Não aceita chaves
de host automaticamente. Não executa em GITHUB_ACTIONS: o runner Terraform não
recebe acesso SSH implícito nem modifica Security Groups para obtê-lo.

## Executar no ambiente autorizado do operador

Exemplo identificado da conta demonstrada; substituir IDs ao reproduzir em outra
conta. Definir os caminhos SSH localmente, sem colocar valores privados no Git.

```bash
export AWS_PROFILE=default
export AWS_REGION=us-east-1
export EXPECTED_AWS_ACCOUNT_ID=207975764067
export CONTROL_PLANE_INSTANCE_ID=i-01c88236610aa5c7f
export WORKER_INSTANCE_ID=i-0c8414ff65026bcae
: "${SSH_PRIVATE_KEY_PATH:?Defina o caminho privado fora do Git}"
: "${SSH_KNOWN_HOSTS:?Defina o arquivo de hosts publicos previamente verificados}"
CONFIRM_BOOTSTRAP_PRODUCTION=sim node scripts/bootstrap-production.mjs
```

O script consulta AWS apenas para identidade e descoberta das duas EC2. A conexão
usa StrictHostKeyChecking=yes, UpdateHostKeys=no, BatchMode e timeout curto.
Aliases previamente verificados podem ser fornecidos em
SSH_CONTROL_PLANE_HOST_ALIAS e SSH_WORKER_HOST_ALIAS se o IP tiver mudado.

Se o Worker ainda não estiver registrado, cria token de dez minutos, fixa o hash
da CA e envia JoinConfiguration somente por stdin ao kubeadm join. O token não é
argumento de processo, arquivo local ou saída, e é revogado ao fim da tentativa.
Configuração existente sem nó registrado causa parada; não há reset automático.
Se já estiver associado, o join é pulado. O fluxo foi reexecutado em produção com
esse resultado, sem duplicar a associação.

## TLS do Metrics Server

O [helper versionado](../scripts/kubelet-serving-tls.py) habilita
serverTLSBootstrap na configuração do cluster e dos dois kubelets. Reinicia
somente kubelet quando a opção precisa mudar; não reinicia EC2 ou containerd.

Antes de aprovar cada CSR, verifica signer, usuário autenticado do nó, grupos,
usages, assinatura, CN/O e SANs exatos contra o mapeamento de nós/IPs confirmado
na AWS e na API Kubernetes. Não aprova outros nós, URI/email ou SANs adicionais.

O instalador existente [install-metrics.sh](../modules/ec2/user-data/install-metrics.sh)
possui modo secure utilizado pelo bootstrap. Ele configura:

- Metrics Server v0.8.0, uma réplica; requests 100m/200Mi e limits 250m/300Mi.
- CA do cluster para validar os certificados de kubelet; nenhum kubelet-insecure-tls.
- Certificado de serviço com SAN DNS e assinatura da CA do cluster, com chave
  gerada e mantida somente no Control Plane/Secret Kubernetes.
- APIService com caBundle e sem bypass TLS. A API pode omitir false no JSON;
  essa omissão significa verificação habilitada, não um bypass.
- RBAC do manifesto oficial, sem permissões adicionais para aprovação automática
  de CSRs. Secret de serviço e ConfigMap da CA não contêm credenciais no Git.

O modo lab anterior continua disponível para reprodução histórica de homologação;
DEPLOY_ENVIRONMENT=production recusa esse modo. O bootstrap usa sempre secure.
Não executar o instalador lab para corrigir produção.

O certificado de serviço vale 365 dias. A reexecução o renova quando restam menos
de 30 dias e modifica a anotação pública do Pod para atualizar a montagem. Os
CSRs de renovação dos kubelets exigem nova revisão; não foi instalado um aprovador
genérico. Programar revisão antes do vencimento e verificar openssl/kubectl top
após renovação. Não copiar chaves de CA, Secrets ou kubeconfig para evidências.

Referências primárias: [certificados kubeadm](https://kubernetes.io/docs/tasks/administer-cluster/kubeadm/kubeadm-certs/)
e [TLS do Metrics Server](https://github.com/kubernetes-sigs/metrics-server/blob/master/FAQ.md).

## HPA sintético de produção

O teste reutiliza [hpa-lab.yaml](../tests/hpa-lab.yaml) com um componente Kustomize
específico, sem modificar os testes de homologação. O ponto de renderização é
tests/kustomization.yaml; tests/production-hpa contém o componente e a carga.

No Control Plane de produção, com uma cópia pública da árvore tests e contexto
verificado, usar os nomes dos dois nós confirmados na AWS/SSH:

```bash
export EXPECTED_CONTROL_PLANE_NODE=ip-172-31-80-64
export EXPECTED_WORKER_NODE=ip-172-31-91-84
CONFIRM_PRODUCTION_HPA=sim bash tests/production-hpa/run.sh
```

O comando é uma alteração autorizada de Kubernetes e gera carga; não é diagnóstico
de leitura. Não executá-lo em homologação. Ele limita o escopo a
production-hpa-lab, exige os dois nós Ready e métricas disponíveis e recusa
namespace existente que não pertença a este teste.

O workload usa imagem por digest, Service ClusterIP, request 100m/32Mi, limit
300m/128Mi e HPA CPU 50%, mínimo 1/máximo 2. O Job de carga separado tem quatro
clientes por 120 segundos, deadline 150 segundos, request 10m/16Mi e limit total
100m/64Mi. Não possui token de ServiceAccount, banco ou dados da aplicação.

Após observar a escala, o script aguarda a carga terminar, registra os contadores,
remove somente o Job criado e observa o retorno a uma réplica. O Deployment,
Service, HPA e namespace permanecem para consulta. Falha encerra a carga e exige
diagnóstico; não há reset ou limpeza de outros namespaces.

O teste demonstra reação do HPA a CPU de um workload sintético. Não comprova
performance de NestJS, banco, SLO ou autoscaling de EC2.

## Arquivos técnicos desta etapa

- [Orquestração pós-Apply](../scripts/bootstrap-production.mjs).
- [Configuração TLS e validação dos CSRs](../scripts/kubelet-serving-tls.py).
- [Instalador Metrics Server](../modules/ec2/user-data/install-metrics.sh), modo secure.
- [Init do Control Plane](../modules/ec2/user-data/init-control-plane.sh), sem persistir/imprimir token.
- [Testes de bootstrap](../tests/kubernetes-bootstrap.test.mjs) e
  [testes de segurança CSR](../tests/kubelet_serving_tls_test.py).
- [CI de validação](../.github/workflows/terraform-validate.yml), incluindo os novos testes.
- [Entrada Kustomize](../tests/kustomization.yaml),
  [componente](../tests/production-hpa/kustomization.yaml),
  [carga limitada](../tests/production-hpa/load-job.yaml) e
  [executor do teste](../tests/production-hpa/run.sh).

Nenhum workflow de Apply, arquivo HCL, state ou recurso AWS foi modificado por
esta implementação. Os scripts de user-data alterados são usados em futuras
criações; a correção do cluster existente ocorreu por SSH, sem reaplicar Terraform.
