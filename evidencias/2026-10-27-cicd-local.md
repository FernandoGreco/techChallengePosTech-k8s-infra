# Validação local do CI/CD

Data: 27/10/2026. Branch feature/finalizacao-tc3 criada a partir de homolog
7ca2771, preservando alterações e arquivos não rastreados. Sem commit/push/PR.
Referências homolog e origin/main conferidas ao final, sem alteração.

| Verificação realmente executada | Resultado |
| --- | --- |
| Terraform fmt nos 13 arquivos .tf, sem abrir tfvars | Passou |
| Terraform 1.16.5 init -backend=false -lockfile=readonly | Passou em TF_DATA_DIR temporário |
| Terraform validate | Passou, provider AWS 6.68.0 do lockfile |
| Sintaxe Bash | 16 scripts passaram |
| Parsing PowerShell | 3 scripts passaram, sem execução privada |
| Node --test tests/cicd-guards.test.mjs | 4 testes passaram, 0 falhas |
| actionlint 1.7.12 -shellcheck= | Passou |
| kubeconform 0.8.0 strict, Kubernetes 1.34.0 | 10 recursos válidos, 0 erros/inválidos/skips |
| Helm 3.22.1 lint e template, chart 4.5.5 | Passaram, zero Secrets renderizados |
| Kubeconform do chart renderizado | 28 recursos: 26 válidos, 2 skips explícitos (Alloy/CRD), 0 erros |
| git diff --check | Passou |
| git check-ignore para arquivo privado, plano cifrado e pem | Todos ignorados |

Testes Node usam apenas dados sintéticos, sem AWS:

1. Exclusão, substituição em ambas as ordens e ação desconhecida não são aceitas;
   resumo não revela valores de atributos.
2. Plano AES-GCM rejeita adulteração, chave errada, expiração, commit/run/conta/
   região divergentes; roundtrip preserva bytes do plano sintético.
3. Apply rejeita push, branch main, confirmação ausente, Environment sem reviewers,
   bypass administrativo e política de branch ampla.
4. Deploy legado em GitHub Actions para antes de chamar executáveis AWS/Terraform
   simulados; nenhuma operação real foi invocada.

Os testes Node foram executados no Node local 24.17.0; workflow usa Node 22 e
a execução desse alvo em runner real continua pendente. Binários Windows oficiais
dos validadores foram baixados no TEMP e conferidos por SHA256. O instalador Linux
preparado para o runner ainda não foi executado em Ubuntu nesta etapa.

Falhas encontradas e resolvidas durante a validação:

- actionlint detectou runner.temp em env de job, contexto não permitido naquele
  nível; diretórios passaram a ser definidos via GITHUB_ENV em steps.
- DNS dos schemas bloqueado pelo sandbox; consulta pública refeita com autorização
  fora dele. Tentativa com opção timeout não suportada foi removida.
- Catálogo kubeconform não fornece schema de Alloy/CustomResourceDefinition;
  skips ficaram explícitos e restritos, sem ignore-missing-schemas global.

Nenhum terraform plan/apply/destroy, leitura de state, alteração SG/EC2/Kubernetes
ou envio Git foi executado. Os relatórios de CI/CD do GitHub publicados anteriormente
permanecem históricos, não validação destas alterações locais.
