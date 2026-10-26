# FIAP Tech Challenge — Infraestrutura Kubernetes AWS

Infraestrutura de homologacao do Tech Challenge: Terraform + Kubernetes kubeadm em duas instancias EC2 Ubuntu 24.04 (control plane e worker), Calico, containerd e Metrics Server. Utiliza VPC e subnet existentes na conta AWS Academy Learner Lab; nao usa EKS.

## Estrutura

- `environments/homolog/`: Terraform, data sources da VPC/subnets existentes e backend S3.
- `modules/security/`: Security Group com trafego interno e SSH restrito.
- `modules/ec2/`: duas EC2 e cloud-init para instalar Kubernetes.
- `scripts/deploy.sh`: plano, confirmacao, provisionamento, join e validacao Kubernetes.
- `scripts/validate-k8s.sh`: verificacao de nodes e pods por SSH.
- `scripts/destroy.sh`: destruicao confirmada dos recursos do estado remoto.
- `.github/workflows/terraform-validate.yml`: CI em branches e PRs.
- `.github/workflows/terraform-deploy.yml`: CD em `homolog` usando GitHub-hosted runner.
- `GUIA-EXECUCAO.md`: configuracao, cuidados, comandos e limites.

## Primeiros passos

1. Leia [GUIA-EXECUCAO.md](GUIA-EXECUCAO.md) antes de executar qualquer deploy.
2. Inicie AWS Academy, confira credenciais e a conta AWS.
3. Prepare bucket S3 e arquivo `environments/homolog/accounts/<ACCOUNT_ID>.tfvars` (nao versionado).
4. Configure `EXPECTED_AWS_ACCOUNT_ID`, `SSH_PRIVATE_KEY_PATH` e `SSH_USER` para uso local; ou Secrets/Variables do Environment `homolog` no GitHub.
5. Rode `bash scripts/deploy.sh` localmente, revise o plano e confirme `sim`; ou faca merge em `homolog` depois de configurar as protecoes e aprovar o deploy automatico.

## Limites

A pasta `environments/prod/` e apenas um placeholder; **nao ha producao implementada**. O deploy do aplicativo NestJS e de outro repositorio. Esta revisao nao executou `terraform apply` na AWS; os testes de integracao exigem a conta AWS Academy ativa.
