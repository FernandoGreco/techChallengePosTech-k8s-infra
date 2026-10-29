# ADR-001 — Grafana Cloud para observabilidade de Kubernetes

Status: implementação técnica adotada no laboratório; aceite arquitetural formal
da equipe não registrado.

## Contexto

O cluster kubeadm utiliza duas EC2 AWS Academy e capacidade limitada.
CPU/memória, saúde, logs e eventos devem ser observáveis sem manter servidores
adicionais de armazenamento de telemetria no cluster.

## Decisão

Utilizar Grafana Cloud Kubernetes Monitoring com Alloy pelo chart oficial
grafana/k8s-monitoring, em modo Lightweight. Manter Metrics Server para HPA/top.
Habilitar métricas de cluster/nós/pods, logs de containers e eventos explicitamente
nos values. Desabilitar Fleet paralelo e componentes opcionais não utilizados.

## Justificativa

Centralizar a telemetria no serviço gerenciado reduz o número de componentes
persistentes nas EC2. Configuração versionada e Secret externo permitem
reprodução sem credenciais no Git. A ferramenta é uma escolha livre dentro do
requisito de observabilidade do desafio.

## Consequências

Há dependência de saída HTTPS, credenciais externas e limites do plano contratado.
Logs precisam de tratamento de dados sensíveis. RBAC e leitura dos logs de host
requerem revisão; TLS de laboratório do kubelet não representa configuração de
produção.

Métricas de latência, traces, correlação e indicadores de ordens de serviço exigem
instrumentação da aplicação. A coleta de recursos/logs não os comprova.

## Comprovação

Métricas foram recebidas por API Cloud; logs/eventos têm confirmação manual no
destino. Não há comprovação de traces ou de disparo de alerta de negócio.

[Configuração](../observability/PLANO-GRAFANA.md) · [Evidências](../evidencias/INDEX.md)
