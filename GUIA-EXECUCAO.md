# Guia de execucao e limites de validacao

## Situacao

- CI: `terraform-validate.yml` valida Terraform e scripts em PRs e branches configuradas.
- CD: `terraform-deploy.yml` executa na branch `homolog` (ou manualmente), usando `ubuntu-latest`.
- `runner-smoke-test.yml` foi removido porque usava runner Windows self-hosted, nao mais necessario.
- Estado remoto: S3 com `use_lockfile=true`, chave `homolog/terraform.tfstate`.
- **Producao ainda nao implementada**. A pasta `environments/prod` esta vazia; nao executar como se fosse um ambiente pronto.

## AWS Academy

1. Inicie o Learner Lab e obtenha novas credenciais temporarias.
2. Confira conta e regiao `us-east-1`; confirme VPC, subnet publica, key pair e quotas.
3. Crie o bucket S3 na conta (nome padrao `fiap-tc3-k8s-tfstate-<ACCOUNT_ID>`), com bloqueio publico, versionamento e criptografia.
4. Confirme que nao ha recursos Terraform existentes fora do estado S3 antes de aplicar.
5. As credenciais temporarias podem expirar durante a execucao; renove antes do teste.

## GitHub Environment `homolog`

**Secrets:** `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_SESSION_TOKEN`, `TFVARS_HOMOLOG`, `SSH_PRIVATE_KEY`.

**Variables:** `AWS_ACCOUNT_ID` (12 digitos), `AUTO_APPROVE_DEPLOY` (`true` para permitir apply automatizado). Opcional `TF_BACKEND_BUCKET` (se o bucket nao seguir o padrao acima).

Restrinja o Environment `homolog` a branch `homolog`. Antes de habilitar `AUTO_APPROVE_DEPLOY=true`, revise o plano e valide o custo e a configuracao. **Push na branch `homolog` pode criar ou alterar EC2 automaticamente.**

O secret `TFVARS_HOMOLOG` contem as variaveis HCL do ambiente, incluindo `vpc_id`, `subnet_ids`, `ssh_key_name` e `ssh_allowed_cidr` (IP publico do operador em `/32`). `SSH_PRIVATE_KEY` deve corresponder ao key pair. Nao versionar esses valores.

## Execucao local (Git Bash)

Na raiz do repositorio, com AWS CLI autenticado:

```bash
export EXPECTED_AWS_ACCOUNT_ID="<ACCOUNT_ID>"
export SSH_PRIVATE_KEY_PATH="/c/caminho/para/labsuser.pem"
export SSH_USER="ubuntu"
# Opcional: export TF_BACKEND_BUCKET="nome-do-bucket"
bash scripts/deploy.sh
```

Criar antes `environments/homolog/accounts/<ACCOUNT_ID>.tfvars` localmente. O script mostra o plano e exige resposta `sim` antes de aplicar. Para verificar o cluster novamente: `bash scripts/validate-k8s.sh`. Para excluir os recursos gerenciados pelo estado remoto: `bash scripts/destroy.sh` (exige `DESTRUIR`).

## Limites e cuidados

- O script de deploy conecta por SSH ao control plane e worker e executa kubeadm, Calico e Metrics Server. A validacao final ocorre antes de revogar o acesso SSH temporario do runner.
- O Security Group ja possui regra SSH para `ssh_allowed_cidr`. GitHub Actions adiciona outra regra temporaria e tenta removê-la mesmo em caso de erro. Verifique manualmente o Security Group caso haja falha na revogacao.
- `--kubelet-insecure-tls` no Metrics Server foi adotado apenas para laboratorio kubeadm. Para producao, configurar certificados de kubelet adequados.
- A automacao **nao faz deploy da aplicacao NestJS**; isso pertence ao repositorio da aplicacao.
- Nenhum deploy AWS real foi executado durante esta revisao. A instalacao completa e a compatibilidade com as politicas do Learner Lab precisam ser testadas na conta.
- Para conta de outro integrante, crie um bucket S3 independente, atualize os secrets/vars do repositorio e valide o estado remoto antes do primeiro apply.
