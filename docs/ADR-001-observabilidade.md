# ADR-001 — Grafana Cloud para observabilidade de Kubernetes
Status: proposta de decisão; requer aceite do grupo

Implementação técnica concluída no laboratório: métricas por API, logs/eventos
confirmados manualmente no Cloud. O status de aceite arquitetural do grupo não
foi presumido. Ver [evidências](../evidencias/INDEX.md).

## Contexto
Tech Challenge fase 3, duas EC2 AWS Academy com Kubernetes kubeadm.
Monitorar saúde, CPU, memória, alertas, logs e APIs sem sobrecarregar
o cluster acadêmico.

## Decisão
Usar **Grafana Cloud Kubernetes Monitoring**, com **Alloy** instalado
pelo chart oficial `grafana/k8s-monitoring`, e manter Metrics Server
para o HPA. Selecionar implantação **Lightweight**.

## Motivos
Menos serviços persistentes na EC2; métricas, logs e alertas em um
portal; instalação guiada pelo fornecedor. Datadog e New Relic são
alternativas aceitas, mas não obrigatórias pelo desafio.

## Consequências e riscos
Requer conta externa e token; plano gratuito tem limites; depende
de saída HTTPS; dados sensíveis dos logs precisam ser tratados.
Métricas de latência, traces e indicadores de ordens de serviço
dependem de instrumentação da aplicação, fora do escopo de
Terraform/Kubernetes isoladamente.

## Validação
Só marcar concluído após ver telemetria real no portal, teste de
alerta e evidência de HPA com réplicas adicionais.
