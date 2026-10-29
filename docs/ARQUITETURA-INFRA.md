# Arquitetura da infraestrutura

[Diagrama de componentes](../README.md#2-arquitetura).
Kubernetes kubeadm em EC2, não EKS.

| Componente | Papel |
| --- | --- |
| Terraform | SG/regras e duas EC2; reutiliza VPC/subnet/Key Pair |
| S3 | State/lock independentes em homolog/ e production/ |
| Control Plane | API Server, etcd, scheduler e controllers |
| Worker | Workloads e kubelet |
| containerd / Calico | Runtime e rede dos Pods |
| Metrics Server | Resource metrics para HPA e kubectl top |
| Alloy / Grafana Cloud | Métricas, logs e eventos |
| GHCR | Imagem NestJS privada por digest |
| PostgreSQL demo | Banco interno efêmero sem PVC/exposição pública |

## Ciclo de vida

Cloud-init instala componentes; Control Plane inicializa kubeadm/Calico.
Worker recebe os componentes, mas o join é realizado pelo orquestrador local de
homolog. Metrics Server é instalado após o join. O workflow aplica só Terraform;
não chama esse orquestrador.

Ignore_changes de user_data preserva as instâncias existentes; não aplica
atualizações futuras de bootstrap. O guard bloqueia substituições e mudanças
disruptivas. Isso não substitui backup e manutenção planejada.

## Demonstração

Namespace oficina-tc3; API com uma réplica inicial, HPA 1–2/70% CPU,
requests 100m/256Mi e limits 500m/512Mi. Startup node dist/main.js.
Job separado preparou dez tabelas sem seed. PostgreSQL possui Service ClusterIP
e emptyDir: substituição/remoção do Pod pode apagar os dados.

Os manifests estão no
[fork da aplicação](https://github.com/felipevrds/techChallengePosTech-Aplication/tree/feature/deploy-kubernetes/k8s/homolog).
RDS/Lambda/API Gateway não são integrações comprovadas pela demo.
Traces e sinais de negócio exigem documentação/instrumentação da equipe.

Control Plane único, Worker único e TLS de laboratório não representam alta
disponibilidade/produção validada. HPA aumenta Pods, não EC2.

## Produção

Configuração independente, nomes/tags próprios e outra chave do state.
Compartilhar bucket não significa compartilhar state. State novo não promove
dados, migra banco nem adota automaticamente instâncias existentes.
