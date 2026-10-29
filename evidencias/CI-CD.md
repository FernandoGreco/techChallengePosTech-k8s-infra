# Evidência de CI/CD da infraestrutura

## Escopo e fontes

Este registro consolida resultados já documentados. As URLs abaixo identificam
execuções históricas; não representam novas consultas ao GitHub.
Os controles do workflow são descritos separadamente de sua execução.

## Execuções documentadas

| Verificação | Referência | Resultado e alcance |
| --- | --- | --- |
| Terraform Validate | [Run 40536574137](https://github.com/felipevrds/techChallengePosTech-k8s-infra/actions/runs/40536574137) | Success no commit d4c82c95259c7d433c12bf753dc81b4ba1ffd5de |
| CI/Plan de homologação | [Run 40560618869](https://github.com/felipevrds/techChallengePosTech-k8s-infra/actions/runs/40560618869) | Success registrado no [resultado da implantação](tc3-deploy-resultado-local.json); não comprova o Apply final |

O primeiro registro informa aprovação de fmt, init sem backend, validate,
sintaxe Bash, PowerShell AST, testes Node, actionlint, manifests e Helm.
Seu alcance é o commit indicado, não o código posterior de produção.

## Controles de aprovação

[terraform-deploy.yml](../.github/workflows/terraform-deploy.yml) reutiliza CI,
salva o plano, aplica os guards, criptografa o artefato e encaminha Apply para
homolog-apply ou production-apply. Não há novo Plan no job Apply.

O guard exige reviewers, bloqueio de bypass administrativo e branch exclusiva.
Conta, contexto do artefato e idade são revalidados após a espera.
O [registro de implantação](tc3-deploy-resultado-local.json) também informa
proteção de homolog/main, check Validate infrastructure, aprovação obrigatória e
bypass administrativo desabilitado. É um registro datado, não consulta atual.

A implementação de produção corresponde ao commit técnico
85c39dd15237063ebcf8b44615738a126623f2e0.
A validação local documentada aprovou 17 testes de segurança, actionlint e
Terraform Validate dos dois ambientes sem backend. Testes locais não equivalem
a execução de produção no GitHub ou a cluster de produção operacional.

## Confirmação manual de Apply

O responsável confirmou Apply de homologação bem-sucedido após aprovação humana,
com zero alterações planejadas. Essa informação tem origem manual.
Não há URL ou saída primária desse Apply final no catálogo disponível.
Não atribuir a confirmação ao run 40560618869 nem fabricar mensagem de log.

## Interpretação

O fluxo começa automaticamente no push homolog/main, mas Apply depende de
aprovação humana. Produção exige confirmação de capacidade e configuração própria.
As evidências deste catálogo não comprovam execução remota de produção nem
deploy automatizado da aplicação.

[Configuração operacional](../docs/CICD-HOMOLOG.md) · [Índice](INDEX.md)
