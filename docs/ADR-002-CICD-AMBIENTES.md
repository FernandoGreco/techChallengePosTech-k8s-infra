# ADR-002 — Ambientes independentes e aprovação de Apply

Status: implementado no código de infraestrutura.

## Contexto

Credenciais Academy são temporárias e a capacidade do Lab é limitada.
O cluster operacional deve ser preservado; produção não pode compartilhar seu
objeto de state ou presumir disponibilidade para outro par de EC2.

## Decisão

Selecionar homolog pela branch homolog e production pela main, reutilizando o CI.
Separar diretórios, chaves S3, Environments e tfvars.
Exigir confirmação externa de capacidade antes de Plan/Apply de produção.

Apply exige revisão humana e utiliza o plano salvo criptografado, vinculado a
ambiente, backend, conta, repositório, commit, run e tentativa. Revalidar conta,
integridade, idade e proteções após a aprovação. Bloquear exclusões, substituições
e alterações disruptivas de EC2. Manter ignore_changes de user_data.

Autorizar somente repositórios conhecidos: o destino padrão e o original mediante
variável explícita. Não aceitar destinos arbitrários por wildcard.

## Consequências

Início automático não equivale a Apply sem aprovação. Plano expirado, troca de
contexto ou state alterado exigem novo ciclo de planejamento/revisão.
Não há destruição automática de homolog para liberar quota.

Most_recent da AMI permanece; substituições são bloqueadas.
O workflow cobre Terraform, sem deploy NestJS nem join de um cluster novo.
Configuração própria e evidência de execução são necessárias para comprovar
produção operacional.

[CI/CD](CICD-HOMOLOG.md) · [Guia](../GUIA-EXECUCAO.md) · [Comprovação](../evidencias/CI-CD.md)
