# CI real da feature — publicação técnica

## Atualização: correção autorizada e CI aprovado

- Commit: d4c82c95259c7d433c12bf753dc81b4ba1ffd5de.
- Mensagem: fix(terraform): adiciona checksum do provider para Linux.
- Único arquivo: environments/homolog/.terraform.lock.hcl, uma linha adicionada.
- Provider AWS 6.68.0 e constraint ~> 6.0 preservados.
- Checksum linux_amd64 gerado por Terraform providers lock com pacote assinado
  HashiCorp; checksum Windows preservado. Init sem backend e validate local passaram.
- Push exclusivo para origin/feature/finalizacao-tc3.
- Run: https://github.com/felipevrds/techChallengePosTech-k8s-infra/actions/runs/40536574137
- Resultado: completed/success. Todas as etapas aprovadas: instalação de ferramentas,
  fmt/init sem backend/validate, sintaxe Bash, parsing PowerShell, testes Node,
  actionlint, manifests Kubernetes, Helm lint/template e validação renderizada.
- CI confirmou a correção no runner Linux. Não houve plan/apply/destroy, deploy,
  alteração de AWS/Kubernetes/SG, PR ou merge.
- Registro atualizado apenas localmente; docs/evidências não entraram no commit.

## Histórico da primeira publicação

- Branch: feature/finalizacao-tc3.
- Commit publicado: 2723fc10a1c77f3a3f5b0a26702d0a2054c15102.
- Mensagem: feat(infra): finaliza automacao kubernetes observabilidade e cicd.
- Push exclusivo para origin/feature/finalizacao-tc3, sem force.
- 27 arquivos técnicos publicados, incluindo README autossuficiente.
- docs/, evidencias/, COMECE-AQUI.md, alterações de GUIA-EXECUCAO.md e
  documentação complementar observability/*.md preservados somente localmente.
- Gitleaks no conteúdo staged: zero achados. Testes Node e actionlint passaram.

## Resultado real

Workflow Terraform Validate, push da feature:
https://github.com/felipevrds/techChallengePosTech-k8s-infra/actions/runs/40533383266

Conclusão: failure. Instalação dos validadores oficiais passou. A etapa Terraform
inicializou sem backend e instalou hashicorp/aws 6.68.0, mas validate falhou:
o pacote em cache do runner Linux não corresponde aos checksums do lockfile.
As etapas seguintes foram puladas, não devem ser declaradas aprovadas no runner.

Log autenticado consultado usando credencial GitHub existente somente em memória;
nenhuma credencial exibida, persistida ou alterada. Avisos Node 20/runner Ubuntu
foram retornados, mas não foram a causa desta falha.

Correção local: completar o lockfile com hashes oficiais para linux_amd64 e
windows_amd64, mantendo a versão 6.68.0. Sem plan/apply/destroy ou state.
Correção concluída localmente: apenas uma linha h1 de linux_amd64 acrescentada;
Windows e a versão 6.68.0 preservados. Pacotes Linux e Windows obtidos da origem
e assinados por HashiCorp. Terraform validate local passou sem backend.
Nova validação no runner Linux depende de autorização de novo commit/push.
Não houve segundo commit/push ou reexecução do CI nesta etapa.

Referências remotas homolog/main permaneceram:
homolog 7ca277175eab3e2cb5bdbd847a4638404803e452
main f29401eaabcdbc1827b0c187585cb4f657b23cb4

Nenhum PR, merge, deploy, alteração AWS/Kubernetes/SG ou publicação de evidência
foi realizado. Este registro é local e fica fora do próximo commit técnico.
