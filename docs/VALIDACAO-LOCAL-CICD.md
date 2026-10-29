# Validação local — homologação e produção

Data: 28/10/2026. Registro da implementação local e das verificações anteriores
aos commits locais autorizados. Sem configuração remota GitHub, Terraform
Plan/Apply/Destroy ou alteração AWS/Kubernetes.

## Resultados executados

| Verificação | Resultado |
| --- | --- |
| Node --test tests/cicd-guards.test.mjs | 17 testes, 17 aprovados, zero falhas |
| Node --check nos scripts/testes .mjs | Passou |
| actionlint 1.7.12 -shellcheck= | Passou nos workflows |
| Terraform fmt -check dos arquivos .tf de environments/modules | 18 arquivos aprovados |
| Terraform init -backend=false -input=false -lockfile=readonly | Passou nos dois ambientes, com mirror local do provider |
| Terraform validate | Homolog e production válidos, AWS provider 6.68.0 |
| Bash -n por arquivo | 16 scripts aprovados |
| PowerShell AST, sem executar scripts | 3 scripts aprovados |
| Varredura local por padrões de segredos | Nenhum achado nos arquivos textuais revisados |
| Links internos Markdown do conjunto selecionado | 119 links conferidos, nenhum destino/âncora quebrado |
| Evidências JSON | 6 arquivos válidos, tratando o BOM histórico quando presente |
| Exemplo de propagação de erros do guia | 6 cenários com Terraform simulado aprovados |

Os testes Node foram executados no Node local 24.17.0; o CI usa Node 22.
Provider reutilizado de cache/mirror, sem backend nem consulta de recursos.
O sandbox negou acesso ao pacote em cache na primeira tentativa; a inicialização
offline e validação foram repetidas fora dele mediante aprovação. O lockfile não
foi alterado. A mensagem de provider unauthenticated refere-se ao mirror local;
não é uma validação nova de assinatura pela rede.

Não foram reexecutados Helm/kubeconform nesta etapa: values/manifests operacionais
não mudaram; essas verificações continuam no CI. A execução completa em runner
GitHub do novo código ainda exige publicação e autorização separadas.

Na preparação dos commits locais, a suíte de 17 testes e o actionlint foram
reexecutados com sucesso. Validate reutilizou os dados já inicializados sem
backend. O exemplo do guia foi exercitado com executáveis simulados: sucesso e
falhas de mktemp/init/validate preservam os códigos de saída e interrompem os
ambientes seguintes. Nenhum Terraform Plan/Apply/Destroy foi executado.

## Cobertura de segurança

- Exclusões, substituições, ações desconhecidas e atualizações EC2 de user-data.
- Valores removidos/desconhecidos e mudanças disruptivas de EC2, inclusive
  unknowns aninhados. Criação inicial/tags permanecem permitidas.
- Artefato rejeita adulteração, chave incorreta, expiração e contexto divergente:
  commit, run, tentativa, conta, região, repositório, ambiente, bucket e state.
- Homolog push mantém Plan e aprovação; main exige confirmação de capacidade.
- Dispatch validate/plan não solicita Apply; apply exige confirmação do target.
- Reviewers, bloqueio de bypass administrativo e política exata homolog/main.
- Adaptação explícita ao original conhecido, rejeitando repositórios arbitrários.
- CLI de roteamento seleciona diretório, Environment, secret e state de produção.
- Backends/lockfiles/tags e wiring do workflow: Apply usa somente plano salvo.
- Script legado para antes de invocar executáveis AWS/Terraform simulados.

## Arquivos técnicos

Modificados:

- .github/workflows/terraform-deploy.yml
- .github/workflows/terraform-validate.yml
- scripts/require-apply-approval.mjs
- scripts/plan-artifact.mjs
- scripts/terraform-plan-summary.mjs
- tests/cicd-guards.test.mjs

Criados:

- scripts/deployment-target.mjs
- environments/production/main.tf
- environments/production/variables.tf
- environments/production/outputs.tf
- environments/production/providers.tf
- environments/production/versions.tf
- environments/production/.terraform.lock.hcl
- environments/production/terraform.tfvars.example

O módulo EC2 existente e o diretório homolog foram preservados. Nenhum tfvars
preenchido, state, plano, chave ou credencial foi criado no repositório.

## Documentação

README, COMECE-AQUI, GUIA-EXECUCAO e guias atuais foram reorganizados. Foram
acrescentados índice, arquitetura, ADR de CI/CD, matriz de requisitos e esta
validação. Revisões/roteiros antigos receberam identificação de histórico.
Observability teve somente ajustes de documentação, sem alteração de configuração.
Os 19 arquivos de evidência originais foram preservados; novos índice e registro
de resultados informados identificam a fonte sem simular novas consultas.

Documentos modificados:

- README.md, COMECE-AQUI.md, GUIA-EXECUCAO.md.
- docs/ADR-001-observabilidade.md, docs/CHECKLIST-FINAL.md,
  docs/CICD-HOMOLOG.md, docs/GUIA-FERNANDO.md, docs/ROTEIRO-VIDEO.md,
  docs/STATUS-INFRA.md.
- Identificação de histórico em docs/REVISAO-CICD.md,
  docs/PR-FINALIZACAO-TC3.md e docs/REVISAO-APLICACAO-SEM-ALTERACOES.md.
- observability/PLANO-GRAFANA.md e observability/VERIFICAR-GRAFANA-CLOUD.md.

Documentos criados:

- docs/INDEX.md, docs/ARQUITETURA-INFRA.md, docs/ADR-002-CICD-AMBIENTES.md,
  docs/REQUISITOS-FASE-3.md e docs/VALIDACAO-LOCAL-CICD.md.
- evidencias/INDEX.md e evidencias/2026-10-28-resultados-informados.md.

Guias substituídos tiveram cópia de preservação fora do repositório. Nenhum
documento ou evidência existente foi excluído. Espaços finais encontrados em uma
saída bruta histórica não foram corrigidos, preservando a fonte.

## Seleção para os dois commits locais

O primeiro commit contém exclusivamente os 14 arquivos técnicos listados acima.
O segundo seleciona 38 arquivos de documentação/evidências. Os materiais pessoais
de gravação não são dependências: o acesso Swagger agora está no guia portátil.

Permanecem locais, sem exclusão:

- docs/DEMONSTRACAO-TC3-DEPLOY-CONTROLADO-LOCAL.md
- docs/GRAVACAO-TC3-COMANDOS-LOCAL.md
- docs/GRAVACAO-TC3-PRECHECK-LOCAL.sh
- evidencias/2026-10-27-publicacao-feature.md, rascunho de publicação.
- evidencias/tc3-deploy-kubernetes-validacao-local.txt, saída bruta original.
- evidencias/.gitkeep, desnecessário com o diretório preenchido.

A cópia evidencias/tc3-deploy-kubernetes-validacao.txt normaliza apenas BOM,
finais de linha e espaços finais da saída bruta, sem alterar estados/eventos.
A revisão dos 52 arquivos selecionados não encontrou padrões de credenciais,
whitespace inválido ou links para arquivos fora da publicação.
Commit local não publica a feature nem dispara GitHub Actions; push continua
dependendo de autorização própria.

## Validação externa futura

1. Revisar arquivos e configurar GitHub com autorização própria.
2. Publicar feature/PR somente após aprovação; confirmar CI real do novo commit.
3. Testar inicialmente dispatch plan, após autorização para acesso AWS/lock S3.
4. Não habilitar produção sem capacidade/isolamento e configuração dos Environments.
5. Aprovar somente o plano exato, revisado e recente. Mudança de contexto ou
   tentativa exige novo ciclo completo; artefatos antigos não são reutilizáveis.

[CI/CD](CICD-HOMOLOG.md) · [Guia](../GUIA-EXECUCAO.md) · [Evidências](../evidencias/INDEX.md)
