# Arquitetura da infraestrutura

[Diagrama de componentes](../README.md#2-arquitetura).
Kubernetes kubeadm em EC2, não EKS.

| Componente | Responsabilidade |
| --- | --- |
| Terraform | SG/regras e duas EC2; reutiliza VPC/subnet/Key Pair |
| S3 | State/lock independentes em homolog/ e production/ |
| Control Plane | API Server, etcd, scheduler e controllers |
| Worker | Workloads e kubelet |
| containerd / Calico | Runtime e rede dos Pods |
| Metrics Server | Resource metrics para HPA e kubectl top |
| Alloy / Grafana Cloud | Métricas, logs e eventos |
| GHCR | Imagem NestJS privada por digest |
| PostgreSQL demonstrativo | Banco interno efêmero sem PVC/exposição pública |

## Provisionamento e bootstrap

Cloud-init instala os componentes; o Control Plane inicializa kubeadm/Calico.
O Worker recebe os componentes, mas seu join é realizado pelo orquestrador local
de homolog. Metrics Server é instalado após o join.
O workflow aplica somente Terraform e não chama esse orquestrador.

Ignore_changes de user_data preserva as instâncias existentes; não propaga
atualizações futuras de bootstrap. O guard bloqueia substituições e mudanças
disruptivas. Essas barreiras não substituem backup e manutenção planejada.

## Aplicação demonstrada

Namespace oficina-tc3, API com uma réplica inicial e HPA 1–2/70% CPU.
Requests 100m/256Mi, limits 500m/512Mi e startup node dist/main.js.
Job separado preparou dez tabelas sem seed. PostgreSQL tem Service ClusterIP
e emptyDir; remoção/substituição do Pod pode apagar dados.

Os manifests pertencem ao
[repositório da aplicação](https://github.com/felipevrds/techChallengePosTech-Aplication/tree/feature/deploy-kubernetes/k8s/homolog).
RDS, Lambda e API Gateway não são integrações comprovadas por essa demonstração.
O [catálogo de evidências](../evidencias/INDEX.md) delimita o que foi verificado.

## Disponibilidade e ambientes

Control Plane único, Worker único e TLS de laboratório não representam alta
disponibilidade/produção validada. HPA aumenta Pods, não EC2.

Produção possui configuração independente, nomes/tags próprios e outra chave
de state. Compartilhar bucket não significa compartilhar state. State novo não
promove dados, migra banco ou adota automaticamente instâncias existentes.

[Decisões de CI/CD](ADR-002-CICD-AMBIENTES.md) · [Execução](../GUIA-EXECUCAO.md)
