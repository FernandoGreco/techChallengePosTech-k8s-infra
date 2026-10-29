# Guia de execução — infraestrutura Kubernetes

## Ambientes

Kubeadm em EC2 Ubuntu, sem EKS. Consultar a [arquitetura](docs/ARQUITETURA-INFRA.md)
e o [catálogo de evidências](evidencias/INDEX.md) antes de operar um ambiente
existente. Os registros são datados e não substituem diagnóstico atual.

| Ambiente | Branch | Diretório | State S3 | Aprovação |
| --- | --- | --- | --- | --- |
| homolog | homolog | environments/homolog | homolog/terraform.tfstate | homolog-apply |
| production | main | environments/production | production/terraform.tfstate | production-apply |

Não copiar o state, importar as mesmas EC2 nos dois ambientes ou tratar produção
como migração do cluster existente. Compartilhar bucket é possível; compartilhar
objeto de state não é. Usar workspace default e região us-east-1.

## Validação local sem provisionamento

Com ferramentas instaladas, da raiz:

```bash
node --test tests/cicd-guards.test.mjs
terraform fmt -check -recursive environments modules
find scripts modules/ec2/user-data tests observability -name '*.sh' -type f -print0 | xargs -0 -r -n 1 bash -n
actionlint -shellcheck=
validar_terraform_local() {
  local target task_tf_data
  for target in homolog production; do
    task_tf_data="$(mktemp -d)" || return
    TF_DATA_DIR="$task_tf_data" terraform -chdir="environments/$target" init -backend=false -input=false -lockfile=readonly || return
    TF_DATA_DIR="$task_tf_data" terraform -chdir="environments/$target" validate -no-color || return
  done
}
validar_terraform_local
```

Init sem backend pode baixar providers, mas não usa state. CI também verifica
PowerShell AST, manifests strict Kubernetes 1.34 e Helm lint/template; apenas
Alloy e sua CRD são excluídos do catálogo. Não é validação de admissão real.
Bash -n não equivale a ShellCheck.
O retorno da função preserva o erro de init/validate e interrompe o processamento
dos ambientes seguintes. Conferir o código de saída antes de continuar.

## Diagnóstico de leitura do cluster existente

Com chave SSH fora do Git, host atual e identidade verificada por canal confiável:

```bash
aws sts get-caller-identity --profile academy-tc3 --region us-east-1 --query Account --output text
ssh -i "$SSH_PRIVATE_KEY_PATH" -o BatchMode=yes -o StrictHostKeyChecking=yes -o UpdateHostKeys=no -o ConnectTimeout=5 "ubuntu@$CONTROL_PLANE_HOST" 'bash -se' < scripts/check-k8s-readonly.sh
```

O segundo comando confere contexto, dois nós Ready, CNI/CoreDNS, Metrics Server e
top. IP público pode mudar. validate-k8s.sh inicializa backend e usa accept-new;
não é diagnóstico estrito de identidade. deploy.sh também mantém accept-new;
revisar a política antes de utilizá-lo.

## Reprodução em outra conta AWS e configuração do GitHub Actions

### 1. Learner Lab e credenciais temporárias

Iniciar Start no portal e aguardar Lab ativo. Em AWS Details/AWS CLI, obter
access key, secret key e session token da mesma sessão. Configurar o perfil
academy-tc3 no arquivo AWS de credenciais do próprio usuário, fora do Git, com
acesso restrito, usando o formato fornecido pelo Academy. Renovar os três campos
juntos; não colar valores em chat, argumentos, histórico ou vídeo.

Confirmar conta por STS e região us-east-1. Conferir tempo restante no portal:
STS não comprova a duração restante do Lab. Essa configuração externa é feita
pelo usuário; o repositório não copia automaticamente credenciais para GitHub.

### 2. Conta, VPC, subnets e Key Pair

Consultas de leitura:

```bash
aws ec2 describe-vpcs --profile academy-tc3 --region us-east-1 --query 'Vpcs[].{Id:VpcId,Default:IsDefault}' --output table
aws ec2 describe-subnets --profile academy-tc3 --region us-east-1 --query 'Subnets[].{Id:SubnetId,Vpc:VpcId,AZ:AvailabilityZone,PublicIP:MapPublicIpOnLaunch}' --output table
aws ec2 describe-key-pairs --profile academy-tc3 --region us-east-1 --query 'KeyPairs[].KeyName' --output table
```

Conferir rotas/saída, VPC/subnet, Key Pair e posse da chave correspondente.
Usar CIDR SSH restrito, preferencialmente /32. Não reutilizar identificadores
ou credenciais de outra conta. Preparar tfvars privado a partir do exemplo: aws_region,
vpc_id, subnet_ids, ssh_key_name e ssh_allowed_cidr. As duas EC2 usam a primeira
subnet. modules/network não é utilizado.

### 3. Backend remoto

Preparar o bucket da própria conta por ação externa autorizada antes do Plan.
Ativar bloqueio público, criptografia e versionamento. Conceder acesso mínimo
ao prefixo: ListBucket; GetObject/PutObject no state; GetObject/PutObject/
DeleteObject no .tflock; permissões KMS se aplicáveis.

Backend usa encrypt=true, use_lockfile=true, região us-east-1 e chaves distintas.
O bucket padrão é fiap-tc3-k8s-tfstate-<ACCOUNT_ID>; TF_BACKEND_BUCKET o substitui.

```bash
aws s3api head-bucket --bucket "$TF_BACKEND_BUCKET" --profile academy-tc3 --region us-east-1
aws s3api head-object --bucket "$TF_BACKEND_BUCKET" --key homolog/terraform.tfstate --profile academy-tc3 --region us-east-1 --query '{Bytes:ContentLength,Modified:LastModified}'
```

Em produção, usar production/terraform.tfstate; sua ausência pode ser normal
antes do primeiro provisionamento. Não baixar conteúdo para demonstrar o state
nem criar/remover locks manualmente. Plan com backend remoto usa lock S3:
não é operação estritamente sem escrita.

### 4. GitHub Environments, secrets e variables

Criar homolog, homolog-apply, production e production-apply.

| Configuração | homolog | homolog-apply | production | production-apply |
| --- | --- | --- | --- | --- |
| AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY / AWS_SESSION_TOKEN | Secrets | Secrets | Secrets | Secrets |
| TFVARS_HOMOLOG | Secret | Não usa | Não usa | Não usa |
| TFVARS_PRODUCTION | Não usa | Não usa | Secret | Não usa |
| TF_PLAN_ENCRYPTION_KEY | Secret | Igual ao Plan | Secret | Igual ao Plan |
| AWS_ACCOUNT_ID | Variable | Mesma conta | Variable | Mesma conta |
| TF_BACKEND_BUCKET | Variable recomendada | Mesmo bucket | Variable recomendada | Mesmo bucket |

Gerar a chave aleatória de ao menos 32 caracteres em gestor seguro, sem exibir.
Preferir uma chave por par Plan/Apply. Secrets de Repository/Organization podem
ser herdados quando permitido; um Environment não herda secrets de outro.
O job Apply não precisa de tfvars, pois aplica o plano salvo.
O perfil local não autentica runners. OIDC não foi introduzido no Lab.

Para somente Plan manual de produção, `production` precisa dos três Secrets AWS,
de `TFVARS_PRODUCTION` e de `AWS_ACCOUNT_ID`; `TF_BACKEND_BUCKET` é recomendado.
`TF_PLAN_ENCRYPTION_KEY` e as proteções de `production-apply` são necessárias
somente no fluxo que encaminha Apply. Sua ausência não impede o Plan-only.
`TERRAFORM_STATE_ROOT`, do antigo backend local, não é lida pelo workflow S3.

O [modelo de produção](environments/production/terraform.tfvars.example) contém
referências da conta demonstrada, que precisam ser revalidadas. O CIDR é um
placeholder intencional: confirmar o IP público atual antes de cadastrar o Secret.
Não adicionar credenciais AWS, chave privada ou configuração de backend a tfvars.

Variables de **repositório**:

- INFRA_DEPLOY_REPOSITORY: opcional no fork. No original, definir exatamente
  FernandoGreco/techChallengePosTech-k8s-infra. O allowlist aceita somente o fork
  e esse original; outros destinos exigem revisão de código e testes.
- PRODUCTION_CAPACITY_APPROVED: manter ausente/false até revisar quotas, custos,
  tempo de Lab e isolamento. Definir true apenas após decisão explícita.
  Esse sinal não consulta automaticamente quotas AWS.
  O dispatch explícito action=plan dispensa essa flag e nunca encaminha Apply.
  Push e dispatch action=apply continuam exigindo true para produção.
  Cadastrar em Settings > Secrets and variables > Actions > Variables, no escopo
  Repository. Uma variável somente no Environment não atende ao job request,
  que não declara Environment. A flag também libera o encaminhamento protegido
  de Apply em pushes futuros; ela não seleciona o modo Plan-only.

State vazio de produção propõe recursos próprios. Preferir conta/Lab separado
quando não houver capacidade de coexistência. Encerrar outro ambiente exige
autorização independente: o pipeline não destrói homolog para liberar espaço.

### 5. Branch protection e aprovação de Apply

Proteger homolog/main: PR obrigatório, check Validate infrastructure, base
atualizada, resolução de conversas, administradores incluídos, force-push e
exclusão bloqueados. Confirmar o nome do check no run ao cadastrá-lo.

Em homolog-apply/production-apply: required reviewers humanos, sem bypass
administrativo e uma única política custom de branch: homolog/main,
respectivamente. Restringir também o Environment de Plan à branch correspondente.
Verificar suporte do plano GitHub; ausência de regras deve bloquear o guard.

As regras são consultadas antes de preparar artefato e depois da aprovação.
Aprovação de PR não substitui aprovação de Apply. Não configurar aprovação
automática de deployments.

### 6. Validar pipelines e executar com segurança

1. Revisar arquivos/segredos e passar nos testes locais.
2. Após autorização de publicação, validar CI real na feature/PR sem AWS.
3. Configurar GitHub e renovar credenciais dos pares Plan/Apply.
4. Dispatch action=plan na branch alvo executa somente Plan.
5. Push/merge autorizado em homolog/main inicia CI, Plan e espera aprovação.
6. Revisar conta, state, contagens e campos antes de aprovar o run/commit exato.
7. O Apply usa somente o plano salvo; não replaneja. Credenciais expiradas,
   state alterado ou plano com mais de quatro horas exigem execução completa
   nova e nova revisão. Não reaproveitar artefato de outra tentativa.

Dispatch validate é padrão e não acessa AWS. Dispatch apply exige APLICAR HOMOLOG
ou APLICAR PRODUCTION e ainda depende da aprovação humana. A verificação SSH
opcional permanece somente em homolog: SSH_PRIVATE_KEY, CONTROL_PLANE_HOST,
SSH_KNOWN_HOSTS e rede previamente autorizada; não abre SG.

Para validar somente o Plan, usar uma nova execução manual em main com action=plan,
confirm_apply vazio e verify_kubernetes=false. Não reexecutar um run de push para
essa finalidade: push solicita Plan e encaminhamento de Apply. O Plan-only não
publica artefato para Apply posterior; esse outro fluxo gera seu próprio plano
na mesma execução e exige nova revisão. Plan remoto cria/remove lock S3.

O guard bloqueia exclusões, substituições, user_data/user_data_base64 e alterações
disruptivas de EC2: AMI, tipo, subnet/AZ, Key Pair, disco raiz, SGs da instância e
source_dest_check. Outras alterações, inclusive de rede permitidas pelo plano,
ainda exigem revisão. Não existe garantia genérica de zero mudança em SG.

### 7. EC2, cloud-init e Kubernetes

Homologação nova pode usar scripts/deploy.sh, mutante e com confirmação sim:
Terraform, cloud-init, join do Worker e Metrics Server. Requer AWS_PROFILE,
AWS_REGION, EXPECTED_AWS_ACCOUNT_ID, SSH_PRIVATE_KEY_PATH e SSH_USER.
O script é bloqueado em Actions e tem homolog hardcoded: **não usar em produção**.

O workflow de produção prepara EC2/cloud-init. Associação do Worker e validação
de Kubernetes exigem etapa operacional revisada e autorizada separadamente.
O [bootstrap de produção pós-Apply](docs/BOOTSTRAP-PRODUCAO.md) implementa essa
etapa sem executar Terraform: valida IDs/tags da conta, associa o Worker por
stdin com token temporário, configura certificados e Metrics Server seguro.
O laboratório HPA de produção usa namespace próprio e carga limitada explícita.
Os novos volumes raiz de produção usam criptografia explícita. O módulo mantém
null como padrão para os consumidores existentes, sem alterar a opção de homolog.
Apply inicial sozinho não comprova cluster de produção Ready.
Verificar EC2/checks, cloud-init, kubelet/containerd, join, Calico, Metrics Server,
top, HPA e telemetria. Não repetir provisionamento no cluster operacional.

### 8. Limpeza ao final

Salvar evidências sanitizadas. Identificar conta, ambiente, state, recursos
exclusivos e dependências. Encerrar somente cargas/túneis do próprio teste.
emptyDir pode perder dados ao remover/substituir Pod.

scripts/destroy.sh atende somente homolog e exige DESTRUIR e plano revisado.
Não usar em produção. Para uma limpeza de produção separadamente autorizada:

1. Confirmar perfil/conta com STS, diretório environments/production e bucket
   correto; isolar TF_DATA_DIR e manter workspace default.
2. Inicializar somente o backend desse diretório, cuja chave é
   production/terraform.tfstate. Não migrar/copiar state nem substituir a chave.
3. Gerar um plano de destruição salvo em arquivo privado fora do Git, com tfvars
   exclusivos de produção. Essa geração e a operação posterior exigem autorização
   própria; não fazem parte desta preparação nem do workflow.
4. Revisar os recursos e as dependências, confirmar que nenhum recurso de homolog
   ou compartilhado será excluído e obter aprovação explícita do plano exato.
5. Aplicar somente esse plano de limpeza aprovado por procedimento manual
   controlado; o guard do pipeline normal deve continuar bloqueando destruições.
6. Conferir a remoção apenas dos recursos autorizados e preservar state/bucket
   e evidências. Não remover locks manualmente em caso de erro.

Workflows não possuem destroy.
Preservar bucket/state conforme a política do grupo. Não limpar durante a
demonstração nem excluir recursos compartilhados.

## Aplicação e Grafana

Manifests NestJS estão no fork da aplicação: digest, ClusterIP, Job schema
separado, startup node dist/main.js e PostgreSQL efêmero. Não executar seed ou
apontar Job para RDS compartilhado. HPA sintético 1–4 e API 1–2 são testes distintos.

Seguir o [plano Grafana](observability/PLANO-GRAFANA.md) sem duplicar release.
Metrics Server atende HPA/top; Alloy envia métricas/logs/eventos. Para entrega
integrada, consultar a [matriz de requisitos](docs/REQUISITOS-FASE-3.md).

Em outra conta ou stack, revisar endpoints, nome de cluster e identidade usados
pelos helpers/values de observabilidade. Não reutilizar tokens, chaves SSH ou
known_hosts de outro ambiente. As chaves dos hosts devem ser verificadas por
canal confiável antes da conexão; um endereço antigo não comprova identidade.

## Acesso local ao Swagger

Com autorização de acesso, chave fora do Git e host previamente verificado,
definir SSH_PRIVATE_KEY_PATH e CONTROL_PLANE_HOST no terminal privado. Em outra
janela, manter o túnel abaixo ativo; não executá-lo junto dos testes locais:

```bash
ssh -i "$SSH_PRIVATE_KEY_PATH" -o BatchMode=yes -o StrictHostKeyChecking=yes -o UpdateHostKeys=no -o ConnectTimeout=5 -o ExitOnForwardFailure=yes \
  -L 127.0.0.1:18080:127.0.0.1:18080 "ubuntu@$CONTROL_PLANE_HOST" \
  'kubectl --context=kubernetes-admin@kubernetes -n oficina-tc3 port-forward --address=127.0.0.1 service/oficina-api 18080:3000'
```

Abrir http://127.0.0.1:18080/api/docs. O Service continua ClusterIP; não abre
Security Group. Encerrar apenas o próprio túnel com Ctrl+C ao final. Isso não
substitui integração com API Gateway/Lambda. Não mostrar JWT ou dados pessoais.

[README](README.md) · [Documentação](docs/INDEX.md)
