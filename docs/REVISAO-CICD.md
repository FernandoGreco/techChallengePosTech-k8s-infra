# Revisão CI/CD da infraestrutura — 27/10/2026

> Registro histórico da versão indicada; não descreve o workflow atual. Consulte [CI/CD atual](CICD-HOMOLOG.md) e [status consolidado](STATUS-INFRA.md).

Este documento registra o diagnóstico histórico do código publicado em 7ca2771.
A implementação local posterior está em [CICD-HOMOLOG.md](CICD-HOMOLOG.md), ainda
sem publicação. As lacunas abaixo não devem ser confundidas com o fluxo novo.

Diagnóstico somente de leitura no GitHub e no Git. Nesta etapa foram alteradas
apenas documentação/evidências autorizadas. Nenhum workflow disparado/editado,
Terraform executado ou operação commit/push/merge realizada.

## Base Git e diferenças

- origin: felipevrds/techChallengePosTech-k8s-infra, público, default main.
- origin/homolog confirmado por ls-remote: 7ca277175eab3e2cb5bdbd847a4638404803e452.
- origin/main: f29401eaabcdbc1827b0c187585cb4f657b23cb4.
- homolog está quatro commits à frente de main; não há branch production em
  origin na consulta. A branch local atual permanece homolog e não está limpa.
- main ainda usa runner self-hosted/linux/k8s-infra e TERRAFORM_STATE_ROOT;
  homolog usa ubuntu-latest e backend S3 com lockfile. Não tratar como equivalentes.
- Ajustes recentes de bootstrap/métricas/deploy e os arquivos não rastreados
  não estão nos commits publicados; os runs históricos não validam esse conteúdo.

## Execuções reais consultadas

Resultados e nomes das etapas obtidos pela API pública, sem baixar logs.
Horários abaixo em America/Sao_Paulo; SHA 7ca2771 em todos os runs.

| Workflow/evento | Data/hora | Resultado e alcance |
| --- | --- | --- |
| Terraform Validate / push homolog | 26/10 15:15:30 | Success: fmt, init sem backend, validate e shell |
| Terraform Deploy / push homolog | 26/10 15:15:30 | Failure em Validate required configuration; deploy pulado |
| Terraform Deploy / workflow_dispatch homolog | 26/10 15:39:49 | Success, inclusive etapa Deploy infrastructure and validate Kubernetes e cleanup |

- [CI aprovado](https://github.com/felipevrds/techChallengePosTech-k8s-infra/actions/runs/40376124782)
- [CD por push com falha](https://github.com/felipevrds/techChallengePosTech-k8s-infra/actions/runs/40376124724)
- [CD manual aprovado](https://github.com/felipevrds/techChallengePosTech-k8s-infra/actions/runs/40379708985)

O motivo específico da falha de configuração não foi inferido sem logs. O run
manual comprova que o GitHub marcou a etapa concluída, não o estado atual do
cluster ou todas as condições de saúde: estas foram comprovadas separadamente.

## Gatilhos e proteções

- CI: PRs para main/homolog/production; pushes para feature/terraform-k8s-infra,
  homolog/production. Não há workflow_dispatch no CI nem cobertura de qualquer
  feature/* por push; push para main também não corresponde ao filtro.
- CD: push homolog ou workflow_dispatch; environment homolog, concorrência
  serializada, sem cancelamento. Não há filtro que impeça usar outra branch no
  workflow_dispatch; a política do Environment é uma barreira adicional.
- CI e CD são workflows independentes: CD não aguarda sucesso do CI desse SHA.
- API de branches: protected=false para main e homolog; rulesets públicos vazios.
- Environment homolog: única regra exposta é branch_policy, permitindo homolog.
  Nenhuma regra required_reviewers foi retornada. Não confundir com PR obrigatório.
- APIs de detalhes de proteção, secrets e variables retornaram HTTP 401 sem
  autenticação GitHub. Não foi possível confirmar nomes cadastrados/validade.

## Configuração esperada em homolog (somente nomes)

Secrets: AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_SESSION_TOKEN,
TFVARS_HOMOLOG e SSH_PRIVATE_KEY.

Variables: AWS_ACCOUNT_ID, AUTO_APPROVE_DEPLOY (exigido true pelo CD atual),
TF_BACKEND_BUCKET (opcional pelo fallback no script).

O profile academy-tc3 local não é transmitido ao runner. As credenciais temporárias
Academy dos secrets precisam estar válidas na hora de uma execução AWS autorizada.
CI sem backend não precisa de credenciais AWS nem acesso SSH. main tem configuração
legada diferente; não solicitar TERRAFORM_STATE_ROOT para o CD atual de homolog.

## Etapas e lacunas

CI em homolog inicializa sem backend e valida Terraform em TF_DATA_DIR temporário;
verifica sintaxe Bash por arquivo. CD gera tfvars/chave com permissões restritas,
executa deploy.sh e remove arquivos privados ao final. deploy.sh faz init S3,
fmt/validate/plan/show, apply, abertura SSH temporária para o runner, join do worker,
espera Ready/Calico, Metrics Server e validação final. Isso não é apenas diagnóstico.

Pendências:

1. Revalidar/publicar código atual por PR autorizado; preservar tudo que já existe.
2. Corrigir xargs do CD (falta -n 1); incluir testes/observabilidade na validação
   Bash e parsing PowerShell. Validar manifests e Helm offline sem credenciais.
3. CI atual não contempla todos os novos arquivos e não testa assertivamente a
   saúde Kubernetes. validate-k8s.sh apenas lista nós/pods e inicializa backend.
4. Disponibilizar entrada de validação manual segura no CI, sem apply, SG, join,
   instalação Metrics Server ou testes HPA mutantes.
5. Impedir CD antes de CI bem-sucedido e exigir barreira explícita para aplicação.
   AUTO_APPROVE_DEPLOY=true sozinho não é revisão humana do plano.
6. Proteger main e homolog, exigir PR/checks e revisar políticas do Environment.
7. Planejar separação de plan/apply e revisão de plano sem exposição de dados.
8. Grafana e testes HPA hoje têm evidências reais, mas não integram automaticamente
   o workflow de infraestrutura; separar instalação de verificação, sem duplicação.
9. Produção e seu deploy automático continuam ausentes: decisão necessária do grupo.

Checagem Kubernetes em GitHub-hosted runner exige caminho SSH autorizado. Hoje
deploy.sh abre SG temporariamente para o runner; isso modifica AWS e não pode ser
usado numa validação estritamente de leitura. Usar runner/canal já autorizado,
se disponível, ou aprovar separadamente a conectividade. Não configurar runner ou
alterar SG implicitamente. Revisar confiança de host e privilégios do kubeconfig.

## Sequência proposta, aguardando aprovação de implementação

1. Autorizar feature/finalizacao-tc3 a partir de homolog atual, preservando alterações.
2. Ajustar CI local: todos os scripts, Helm/manifests, fmt/validate sem backend;
   acrescentar acionamento manual somente de validação. Testar em área temporária.
3. Revisar regras GitHub e a configuração necessária, sem solicitar valores de secrets.
4. Com autorização de commit/push/PR, executar CI real do SHA atualizado e capturar
   run/link/resultados. Não fazer merge enquanto o CD atual puder aplicar sem revisão.
5. Preparar CD com dependência do CI e separação de validação/plano/aplicação.
   Nenhum apply até autorização e revisão de impacto; nenhuma recriação implícita.
6. Demonstrar CI novo e CD histórico já aprovado. Para comprovar CD atualizado,
   autorizar execução específica após plano; não repetir deploy apenas para vídeo.
7. Definir produção com o grupo antes de afirmar atendimento integral do enunciado.

## Integração NestJS depois do CI de infraestrutura

Infra oferece cluster saudável, rede/CNI, Metrics Server/HPA e observabilidade.
Combinar com a equipe: imagem versionada por SHA/digest, registry e acesso,
namespace da aplicação, ServiceAccount/RBAC restritos ao namespace, Secrets,
requests/limits, probes, Service e interface com Gateway/Ingress.

Pipeline da aplicação pertence ao repositório da equipe: testes/build, publicação
da imagem e deploy/rollout. Não usar cluster-admin como credencial de aplicação.
Revisar migrations/seeds e compatibilidade com múltiplas réplicas antes de apontar
para banco compartilhado; qualquer operação no banco depende do responsável.

Só então validar aplicação em homolog, readiness, APIs/Gateway e HPA do workload
real, coordenar JSON/correlation IDs, latência, traces, métricas de ordens de serviço
e dashboards/alertas de negócio. O teste HPA sintético não comprova esses requisitos.
Não alterar código NestJS, banco ou recursos compartilhados sem autorização.
