# Evidências técnicas

Cada registro identifica seu alcance e a data de coleta/confirmação.
Uma observação histórica não garante o estado atual do ambiente.
Confirmações manuais não são apresentadas como resultados automatizados.

## Fechamento de 29/10/2026

- [Homologação](../docs/EVIDENCIAS-HOMOLOG.md): Plan/Apply históricos recuperados,
  consultas AWS e Kubernetes atual, sem repetir carga.
- [Produção](../docs/EVIDENCIAS-PRODUCAO.md): Apply aprovado, confirmação EC2/EBS/SG/S3
  e bootstrap Kubernetes com dois nós Ready, Metrics Server TLS e HPA sintético.
- [Saídas reais de produção](2026-10-29-producao-kubernetes-hpa.txt): escala 1→2→1,
  carga encerrada, contadores HTTP com timeouts e preservação de homologação.
- [CI/CD e checklist FIAP](../docs/CI-CD.md): fontes primárias e alcance por requisito.

As saídas originais abaixo foram preservadas. Seus resultados mantêm a data
original; não foram convertidos em validações novas.

## Infraestrutura e Kubernetes

| Arquivo | Comprovação |
| --- | --- |
| [Kubernetes/HPA](2026-10-27-kubernetes-hpa.txt) | Nós Ready, Calico, Metrics Server e laboratório sintético 1→4→1 |
| [Idempotência Metrics Server](2026-10-27-metrics-idempotencia.txt) | Spec preservada após reexecução autorizada e API disponível |
| [Implantação da aplicação](tc3-deploy-resultado-local.json) | Identidade/região registradas, nós, schema, NestJS, Swagger e PostgreSQL temporário |
| [HPA da aplicação](HPA-APLICACAO.md) | Configuração 1–2 e resultado de carga com origem manual identificada |

O PostgreSQL demonstrado usa emptyDir, não RDS. HPA escala Pods, não EC2.

## Observabilidade

| Arquivo | Comprovação |
| --- | --- |
| [Agentes no cluster](2026-10-27-grafana-cluster.txt) | Saúde e consumo instantâneo de Alloy/componentes |
| [API Cloud](2026-10-27-grafana-cloud-api.json) | Métricas de nós/Pods recentes recebidas |
| [Permissões](2026-10-27-grafana-rbac.txt) | Verificações seletivas de RBAC |
| [Logs/eventos](2026-10-27-grafana-validacao-manual.md) | Confirmação manual de logs e eventos no Loki |
| [Métricas da API](tc3-deploy-observabilidade-local.json) | Séries CPU/memória da aplicação; readiness sem série nessa consulta |
| [Logs da API](tc3-deploy-loki-confirmacao-manual-local.json) | Logs NestJS recentes confirmados manualmente no destino, sem captura |

Respostas 401 de leitura por scope insuficiente permanecem registradas e não
invalidam por si só o envio de dados. Traces não foram comprovados.
O marcador de teste não comprova JSON/correlação de logs de negócio.

## CI/CD

[CI-CD.md](CI-CD.md) apresenta referências de execuções documentadas, os controles
de aprovação protegida e a distinção entre testes locais e confirmação manual
do Apply no catálogo anterior. As consultas atuais e a execução real de produção
estão no [fechamento de CI/CD](../docs/CI-CD.md).

## Integridade e privacidade

Datas, versões, digest da imagem e identificadores que contextualizam as coletas
são metadados técnicos, não credenciais. Não publicar tokens, tfvars reais,
kubeconfig, chaves, state ou planos. Os originais dos registros consolidados são
preservados localmente; não são dependências da reprodução.

[README](../README.md) · [Arquitetura](../docs/ARQUITETURA-INFRA.md)
