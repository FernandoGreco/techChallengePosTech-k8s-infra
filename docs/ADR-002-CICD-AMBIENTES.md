# ADR-002 — Ambientes independentes e aprovação de Apply

Status: implementado localmente; produção não executada remotamente.

## Contexto

Credenciais Academy são temporárias; capacidade do Lab é limitada. Preservar
homolog existente e não presumir recursos para outro par de EC2.

## Decisão

Reutilizar o fluxo protegido. Homolog seleciona homolog; main seleciona production.
Separar diretórios, chaves S3, Environments e tfvars. Validar ambos no CI.
Exigir confirmação externa de capacidade antes de Plan/Apply de produção.

Apply exige revisão humana e aplica o plano salvo criptografado, vinculado a
ambiente/backend/repositório/run/tentativa. Revalidar conta e proteções depois da
aprovação. Bloquear exclusões, substituições e alterações disruptivas de EC2.
Manter ignore_changes de user_data.

Autorizar o fork por padrão e o original conhecido somente com variável explícita;
não aceitar destinos arbitrários por wildcard.

## Consequências

Início automático não equivale a Apply sem aprovação. Plano expirado, troca de
credenciais/backend ou state alterado exigem novo ciclo/revisão.
Não há destruição automática de homolog para liberar quota.

Most_recent da AMI permanece inalterado; substituições continuam bloqueadas.
Workflow cobre Terraform, sem deploy NestJS nem join de um cluster novo.
Configurações remotas exigem autorização separada.

[Testes](VALIDACAO-LOCAL-CICD.md) · [Guia](../GUIA-EXECUCAO.md)
