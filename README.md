# Tech Challenge FIAP — Infraestrutura Kubernetes na AWS

## 1. Objetivo

Provisionar a infraestrutura necessária para executar a aplicação de oficina mecânica do Tech Challenge da FIAP em um cluster Kubernetes na AWS.

A infraestrutura é definida utilizando Terraform e utiliza recursos disponíveis no ambiente AWS Academy Learner Lab.

## 2. Arquitetura

A solução utiliza Kubernetes autogerenciado em instâncias Amazon EC2, sem utilização do Amazon EKS.

**Componentes:**

- AWS VPC existente no laboratório.
- Duas instâncias EC2 Ubuntu 24.04.
- Control Plane Kubernetes, responsável pelo gerenciamento do cluster.
- Worker Node, responsável pela execução das aplicações.
- Security Group para comunicação interna entre os nós.
- Containerd como runtime de containers.
- Kubeadm para inicialização e associação dos nós.
- Calico como plugin de rede (CNI).
- Terraform para provisionamento da infraestrutura.
- GitHub Actions para validação contínua.

A arquitetura inicial utiliza duas instâncias `t3.medium`, com volumes EBS `gp3` de 20 GiB cada.

## 3. Estrutura do repositório

```text
.github/
  workflows/
    terraform-validate.yml

environments/
  homolog/
    main.tf
    variables.tf
    outputs.tf
    providers.tf
    versions.tf

  prod/

modules/
  ec2/
    main.tf
    variables.tf
    outputs.tf
    user-data/
      install-k8s.sh
      init-control-plane.sh
      install-cni.sh
      join-worker.sh
      control-plane.sh.tftpl
      worker.sh.tftpl

  network/
  security/

README.md
```

O ambiente `homolog` é o foco da implementação atual. A existência de diretórios para outros ambientes ou módulos não significa que estejam implementados.

## 4. Pré-requisitos

- Terraform compatível com a configuração do projeto.
- AWS CLI configurado com credenciais válidas.
- Git.
- Acesso ao AWS Academy Learner Lab.
- Permissões AWS para consultar a rede e provisionar os recursos necessários.

As credenciais do AWS Academy podem mudar a cada inicialização do laboratório.

**Nunca adicionar credenciais, tokens ou arquivos de estado Terraform ao Git.**

## 5. Configuração do Terraform

Acessar o diretório:

```bash
cd environments/homolog
```

Configurar o arquivo local `terraform.tfvars` com os identificadores do ambiente:

```hcl
aws_region = "us-east-1"

vpc_id = "ID_DA_VPC"

subnet_ids = [
  "ID_DA_SUBNET_1",
  "ID_DA_SUBNET_2"
]
```

Os valores devem corresponder aos recursos existentes na conta AWS utilizada.

## 6. Validação local

Inicializar o Terraform:

```bash
terraform init
```

Verificar a formatação:

```bash
terraform fmt -check -recursive
```

Validar a configuração:

```bash
terraform validate
```

Validar a sintaxe dos scripts:

```bash
bash -n ../../modules/ec2/user-data/install-k8s.sh
bash -n ../../modules/ec2/user-data/init-control-plane.sh
bash -n ../../modules/ec2/user-data/install-cni.sh
bash -n ../../modules/ec2/user-data/join-worker.sh
```

Esses comandos não criam recursos na AWS e não comprovam que o cluster funcionará após a implantação.

## 7. Provisionamento da infraestrutura

Com as credenciais AWS válidas e após verificar as permissões, a conectividade e o orçamento:

```bash
terraform plan -out=tfplan
```

Revisar os recursos planejados antes de aplicar:

```bash
terraform apply tfplan
```

Consultar os outputs:

```bash
terraform output
```

O provisionamento depende das permissões disponíveis no AWS Academy Learner Lab.

## 8. Inicialização do Kubernetes

O Terraform utiliza `user_data` para preparar as instâncias.

**Control Plane:**

1. Instala containerd e os componentes Kubernetes.
2. Executa `kubeadm init`.
3. Configura o acesso administrativo ao cluster.
4. Aplica o manifesto do Calico.
5. Aguarda a inicialização dos componentes de rede.

**Worker:**

1. Instala containerd e os componentes Kubernetes.
2. Prepara o ambiente para associação ao cluster.
3. Aguarda a execução do `kubeadm join`.

Na implementação atual, a associação do Worker é manual.

## 9. Associação do Worker

Após a inicialização do Control Plane, gerar o comando de associação diretamente na instância:

```bash
sudo kubeadm token create --print-join-command
```

Executar o comando gerado no Worker por meio de uma sessão administrativa segura.

Não armazenar o token no repositório, nos arquivos Terraform ou em mensagens compartilhadas.

## 10. Validação do cluster

No Control Plane:

```bash
sudo KUBECONFIG=/etc/kubernetes/admin.conf kubectl get nodes -o wide
```

Consultar os pods do sistema:

```bash
sudo KUBECONFIG=/etc/kubernetes/admin.conf kubectl get pods -n kube-system
```

O resultado esperado é que Control Plane e Worker estejam no estado `Ready`, após a instalação e configuração correta da rede.

## 11. Integração contínua

O GitHub Actions executa o workflow `Terraform Validate`.

As verificações incluem:

- Formatação Terraform.
- Inicialização sem backend remoto.
- Validação da configuração Terraform.
- Verificação de sintaxe dos scripts Bash.

A execução bem-sucedida do workflow não representa implantação na AWS.

A automação de implantação (CD) ainda não foi implementada neste repositório.

## 12. Limitações e pendências

Antes de considerar a infraestrutura operacional, ainda é necessário:

- Confirmar permissões e disponibilidade de recursos na AWS Academy.
- Validar as rotas da subnet e o acesso à internet.
- Definir o método seguro de acesso às EC2.
- Confirmar a compatibilidade entre Kubernetes e Calico.
- Verificar os CIDRs da VPC e da rede dos pods.
- Executar o provisionamento real.
- Inicializar o cluster e associar o Worker.
- Registrar evidências de funcionamento.
- Integrar o deploy da aplicação e a automação CD.

## 13. Destruição da infraestrutura

Após a conclusão dos testes, revisar o plano de destruição:

```bash
terraform plan -destroy
```

Se os recursos não forem mais necessários:

```bash
terraform destroy
```

Executar a destruição somente após confirmar que não existem dependências ou atividades de outros integrantes.

## 14. Projeto acadêmico

Infraestrutura desenvolvida como parte do Tech Challenge — Fase 3, Pós-Tech FIAP.

**Status atual:** estrutura Terraform e scripts preparados, validação local e GitHub Actions funcionando. Provisionamento e testes na AWS pendentes.