# Status consolidado — 28/10/2026

## Estado conhecido

Cluster de demonstração kubeadm em EC2, sem EKS. Evidências locais registram dois
nós Ready, Calico/Metrics Server, Job Prisma v3 Complete, dez tabelas sem seed,
NestJS/Swagger e PostgreSQL temporário. São consultas históricas; nenhuma
revalidação AWS/Kubernetes foi executada nesta finalização local.

Grafana: métricas por API; logs/eventos e logs NestJS confirmados manualmente.
Traces não comprovados. PostgreSQL emptyDir não é banco gerenciado.

HPA sintético 1→4→1 está documentado. O responsável informou depois API 1→2,
9.986 HTTP bem-sucedidos/zero erros, com carga dentro do Pod (não benchmark
independente), e Apply homolog aprovado sem alterações planejadas.
[Origem identificada](../evidencias/2026-10-28-resultados-informados.md);
ainda faltam referências primárias dos dois resultados posteriores.

## Implementação local atual

Workflow equivalente para homolog/main, CI dos dois diretórios, states separados,
aprovação obrigatória e guard de alterações disruptivas de EC2. Produção exige
confirmação externa de capacidade; não foi provisionada. Contexto criptografado
impede reaproveitar planos entre ambientes/backends/tentativas.

Na preparação inicial não houve operação Git, AWS, Kubernetes ou configuração
remota GitHub. A etapa seguinte autorizou dois commits locais segregados, após
validações, sem push. Publicação remota continua dependendo de nova autorização.
[Validação local](VALIDACAO-LOCAL-CICD.md) · [CI/CD](CICD-HOMOLOG.md).

## Próximos passos autorizáveis

Configurar GitHub externamente, obter evidências primárias finais, revisar o
conteúdo selecionado para publicação e validar CI real após autorização.
Coordenar banco gerenciado, Gateway/Lambda, deploy da aplicação, traces e sinais
de negócio com a equipe. Ver [matriz](REQUISITOS-FASE-3.md).

---

## Registro histórico preservado — etapa anterior

O conteúdo abaixo é histórico de 27/10, com PR/proteções/fluxo daquela etapa.
Não interpretar seus próximos passos, IPs ou pendências como situação atual.


Atualizado em 27/10/2026. Conta confirmada: `207975764067`; perfil local
`academy-tc3`; região `us-east-1`. Branch atual: `feature/finalizacao-tc3`,
criada com autorização a partir de homolog preservando alterações.

Atualização de publicação: commit técnico 2723fc1 publicado exclusivamente na
feature, com 27 arquivos e README autossuficiente. Documentação complementar e
evidências ficaram locais. Após a falha 40533383266, o checksum Linux foi corrigido
em commit separado autorizado d4c82c9 (somente uma linha no lockfile). Push da
feature concluído e CI real 40536574137 aprovado em todas as etapas.
Registro local: evidencias/2026-10-27-ci-github-feature.md.

PR #1 aberto como rascunho de feature/finalizacao-tc3 para homolog, sem merge:
https://github.com/felipevrds/techChallengePosTech-k8s-infra/pull/1
CI do PR 40539370822 aprovado; sem conflitos segundo GitHub. Merge dispara plan
com consultas AWS e lock S3, nunca apply. Branch protection, aceitação desse plan
automático e revisão de credenciais pendentes; homolog-apply/chave ainda ausentes
para qualquer apply futuro. Detalhes locais em PR-FINALIZACAO-TC3.md.

## Validação real concluída

- SSH do Git Bash (`C:/Program Files/Git/usr/bin/ssh.exe`) funciona com
  `StrictHostKeyChecking=yes`, `BatchMode=yes` e `ConnectTimeout=5`.
  A chave original e sua ACL não foram alteradas; não foi necessária cópia.
- Control plane: `i-0ceda6c6a818b75ac`, público `44.206.227.188`,
  privado `172.31.87.121`; nó `ip-172-31-87-121` Ready.
- Worker: `i-0f93be0748f23792c`, público `3.91.180.182`,
  privado `172.31.88.192`; nó `ip-172-31-88-192` Ready após associação.
- Nos dois hosts: cloud-init done; kubelet e containerd active.
- Worker alcança `172.31.87.121:6443` por TCP privado.
- Calico nos dois nós, CoreDNS, etcd, API server e demais pods essenciais Running.
- Metrics Server disponível; API `v1beta1.metrics.k8s.io` True;
  `kubectl top nodes` retorna CPU e memória dos dois nós.
- HPA isolado: aplicação sintética escalou de 1 para 4 réplicas, todas Ready;
  evento `SuccessfulRescale`, CPU observada em 138% para alvo de 50%.
- Gerador de carga removido; redução automática de 4 para 1 comprovada às
  08:50 de São Paulo (11:50 UTC), respeitando a janela padrão de estabilização.
  Evento `SuccessfulRescale` para 1 e deployment 1/1. Namespace `hpa-lab`
  mantido com uma réplica sem carga para evidência.

## Diagnóstico e correções

O worker estava preparado, sem `/etc/kubernetes/kubelet.conf`. Seu user-data
instala Kubernetes, mas o join é executado pelo orquestrador `scripts/deploy.sh`.
A associação foi realizada por SSH com token de duração de 10 minutos,
sem impressão ou gravação do token. Não houve reset ou recriação de EC2.

Havia um deployment Metrics Server com dois ReplicaSets de um rollout bloqueado,
não dois deployments. Após o join e a inicialização do Calico, o rollout convergiu
para uma réplica saudável e zero réplicas no ReplicaSet antigo, automaticamente.

A alteração local anterior instalava Metrics Server durante o cloud-init do
control plane. Isso podia impedir o deploy de chegar ao join, pois aguardava
cloud-init antes de associar o worker. Não há log de execução do deploy que
comprove que esse foi o bloqueio histórico desta instalação.

Ajustes locais autorizados:

- Template do control plane apenas prepara o instalador de métricas;
  sua execução permanece após o join no deploy.
- Deploy gera token com TTL de 10 minutos e aguarda rollout do Calico
  após os nós Ready, antes de instalar métricas.
- Instalador Metrics Server prepara o manifesto com Kustomize antes do apply,
  adicionando uma única vez o argumento de laboratório já utilizado.
  Evita aplicar primeiro a configuração sem esse argumento.
- Script atualizado executado repetidamente no cluster, com rollout e API
  disponíveis; não foi executado Terraform apply nem um novo deploy completo.
  Comparação antes/depois: spec idêntica, geração 3 preservada e exatamente
  uma ocorrência de `--kubelet-insecure-tls`.

Validações locais: sintaxe de 12 scripts Bash, `terraform fmt -check -recursive`
e `git diff --check` passaram. Isso não equivale a `terraform validate` ou plan.

## Pendências por responsabilidade

Infraestrutura:

- Grafana/Alloy instalado com autorização: Helm 3.22.1, chart 4.5.5, release
  grafana-cloud revisão 2. Seis pods Running/Ready; cerca de 32m CPU/268Mi RAM.
  Fleet desabilitado após consulta revelar pipelines extras/incompletas; os
  três sinais estão explícitos no values, sem Beyla ou coleta duplicada.
  API Cloud confirma dois nós e CPU/memória de nós/pods recentes. Loki aceitou
  lotes HTTP 204, sem perdas/retries. Leitura de logs/eventos validada manualmente
  pelo usuário no Loki: logs reais, 74 eventos e Created/Started do pod de teste.
  Token continua sem logs:read; a confirmação manual complementa a API.
  RBAC reduzido e validado; credenciais somente em Secret criado por stdin.
  Detalhes reproduzíveis em observability/PLANO-GRAFANA.md.
- CI/CD: validar execuções reais e proteções de branch/Environment;
  CD atual dispara em push para homolog. Produção não implementada.
  Auditoria GitHub confirmou CI por push aprovado e CD manual aprovado em
  26/10, SHA 7ca2771; CD por push falhou na validação de configuração.
  main/homolog sem proteção; Environment permite homolog, sem regra de revisão
  humana exposta. Secrets/variables não auditáveis sem autenticação GitHub.
  Código local recente ainda não foi validado nesses runs. Plano detalhado em
  [REVISAO-CICD.md](REVISAO-CICD.md).
- CD usa `xargs ... bash -n` sem `-n 1`; os testes HPA e observabilidade
  não eram incluídos na checagem de shell publicada. Corrigido localmente:
  CI reutilizável cobre todos os diretórios, Terraform sem backend, workflows,
  manifests, Helm, parsing PowerShell e testes das barreiras de aplicação.
  CI precede plan; apply exige confirmação e Environment protegido, com plano
  criptografado, vinculado a SHA/run/conta/região e válido por quatro horas.
  Push homolog agora somente planeja; script legado recusa Actions e não abre SG.
  Código técnico publicado em 2723fc1; checksum Linux corrigido em d4c82c9.
  CI real 40536574137 aprovado, sem execução de plan/apply. Configuração das
  proteções/Environments e autorização de PR/merge permanecem pendentes.
  Testes locais passaram: fmt de 13 .tf, init sem backend/validate, sintaxe de
  16 Bash e 3 PowerShell, 4 testes de segurança, actionlint, 10 recursos de
  manifests e 26 recursos nativos do chart (2 tipos custom explicitamente
  excluídos), Helm lint/template. Evidência em 2026-10-27-cicd-local.md.
- Revisar uso de `StrictHostKeyChecking=accept-new` nas automações antes de
  escolher e aprovar a política de confiança; os acessos desta sessão usaram yes.
- Revisar todos os arquivos não rastreados antes de preparar commit/PR.
- Diagrama específico, ADR/RFC e roteiro precisam refletir resultados reais.
- Testar o fluxo completo de deploy somente mediante autorização apropriada.

Grupo/aplicação/serviços externos:

- Instrumentação de latência, logs JSON, correlação, traces e sinais de negócio.
- Dashboards de ordens de serviço e alertas de falhas de processamento.
- Integração Gateway/serverless/banco e consolidação dos quatro repositórios.
- Acesso `soat-architecture`, vídeo do grupo de até 15 minutos e PDF de entrega.

## Segurança e próximos passos

Não houve alterações de Security Group, ACL da chave, recursos compartilhados,
repositório da aplicação ou Git remoto. A feature foi criada com autorização.
Terraform init sem backend e validate foram executados apenas localmente, com
dados temporários; nenhum plan/apply/destroy foi executado nesta finalização CI/CD.
O Metrics Server mantém `--kubelet-insecure-tls` preexistente, restrito ao
contexto de laboratório; não representa a configuração TLS de produção.

Evidências:

- [Consultas Kubernetes e HPA](../evidencias/2026-10-27-kubernetes-hpa.txt).
- [Idempotência Metrics Server](../evidencias/2026-10-27-metrics-idempotencia.txt).
- [Pré-instalação Grafana](../evidencias/2026-10-27-grafana-preflight.md).
- [Saúde e consumo Grafana](../evidencias/2026-10-27-grafana-cluster.txt).
- [API Cloud](../evidencias/2026-10-27-grafana-cloud-api.json).
- [Envio aceito pelo Loki](../evidencias/2026-10-27-grafana-envio.json).
- [Permissões verificadas](../evidencias/2026-10-27-grafana-rbac.txt).
- [Marcador de logs/eventos e validações finais](../evidencias/2026-10-27-grafana-smoke.txt).
- [Confirmação manual de logs e eventos no destino](../evidencias/2026-10-27-grafana-validacao-manual.md).
- [Testes locais do CI/CD novo](../evidencias/2026-10-27-cicd-local.md).

Validação Grafana final às 10:14:31 de São Paulo: dois nós únicos e métricas de
CPU/memória de nós/pods no destino com 8 segundos de defasagem. Treze scripts Bash,
três PowerShell e lint Helm passaram. Token literal ausente nos arquivos preparados.
Pod de teste isolado gerou log JSON e eventos às 10:12:53; configurado para encerrar
após 120 segundos, não removido. Usuário confirmou no portal os eventos
Created/Started, 74 eventos no filtro de eventhandler e logs reais de pods.
Observabilidade dos três sinais validada; capturas para apresentação pendentes.

Próximos passos: validar CI/CD atual, preparar alerta e capturas do dashboard,
revisar evidências e alterações locais antes do PR e integração com a aplicação.
Limpeza do namespace e infraestrutura exige escopo e autorização; não executar
`terraform destroy`, `kubeadm reset` ou recriação de EC2 automaticamente.
