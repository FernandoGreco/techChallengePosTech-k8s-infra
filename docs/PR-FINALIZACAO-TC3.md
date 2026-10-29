# PR de integração com homolog

> Registro histórico da preparação do PR #1. A descrição de gatilhos/proteções abaixo pertence àquela versão; consulte [CI/CD atual](CICD-HOMOLOG.md).

PR #1, rascunho aberto, sem merge:
https://github.com/felipevrds/techChallengePosTech-k8s-infra/pull/1

Head d4c82c95259c7d433c12bf753dc81b4ba1ffd5de, base homolog 7ca2771.
Dois commits à frente, zero atrás, 28 arquivos técnicos. GitHub informou
mergeable=true / mergeable_state=clean; isso não substitui aprovação.

CI push aprovado: https://github.com/felipevrds/techChallengePosTech-k8s-infra/actions/runs/40536574137
CI do próprio PR aprovado: https://github.com/felipevrds/techChallengePosTech-k8s-infra/actions/runs/40539370822

README essencial e todos os arquivos técnicos estão publicados. Nenhuma
dependência de execução foi encontrada em docs/ ou evidencias/. Esses diretórios
e guias complementares permanecem locais, sem novo commit/push nesta etapa.

GitHub verificado por leitura autenticada, sem ler valores de secrets:

- homolog existe e permite exclusivamente a branch homolog.
- Secrets homolog presentes: AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY,
  AWS_SESSION_TOKEN, SSH_PRIVATE_KEY, TFVARS_HOMOLOG.
- AWS_ACCOUNT_ID e TF_BACKEND_BUCKET correspondem ao ambiente esperado.
- AUTO_APPROVE_DEPLOY ainda existe, mas não é usado no novo fluxo.
- Nenhum secret no nível de repositório retornado; TF_PLAN_ENCRYPTION_KEY ausente.
- homolog-apply não existe; main/homolog não estão protegidas.
- Validade de credenciais, conteúdo/equivalência de secrets não são verificáveis
  por essa API e não foram presumidos.

Após merge: CI reutilizável, checagem da solicitação/conta e plan automático.
Sem apply, SSH, join, instalação Helm, mudança SG ou deploy da aplicação.
Plan consulta AWS e cria/remove lock S3; não representa zero escrita AWS.
Antes de merge, aprovar esse acesso, proteger branches e revisar as credenciais.
Antes de apply futuro, configurar homolog-apply protegido, secrets/variables e
chave de criptografia, além de autorização específica e revisão do plano.

## Título e descrição publicados

feat(infra): finaliza Kubernetes, observabilidade e CI/CD protegido

O bootstrap passa a instalar Metrics Server após a associação do worker, e o CI/CD de homologação passa a separar validação, plano e aplicação aprovada.

## Alterações
- Join com token de 10 minutos, espera do Calico e Metrics Server idempotente.
- Grafana Cloud Lightweight reproduzível, com métricas, logs e eventos explícitos, sem credenciais versionadas e com RBAC restrito.
- CI reutilizável para Terraform sem backend, Bash, PowerShell, testes de segurança, workflows, manifests e Helm.
- Push em homolog executa somente CI e plan. Apply exige dispatch manual, confirmação APLICAR HOMOLOG e Environment protegido.
- Plano criptografado, vinculado ao SHA/run/conta/região e válido por quatro horas. Exclusões/substituições bloqueadas.
- Deploy legado bloqueado no Actions, sem abertura automática de SSH no SG.
- README autossuficiente; checksum Linux do AWS provider 6.68.0 / ~> 6.0 corrigido. Docs complementares/evidências ficam locais e não são dependências de execução.

## Validação
CI integralmente aprovado em d4c82c95259c7d433c12bf753dc81b4ba1ffd5de:
https://github.com/felipevrds/techChallengePosTech-k8s-infra/actions/runs/40536574137

Passaram Terraform fmt/init sem backend/validate, 16 Bash, parsing de 3 PowerShell, 4 testes Node, actionlint, manifests e Helm. Kubeconform validou 10 recursos dos manifests e 26 nativos renderizados; Alloy e sua CRD são os únicos skips explícitos. Gitleaks staged: zero achados.

Cluster validado separadamente: dois nós Ready, Metrics Server disponível, HPA 1→4→1, métricas Cloud por API e logs/eventos confirmados manualmente pelo responsável. Não houve teste de apply/deploy completo do novo fluxo.

## Efeito do merge
1. Push homolog inicia Terraform Deploy e chama o CI reutilizável.
2. CI aprovado permite checagem da conta e plan usando o Environment homolog e backend S3.
3. Publica resumo sem valores sensíveis; apply, artefato para apply e SSH ficam pulados.

Não executa Terraform apply, kubeadm, Helm, deploy da aplicação ou mudança de SG. O plano consulta AWS e cria/remove objeto de lock no S3: **não equivale a zero acesso/escrita AWS**. Se isso for exigido, não fazer merge antes de revisar o gatilho de plan.

## Pendências para liberar merge
- [ ] Revisar diff e aguardar o CI do PR.
- [ ] Proteger homolog/main, exigir PR e check aprovado.
- [ ] Aceitar explicitamente o plano automático com acesso AWS/lock S3.
- [ ] Confirmar credenciais Academy atuais e política de homolog permitindo apenas homolog.

## Antes de qualquer apply futuro
- [ ] Criar homolog-apply com reviewers, política única homolog e sem bypass administrativo.
- [ ] Configurar três secrets AWS e variables AWS_ACCOUNT_ID/TF_BACKEND_BUCKET nesse Environment.
- [ ] Configurar TF_PLAN_ENCRYPTION_KEY igual nos dois Environments (ou no repositório), aleatória, ao menos 32 caracteres.
- [ ] Revisar o plano exato e obter autorização específica para dispatch/apply.

Auditoria GitHub: homolog existe com os cinco nomes de secrets esperados e conta/bucket correspondentes; homolog-apply e chave de criptografia ausentes. main/homolog sem proteção. Apenas nomes/presença foram consultados; validade/igualdade de valores privados não podem ser verificadas pela API. AUTO_APPROVE_DEPLOY é legado e não é usado.

## Riscos e limites
- AMI/user_data podem causar reinício/substituição se futuramente aplicados; revisar impacto, sem liberar substituições neste fluxo.
- SSH opcional exige rede já autorizada e host keys verificadas; não abre SG.
- Control plane único e TLS de laboratório não representam alta disponibilidade/segurança de produção.
- Produção e integração NestJS/Gateway/banco/APM ficam fora deste PR.
- Avisos de runtime Node das actions e migração ubuntu-latest são não bloqueantes no run aprovado.

Rascunho para revisão. Nenhum merge, apply ou deploy autorizado por este PR.
